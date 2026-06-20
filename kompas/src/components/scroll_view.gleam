import gleam/dynamic/decode
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import lustre/effect
import lustre/attribute.{class, id}
import lustre/element/html.{div}
import lustre/element.{map, type Element}
import lustre/event.{advanced}
import components/scroll_view/codec
import components/scroll_view/helpers
import components/scroll_view/anchor as scroll_view_anchor
import components/scroll_view/parent_resize_observer
import components/scroll_view/pointer_events_overlay
import components/scroll_view/scrollbar
import components/scroll_view/types

pub type Config(msg, a) = types.Config(msg, a)
pub type Model = types.Model
pub type Msg = types.Msg

pub fn config(
  container_id: String,
  row_class: String,
  render_row: fn(a) -> Element(msg),
) -> Config(msg, a) {
  types.Config(
    container_id: container_id,
    row_class: row_class,
    render_row: render_row,
  )
}

@external(javascript, "./scroll_view/scroll_view_ffi.mjs", "measureScrollView")
fn measure_scroll_view(root: Dynamic, container_id: String, row_class: String) -> Dynamic

@external(javascript, "./scroll_view/scroll_view_ffi.mjs", "performanceNow")
fn performance_now() -> Float

fn record_scroll_event(model: Model) -> List(Float) {
  let now = performance_now()
  let kept =
    list.filter(model.event_timestamps, fn(t) { now -. t <. 3000.0 })
  list.append(kept, [now])
}

/// Counts wheel + scrollbar-track events in each of three 1s age buckets (3s window).
pub fn event_rates_summary(model: Model) -> String {
  let now = performance_now()
  let ts =
    list.filter(model.event_timestamps, fn(t) { now -. t <. 3000.0 })
  case ts {
    [] -> "(none)"
    _ -> {
      let count_age = fn(low: Float, high: Float) {
        list.length(list.filter(ts, fn(t) {
          let age = now -. t
          age >=. low && age <. high
        }))
      }
      let b_old = count_age(2000.0, 3000.0)
      let b_mid = count_age(1000.0, 2000.0)
      let b_new = count_age(0.0, 1000.0)
      int.to_string(b_old) <> "/s · " <> int.to_string(b_mid) <> "/s · " <> int.to_string(b_new) <> "/s"
    }
  }
}

pub fn init(container_id: String, row_class: String) {
  parent_resize_observer.init()
  scroll_view_anchor.register()
  #(
    types.Model(
      container_id: container_id,
      row_class: row_class,
      container_height: option.None,
      row_height: option.None,
      scroll_offset: 0.0,
      event_timestamps: [],
      cursor_y_relative: option.None,
      scrollbar_pressed: False,
      scrollbar_track_top: option.None,
      scrollbar_track_height: option.None,
      debug_enabled: False,
    ),
    effect.after_paint(fn(dispatch, root) {
      case measure_scroll_view(root, container_id, row_class)
      |> decode.run(codec.measure_decoder())
      {
        Ok(#(ch, rh)) -> dispatch(types.Measured(ch, rh))
        Error(_) -> Nil
      }
    }),
  )
}

pub fn max_scroll_offset(container_height: Float, row_height: Float, total_items: Int) -> Float {
  let fit = items_fit(container_height, row_height)
  case total_items > fit {
    True -> {
      let items_fit_f = float.ceiling(container_height /. row_height)
      let total = int.to_float(total_items)
      let max_start = total -. items_fit_f
      let base = float.max(0.0, max_start *. row_height)
      base +. { container_height *. 0.5 }
    }
    False -> 0.0
  }
}

pub fn start_index(scroll_offset: Float, row_height: Float) -> Int {
  case row_height >. 0.0 {
    True -> float.truncate(float.floor(scroll_offset /. row_height))
    False -> 0
  }
}

pub fn items_fit(container_height: Float, row_height: Float) -> Int {
  case row_height >. 0.0 {
    True -> float.truncate(float.ceiling(container_height /. row_height))
    False -> 0
  }
}

