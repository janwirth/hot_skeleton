//// Run the Tailwind CLI in watch mode: install the binary, ensure an input
//// file, emit CSS, and report [`Event`]s (colored line + output path on each build).

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Selector}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile
import tailwind

const default_input_source = "@import \"tailwindcss\";\n"

pub type Config {
  Config(
    cli_path: String,
    app_input: Option(String),
    generated_input: String,
    output_css: String,
    log_built_to_stdout: Bool,
  )
}

/// `priv/tailwind.css` and `.tailwind-wrapper/tailwind-input.css` when there is no `./app.tailwind.css`.
pub fn default_config() -> Config {
  Config(
    cli_path: "./build/bin/tailwindcss",
    app_input: None,
    generated_input: ".tailwind-wrapper/tailwind-input.css",
    output_css: "priv/tailwind.css",
    log_built_to_stdout: True,
  )
}

/// Paths under `.hot_skeleton/` for an HMR-style app layout.
pub fn config_hot_skeleton() -> Config {
  Config(
    cli_path: "./build/bin/tailwindcss",
    app_input: None,
    generated_input: ".hot_skeleton/tailwind-input.css",
    output_css: ".hot_skeleton/tailwind.css",
    log_built_to_stdout: True,
  )
}

pub type Event {
  Initialized
  Failed(String)
  Built(colored_log_line: String, output_path: String)
}

@external(erlang, "tailwind_wrapper_ffi", "start_tailwind_watch")
fn start_tailwind_watch(executable: String, args: List(String), notify: process.Pid) -> Nil

@external(erlang, "tailwind_wrapper_ffi", "absolute_path")
fn absolute_path_ffi(relative: String) -> String

@external(erlang, "tailwind_wrapper_ffi", "file_mtime_size")
fn file_mtime_size(path: String) -> #(Int, Int)

@external(erlang, "tailwind_wrapper_ffi", "wait_for_css_write_complete")
fn wait_for_css_write_complete(path: String, pre_m: Int, pre_s: Int) -> #(Int, Int)

@external(erlang, "tailwind_wrapper_ffi", "css_cache_bust")
fn css_cache_bust_ffi(path: String) -> String

@external(erlang, "tailwind_wrapper_ffi", "monotonic_ms")
pub fn monotonic_ms() -> Int

/// Absolute path to the configured output CSS.
pub fn output_path_for(config: Config) -> String {
  absolute_path_ffi(config.output_css)
}

/// `?t=` value derived from the output file mtime.
pub fn css_cache_bust(config: Config) -> String {
  css_cache_bust_ffi(output_path_for(config))
}

/// Install the CLI, ensure input, then spawn a watch. [`Initialized`] and [`Failed`]
/// run on the calling process; [`Built`] runs on a background worker. With
/// [`Config]` `log_built_to_stdout: True`, each build line is also printed.
pub fn start(config: Config, on_event: fn(Event) -> Nil) -> Nil {
  case do_install_and_prepare(config) {
    Error(m) -> on_event(Failed(m))
    Ok(Nil) -> {
      on_event(Initialized)
      case simplifile.is_file(config.cli_path) {
        Ok(True) -> {
          let _ = process.spawn(fn() { watch_worker(config, on_event) })
          Nil
        }
        _ -> on_event(Failed("tailwind CLI missing at " <> config.cli_path))
      }
    }
  }
}

fn do_install_and_prepare(config: Config) -> Result(Nil, String) {
  let _ = ensure_input_file(config)
  let _ = simplifile.create_directory_all(parent_dir(config.output_css))
  case tailwind.install() {
    Error(msg) -> Error(msg)
    Ok(Nil) -> Ok(Nil)
  }
}

fn parent_dir(path: String) -> String {
  let parts = string.split(path, on: "/")
  case list.length(parts) {
    0 | 1 -> "."
    n -> string.join(list.take(parts, n - 1), with: "/")
  }
}

fn ensure_input_file(config: Config) -> Nil {
  case config.app_input {
    Some(f) -> {
      let _ = simplifile.create_directory_all(parent_dir(f))
      Nil
    }
    None ->
      case simplifile.is_file("app.tailwind.css") {
        Ok(True) -> Nil
        _ -> {
          let _ = simplifile.create_directory_all(parent_dir(config.generated_input))
          case simplifile.is_file(config.generated_input) {
            Ok(True) -> Nil
            _ -> {
              let _ = simplifile.write(config.generated_input, default_input_source)
              Nil
            }
          }
        }
      }
  }
}

fn watch_cli_args(config: Config) -> List(String) {
  let i = case config.app_input {
    Some(p) -> "-i=" <> p
    None ->
      case simplifile.is_file("app.tailwind.css") {
        Ok(True) -> "-i=./app.tailwind.css"
        _ -> {
          let _ = ensure_input_file(config)
          "-i=./" <> config.generated_input
        }
      }
  }
  [i, "-o=./" <> config.output_css, "-w=always"]
}

fn watch_worker(config: Config, on_event: fn(Event) -> Nil) {
  let out_abs = output_path_for(config)
  let pre0 = file_mtime_size(out_abs)
  let tag = atom.create("tw_rebuild")
  let me = process.self()
  start_tailwind_watch(config.cli_path, watch_cli_args(config), me)
  let sel =
    process.new_selector()
    |> process.select_record(tag, 1, fn(d) { decode_rebuild_line(d) })
  watch_loop(config, on_event, sel, pre0, out_abs)
}

fn decode_rebuild_line(d: Dynamic) -> String {
  case decode.run(d, decode.bit_array) {
    Ok(b) -> {
      case bit_array.to_string(b) {
        Ok(s) -> s
        _ -> ""
      }
    }
    _ -> {
      case decode.run(d, decode.string) {
        Ok(s) -> s
        _ -> ""
      }
    }
  }
}

fn watch_loop(
  config: Config,
  on_event: fn(Event) -> Nil,
  sel: Selector(String),
  pre: #(Int, Int),
  out_abs: String,
) {
  let line = process.selector_receive_forever(from: sel)
  let t0 = monotonic_ms()
  let #(pre_m, pre_s) = pre
  let #(post_m, post_s) = file_mtime_size(out_abs)
  let _ = case post_m == pre_m && post_s == pre_s {
    True -> #(0, 0)
    False -> wait_for_css_write_complete(out_abs, pre_m, pre_s)
  }
  let _ = t0
  on_event(Built(line, out_abs))
  case config.log_built_to_stdout {
    True -> io.println(line)
    False -> Nil
  }
  watch_loop(config, on_event, sel, file_mtime_size(out_abs), out_abs)
}
