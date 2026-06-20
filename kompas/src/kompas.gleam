import components/gesture_scroller
import components/scroll_view
import components/scroll_view_app
import demos/layout_common
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}

pub fn col(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  layout_common.col(attrs, children)
}

pub fn row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  layout_common.row(attrs, children)
}

pub fn fill_col(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  layout_common.fill_col(attrs, children)
}

pub fn wrap_row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  layout_common.wrap_row(attrs, children)
}

pub fn fill_row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  layout_common.fill_row(attrs, children)
}

pub fn scroll_view(msg: fn(ScrollWindow) -> msg, attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  gesture_scroller.view(msg, attrs, children)
}

pub fn register_scroll_view() {
  gesture_scroller.register()
}

pub type ScrollWindow = scroll_view_app.ScrollWindow

pub fn initial_scroll_window() -> ScrollWindow {
  scroll_view_app.ScrollWindow(drop: 0, take: 4)
}

pub fn scroll_window(drop drop: Int, take take: Int) -> ScrollWindow {
  scroll_view_app.ScrollWindow(drop:, take:)
}

pub fn prepare_scroll_view_items(items: List(Element(msg))) -> List(Element(msg)) {
  list.append(items, [scroll_view.anchor([])])
}

pub type LayoutType = layout_common.LayoutType

pub fn layout_type_attrs(layout_type: LayoutType) -> List(Attribute(msg)) {
  layout_common.layout_type_attrs(layout_type)
}

pub fn scroll_view_fill_col_attrs() -> List(Attribute(msg)) {
  layout_common.layout_type_attrs(layout_common.FillCol)
}

pub fn main() {
  Nil
}
