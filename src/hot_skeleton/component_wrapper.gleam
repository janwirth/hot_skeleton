import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import lustre.{
  type App,
  type Runtime,
  send as lustre_send,
  shutdown,
  start_server_component,
}
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/server_component
import mist
import hot_skeleton/server as hot_server

import woof

/// [`mist.new`] service function type for this app.
pub type HttpHandler =
  fn(Request(mist.Connection)) -> Response(mist.ResponseData)

/// Lustre server component on `/`, WebSocket on `/ws`. The same handler is
/// used in production and in dev. In dev, run [`start_hot_server_dev`] or pass
/// [`reload.wrap`](https://hexdocs.pm/mist_reload/mist/reload.html#wrap) so
/// the browser and Erlang get hot updates from [mist_reload](https://github.com/CrowdHailer/mist_reload).
pub fn start_hot_server(
  make_app: fn() -> App(Nil, model, message),
) -> Nil {
  start_hot_server_with_wrap(make_app, 8080, fn(h) { h })
}

pub fn start_hot_server_with_wrap(
  make_app: fn() -> App(Nil, model, message),
  default_port: Int,
  mist_wrap: fn(HttpHandler) -> HttpHandler,
) -> Nil {
  let port = hot_server.resolve_port(default_port)
  let base = build_http_handler(make_app)
  let handle = mist_wrap(base)
  hot_server.start(port, handle)
}

type ComponentSocket(msg) {
  ComponentSocket(
    component: Runtime(msg),
    self: process.Subject(server_component.ClientMessage(msg)),
  )
}

type ComponentSocketMessage(msg) =
  server_component.ClientMessage(msg)

fn build_http_handler(
  make_app: fn() -> App(Nil, model, message),
) -> HttpHandler {
  let serve_ws = fn(req: Request(mist.Connection)) {
    serve_component_websocket(req, make_app)
  }
  fn(req: Request(mist.Connection)) {
    let segments = request.path_segments(req)
    let path = "/" <> string.join(segments, "/")
    woof.info("http", [woof.str("event", hot_server.http_method(req.method) <> " " <> path)])
    case req.method, segments {
      http.Get, [] -> serve_index()
      http.Get, ["ws"] -> serve_ws(req)
      http.Get, ["lustre-server-component.mjs"] -> serve_lustre_mjs()
      _, _ -> hot_server.not_found(path)
    }
  }
}

fn index_document() -> String {
  let page =
    html.html(
      [],
      [
        html.head(
          [],
          [
            html.title([], "App"),
            html.script(
              [
                attribute.type_("module"),
                attribute.src("/lustre-server-component.mjs"),
              ],
              "",
            ),
          ],
        ),
        html.body(
          [],
          [
            server_component.element(
              [
                server_component.route("/ws"),
                server_component.method(server_component.WebSocket),
              ],
              [],
            ),
          ],
        ),
      ],
    )
  element.to_document_string(page)
}

fn serve_index() -> Response(mist.ResponseData) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(index_document())))
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
  make_app: fn() -> App(Nil, m, message),
) -> Response(mist.ResponseData) {
  let on_init = fn(_connection: mist.WebsocketConnection) {
    let app = make_app()
    let assert Ok(component) = start_server_component(app, Nil)
    let self = process.new_subject()
    let selector =
      process.new_selector()
      |> process.select(self)
    let registered = server_component.register_subject(self)
    lustre_send(to: component, message: registered)
    let state = ComponentSocket(component:, self:)
    #(state, Some(selector))
  }
  let handler = fn(
    state: ComponentSocket(message),
    message: mist.WebsocketMessage(ComponentSocketMessage(message)),
    connection: mist.WebsocketConnection,
  ) -> mist.Next(
    ComponentSocket(message),
    ComponentSocketMessage(message),
  ) {
    case message {
      mist.Text(text) -> {
        case json.parse(text, server_component.runtime_message_decoder()) {
          Ok(runtime_message) -> lustre_send(to: state.component, message: runtime_message)
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
    lustre_send(to: state.component, message: shutdown())
  }
  mist.websocket(
    request:,
    on_init:,
    handler:,
    on_close:,
  )
}
