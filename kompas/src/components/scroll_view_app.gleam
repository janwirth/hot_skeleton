import gleam/option
import lustre
import lustre/effect
import lustre/element.{type Element}
import gleam/json
import lustre/attribute.{ type Attribute}
import lustre/event.{emit, on}
import gleam/dynamic/decode




/// Scroll window state: the in/out type for scroll-view events.
pub type ScrollWindow {
  ScrollWindow(drop: Int, take: Int)
}

/// Encapsulates model, init, update, view for a scroll-view app.
pub type ScrollViewApp(msg, model) {
  ScrollViewApp(
    init: fn(Nil) -> #(model, option.Option(ScrollWindow), effect.Effect(msg)),
    update: fn(model, msg) -> UpdateReturn(msg, model),
    view: fn(model) -> Element(msg),
  )
}
pub type UpdateReturn(msg, model) = #(model, ScrollWindow, effect.Effect(msg))

pub fn to_lustre_app(app: ScrollViewApp(msg, model)) -> lustre.App(Nil, model, msg) {
  let init_adapted = fn (_flags: Nil) -> #(model, effect.Effect(msg)) {
    case app.init(Nil) {
      #(model, option.Some(window), effect) -> #(model, effect.batch([effect, emit_scroll_window(window.drop, window.take)]))
      #(model, option.None, effect) -> #(model, effect)
    }
  }
  let update_adapted = fn (model: model, msg: msg) -> #(model, effect.Effect(msg)) {
    case app.update(model, msg) {
      #(model, window, effect) -> #(model, effect.batch([effect, emit_scroll_window(window.drop, window.take)]))
    }
  }
  lustre.component(init_adapted, update_adapted, app.view, [])
}

pub fn register(name: String, app: ScrollViewApp(msg, model)) {
  register_with_options(name, app, [])
}

pub fn register_with_options(name: String, app: ScrollViewApp(msg, model), options) {
  case lustre.is_registered(name) {
    True -> Ok(Nil)
    False ->
      case app {
        ScrollViewApp(init, update, view) -> {
          // Lustre init only returns #(model, Effect). Map scroll-view init, which may
          // report an initial visible window (drop/take), onto that shape: when a window
          // is present, batch the app's effect with one that emits "scroll-window" so the
          // host element can sync slice bounds; otherwise leave the effect unchanged.
          let init_adapted = fn(_flags: Nil) -> #(model, effect.Effect(msg)) {
            case init(Nil) {
              #(m, option.Some(window), eff) ->
                #(m, effect.batch([eff, emit_scroll_window(window.drop, window.take)]))
              #(m, option.None, eff) -> #(m, eff)
            }
          }
          // After every message, scroll-view update always yields the new window; batch the
          // app's effect with emit_scroll_window so the custom element receives updated
          // drop/take on each model transition.
          let update_adapted = fn(model: model, msg: msg) -> #(model, effect.Effect(msg)) {
            case update(model, msg) {
              #(m, window, eff) -> {
                #(m, effect.batch([eff, emit_scroll_window(window.drop, window.take)]))
              }
            }
          }
          lustre.register(
            lustre.component(init_adapted, update_adapted, view, options),
            name,
          )
        }
      }
  }
}



fn emit_scroll_window(drop: Int, take: Int) -> effect.Effect(msg) {
  emit(
    "scroll-window",
    json.object([
      #("drop", json.int(drop)),
      #("take", json.int(take)),
    ]),
  )
}

import lustre/server_component

/// Type-safe wrapper around the scroll-view custom element.
/// attrs: additional attributes (e.g. layout_type_attrs, event.on("scroll-window", decoder))
/// children: slotted content (parent slices data and renders the window)
pub fn view(element_name: String, on_scroll_window: fn(ScrollWindow) -> msg,
  attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  element.element(element_name, [
    on("scroll-window", scroll_window_decoder() |> decode.map(on_scroll_window))
    |> server_component.include(["detail.drop", "detail.take"])
    ,
    ..attrs,

  ], children)
}
fn scroll_window_decoder() {
  decode.then(decode.dynamic, fn(event) {
    case decode.run(event, decode.at(["detail", "drop"], decode.int)) {
      Ok(drop) ->
        case decode.run(event, decode.at(["detail", "take"], decode.int)) {
          Ok(take) -> decode.success(ScrollWindow(drop, take))
          Error(_) -> decode.failure(ScrollWindow(0, 0), expected: "detail.take")
        }
      Error(_) -> decode.failure(ScrollWindow(0, 0), expected: "detail.drop")
    }
  })
}
