import gleam/io
import examples/hot_counter
import examples/not_hot_counter
import hot_skeleton/component_wrapper

/// Development: run with `gleam dev`. Uses [`hot_reload`](./hot_skeleton/hot_reload.gleam) —
/// same as [`start_hot_server`](../hot_skeleton/component_wrapper.gleam), plus
/// a post-reload `dispatch` so the singleton Lustre runtime remounts vdom for new clients.
pub fn main() -> Nil {
  io.print("Registering counter")
  hot_counter.register()
  component_wrapper.start_hot_server(
    hot_counter.component,
    8080,
    hot_counter.trigger_rerender_view,
  )
}
// pub fn main() -> Nil {
//   io.print("Registering counter")
//   not_hot_counter.register()
//   component_wrapper.start_hot_server(
//     not_hot_counter.component,
//     8080,
//     not_hot_counter.trigger_rerender_view,
//   )
// }
