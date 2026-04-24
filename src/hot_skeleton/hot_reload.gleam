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
//// CSS: [glailglind](https://github.com/okkdev/glailglind) installs the Tailwind
//// CLI, compiles to [`css_path_string`], and recompiles on every [radiate]
//// reload (same watcher as Gleam, no separate `tailwind --watch` process).
//// Input is `./app.tailwind.css` when that file exists, otherwise a generated
//// [`default_tailwind_input_path`]. For `gleam run -m tailwind/run`, match
//// `[tools.tailwind] args` to that entry (`-i=./app.tailwind.css` or, without
//// that file, `-i=./.hot_skeleton/tailwind-input.css` once it exists).

import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string
import radiate
import simplifile
import tailwind

const default_tailwind_input_rel = ".hot_skeleton/tailwind-input.css"

const default_tailwind_input_source = "@import \"tailwindcss\";\n"

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
  let _ = bootstrap_tailwind()
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
      rebuild_tailwind("watch " <> path)
      Nil
    })
    |> radiate.start()
  handler
}

/// Always `True` when the app uses dev [`wrap`]: CSS is built to
/// `.hot_skeleton/tailwind.css` so `/app.css` can serve the latest compile.
pub fn tailwind_enabled() -> Bool {
  True
}

/// Host input when `./app.tailwind.css` is missing: created at bootstrap with
/// a minimal v4 import so Tailwind does not need a user-owned entry file.
pub fn default_tailwind_input_path() -> String {
  default_tailwind_input_rel
}

/// Same as `[tools.tailwind] args` in the host app’s `gleam.toml` — keep them aligned.
fn tailwind_cli_args() -> List(String) {
  let input = case simplifile.is_file("app.tailwind.css") {
    Ok(True) -> "./app.tailwind.css"
    _ -> "./" <> default_tailwind_input_rel
  }
  ["-i=" <> input, "-o=./.hot_skeleton/tailwind.css"]
}

fn ensure_default_tailwind_input() -> Nil {
  case simplifile.is_file("app.tailwind.css") {
    Ok(True) -> Nil
    _ -> {
      let _ = simplifile.create_directory_all(".hot_skeleton")
      case simplifile.is_file(default_tailwind_input_rel) {
        Ok(True) -> Nil
        _ -> {
          let _ =
            simplifile.write(
              default_tailwind_input_rel,
              default_tailwind_input_source,
            )
          Nil
        }
      }
    }
  }
}

/// Install CLI if needed, ensure input file, one compile, log result.
fn bootstrap_tailwind() {
  let _ = ensure_default_tailwind_input()
  let _ = simplifile.create_directory_all(".hot_skeleton")
  case tailwind.install() {
    Error(msg) -> io.println(msg)
    Ok(Nil) -> Nil
  }
  rebuild_tailwind("bootstrap")
  Nil
}

/// Run Tailwind CLI; log to the console on success (CLI output) or on error.
fn rebuild_tailwind(reason: String) {
  case tailwind.run(tailwind_cli_args()) {
    Error(msg) -> {
      io.println("Tailwind rebuild failed (" <> reason <> "): " <> msg)
    }
    Ok(out) -> {
      let trimmed = string.trim(out)
      case trimmed {
        "" ->
          io.println("Tailwind compiled (" <> reason <> "): .hot_skeleton/tailwind.css")
        _ -> io.println("Tailwind compiled (" <> reason <> "): " <> trimmed)
      }
    }
  }
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

