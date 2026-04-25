import hot_skeleton/component_wrapper
import lustre.{type App}

/// Start the Lustre server (Mist, WebSocket, Tailwind output at `./.hot_skeleton/tailwind.css` in dev).
pub fn start(component: fn() -> App(Nil, model, message), refresh_view: fn() -> message) -> Nil {
  component_wrapper.start_hot_server(component, 8080, refresh_view)
}

