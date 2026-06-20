import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import * as $gesture_scroller from "./components/gesture_scroller.mjs";
import * as $scroll_view from "./components/scroll_view.mjs";
import * as $scroll_view_app from "./components/scroll_view_app.mjs";
import * as $layout_common from "./demos/layout_common.mjs";
import { toList } from "./gleam.mjs";

export function col(attrs, children) {
  return $layout_common.col(attrs, children);
}

export function row(attrs, children) {
  return $layout_common.row(attrs, children);
}

export function fill_col(attrs, children) {
  return $layout_common.fill_col(attrs, children);
}

export function wrap_row(attrs, children) {
  return $layout_common.wrap_row(attrs, children);
}

export function fill_row(attrs, children) {
  return $layout_common.fill_row(attrs, children);
}

export function scroll_view(msg, attrs, children) {
  return $gesture_scroller.view(msg, attrs, children);
}

export function register_scroll_view() {
  return $gesture_scroller.register();
}

export function initial_scroll_window() {
  return new $scroll_view_app.ScrollWindow(0, 4);
}

export function scroll_window(drop, take) {
  return new $scroll_view_app.ScrollWindow(drop, take);
}

export function prepare_scroll_view_items(items) {
  return $list.append(items, toList([$scroll_view.anchor(toList([]))]));
}

export function layout_type_attrs(layout_type) {
  return $layout_common.layout_type_attrs(layout_type);
}

export function scroll_view_fill_col_attrs() {
  return $layout_common.layout_type_attrs(new $layout_common.FillCol());
}

export function main() {
  return undefined;
}
