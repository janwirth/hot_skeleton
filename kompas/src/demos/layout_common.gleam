import gleam/list
import lustre/attribute.{class, type Attribute}
import lustre/element/html.{div}
import lustre/element.{type Element}

pub type LayoutType {
  Col
  FillCol
  FillToCol(width_class: String, extra: String)
  Row
  FillRow
  FillToRow(height_class: String, extra: String)
}

pub fn layout_type_to_class(t: LayoutType) -> String {
  let specific = case t {
    Col -> "flex-col basis-min-content" // shrinks
    FillCol -> "basis-0 flex-col flex-1 "
    FillToCol(w, e) ->
      case e {
        "" -> "basis-0 flex-col flex-1  max-w-" <> w
        _ -> "basis-0 flex-col flex-1  max-w-" <> w <> " " <> e
      }
    Row -> "flex-row basis-min-content" // shrinks
    FillRow -> "basis-0 flex-row flex-1  basis-0"
    FillToRow(h, e) ->
      case e {
        "" -> "basis-0 flex-row flex-1  max-h-" <> h
        _ -> "basis-0 flex-row flex-1  max-h-" <> h <> " " <> e
      }
  }
  let shared = "flex content-start content-start"
  shared <> " " <> specific
}

pub fn layout_type_attrs(layout_type: LayoutType) -> List(Attribute(msg)) {
  [class(layout_type_to_class(layout_type))]
}

pub fn col(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  div(list.append(layout_type_attrs(Col), attrs), children)
}

pub fn fill_col(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  div(list.append(layout_type_attrs(FillCol), attrs), children)
}

pub fn fill_to_col(
  width_class: String,
  extra: String,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  div(list.append(layout_type_attrs(FillToCol(width_class, extra)), attrs), children)
}

pub fn row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  div(list.append(layout_type_attrs(Row), attrs), children)
}

pub fn fill_row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  div(list.append(layout_type_attrs(FillRow), attrs), children)
}

pub fn fill_to_row(
  height_class: String,
  extra: String,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  div(list.append(layout_type_attrs(FillToRow(height_class, extra)), attrs), children)
}

pub fn wrap_row(attrs: List(Attribute(msg)), children: List(Element(msg))) -> Element(msg) {
  div(list.append([class("flex flex-row flex-wrap h-full w-full min-h-content content-start")], attrs), children)
}

pub fn in_front(child: Element(msg)) -> Element(msg) {
  div([class("absolute inset-0 p-2 text-xs opacity-70 box-border pointer-events-none")], [child])
}
