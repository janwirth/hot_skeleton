import gleam/dynamic/decode
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/io
import gleam/list
import gleam/string
import lustre/event.{handler}
import components/scroll_view/types
import components/scroll_view/helpers

@external(javascript, "./scroll_view_ffi.mjs", "getBoundingClientRect")
fn get_bounding_client_rect(event: Dynamic) -> Dynamic

fn rect_decoder() {
  use top <- decode.field("top", decode.float)
  use height <- decode.field("height", decode.float)
  decode.success(#(top, height))
}

pub fn measure_decoder() {
  use ch <- decode.field("containerHeight", decode.float)
  use rh <- decode.field("rowHeight", decode.float)
  decode.success(#(ch, rh))
}

pub fn anchor_measured_decoder() {
  decode.then(decode.dynamic, fn(event) {
    case decode.run(event, decode.at(["detail", "containerHeight"], decode.float)), decode.run(
      event,
      decode.at(["detail", "rowHeight"], decode.float),
    ) {
      Ok(ch), Ok(rh) ->
        decode.success(handler(types.Measured(ch, rh), False, False))
      Error(_), _ ->
        decode.failure(handler(types.NoOp, False, False), expected: "detail.containerHeight")
      _, Error(_) ->
        decode.failure(handler(types.NoOp, False, False), expected: "detail.rowHeight")
    }
  })
}

pub fn pointer_up_decoder() {
  decode.then(decode.dynamic, fn(_) {
    decode.success(handler(types.ScrollbarReleased, False, False))
  })
}

pub fn wheel_decoder(max_scroll: Float) {
  decode.then(decode.dynamic, fn(event) {
    let ctrl = decode.run(event, decode.at(["ctrlKey"], decode.bool)) == Ok(True)
    let delta_decoder = decode.at(["deltaY"], decode.float)
    case ctrl {
      True ->
        decode.failure(
          handler(types.Wheel(0.0), True, False),
          expected: "ctrlKey ignored",
        )
      False ->
        decode.map(delta_decoder, fn(delta) {
          let prevent = max_scroll >. 0.0
          handler(types.Wheel(delta), prevent, False)
        })
    }
  })
}

pub fn overlay_pointer_move_decoder() {
  decode.then(decode.dynamic, fn(event) {
    case decode.run(event, decode.at(["clientY"], decode.float)), decode.run(
      event,
      decode.at(["buttons"], decode.int),
    ) {
      Ok(client_y), Ok(buttons) ->
        decode.success(handler(types.PointerMove(client_y, buttons), False, False))
      Error(_), _ ->
        decode.failure(handler(types.NoOp, False, False), expected: "clientY")
      _, Error(_) ->
        decode.failure(handler(types.NoOp, False, False), expected: "buttons")
    }
  })
}

pub fn track_pointerdown_decoder(max_scroll: Float) {
  decode.then(decode.dynamic, fn(event) {
    case decode.run(event, decode.at(["clientY"], decode.float)) {
      Ok(client_y) -> {
        case get_bounding_client_rect(event) |> decode.run(rect_decoder()) {
          Ok(#(top, height)) -> {
            let offset = helpers.rel_to_offset(client_y, top, height, max_scroll)
            decode.success(handler(types.TrackPointerdown(offset, top, height), True, True))
          }
          Error(e) -> {
            io.println(
              "error, failed to get bounding client rect"
              <> " clientY: "
              <> float.to_string(client_y)
              <> " error: "
              <> string.join(
                list.map(e, fn(e) {
                  e.expected <> " " <> e.found <> " " <> string.join(e.path, with: ".")
                }),
                with: " ",
              ),
            )
            decode.success(handler(types.TrackPointerdown(0.0, 0.0, 1.0), True, True))
          }
        }
      }
      Error(_) -> {
        io.println("error, failed to get clientY")
        decode.success(handler(types.TrackPointerdown(0.0, 0.0, 1.0), True, True))
      }
    }
  })
}
