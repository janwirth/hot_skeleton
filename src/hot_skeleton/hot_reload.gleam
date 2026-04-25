//// Hot-reload wrapper for dev. Uses [radiate](https://hexdocs.pm/radiate)
//// to watch `<cwd>/src` and hot-swap modified modules into the running
//// BEAM VM — **without restarting the node** and without a full page reload
//// for Gleam (Lustre hot-swap). New Tailwind output is signalled to the
//// browser out-of-band (see the companion `/__hot_css` WebSocket in
//// `component_wrapper`) so `/app.css`’s `?t=` cache-bust can update
//// in place.
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
//// CLI. A **long-running** `tailwindcss -w=always` process (see
//// [`start_tailwind_watch` in the FFI](hot_skeleton_hot_reload_ffi.erl)) streams
//// stdout; when a line contains `Done in`, the host runs [`after_tailwind_rebuilt`]
//// after [`wait_for_css_write_complete`]. **Radiate reloads are only for BEAM
//// code** — they do not re-run the Tailwind CLI, so changing `.gleam` is no
//// longer charged a full ~1s Tailwind spawn per save.
//// Input is `./app.tailwind.css` when that file exists, otherwise a generated
//// [`default_tailwind_input_path`]. For `gleam run -m tailwind/run`, match
//// `[tools.tailwind] args` to that entry (`-i=./app.tailwind.css` or, without
//// that file, `-i=./.hot_skeleton/tailwind-input.css` once it exists).

import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string
import radiate
import simplifile
import tailwind

const default_tailwind_input_rel = ".hot_skeleton/tailwind-input.css"

const default_tailwind_input_source = "@import \"tailwindcss\";\n"

/// Path to the CLI installed by [tailwind.install] (same as [glailglind]’s
/// [tailwind] module).
const tailwind_cli_exe = "./build/bin/tailwindcss"

