//// Debug helper: log every [`tailwind_wrapper`] event to a file (and echo to stdout).
////
//// ```sh
//// cd tailwind_wrapper
//// TAILWIND_WRAPPER_LOG=./events.log gleam run -m cli
//// ```
////
//// Default log path: `.tailwind-wrapper/events.log` (created under the current working directory).

import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile
import tailwind_wrapper as tw

const default_log = ".tailwind-wrapper/events.log"

fn parent_dir(path: String) -> String {
  let parts = string.split(path, on: "/")
  case list.length(parts) {
    0 | 1 -> "."
    n -> string.join(list.take(parts, n - 1), with: "/")
  }
}

fn append_log(path: String, line: String) -> Nil {
  let _ = case simplifile.read(path) {
    Ok(existing) -> simplifile.write(path, existing <> line)
    Error(_) -> simplifile.write(path, line)
  }
  Nil
}

fn format_event(e: tw.Event) -> String {
  case e {
    tw.Initialized -> "initialized"
    tw.Failed(m) -> "failed: " <> m
    tw.Built(line, out) ->
      "built out=" <> out <> " line=" <> string.replace(line, "\n", " ")
  }
}

pub fn main() -> Nil {
  let log_path = result.unwrap(envoy.get("TAILWIND_WRAPPER_LOG"), default_log)
  let _ = simplifile.create_directory_all(parent_dir(log_path))
  let stamp = int.to_string(tw.monotonic_ms())
  append_log(log_path, "--- session " <> stamp <> " ---\n")
  io.println("tailwind_wrapper cli: logging to " <> log_path)
  tw.start(tw.default_config(), fn(e) {
    let text = format_event(e)
    append_log(log_path, text <> "\n")
    io.println(text)
  })
  process.sleep_forever()
}
