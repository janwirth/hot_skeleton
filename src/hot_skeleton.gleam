import hot_skeleton/component_wrapper
import lustre.{type App}

/// Start the Lustre server (Mist, WebSocket, optional Tailwind when `./app.tailwind.css` exists in cwd).
pub fn start(component: fn() -> App(Nil, model, message), refresh_view: fn() -> message) -> Nil {
  component_wrapper.start_hot_server_with_wrap(component, 8080, fn(h) { h }, refresh_view)
}