pub fn update(model: Model, msg: Msg, total_items: Int) {
  case msg {
    types.NoOp -> #(model, effect.none())
    types.ParentResized -> #(
      model,
      effect.after_paint(fn(dispatch, root) {
        case measure_scroll_view(root, model.container_id, model.row_class)
        |> decode.run(codec.measure_decoder())
        {
          Ok(#(ch, rh)) -> dispatch(types.Measured(ch, rh))
          Error(_) -> Nil
        }
      }),
    )
    types.Measured(ch, rh) -> {
      let max = max_scroll_offset(ch, rh, total_items)
      let clamped_offset = helpers.clamp_scroll(model.scroll_offset, max)
      #(
        types.Model(
          ..model,
          container_height: option.Some(ch),
          row_height: option.Some(rh),
          scroll_offset: clamped_offset

        ),
        effect.none(),
      )
    }
    types.DebugChanged(enabled) -> #(
      types.Model(..model, debug_enabled: enabled),
      effect.none(),
    )
    types.Wheel(delta) -> {
      let new_offset =
        case model.container_height, model.row_height {
          option.Some(ch), option.Some(rh) -> {
            let max = max_scroll_offset(ch, rh, total_items)
            helpers.clamp_scroll(model.scroll_offset +. delta, max)
          }
          _, _ -> model.scroll_offset
        }
      let ts = record_scroll_event(model)
      #(
        types.Model(..model, scroll_offset: new_offset, event_timestamps: ts),
        effect.none(),
      )
    }
    types.TrackPointerdown(offset, track_top, track_height) -> {
      let clamped =
        case model.container_height, model.row_height {
          option.Some(ch), option.Some(rh) -> helpers.clamp_scroll(offset, max_scroll_offset(ch, rh, total_items))
          _, _ -> offset
        }
      let ts = record_scroll_event(model)
      #(
        types.Model(
          ..model,
          scroll_offset: clamped,
          event_timestamps: ts,
          scrollbar_pressed: True,
          scrollbar_track_top: option.Some(track_top),
          scrollbar_track_height: option.Some(track_height),
        ),
        effect.none(),
      )
    }
    types.PointerMove(client_y, buttons) -> {
      let new_model =
        case model.scrollbar_track_top, model.scrollbar_track_height {
          option.Some(track_top), option.Some(track_height) -> {
            let max =
              case model.container_height, model.row_height {
                option.Some(ch), option.Some(rh) -> max_scroll_offset(ch, rh, total_items)
                _, _ -> 0.0
              }
            let rel =
              case track_height >. 0.0 {
                True ->
                  float.min(1.0, float.max(0.0, { client_y -. track_top } /. track_height))
                False -> 0.0
              }
            case buttons == 1 {
              True -> {
                let offset = helpers.rel_to_offset(client_y, track_top, track_height, max)
                let clamped = helpers.clamp_scroll(offset, max)
                types.Model(..model, cursor_y_relative: option.Some(rel), scroll_offset: clamped)
              }
              False -> types.Model(..model, cursor_y_relative: option.Some(rel))
            }
          }
          _, _ -> model
        }
      #(new_model, effect.none())
    }
    types.ScrollbarReleased -> #(
      types.Model(
        ..model,
        scrollbar_pressed: False,
        scrollbar_track_top: option.None,
        scrollbar_track_height: option.None,
      ),
      effect.none(),
    )
  }
}

pub fn view(data: List(a), model: Model, config: Config(msg, a)) -> Element(Msg) {
  let types.Config(container_id, row_class, render_row) = config
  let total_items = list.length(data)
  let render_rows = fn(rows: List(a)) {
    list.index_map(rows, fn(item, i) {
      let row = map(render_row(item), fn(_) { types.NoOp })
      let row_classes = case i == 0 {
        True -> row_class <> " border-b border-black/5 dark:border-white/5 px-2 py-1 text-sm"
        False -> "border-b border-black/5 dark:border-white/5 px-2 py-1 text-sm"
      }
      div([class(row_classes)], [row])
    })
  }

  let max_scroll =
    case model.container_height, model.row_height {
      option.Some(ch), option.Some(rh) -> max_scroll_offset(ch, rh, total_items)
      _, _ -> 0.0
    }

  let shadow_classes =
    case model.scroll_offset >. 0.0, max_scroll >. 0.0 && model.scroll_offset <. max_scroll {
      True, True ->
        " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3),inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45),inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]"
      True, False ->
        " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45)]"
      False, True ->
        " [box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]"
      False, False -> ""
    }

  let container_attrs = [
    id(container_id),
    class("h-96 overflow-hidden" <> shadow_classes),
    advanced("wheel", codec.wheel_decoder(max_scroll)),
  ]

  let content =
    case model.container_height, model.row_height {
      option.Some(ch), option.Some(rh) -> {
        let unclamped_drop = start_index(model.scroll_offset, rh)
        let max_drop = int.max(0, total_items - 1)
        let drop = int.min(unclamped_drop, max_drop)
        let fit = items_fit(ch, rh)
        let available = total_items - drop
        let take = case available {
          0 -> 0
          n -> int.max(1, int.min(int.max(1, fit), n))
        }
        let visible = list.take(list.drop(data, drop), take)
        render_rows(visible)
      }
      option.None, option.None -> {
        let visible = list.take(data, 1)
        render_rows(visible)
      }
      _, _ -> []
    }

  let resize_observer =
    parent_resize_observer.view(fn(_) { types.ParentResized }, content)

  let scrollbar = scrollbar.view(container_id, model, max_scroll)
  let overlay = pointer_events_overlay.view(container_id, model, max_scroll)

  div(
    [class("flex-1 flex min-h-0")],
    list.append(
      [
        div([class("flex-1 min-w-0 overflow-hidden h-full"), ..container_attrs], [resize_observer]),
        scrollbar,
      ],
      overlay,
    ),
  )
}

pub fn anchor(attrs: List(attribute.Attribute(msg))) -> Element(msg) {
  scroll_view_anchor.view(attrs)
}

