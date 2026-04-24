import examples/counter
import examples/counter/logic
import gleam/option.{Some}
import hot_skeleton/component_wrapper
import lustre

/// Development: run with `gleam dev`. Uses [`hot_reload`](./hot_skeleton/hot_reload.gleam) —
/// same as in [`start_hot_server_with_wrap`](../hot_skeleton/component_wrapper.gleam), plus
/// a post-reload `dispatch` so the singleton Lustre runtime remounts vdom for new clients.
pub fn main() -> Nil {
  component_wrapper.start_hot_server_with_wrap(
    counter.component,
    8080,
    fn(h) { h },
    Some(fn(r) { lustre.send(r, lustre.dispatch(logic.dev_rerender_message())) }),
  )
}
