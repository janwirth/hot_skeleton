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

import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string
import radiate

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

fn absolute_src_dir() -> String {
  let cwd = get_cwd()
  case string.ends_with(cwd, "/") {
    True -> cwd <> "src"
    False -> cwd <> "/src"
  }
}

@external(erlang, "hot_skeleton_hot_reload_ffi", "cwd")
fn get_cwd() -> String
