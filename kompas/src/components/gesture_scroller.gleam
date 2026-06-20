import gleam/io
import components/scroll_view
import components/scroll_view/codec
import components/scroll_view/debug
import components/scroll_view/helpers
import components/scroll_view/anchor
import components/scroll_view/pointer_events_overlay
import components/scroll_view/scrollbar
import components/scroll_view/types
import gleam/int
import gleam/option
import gleam/string
import components/scroll_view_app.{type ScrollViewApp}
import gleam/dynamic/decode
import lustre/attribute.{class, id, type Attribute}
import lustre/component
import lustre/effect
import lustre/element/html.{div, slot}
import lustre/element.{type Element, map as element_map}
import lustre/event.{advanced}

pub const element_name = "gesture-scroller"

pub type Model {
  Model(scroll: scroll_view.Model, total_items: option.Option(Int))
}

pub type Msg {
  Scroll(scroll_view.Msg)
  TotalItemsAttribute(Int)
  ScrollInstanceAttribute(String)
}

const default_container_id = "gesture-scroller-container"
const default_row_class = "gesture-scroller-row"

fn scroll_ids_from_instance_slug(slug: String) -> #(String, String) {
  #(slug <> "-vp", slug <> "-row")
}

@external(javascript, "./gesture_scroller_ffi.mjs", "ensureThemeClassSync")
fn ensure_theme_class_sync() -> Nil

fn total_for_scroll_count(total_items: option.Option(Int)) -> Int {
  option.unwrap(total_items, 0)
}

fn window_from_model(
  model: scroll_view.Model,
  total_items: option.Option(Int),
) -> scroll_view_app.ScrollWindow {
  case model.container_height, model.row_height {
    option.Some(ch), option.Some(rh) ->
      case total_items {
        option.Some(ti) -> {
          let unclamped_drop = scroll_view.start_index(model.scroll_offset, rh)
          let max_drop = int.max(0, ti - 1)
          let drop = int.min(unclamped_drop, max_drop)
          let fit = scroll_view.items_fit(ch, rh)
          let available = ti - drop
          let take = case available {
            0 -> 0
            n -> int.max(1, int.min(int.max(1, fit), n))
          }
          scroll_view_app.ScrollWindow(drop: drop, take: take)
        }
        option.None -> scroll_view_app.ScrollWindow(drop: 0, take: 0)
      }
    _, _ -> scroll_view_app.ScrollWindow(drop: 0, take: 4)
  }
}

fn decode_total_items_attr(value: String) -> Result(Msg, Nil) {
  case int.parse(value) {
    Ok(n) -> Ok(TotalItemsAttribute(int.max(0, n)))
    Error(_) -> Error(Nil)
  }
}
import components/random_id

fn init(_flags: Nil) -> #(Model, option.Option(scroll_view_app.ScrollWindow), effect.Effect(Msg)) {
  ensure_theme_class_sync()
  anchor.register()
  let container_id = default_container_id <> "-" <> random_id.random_id_5()
  io.println("container_id: " <> container_id)
  let #(scroll, eff) = scroll_view.init(container_id, default_row_class)
  #(
    Model(scroll: scroll, total_items: option.None),
    option.None,
    effect.map(eff, Scroll),
  )
}

pub fn component() -> ScrollViewApp(Msg, Model) {
  scroll_view_app.ScrollViewApp(init, update, component_view)
}

fn update(model: Model, msg: Msg) -> scroll_view_app.UpdateReturn(Msg, Model) {
  case msg {
    Scroll(inner) -> {
      let count = total_for_scroll_count(model.total_items)
      let #(next_scroll, next_effect) =
        scroll_view.update(model.scroll, inner, count)
      #(
        Model(scroll: next_scroll, total_items: model.total_items),
        window_from_model(next_scroll, model.total_items),
        effect.map(next_effect, Scroll),
      )
    }
    TotalItemsAttribute(n) -> {
      let total_items = option.Some(int.max(0, n))
      let scroll = model.scroll
      let count = total_for_scroll_count(total_items)
      let #(next_scroll, reclamp_eff) = case scroll.container_height, scroll.row_height {
        option.Some(ch), option.Some(rh) -> {
          let max = scroll_view.max_scroll_offset(ch, rh, count)
          let clamped = helpers.clamp_scroll(scroll.scroll_offset, max)
          #(
            types.Model(..scroll, scroll_offset: clamped),
            effect.none(),
          )
        }
        _, _ -> #(scroll, effect.none())
      }
      #(
        Model(scroll: next_scroll, total_items: total_items),
        window_from_model(next_scroll, total_items),
        effect.map(reclamp_eff, Scroll),
      )
    }
    ScrollInstanceAttribute(slug) -> {
      let #(cid, rc) = scroll_ids_from_instance_slug(slug)
      case model.scroll.container_id == cid && model.scroll.row_class == rc {
        True -> #(
          model,
          window_from_model(model.scroll, model.total_items),
          effect.none(),
        )
        False -> {
          let #(next_scroll, eff) = scroll_view.init(cid, rc)
          #(
            Model(scroll: next_scroll, total_items: model.total_items),
            window_from_model(next_scroll, model.total_items),
            effect.map(eff, Scroll),
          )
        }
      }
    }
  }
}

fn component_view(model: Model) -> Element(Msg) {
  let count = total_for_scroll_count(model.total_items)
  let scroll = model.scroll
  let max_scroll =
    case scroll.container_height, scroll.row_height {
      option.Some(ch), option.Some(rh) ->
        scroll_view.max_scroll_offset(ch, rh, count)
      _, _ -> 0.0
    }
  let shadow_classes =
    case scroll.scroll_offset >. 0.0, max_scroll >. 0.0 && scroll.scroll_offset <. max_scroll {
      True, True ->
        " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3),inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45),inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]"
      True, False ->
        " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45)]"
      False, True ->
        " [box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]"
      False, False -> ""
    }

  let cid = scroll.container_id
  let scrollbar = scrollbar.view(cid, scroll, max_scroll)
  let overlay = pointer_events_overlay.view(cid, scroll, max_scroll)
  let debug_block =
    case scroll.debug_enabled {
      True -> div([class("mb-2")], [debug.debug_info(scroll, count)])
      False -> div([], [])
    }

  div([class("flex flex-col min-h-0 h-full")], [
    div(
      [class("flex-1 flex min-h-0")],
      [
        div(
          [
            class(
              "flex-1 min-h-0 min-w-0 overflow-hidden h-full " <> shadow_classes,
            ),
            id(cid),
            advanced("wheel", codec.wheel_decoder(max_scroll)),
            advanced("anchormeasured", codec.anchor_measured_decoder()),
          ],
          [slot([], [])],
        ),
        scrollbar,
        ..overlay,
      ],
    ),
    debug_block,
  ])
  |> element_map(Scroll)
}

fn decode_scroll_instance_attr(value: String) -> Result(Msg, Nil) {
  let slug = string.trim(value)
  case slug == "" {
    True -> Error(Nil)
    False -> Ok(ScrollInstanceAttribute(slug))
  }
}

pub fn register() {
  scroll_view_app.register_with_options(element_name, component(), [
    component.on_attribute_change("total-items", decode_total_items_attr),
    component.on_attribute_change("scroll-instance", decode_scroll_instance_attr),
    component.on_context_change(
      debug.context_key,
      decode.bool |> decode.map(fn(b) { Scroll(types.DebugChanged(b)) }),
    ),
  ])
}

pub fn view(
  on_scroll_window: fn(scroll_view_app.ScrollWindow) -> msg,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  scroll_view_app.view(element_name, on_scroll_window, attrs, children)
}
