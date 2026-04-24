//// Drop-in replacement for [`mist/reload.wrap`](https://hexdocs.pm/mist_reload/mist/reload.html#wrap)
//// that feeds [radiate](https://hexdocs.pm/radiate) an **absolute path** to
//// the project `src/` directory. Radiate's docs explicitly warn:
////
//// > macOS users: always use `"."` or an absolute path, otherwise it won't
//// > work properly!
////
//// `mist_reload` 1.0.1 passes the relative string `"src"`, which means
//// fsevents on macOS never fires and no hot reload ever happens. This module
//// resolves the project root from the current working directory and passes
//// `<cwd>/src` instead. The wire protocol (SSE on `/_reload`, script injected
//// into `<head>`) is identical to `mist_reload`'s.

import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/otp/actor
import gleam/set
import gleam/string
import gleam/string_tree
import mist
import radiate

type Message(t) {
  Register(subscriber: process.Subject(t), reply: process.Subject(Nil))
  Broadcast(t)
}

type ReloadMessage {
  Reloaded
}

/// Wrap a mist handler so that code changes under `<cwd>/src` trigger a
/// `gleam build`, Erlang code swap, and browser refresh. Pass this in place of
/// `mist/reload.wrap` to [`component_wrapper.start_hot_server_with_wrap`].
pub fn wrap(handler) {
  let assert Ok(registry) =
    actor.new(set.new())
    |> actor.on_message(fn(state, message) {
      case message {
        Register(subscriber, reply) -> {
          actor.send(reply, Nil)
          set.insert(state, subscriber)
          |> actor.continue
        }
        Broadcast(payload) -> {
          let _ = set.each(state, fn(pid) { actor.send(pid, payload) })
          actor.continue(state)
        }
      }
    })
    |> actor.start()

  let src_dir = absolute_src_dir()
  let _ =
    radiate.new()
    |> radiate.add_dir(src_dir)
    |> radiate.on_reload(fn(_state: Nil, _file) {
      actor.send(registry.data, Broadcast(Reloaded))
    })
    |> radiate.start()
  debug_handler(registry.data, handler)
}

fn absolute_src_dir() -> String {
  let cwd = get_cwd()
  case string.ends_with(cwd, "/") {
    True -> cwd <> "src"
    False -> cwd <> "/src"
  }
}

@external(erlang, "hot_skeleton_hot_reload_ffi", "cwd")
fn get_cwd() -> String

const debug_script = "<script>
  let reloading = false;
  const source = new EventSource(\"/_reload\");
  source.onmessage = (e) => {
    if (reloading) return;
    reloading = true;
    globalThis.setTimeout(() => window.location.reload(), 200);
  }
</script>"

fn debug_handler(registry, handler) {
  fn(req) {
    let resp = case request.path_segments(req) {
      ["_reload"] -> reload(registry, req)
      _ -> handler(req)
    }
    case resp.body {
      mist.Websocket(..) -> resp
      mist.Bytes(tree) ->
        case response.get_header(resp, "content-type") {
          Ok("text/html" <> _) -> {
            let binary = bytes_tree.to_bit_array(tree)
            case bit_array.to_string(binary) {
              Ok(html) ->
                html
                |> string.replace("</head>", debug_script <> "</head>")
                |> bytes_tree.from_string
                |> mist.Bytes
                |> response.set_body(resp, _)
              Error(_) -> resp
            }
          }
          _ -> resp
        }
      mist.Chunked(..) -> resp
      mist.File(..) -> resp
      mist.ServerSentEvents(..) -> resp
    }
  }
}

fn reload(registry, req) {
  let init = fn(self) {
    let Nil = actor.call(registry, 10, Register(self, _))
    Ok(actor.initialised(Nil))
  }
  mist.server_sent_events(req, response.new(200), init:, loop:)
}

fn loop(state, message, conn) {
  case message {
    Reloaded -> {
      let _ =
        mist.send_event(conn, mist.event(string_tree.from_string("reload")))
      actor.continue(state)
    }
  }
}