/// Start the radiate file watcher and return the handler unchanged. The
/// reload is a pure BEAM code swap; in-memory state is preserved.
///
/// If `after_modules_loaded` is [`Some`], it runs after `code:atomic_load`
/// (for example to [`lustre.dispatch`](https://hexdocs.pm/lustre/lustre.html#dispatch)
/// so a singleton server component re-runs `view` with the new code — new
/// WebSocket clients otherwise receive a stale cached vdom.
///
/// If `after_tailwind_rebuilt` is [`Some`], it runs when the Tailwind **watch**
/// process prints a `Done in …` line (FFI) and the output file is stable on
/// disk (see `wait_for_css_write_complete` in the FFI) — e.g. push `?t=` to
/// `/__hot_css`.
pub fn wrap(
  handler: a,
  after_modules_loaded: Option(fn() -> Nil),
  after_tailwind_rebuilt: Option(fn() -> Nil),
) -> a {
  let _ = bootstrap_tailwind()
  start_tailwind_watcher(after_tailwind_rebuilt)
  let src_dir = absolute_src_dir()
  let _ =
    radiate.new()
    |> radiate.add_dir(src_dir)
    |> radiate.on_reload(fn(_state, path) {
      let t_handler0 = monotonic_ms()
      io.println("Change in " <> path <> ", reloading.")
      case after_modules_loaded {
        Some(f) -> {
          let t_beam0 = monotonic_ms()
          f()
          let t_beam1 = monotonic_ms()
          io.println(
            "Hot reload timing: after_modules_loaded (beam/Lustre) "
            <> int.to_string(t_beam1 - t_beam0)
            <> "ms",
          )
        }
        None -> Nil
      }
      let t_handler1 = monotonic_ms()
      io.println(
        "Hot reload timing: on_reload callback "
        <> int.to_string(t_handler1 - t_handler0)
        <> "ms (beam only; tailwind is a separate watch process)",
      )
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

/// Resolve `-i=…` the same as `[tools.tailwind] args` in the host’s `gleam.toml`.
fn tailwind_input_arg() -> String {
  let input = case simplifile.is_file("app.tailwind.css") {
    Ok(True) -> "./app.tailwind.css"
    _ -> "./" <> default_tailwind_input_rel
  }
  "-i=" <> input
}

/// Same as `[tools.tailwind] args` in `gleam.toml`, plus [`-w=always`].
fn tailwind_watch_cli_args() -> List(String) {
  [tailwind_input_arg(), "-o=./.hot_skeleton/tailwind.css", "-w=always"]
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

/// Install CLI if needed and ensure the default input file exists. Tailwind
/// runs under [`start_tailwind_watcher`], not on each [radiate] event.
fn bootstrap_tailwind() -> Nil {
  let _ = ensure_default_tailwind_input()
  let _ = simplifile.create_directory_all(".hot_skeleton")
  case tailwind.install() {
    Error(msg) -> io.println(msg)
    Ok(Nil) -> Nil
  }
  Nil
}

/// Spawn a process that subscribes to the FFI tailwind [+-w=always] port and
/// runs the cache-bust / hub when the CLI reports a successful compile.
fn start_tailwind_watcher(after: Option(fn() -> Nil)) {
  case simplifile.is_file(tailwind_cli_exe) {
    Ok(True) -> {
      let pre0 = css_path_mtime_size()
      let tag = atom.create("hot_skeleton_tailwind_rebuilt")
      let _ = process.spawn_unlinked(fn() {
        let me = process.self()
        start_tailwind_watch(
          tailwind_cli_exe,
          tailwind_watch_cli_args(),
          me,
        )
        let sel =
          process.new_selector()
          |> process.select_record(tag, 1, fn(_d) { Nil })
        tailwind_done_loop(after, sel, pre0)
      })
      Nil
    }
    _ -> {
      io.println("hot_skeleton: tailwind CLI missing at " <> tailwind_cli_exe)
      Nil
    }
  }
}

fn tailwind_done_loop(
  after: Option(fn() -> Nil),
  sel: process.Selector(Nil),
  pre: #(Int, Int),
) {
  let _ = process.selector_receive_forever(sel)
  let t0 = monotonic_ms()
  let #(pre_m, pre_s) = pre
  let #(post_m, post_s) = css_path_mtime_size()
  let #(wait_changed_ms, wait_settled_ms) = case
    post_m == pre_m && post_s == pre_s
  {
    True -> {
      io.println(
        "Tailwind watch: output mtime+size still matches pre snapshot; skipped ffi poll.",
      )
      #(0, 0)
    }
    False -> wait_for_css_write_complete(pre_m, pre_s)
  }
  let t_after = monotonic_ms()
  io.println(
    "Tailwind timing (watch): ffi_wait_changed "
    <> int.to_string(wait_changed_ms)
    <> "ms, ffi_wait_settled "
    <> int.to_string(wait_settled_ms)
    <> "ms, total_to_stable "
    <> int.to_string(t_after - t0)
    <> "ms",
  )
  io.println("Tailwind watch: compiled .hot_skeleton/tailwind.css")
  case after {
    Some(f) -> {
      let t = css_cache_bust()
      io.println("CSS cache bust (after tailwind watch, before hub) t=" <> t)
      let t_hub0 = monotonic_ms()
      f()
      let t_hub1 = monotonic_ms()
      io.println(
        "Tailwind timing: hub / cache-bust notify " <> int.to_string(t_hub1 - t_hub0) <> "ms",
      )
    }
    None -> Nil
  }
  tailwind_done_loop(after, sel, css_path_mtime_size())
}

fn absolute_src_dir() -> String {
  let cwd = get_cwd()
  case string.ends_with(cwd, "/") {
    True -> cwd <> "src"
    False -> cwd <> "/src"
  }
}

@external(erlang, "hot_skeleton_hot_reload_ffi", "start_tailwind_watch")
fn start_tailwind_watch(executable: String, args: List(String), notify: process.Pid) -> Nil

@external(erlang, "hot_skeleton_hot_reload_ffi", "cwd")
fn get_cwd() -> String

@external(erlang, "hot_skeleton_hot_reload_ffi", "css_path_string")
pub fn css_path_string() -> String

@external(erlang, "hot_skeleton_hot_reload_ffi", "css_cache_bust")
pub fn css_cache_bust() -> String

@external(erlang, "hot_skeleton_hot_reload_ffi", "css_path_mtime_size")
fn css_path_mtime_size() -> #(Int, Int)

@external(erlang, "hot_skeleton_hot_reload_ffi", "wait_for_css_write_complete")
fn wait_for_css_write_complete(pre_mtime: Int, pre_size: Int) -> #(Int, Int)

@external(erlang, "hot_skeleton_hot_reload_ffi", "monotonic_ms")
fn monotonic_ms() -> Int
