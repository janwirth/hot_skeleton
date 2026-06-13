import gleam/erlang/process
import gleam/io
import hot_skeleton/component_wrapper
import lustre.{type App}

/// Start the Lustre server (Mist, WebSocket, Tailwind output at `./.hot_skeleton/tailwind.css` in dev).
pub fn start(
  component: fn() -> App(Nil, model, message),
  refresh_view: fn() -> message,
) -> Nil {
  hard_reload_loop(component, refresh_view)
}

/// When the lustre runtime or another linked child dies (e.g. `badarg` outside
/// Gleam), restart the whole dev server instead of exiting.
fn hard_reload_loop(
  component: fn() -> App(Nil, model, message),
  refresh_view: fn() -> message,
) -> Nil {
  let server = process.spawn_unlinked(fn() {
    component_wrapper.start_hot_server(component, 8080, refresh_view)
  })
  let _monitor = process.monitor(server)
  let selector =
    process.new_selector()
    |> process.select_monitors(fn(d) {
      case d {
        process.ProcessDown(..) -> Nil
        process.PortDown(..) -> Nil
      }
    })
  process.selector_receive_forever(from: selector)
  io.println("[hot_skeleton] hard reload")
  hard_reload_loop(component, refresh_view)
}
