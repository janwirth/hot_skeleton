import gleam/float
import gleam/int
import gleam/option
import lustre/attribute.{class}
import lustre/element/html.{div}
import lustre/element.{type Element, text}
import components/scroll_view

pub const context_key = "scroll-view/debug"

pub type DebugConfig {
  DebugConfig(enabled: Bool)
}

pub fn debug_info(model: scroll_view.Model, total_items: Int) -> Element(msg) {
  let item_class = "text-xs font-mono opacity-70"

  let events_line =
    div([class(item_class <> " col-span-2")], [
      text("scroll events/s (3×1s windows, oldest→newest): " <> scroll_view.event_rates_summary(model)),
    ])

  let items =
    case model.container_height, model.row_height {
      option.Some(ch), option.Some(rh) -> {
        let drop = scroll_view.start_index(model.scroll_offset, rh)
        let fit = scroll_view.items_fit(ch, rh)
        let max = scroll_view.max_scroll_offset(ch, rh, total_items)
        [
          events_line,
          div([class(item_class)], [
            text(
              "offset: "
              <> int.to_string(float.round(model.scroll_offset))
              <> " | container_height: "
              <> float.to_string(ch)
              <> " | row_height: "
              <> float.to_string(rh),
            ),
          ]),
          div([class(item_class)], [
            text(
              "drop: "
              <> int.to_string(drop)
              <> " | items_fit: "
              <> int.to_string(fit)
              <> " | max_scroll: "
              <> float.to_string(max),
            ),
          ]),
        ]
      }
      _, _ -> [
        events_line,
        div([class(item_class)], [text("measuring...")]),
      ]
    }

  div([], [div([class("mt-2 pt-2 opacity-30 hover:opacity-100 transition-opacity")], [
    div([class("grid grid-cols-2 gap-1")], items),
  ])])
}

pub fn events_display(model: scroll_view.Model) -> Element(msg) {
  div([class("text-xs font-mono opacity-70 m-1")], [
    text("scroll events/s (3s): " <> scroll_view.event_rates_summary(model)),
  ])
}
