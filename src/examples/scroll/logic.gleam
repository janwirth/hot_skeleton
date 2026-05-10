//// MVU for the scroll-view demo. Split from [`hot_scroll`](../hot_scroll.gleam)
//// so `update` / `view` resolve through cross-module fun refs for hot reload.

import demos/layout_common
import gleam/int
import gleam/list
import kompas
import lustre/attribute.{attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{div, text}

pub type Model {
  Model(scroll_window: kompas.ScrollWindow)
}

pub opaque type Message {
  ScrollChanged(kompas.ScrollWindow)
  DevRerenderView
}

const row_count: Int = 400

pub fn init(_: Nil) -> Model {
  Model(scroll_window: kompas.initial_scroll_window())
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    ScrollChanged(sw) -> Model(scroll_window: sw)
    DevRerenderView -> model
  }
}

pub fn trigger_rerender_view() -> Message {
  DevRerenderView
}

fn row_el(i: Int) -> Element(Message) {
  div([class("border-b border-black/30 px-2 py-0.5 hover:opacity-60")], [
    text("Row " <> int.to_string(i)),
  ])
}

fn all_row_indices() -> List(Int) {
  indices_go(0, row_count - 1, [])
}

fn indices_go(i: Int, max: Int, acc: List(Int)) -> List(Int) {
  case i > max {
    True -> list.reverse(acc)
    False -> indices_go(i + 1, max, [i, ..acc])
  }
}

fn visible_rows(window: kompas.ScrollWindow) -> List(Element(Message)) {
  all_row_indices()
  |> list.drop(window.drop)
  |> list.take(window.take)
  |> list.map(row_el)
  |> kompas.prepare_scroll_view_items
}

pub fn view(model: Model) -> Element(Message) {
  let items = visible_rows(model.scroll_window)
  kompas.fill_col([class("h-[70vh] min-h-0 font-mono text-sm")], [
    div([class("opacity-70 pb-1 shrink-0")], [
      text(
        "virtual scroll · drop="
        <> int.to_string(model.scroll_window.drop)
        <> " take="
        <> int.to_string(model.scroll_window.take)
        <> " total="
        <> int.to_string(row_count),
      ),
    ]),
    kompas.scroll_view(
      ScrollChanged,
      list.append(kompas.layout_type_attrs(layout_common.FillCol), [
        attribute("total-items", int.to_string(row_count)),
        class("display-table min-h-0 bg-red-100"),
      ]),
      [div([class("w-full flex flex-col min-h-0 h-full")], items)],
    ),
  ])
}

pub fn view_nonrecursive(model: Model) -> Element(Message) {
  view(model)
}
