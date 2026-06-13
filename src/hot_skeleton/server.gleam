//// HTTP helpers for a mist web server: port, static files, 404, etc.
////
//// [`serve_reverse_proxy`](#serve_reverse_proxy) implements
//// `GET /reverse-proxy?path=…` for streaming local audio, images, and text.
////
//// Hot reload in dev is built on [`hot_reload`](../hot_reload.gleam) in
//// [`component_wrapper`](./component_wrapper.gleam) and the dev entrypoint.

import envoy
import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process.{sleep_forever}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import mist
import simplifile

import woof

const max_port_attempts: Int = 10_000

@external(erlang, "hot_skeleton_ffi", "first_free_tcp_port")
fn first_free_tcp_port(first: Int, last: Int) -> Result(Int, Nil)

/// [`mist.new`] accepts a handler `fn(Request(mist.Connection)) -> Response(mist.ResponseData)`.
/// [`component_wrapper.start_hot_server`](./component_wrapper.gleam#start_hot_server) passes the
/// [`hot_reload`](./hot_reload.gleam)-wrapped handler.
///
/// Picks a free port with `gen_tcp` first (avoids a failed [`mist`]/glisten start tearing down
/// the whole runtime on `Eaddrinuse`), then starts mist once. Prefers `first_port`, then
/// `first_port+1` … (capped at 65535, up to 10,000 steps).
pub fn start(
  first_port: Int,
  handle: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> Nil {
  let end_port = int.min(first_port + max_port_attempts, 65_535)
  case first_free_tcp_port(first_port, end_port) {
    Error(Nil) -> {
      io.println(
        "[hot_skeleton] no free TCP port from "
        <> int.to_string(first_port)
        <> " to "
        <> int.to_string(end_port)
        <> " (inclusive).",
      )
      panic as "no free TCP port in range for hot_skeleton server"
    }
    Ok(port) -> {
      case try_bind(port, handle) {
        Ok(bound) -> {
          woof.info("boot", [
            woof.str("event", "listening on 0.0.0.0:" <> int.to_string(bound)),
          ])
          io.println(
            "[hot_skeleton] listening on 0.0.0.0:" <> int.to_string(bound),
          )
          case bound == first_port {
            True -> Nil
            False ->
              io.println(
                "[hot_skeleton] port "
                <> int.to_string(first_port)
                <> " in use, using "
                <> int.to_string(bound),
              )
          }
          sleep_forever()
        }
        Error(_) -> {
          io.println(
            "[hot_skeleton] could not start HTTP server (port was free in probe; try again).",
          )
          panic as "hot_skeleton mist start failed after port probe"
        }
      }
    }
  }
}

fn try_bind(
  port: Int,
  handle: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> Result(Int, actor.StartError) {
  case
    handle
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.after_start(fn(_p, _scheme, _ip) { Nil })
    |> mist.start
  {
    Ok(_) -> Ok(port)
    Error(e) -> Error(e)
  }
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

/// `GET /reverse-proxy?path=…` — stream a local file (audio, image, or text) via
/// [`mist.send_file`]. Returns 400 without `path`, 404 if missing, 415 for
/// unsupported types.
pub fn serve_reverse_proxy(
  req: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  case query_param(req, "path") {
    None -> bad_request("missing path query parameter")
    Some(file_path) ->
      case streamable_content_type(file_path) {
        None -> unsupported_media_type(file_path)
        Some(content_type) ->
          case simplifile.is_file(file_path) {
            Ok(True) -> serve_local_file(file_path, content_type)
            _ -> not_found(file_path)
          }
      }
  }
}

fn bad_request(message: String) -> response.Response(mist.ResponseData) {
  response.new(400)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(message)))
}

fn unsupported_media_type(path: String) -> response.Response(mist.ResponseData) {
  woof.info("http", [woof.str("event", "415 reverse-proxy " <> path)])
  response.new(415)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("unsupported media type")))
}

fn serve_local_file(
  file_path: String,
  content_type: String,
) -> response.Response(mist.ResponseData) {
  case mist.send_file(file_path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", content_type)
      |> response.prepend_header("cross-origin-resource-policy", "same-origin")
      |> response.set_header("connection", "keep-alive")  // persistent connection
      |> response.set_header("cache-control", "max-age=3600")  // cache hot files
      |> response.set_body(file)
    Error(_) -> not_found(file_path)
  }
}

fn file_extension(path: String) -> String {
  case string.split(path, ".") |> list.reverse {
    [] -> ""
    [ext, ..] -> string.lowercase(ext)
  }
}

/// MIME type for paths we stream through `/reverse-proxy`; `None` otherwise.
pub fn streamable_content_type(path: String) -> Option(String) {
  case file_extension(path) {
    "png" -> Some("image/png")
    "jpg" | "jpeg" -> Some("image/jpeg")
    "gif" -> Some("image/gif")
    "webp" -> Some("image/webp")
    "svg" -> Some("image/svg+xml")
    "ico" -> Some("image/x-icon")
    "bmp" -> Some("image/bmp")
    "avif" -> Some("image/avif")
    "mp3" -> Some("audio/mpeg")
    "m4a" -> Some("audio/mp4")
    "wav" -> Some("audio/wav")
    "ogg" -> Some("audio/ogg")
    "flac" -> Some("audio/flac")
    "aac" -> Some("audio/aac")
    "opus" -> Some("audio/opus")
    "weba" -> Some("audio/webm")
    "txt" -> Some("text/plain; charset=utf-8")
    "md" -> Some("text/markdown; charset=utf-8")
    "html" | "htm" -> Some("text/html; charset=utf-8")
    "css" -> Some("text/css; charset=utf-8")
    "json" -> Some("application/json; charset=utf-8")
    "xml" -> Some("application/xml; charset=utf-8")
    "js" | "mjs" | "cjs" -> Some("text/javascript; charset=utf-8")
    "ts" -> Some("text/typescript; charset=utf-8")
    "gleam" -> Some("text/plain; charset=utf-8")
    "csv" -> Some("text/csv; charset=utf-8")
    "log" -> Some("text/plain; charset=utf-8")
    "yaml" | "yml" -> Some("text/yaml; charset=utf-8")
    _ -> None
  }
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
