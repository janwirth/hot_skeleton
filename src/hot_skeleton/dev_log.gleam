import envoy
import gleam/string

const log_env = "HOT_SKELETON_LOG"

/// When [`is_debug`] is `False` (default), the dev entrypoint only prints one
/// line per Gleam recompile and one per Tailwind rebuild. Set
/// `HOT_SKELETON_LOG=debug` for timings, per-request HTTP lines, and CSS
/// cache-bust detail (previous always-on behavior).
pub fn is_debug() -> Bool {
  case envoy.get(log_env) {
    Error(_) -> False
    Ok(v) -> {
      let v = string.trim(string.lowercase(v))
      v == "debug" || v == "1" || v == "true" || v == "yes"
    }
  }
}
