//// HTTP helpers for a mist web server: port, static files, 404, etc.
////
//// Hot reload in dev is built on [`hot_reload`](../hot_reload.gleam) in
//// [`component_wrapper`](./component_wrapper.gleam) and the dev entrypoint.

import envoy
import gleam/bytes_tree
import gleam/io
import gleam/erlang/application
import gleam/erlang/process.{sleep_forever}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import mist

import woof

/// [`mist.new`] accepts a handler `fn(Request(mist.Connection)) -> Response(mist.ResponseData)`.
/// [`component_wrapper.start_hot_server`](./component_wrapper.gleam#start_hot_server) passes the
/// [`hot_reload`](./hot_reload.gleam)-wrapped handler.
pub fn start(
  port: Int,
  handle: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> Nil {
  let assert Ok(_) =
    handle
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start
  woof.info("boot", [
    woof.str("event", "listening on 0.0.0.0:" <> int.to_string(port)),
  ])
  io.println("[hot_skeleton] listening on 0.0.0.0:" <> int.to_string(port))
  sleep_forever()
}

/// Read `PORT` from the environment, falling back to `default`.
pub fn resolve_port(default: Int) -> Int {
  case envoy.get("PORT") {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> default
      }
    Error(_) -> default
  }
}

/// Extract a single query-string value. Returns `None` if the key is
/// absent or blank.
pub fn query_param(
  req: request.Request(mist.Connection),
  key: String,
) -> Option(String) {
  case request.get_query(req) {
    Ok(pairs) ->
      case list.key_find(pairs, key) {
        Ok("") -> None
        Ok(v) -> Some(v)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

pub fn http_method(m: http.Method) -> String {
  case m {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Patch -> "PATCH"
    http.Head -> "HEAD"
    http.Options -> "OPTIONS"
    _ -> "?"
  }
}

pub fn serve_redirect(to: String) -> response.Response(mist.ResponseData) {
  response.new(302)
  |> response.set_header("location", to)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}

pub fn not_found(path: String) -> response.Response(mist.ResponseData) {
  woof.info("http", [woof.str("event", "404 " <> path)])
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("not found")))
}

/// Serve a file from the given OTP application's `priv/static/` directory.
/// Set `app_name` to the `name` in `gleam.toml`.
pub fn serve_priv_static(
  app_name: String,
  name: String,
  content_type: String,
) -> response.Response(mist.ResponseData) {
  let assert Ok(app_priv) = application.priv_directory(app_name)
  let file_path = app_priv <> "/static/" <> name
  case mist.send_file(file_path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", content_type)
      |> response.set_body(file)
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}
