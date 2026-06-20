import gleam/float
import gleam/option
import lustre/attribute.{class, id, style}
import lustre/element/html.{div}
import lustre/event.{advanced}
import lustre/element.{type Element}
import components/scroll_view/types
import components/scroll_view/codec
import components/scroll_view/helpers

pub fn view(
  container_id: String,
  model: types.Model,
  max_scroll: Float,
) -> Element(types.Msg) {
  case model.container_height, model.row_height {
    option.Some(_ch), option.Some(_rh) -> {
      case max_scroll >. 0.0 {
        True -> {
          let handle_height = helpers.handle_height()
          let n = model.scroll_offset /. max_scroll
          let top_calc =
            "calc("
            <> float.to_string(n)
            <> " * (100% - "
            <> float.to_string(handle_height)
            <> "px))"
          let track_id = container_id <> "-track"
          div(
            [
              id(track_id),
              class(" w-8 shrink-0 relative border-l border-black/10 dark:border-white/10"),
              advanced("pointerdown", codec.track_pointerdown_decoder(max_scroll)),
            ],
            [
              div(
                [
                  class(
                    "absolute left-0.5 right-0.5 bg-black dark:bg-white pointer-events-none",
                  ),
                  style("height", float.to_string(handle_height) <> "px"),
                  style("top", top_calc),
                ],
                [],
              ),
            ],
          )
        }
        False -> div([class("w-4 shrink-0")], [])
      }
    }
    _, _ -> div([class("w-4 shrink-0")], [])
  }
}
