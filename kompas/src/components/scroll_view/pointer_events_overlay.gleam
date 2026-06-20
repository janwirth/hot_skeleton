import gleam/option
import lustre/attribute.{class}
import lustre/element/html.{div}
import lustre/event.{advanced}
import lustre/element.{type Element}
import components/scroll_view/types
import components/scroll_view/codec

pub fn view(
  _container_id: String,
  model: types.Model,
  _max_scroll: Float,
) -> List(Element(types.Msg)) {
  case model.container_height, model.row_height {
    option.Some(_ch), option.Some(_rh) -> {
      case model.scrollbar_pressed {
        True -> {
          [
            div(
              [
                class("fixed inset-0 w-full h-full z-[9999]"),
                advanced("pointermove", codec.overlay_pointer_move_decoder()),
                advanced("pointerup", codec.pointer_up_decoder()),
              ],
              [],
            ),
          ]
        }
        False -> []
      }
    }
    _, _ -> []
  }
}
