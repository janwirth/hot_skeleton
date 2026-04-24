//// Hot reloading — end-to-end feature test driving Chrome with chrobot.
////
//// Scenario (Gherkin / dream_test inline DSL):
////
////   Given the dev server is running on port 8080
////   And a browser is opened on the counter page
////   Then the count shows 0                       # fresh init
////   When I click the + button
////   Then the count shows 1                       # original +1 applied
////   When I edit counter.gleam so that clicking + increments by 2
////   Then the count shows 1                       # state preserved across hot swap
////   When I click the + button
////   Then the count shows 3                       # 1 + 2 using new code on old state
////
//// This verifies radiate's core feature: the BEAM VM loads the new
//// `counter` module *without* tearing down the running
//// lustre-server-component actor. The WebSocket stays open, the
//// in-memory model survives, and the next `update` call dispatches
//// into the new module.
////
//// The server is started inside the test VM via [`component_wrapper`](../../src/hot_skeleton/component_wrapper.gleam)
//// wrapped with [`hot_reload`](../../src/hot_skeleton/hot_reload.gleam) —
//// a radiate watcher that (unlike mist_reload) does *not* refresh the
//// browser. It feeds radiate an absolute path so fsevents fires on
//// macOS.
////
//// `src/examples/counter.gleam` is restored to its original content
//// after the scenario finishes.

import chrobot
import dream_test/assertions/should.{or_fail_with, should}
import dream_test/gherkin/feature.{and, feature, given, scenario, then, when}
import dream_test/gherkin/steps.{
  type StepContext, get_int, given as def_given, new_registry, then_ as def_then,
  when_ as def_when,
}
import dream_test/gherkin/world
import dream_test/matchers/equality.{equal}
import dream_test/types.{type AssertionResult, type TestSuite, AssertionOk}
import examples/counter
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import hot_skeleton/component_wrapper
import simplifile

const counter_path = "src/examples/counter/logic.gleam"

const base_url = "http://localhost:8080"

pub fn tests() -> TestSuite {
  let registry =
    new_registry()
    |> def_given("the dev server is running on port {int}", step_start_server)
    |> def_given("a browser is opened on the counter page", step_open_browser)
    |> def_when("I click the + button", step_click_plus)
    |> def_then("the count shows {int}", step_assert_count)
    |> def_when(
      "I edit counter.gleam so that clicking + increments by {int}",
      step_modify_counter,
    )
    |> def_then(
      "counter.gleam is restored and the browser is closed",
      step_cleanup,
    )

  feature("Hot Reloading", registry, [
    scenario("Source edits hot-swap into the running actor, state survives", [
      given("the dev server is running on port 8080"),
      and("a browser is opened on the counter page"),
      then("the count shows 0"),
      when("I click the + button"),
      then("the count shows 1"),
      when("I edit counter.gleam so that clicking + increments by 2"),
      then("the count shows 1"),
      when("I click the + button"),
      then("the count shows 3"),
      and("counter.gleam is restored and the browser is closed"),
    ]),
  ])
}

// ============================================================================
// Steps
// ============================================================================

fn step_start_server(ctx: StepContext) -> AssertionResult {
  let assert Ok(port) = get_int(ctx.captures, 0)
  let _ = ensure_server_started(port)
  // First `gleam test` can block on `tailwind/install` (CLI download) before the port opens.
  wait_for_server(port, 200)
  AssertionOk
}

fn step_open_browser(ctx: StepContext) -> AssertionResult {
  let assert Ok(browser) = chrobot.launch()
  let assert Ok(page) = chrobot.open(browser, base_url, 15_000)
  let assert Ok(_) = chrobot.await_selector(page, "lustre-server-component")
  // Wait until the shadow DOM has rendered the counter buttons.
  let _ = poll_until(page, count_buttons_js, "2", 40)

  world.put(ctx.world, "browser", browser)
  world.put(ctx.world, "page", page)
  // Snapshot the file contents into persistent_term so cleanup survives
  // whatever runtime weirdness happens between steps.
  pt_put("hot_skeleton_counter_original", read_file(counter_path))
  AssertionOk
}

fn step_modify_counter(ctx: StepContext) -> AssertionResult {
  let assert Ok(new_inc) = get_int(ctx.captures, 0)
  let original: String = pt_get_default("hot_skeleton_counter_original", "")
  let rewritten = rewrite_increment(original, int.to_string(new_inc))
  let _ = simplifile.write(counter_path, rewritten)

  // Wait for radiate → `gleam build` → purge+atomic_load → mist_reload SSE
  // broadcast → `window.location.reload()`. The full cycle takes a few
  // seconds; tune the sleep upward if CI is slow.
  process.sleep(8000)
  AssertionOk
}

fn step_click_plus(ctx: StepContext) -> AssertionResult {
  let assert Ok(page) = world.get(ctx.world, "page")
  // Make sure the component (re-)mounted — after the auto-reload it takes a
  // moment before the shadow DOM has buttons again.
  let _ = poll_until(page, count_buttons_js, "2", 40)
  let _ = eval_to_string(page, click_plus_js)
  AssertionOk
}

