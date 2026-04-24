import hot_skeleton/component_wrapper
import mist/reload.{wrap}
import examples/counter

/// Development: run with `gleam dev`. Uses
/// [mist_reload](https://github.com/CrowdHailer/mist_reload) so the VM reloads
/// code on `src` changes and the browser refreshes.
pub fn main() -> Nil {
  component_wrapper.start_hot_server_with_wrap(counter.component, 8080, wrap)
}
