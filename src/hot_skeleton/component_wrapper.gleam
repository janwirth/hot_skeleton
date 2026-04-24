import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, None, Some, map}
import gleam/string
import hot_skeleton/hot_reload
import hot_skeleton/server as hot_server
import lustre.{
  type App, type Runtime, send as lustre_send, start_server_component,
}
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/server_component
import mist

import woof

/// [`mist.new`] service function type for this app.
pub type HttpHandler =
  fn(Request(mist.Connection)) -> Response(mist.ResponseData)

/// Lustre server component on `/`, WebSocket on `/ws`. The same handler is
/// used in production and in dev. In dev, run [`start_hot_server_dev`] or pass
/// [`reload.wrap`](https://hexdocs.pm/mist_reload/mist/reload.html#wrap) so
/// the browser and Erlang get hot updates from [mist_reload](https://github.com/CrowdHailer/mist_reload).
pub fn start_hot_server(make_app: fn() -> App(Nil, model, message)) -> Nil {
  start_hot_server_with_wrap(make_app, 8080, fn(h) { h }, None)
}

/// `on_beam_modules_loaded`: after radiate runs `gleam build` and loads new
/// BEAM modules, this is called with the singleton [`Runtime`]. Use it to
/// [`lustre.dispatch`](https://hexdocs.pm/lustre/lustre.html#dispatch) a
/// no-op message so `view` runs again; otherwise new WebSocket clients keep
/// receiving the vdom cached before the code swap.
pub fn start_hot_server_with_wrap(
  make_app: fn() -> App(Nil, model, message),
  default_port: Int,
  mist_wrap: fn(HttpHandler) -> HttpHandler,
  on_beam_modules_loaded: Option(fn(Runtime(message)) -> Nil),
) -> Nil {
  let port = hot_server.resolve_port(default_port)
  let #(base, runtime) = build_http_handler_with_runtime(make_app)
  let after: Option(fn() -> Nil) =
    map(on_beam_modules_loaded, fn(f) { fn() { f(runtime) } })
  let base = hot_reload.wrap(base, after)
  let handle = mist_wrap(base)
  hot_server.start(port, handle)
}

type ComponentSocket(msg) {
  ComponentSocket(self: process.Subject(server_component.ClientMessage(msg)))
}

type ComponentSocketMessage(msg) =
  server_component.ClientMessage(msg)

fn build_http_handler_with_runtime(
  make_app: fn() -> App(Nil, model, message),
) -> #(HttpHandler, Runtime(message)) {
  let app = make_app()
  let assert Ok(singleton) = start_server_component(app, Nil)
  let serve_ws = fn(req: Request(mist.Connection)) {
    serve_component_websocket(req, singleton)
  }
  let http_handler = fn(req: Request(mist.Connection)) {
    let segments = request.path_segments(req)
    let path = "/" <> string.join(segments, "/")
    woof.info("http", [
      woof.str("event", hot_server.http_method(req.method) <> " " <> path),
    ])
    case req.method, segments {
      http.Get, [] -> serve_index()
      http.Get, ["app.css"] -> serve_app_css()
      http.Get, ["ws"] -> serve_ws(req)
      http.Get, ["lustre-server-component.mjs"] -> serve_lustre_mjs()
      _, _ -> hot_server.not_found(path)
    }
  }
  #(http_handler, singleton)
}

fn index_document() -> String {
  let t = hot_reload.css_cache_bust()
  let page =
    html.html([], [
      html.head([], [
        html.title([], "App"),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("/app.css?t=" <> t),
        ]),
        html.script(
          [
            attribute.type_("module"),
            attribute.src("/lustre-server-component.mjs"),
          ],
          "",
        ),
      ]),
      html.body([], [
        server_component.element(
          [
            server_component.route("/ws"),
            server_component.method(server_component.WebSocket),
          ],
          [],
        ),
      ]),
    ])
  element.to_document_string(page)
}

fn serve_index() -> Response(mist.ResponseData) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(index_document())))
}

fn serve_app_css() -> Response(mist.ResponseData) {
  case mist.send_file(hot_reload.css_path_string(), offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", "text/css; charset=utf-8")
      |> response.set_body(file)
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn serve_lustre_mjs() -> Response(mist.ResponseData) {
  let assert Ok(lustre_priv) = application.priv_directory("lustre")
  let file_path = lustre_priv <> "/static/lustre-server-component.mjs"
  case mist.send_file(file_path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", "application/javascript")
      |> response.set_body(file)
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn serve_component_websocket(
  request: Request(mist.Connection),
  component: Runtime(message),
) -> Response(mist.ResponseData) {
  let on_init = fn(_connection: mist.WebsocketConnection) {
    let self = process.new_subject()
    let selector =
      process.new_selector()
      |> process.select(self)
    let registered = server_component.register_subject(self)
    lustre_send(to: component, message: registered)
    let state = ComponentSocket(self:)
    #(state, Some(selector))
  }
  let handler = fn(
    state: ComponentSocket(message),
    message: mist.WebsocketMessage(ComponentSocketMessage(message)),
    connection: mist.WebsocketConnection,
  ) -> mist.Next(ComponentSocket(message), ComponentSocketMessage(message)) {
    case message {
      mist.Text(text) -> {
        case json.parse(text, server_component.runtime_message_decoder()) {
          Ok(runtime_message) ->
            lustre_send(to: component, message: runtime_message)
          Error(_) -> Nil
        }
        mist.continue(state)
      }
      mist.Binary(_) -> mist.continue(state)
      mist.Custom(client_message) -> {
        let j = server_component.client_message_to_json(client_message)
        let assert Ok(_) = mist.send_text_frame(connection, json.to_string(j))
        mist.continue(state)
      }
      mist.Closed | mist.Shutdown -> mist.stop()
    }
  }
  let on_close = fn(state: ComponentSocket(message)) {
    lustre_send(
      to: component,
      message: server_component.deregister_subject(state.self),
    )
  }
  mist.websocket(request:, on_init:, handler:, on_close:)
}
