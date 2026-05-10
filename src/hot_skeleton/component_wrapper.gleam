import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some, map}
import gleam/string
import hot_skeleton/css_bust_hub
import hot_skeleton/dev_log
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
import simplifile

import woof

/// [`mist.new`] service function type for this app.
pub type HttpHandler =
  fn(Request(mist.Connection)) -> Response(mist.ResponseData)

/// Lustre server component on `/`, WebSocket on `/ws`. The same handler is
/// used in production and in dev.
/// `on_beam_modules_loaded`: after [radiate] runs `gleam build` and loads new
/// BEAM modules, this is called with the singleton [`Runtime`]. Use it to
/// [`lustre.dispatch`](https://hexdocs.pm/lustre/lustre.html#dispatch) a
/// no-op message so `view` runs again; otherwise new WebSocket clients keep
/// receiving the vdom cached before the code swap.
pub fn start_hot_server(
  make_app: fn() -> App(Nil, model, message),
  default_port: Int,
  reload_msg: fn() -> message,
) -> Nil {
  let on_beam_modules_loaded = fn(r: Runtime(message)) {
    lustre.send(r, lustre.dispatch(reload_msg()))
  }

  io.println("[hot_skeleton] start_hot_server: css_bust_hub.start…")
  let assert Ok(hub) = css_bust_hub.start()
  io.println("[hot_skeleton] start_hot_server: css hub ok, resolve_port…")
  let on_tailwind = fn() {
    process.send(hub, css_bust_hub.DoPush(t: hot_reload.css_cache_bust()))
  }
  let port = hot_server.resolve_port(default_port)
  io.println(
    "[hot_skeleton] start_hot_server: build handler + start_server_component…",
  )
  let #(base, runtime) = build_http_handler_with_runtime(make_app, hub)
  io.println(
    "[hot_skeleton] start_hot_server: hot_reload.wrap + hot_server.start…",
  )
  let after: Option(fn() -> Nil) =
    map(Some(on_beam_modules_loaded), fn(f) { fn() { f(runtime) } })
  let handle = hot_reload.wrap(base, after, Some(on_tailwind))
  hot_server.start(port, handle)
}

type ComponentSocket(msg) {
  ComponentSocket(self: process.Subject(server_component.ClientMessage(msg)))
}

type ComponentSocketMessage(msg) =
  server_component.ClientMessage(msg)

fn build_http_handler_with_runtime(
  make_app: fn() -> App(Nil, model, message),
  hub: process.Subject(css_bust_hub.Message),
) -> #(HttpHandler, Runtime(message)) {
  io.println("[hot_skeleton] build_http_handler: make_app()")
  let app = make_app()
  io.println(
    "[hot_skeleton] build_http_handler: start_server_component (runs logic.init)…",
  )
  let assert Ok(singleton) = start_server_component(app, Nil)
  io.println("[hot_skeleton] build_http_handler: lustre runtime ready")
  let serve_ws = fn(req: Request(mist.Connection)) {
    serve_component_websocket(req, singleton)
  }
  let http_handler = fn(req: Request(mist.Connection)) {
    let segments = request.path_segments(req)
    let path = "/" <> string.join(segments, "/")
    case dev_log.is_debug() {
      True ->
        woof.info("http", [
          woof.str("event", hot_server.http_method(req.method) <> " " <> path),
        ])
      False -> Nil
    }
    case req.method, segments {
      http.Get, [] -> serve_index()
      http.Get, ["app.css"] -> serve_app_css()
      http.Get, ["__hot_css"] -> serve_css_bust(req, hub)
      http.Get, ["ws"] -> serve_ws(req)
      http.Get, ["hot_skeleton_hmr.mjs"] -> serve_hot_skeleton_hmr_mjs()
      http.Get, ["lustre-server-component.mjs"] -> serve_lustre_mjs()
      http.Get, ["kompas.js"] -> serve_kompas_js()
      _, _ -> hot_server.not_found(path)
    }
  }
  #(http_handler, singleton)
}

fn index_document() -> String {
  let initial_css = case simplifile.read(hot_reload.css_path_string()) {
    Ok(s) -> s
    Error(_) -> ""
  }
  let head_children = [
    html.title([], "App"),
    html.style([attribute.id("hot-skeleton-app-css")], initial_css),
    html.script(
      [
        attribute.type_("module"),
        attribute.src("/hot_skeleton_hmr.mjs"),
      ],
      "",
    ),
    html.script(
      [
        attribute.type_("module"),
        attribute.src("/lustre-server-component.mjs"),
      ],
      "",
    ),
    html.script(
      [attribute.type_("module")],
      "
import * as kompas from '/kompas.js';
kompas.register_scroll_view();
",
    ),
  ]
  let page =
    html.html([], [
      html.head([], head_children),
      html.body([], [
        server_component.element(
          [
            server_component.route("/ws"),
            server_component.method(server_component.WebSocket),
            attribute.shadowrootmode("open"),
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

fn serve_hot_skeleton_hmr_mjs() -> Response(mist.ResponseData) {
  let assert Ok(priv) = application.priv_directory("hot_skeleton")
  let file_path = priv <> "/static/hot_skeleton_hmr.mjs"
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

fn serve_kompas_js() -> Response(mist.ResponseData) {
  let assert Ok(priv) = application.priv_directory("hot_skeleton")
  let file_path = priv <> "/static/kompas.js"
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

type CssHmrState {
  CssHmrState(hub: process.Subject(css_bust_hub.Message), id: Int)
}

fn serve_css_bust(
  request: Request(mist.Connection),
  hub: process.Subject(css_bust_hub.Message),
) -> Response(mist.ResponseData) {
  let on_init = fn(connection: mist.WebsocketConnection) {
    let bust = process.new_subject()
    let ack = process.new_subject()
    process.send(hub, css_bust_hub.AddClient(bust, ack))
    let id = case process.receive(ack, 2000) {
      Ok(i) -> i
      Error(_) -> 0
    }
    let t0 = hot_reload.css_cache_bust()
    let _ = mist.send_text_frame(connection, t0)
    case dev_log.is_debug() {
      True -> {
        let _ = io.println("CSS cache bust (__hot_css initial frame) t=" <> t0)
        Nil
      }
      False -> Nil
    }
    let sel = process.new_selector() |> process.select(bust)
    #(CssHmrState(hub, id), Some(sel))
  }
  let handler = fn(
    st: CssHmrState,
    message: mist.WebsocketMessage(String),
    connection: mist.WebsocketConnection,
  ) {
    case message {
      mist.Text(_) | mist.Binary(_) -> mist.continue(st)
      mist.Custom(t) -> {
        let _ = mist.send_text_frame(connection, t)
        mist.continue(st)
      }
      mist.Closed | mist.Shutdown -> mist.stop()
    }
  }
  let on_close = fn(st: CssHmrState) {
    case st.id {
      0 -> Nil
      _ -> process.send(st.hub, css_bust_hub.RmClient(st.id))
    }
  }
  mist.websocket(request:, on_init:, handler:, on_close:)
}
