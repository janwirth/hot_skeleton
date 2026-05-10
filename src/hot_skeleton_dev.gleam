import examples/hot_scroll
import gleam/io
import hot_skeleton/component_wrapper

/// Development: run with `gleam dev`. Uses [`hot_reload`](./hot_skeleton/hot_reload.gleam) —
/// same as [`start_hot_server`](../hot_skeleton/component_wrapper.gleam), plus
/// a post-reload `dispatch` so the singleton Lustre runtime remounts vdom for new clients.
pub fn main() -> Nil {
  io.println("[hot_skeleton_dev] scroll view demo (kompas)")
  component_wrapper.start_hot_server(
    hot_scroll.component,
    8080,
    hot_scroll.trigger_rerender_view,
  )
}
