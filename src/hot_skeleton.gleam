import examples/counter
import gleam/io
import hot_skeleton/component_wrapper
import lustre.{type App}

/// Production: `gleam run` — no live reload; static identity [`mist` handler](https://hexdocs.pm/mist).
// pub fn main() -> Nil {
//   io.println("Hello from hot_skeleton!")
//   component_wrapper.start_hot_server(counter.component)
// }

pub fn start_hot_server(component: fn() -> App(Nil, model, message)) -> Nil {
  component_wrapper.start_hot_server(component)
}