fn step_assert_count(ctx: StepContext) -> AssertionResult {
  let assert Ok(expected) = get_int(ctx.captures, 0)
  let assert Ok(page) = world.get(ctx.world, "page")

  // Give the server component time to push the patch back over the websocket.
  let _ = poll_until(page, count_text_js, expected_text(expected), 40)
  let actual = eval_to_string(page, count_text_js)

  let result =
    should(actual)
    |> equal(expected_text(expected))
    |> or_fail_with(
      "Expected `" <> expected_text(expected) <> "`, got `" <> actual <> "`",
    )

  // Defensive cleanup: if an assertion fails mid-scenario, make sure we
  // don't leave `counter.gleam` rewritten or Chrome dangling.
  case result {
    AssertionOk -> result
    _ -> {
      restore_counter()
      shutdown_browser(ctx)
      result
    }
  }
}

fn step_cleanup(ctx: StepContext) -> AssertionResult {
  restore_counter()
  shutdown_browser(ctx)
  AssertionOk
}

// ============================================================================
// Dev server (spawned once per VM)
// ============================================================================

@external(erlang, "persistent_term", "put")
fn pt_put(key: String, value: a) -> Nil

@external(erlang, "persistent_term", "get")
fn pt_get_default(key: String, default: a) -> a

fn ensure_server_started(port: Int) -> Nil {
  // An external `gleam dev` may already be serving on this port. In that
  // case we piggy-back on it — it has its own mist_reload + radiate loop
  // that will hot-swap the counter module when the file changes.
  case tcp_connect(port) {
    True -> Nil
    False ->
      case pt_get_default("hot_skeleton_dev_server", False) {
        True -> Nil
        False -> {
          pt_put("hot_skeleton_dev_server", True)
          let _ =
            process.spawn(fn() {
              component_wrapper.start_hot_server_with_wrap(
                counter.component,
                port,
                fn(h) { h },
                None,
              )
            })
          Nil
        }
      }
  }
}

fn wait_for_server(port: Int, attempts: Int) -> Nil {
  case attempts {
    0 -> Nil
    _ -> {
      case tcp_connect(port) {
        True -> Nil
        False -> {
          process.sleep(250)
          wait_for_server(port, attempts - 1)
        }
      }
    }
  }
}

@external(erlang, "hot_skeleton_test_ffi", "tcp_connect")
fn tcp_connect(port: Int) -> Bool

// ============================================================================
// Counter rewriting
// ============================================================================

fn read_file(path: String) -> String {
  result.unwrap(simplifile.read(path), "")
}

/// Replace the integer after `UserClickedIncrement -> model + ` with `new`.
fn rewrite_increment(source: String, new: String) -> String {
  let prefix = "UserClickedIncrement -> model + "
  case string.split_once(source, prefix) {
    Ok(#(before, tail)) -> before <> prefix <> new <> drop_leading_digits(tail)
    Error(_) -> source
  }
}

fn drop_leading_digits(s: String) -> String {
  case string.pop_grapheme(s) {
    Ok(#(c, rest)) ->
      case is_digit(c) {
        True -> drop_leading_digits(rest)
        False -> s
      }
    Error(_) -> s
  }
}

fn is_digit(c: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], c)
}

// ============================================================================
// Browser automation helpers
// ============================================================================

/// JS expression: number of buttons in the lustre-server-component shadow root.
const count_buttons_js = "String(document.querySelector('lustre-server-component').shadowRoot.querySelectorAll('button').length)"

/// JS expression: click the `+` button (second of two buttons).
const click_plus_js = "document.querySelector('lustre-server-component').shadowRoot.querySelectorAll('button')[1].click(); 'ok'"

/// JS expression: the `Count: N` paragraph text from the shadow root.
const count_text_js = "document.querySelector('lustre-server-component').shadowRoot.querySelector('p').innerText"

fn expected_text(n: Int) -> String {
  "Count: " <> int.to_string(n)
}

fn eval_to_string(page, js: String) -> String {
  case chrobot.eval_to_value(page, js) {
    Ok(remote) ->
      case remote.value {
        Some(dyn) ->
          decode.run(dyn, decode.string)
          |> result.unwrap("")
        None -> ""
      }
    Error(_) -> ""
  }
}

fn poll_until(page, js: String, expected: String, attempts: Int) -> Bool {
  case attempts {
    0 -> False
    _ ->
      case eval_to_string(page, js) == expected {
        True -> True
        False -> {
          process.sleep(250)
          poll_until(page, js, expected, attempts - 1)
        }
      }
  }
}

fn restore_counter() -> Nil {
  let original: String = pt_get_default("hot_skeleton_counter_original", "")
  case original {
    "" -> Nil
    other -> {
      let _ = simplifile.write(counter_path, other)
      Nil
    }
  }
}

fn shutdown_browser(ctx: StepContext) -> Nil {
  case world.get(ctx.world, "browser") {
    Ok(browser) -> {
      let _ = chrobot.quit(browser)
      Nil
    }
    Error(_) -> Nil
  }
}
