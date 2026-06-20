import gleam/dynamic/decode
import gleam/dynamic.{type Dynamic}
import gleam/option
import lustre/attribute.{class}
import lustre/element.{element, type Element}
import lustre/event.{advanced, handler}

@external(javascript, "./parent_resize_observer_ffi.mjs", "register")
fn register() -> Nil

pub fn init() {
  register()
}

@external(javascript, "./parent_resize_observer_ffi.mjs", "getBoundingClientRect")
fn get_bounding_client_rect(event: Dynamic) -> Dynamic

fn rect_decoder() {
  use width <- decode.field("width", decode.float)
  use height <- decode.field("height", decode.float)
  use x <- decode.field("x", decode.float)
  use y <- decode.field("y", decode.float)
  use row_height <- decode.field("rowHeight", decode.optional(decode.float))
  decode.success(#(width, height, x, y, row_height))
}

fn parentresized_decoder(on_resize: fn(#(Float, Float, Float, Float, option.Option(Float))) -> msg) {
  decode.then(decode.dynamic, fn(event) {
    case get_bounding_client_rect(event) |> decode.run(rect_decoder()) {
      Ok(rect) -> decode.success(handler(on_resize(rect), False, False))
      Error(_) ->
        decode.failure(
          handler(on_resize(#(0.0, 0.0, 0.0, 0.0, option.None)), False, False),
          expected: "rect",
        )
    }
  })
}

pub fn view(on_resize: fn(#(Float, Float, Float, Float, option.Option(Float))) -> msg, content: List(Element(msg))) -> Element(msg) {
  element(
    "parent-resize-observer",
    [
      class("block h-full min-h-0")
      ,
      advanced("parentresized", parentresized_decoder(on_resize)),
    ],
    content,
  )
}
