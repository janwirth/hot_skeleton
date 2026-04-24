//// Hot-reload wrapper for dev. Uses [radiate](https://hexdocs.pm/radiate)
//// to watch `<cwd>/src` and hot-swap modified modules into the running
//// BEAM VM — **without restarting the node and without refreshing the
//// browser**.
////
//// Lustre stores `update`/`view` as function references in the runtime
//// actor's state. For hot-swap to take effect on the next message, those
//// references must be **cross-module** (external) fun refs — Erlang's
//// external funs dispatch through the code server on every call.
//// Gleam compiles *same-module* references as *local* fun refs, which
//// are pinned to the module version at capture time and therefore never
//// pick up new code. See [`examples/counter`](../examples/counter.gleam)
//// for the split-module pattern that makes `update` hot-swappable.
////
//// On macOS, `radiate.add_dir` needs `"."` or an absolute path or
//// fsevents will silently do nothing. We always resolve the project
//// root via `file:get_cwd/0` and pass the absolute `<cwd>/src`.
////
//// Optional CSS: if `./app.tailwind.css` exists in the **application cwd**
//// (the directory you run `gleam` from), [glailglind](https://github.com/okkdev/glailglind)
//// installs the CLI, runs a build, and starts `--watch`. Add `[tools.tailwind]`
//// in that app’s `gleam.toml` and keep its `args` in sync with
//// [`tailwind_cli_args`]. Apps without that file skip Tailwind entirely.

import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import radiate
import simplifile
import tailwind

/// Start the radiate file watcher and return the handler unchanged. No
/// SSE endpoint, no HTML injection, no client-side reload script — the
/// reload is a pure BEAM code swap and in-memory state is preserved
/// across it.
///
/// If `after_modules_loaded` is [`Some`], it runs after `code:atomic_load`
/// (for example to [`lustre.dispatch`](https://hexdocs.pm/lustre/lustre.html#dispatch)
/// so a singleton server component re-runs `view` with the new code — new
/// WebSocket clients otherwise receive a stale cached vdom.
pub fn wrap(handler: a, after_modules_loaded: Option(fn() -> Nil)) -> a {
  let _ = case tailwind_enabled() {
    True -> bootstrap_tailwind()
    False -> Nil
  }
  let src_dir = absolute_src_dir()
  let _ =
    radiate.new()
    |> radiate.add_dir(src_dir)
    |> radiate.on_reload(fn(_state, path) {
      io.println("Change in " <> path <> ", reloading.")
      case after_modules_loaded {
        Some(f) -> f()
        None -> Nil
      }
      Nil
    })
    |> radiate.start()
  handler
}

/// `True` when `./app.tailwind.css` is present in cwd (i.e. this app uses Tailwind).
pub fn tailwind_enabled() -> Bool {
  case simplifile.is_file("app.tailwind.css") {
    Ok(True) -> True
    _ -> False
  }
}

/// Same as `[tools.tailwind] args` in the host app’s `gleam.toml` — keep them aligned.
fn tailwind_cli_args() -> List(String) {
  ["-i=./app.tailwind.css", "-o=./.hot_skeleton/tailwind.css"]
}

fn bootstrap_tailwind() {
  let _ = simplifile.create_directory_all(".hot_skeleton")
  case tailwind.install() {
    Error(msg) -> io.println(msg)
    Ok(Nil) -> Nil
  }
  case tailwind.run(tailwind_cli_args()) {
    Error(msg) -> io.println(msg)
    Ok(_) -> Nil
  }
  let wargs = list.append(tailwind_cli_args(), ["--watch"])
  let _ =
    process.spawn(fn() {
      case tailwind.run(wargs) {
        Error(msg) -> io.println(msg)
        Ok(_) -> Nil
      }
    })
  Nil
}

fn absolute_src_dir() -> String {
  let cwd = get_cwd()
  case string.ends_with(cwd, "/") {
    True -> cwd <> "src"
    False -> cwd <> "/src"
  }
}

@external(erlang, "hot_skeleton_hot_reload_ffi", "cwd")
fn get_cwd() -> String

@external(erlang, "hot_skeleton_hot_reload_ffi", "css_path_string")
pub fn css_path_string() -> String

@external(erlang, "hot_skeleton_hot_reload_ffi", "css_cache_bust")
pub fn css_cache_bust() -> String
