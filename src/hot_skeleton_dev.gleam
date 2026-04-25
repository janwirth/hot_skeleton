import gleam/io
import examples/counter
import examples/counter/logic
import hot_skeleton/component_wrapper

/// Development: run with `gleam dev`. Uses [`hot_reload`](./hot_skeleton/hot_reload.gleam) —
/// same as [`start_hot_server`](../hot_skeleton/component_wrapper.gleam), plus
/// a post-reload `dispatch` so the singleton Lustre runtime remounts vdom for new clients.
pub fn main() -> Nil {
  io.print("Registering counter")
  counter.register()
  component_wrapper.start_hot_server(
    counter.component,
    8080,
    logic.dev_rerender_message,
  )
}
