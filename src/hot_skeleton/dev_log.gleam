import envoy
import gleam/string

const log_env = "HOT_SKELETON_LOG"

/// When [`is_debug`] is `False` (default), one line per Gleam recompile
/// (`Gleam: Nms src/...`) and Tailwind lines from the FFI (`Done in` → `Tailwind:`).
/// Set `HOT_SKELETON_LOG=debug` for extra timings, HTTP lines, and CSS hub detail.
pub fn is_debug() -> Bool {
  case envoy.get(log_env) {
    Error(_) -> False
    Ok(v) -> {
      let v = string.trim(string.lowercase(v))
      v == "debug" || v == "1" || v == "true" || v == "yes"
    }
  }
}
