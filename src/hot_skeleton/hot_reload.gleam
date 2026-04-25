//// Hot-reload wrapper for dev. Uses [radiate](https://hexdocs.pm/radiate)
//// to watch `<cwd>/src` and hot-swap modified BEAM code. CSS is built by
//// [`tailwind_wrapper`](../../tailwind_wrapper/) (watch, install, events).
////
//// **Logging (default):** `Gleam: <N>ms src/...` and colored Tailwind lines.
//// `HOT_SKELETON_LOG=debug` for verbose. See [`dev_log.is_debug`].
////
//// Lustre stores `update`/`view` as function references; use cross-module
//// calls for hot-swap. See [`examples/counter`](../examples/counter.gleam).

import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import hot_skeleton/dev_log
import radiate
import simplifile
import tailwind_wrapper as tw

const default_input_rel = ".hot_skeleton/tailwind-input.css"

/// Same paths as [`tailwind_wrapper.config_hot_skeleton`]; align `[tools.tailwind]`.
fn twc() -> tw.Config {
  tw.config_hot_skeleton()
}

/// When [`wrap`] is used, CSS is at [`css_path_string`] (default under `.hot_skeleton/`).
pub fn tailwind_enabled() -> Bool {
  True
}

/// Generated entry when `./app.tailwind.css` is missing; matches [`twc`].
pub fn default_tailwind_input_path() -> String {
  default_input_rel
}

pub fn css_path_string() -> String {
  tw.output_path_for(twc())
}

pub fn css_cache_bust() -> String {
  tw.css_cache_bust(twc())
}

/// Start [radiate] and the Tailwind watch from [`tw`]. After each Tailwind
/// build (file stable on disk), [`after_tailwind_rebuilt`] runs (e.g. push `?t=`).
pub fn wrap(
  handler: a,
  after_modules_loaded: Option(fn() -> Nil),
  after_tailwind_rebuilt: Option(fn() -> Nil),
) -> a {
  let _ =
    tw.start(twc(), fn(e) {
      case e {
        tw.Initialized ->
          io.println("[hot_skeleton] tailwind -> " <> tw.output_path_for(twc()))
        tw.Failed(m) -> io.println("tailwind_wrapper: " <> m)
        tw.Built(_line, _out) -> {
          case after_tailwind_rebuilt {
            Some(f) -> f()
            None -> Nil
          }
        }
      }
    })
  let src_dir = absolute_src_dir()
  let _ =
    radiate.new()
    |> radiate.add_dir(src_dir)
    |> radiate.on_reload(fn(_state, path) {
      let t_handler0 = tw.monotonic_ms()
      case dev_log.is_debug() {
        True -> io.println("Change in " <> path <> ", reloading.")
        False -> Nil
      }
      case after_modules_loaded {
        Some(f) -> {
          case dev_log.is_debug() {
            True -> {
              let t_beam0 = tw.monotonic_ms()
              f()
              let t_beam1 = tw.monotonic_ms()
              io.println(
                "Hot reload timing: after_modules_loaded (beam/Lustre) "
                <> int.to_string(t_beam1 - t_beam0)
                <> "ms",
              )
            }
            False -> f()
          }
        }
        None -> Nil
      }
      let t_handler1 = tw.monotonic_ms()
      case dev_log.is_debug() {
        True ->
          io.println(
            "Hot reload timing: on_reload callback "
            <> int.to_string(t_handler1 - t_handler0)
            <> "ms (beam only; tailwind is a separate watch process)",
          )
        False ->
          io.println(
            "Gleam: "
            <> int.to_string(t_handler1 - t_handler0)
            <> "ms "
            <> path_for_recompile_log(path),
          )
      }
      Nil
    })
    |> radiate.start()
  handler
}

fn get_cwd() -> String {
  result.unwrap(simplifile.current_directory(), ".")
}

fn absolute_src_dir() -> String {
  let cwd = get_cwd()
  case string.ends_with(cwd, "/") {
    True -> cwd <> "src"
    False -> cwd <> "/src"
  }
}

fn path_for_recompile_log(absolute_path: String) -> String {
  let base = get_cwd()
  let prefix = case string.ends_with(base, "/") {
    True -> base
    False -> base <> "/"
  }
  case string.starts_with(absolute_path, prefix) {
    True -> {
      let n = string.length(prefix)
      string.slice(
        from: absolute_path,
        at_index: n,
        length: string.length(absolute_path) - n,
      )
    }
    False ->
      case string.split_once(absolute_path, on: "/src/") {
        Ok(#(_, after)) -> "src/" <> after
        Error(Nil) -> absolute_path
      }
  }
}
