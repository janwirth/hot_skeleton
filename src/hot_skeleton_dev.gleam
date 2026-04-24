import examples/counter
import hot_skeleton/component_wrapper
import hot_skeleton/hot_reload

/// Development: run with `gleam dev`. Uses a local
/// [`hot_reload`](./hot_skeleton/hot_reload.gleam) wrapper — a patched variant
/// of [mist_reload](https://github.com/CrowdHailer/mist_reload) that passes
/// [radiate](https://hexdocs.pm/radiate) an absolute path, which is required
/// for filespy/fsevents to actually fire on macOS.
pub fn main() -> Nil {
  component_wrapper.start_hot_server_with_wrap(
    counter.component,
    8080,
    hot_reload.wrap,
  )
}
