import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $attribute from "../../lustre/lustre/attribute.mjs";
import { class$ } from "../../lustre/lustre/attribute.mjs";
import * as $element from "../../lustre/lustre/element.mjs";
import * as $html from "../../lustre/lustre/element/html.mjs";
import { div } from "../../lustre/lustre/element/html.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class Col extends $CustomType {}
export const LayoutType$Col = () => new Col();
export const LayoutType$isCol = (value) => value instanceof Col;

export class FillCol extends $CustomType {}
export const LayoutType$FillCol = () => new FillCol();
export const LayoutType$isFillCol = (value) => value instanceof FillCol;

export class FillToCol extends $CustomType {
  constructor(width_class, extra) {
    super();
    this.width_class = width_class;
    this.extra = extra;
  }
}
export const LayoutType$FillToCol = (width_class, extra) =>
  new FillToCol(width_class, extra);
export const LayoutType$isFillToCol = (value) => value instanceof FillToCol;
export const LayoutType$FillToCol$width_class = (value) => value.width_class;
export const LayoutType$FillToCol$0 = (value) => value.width_class;
export const LayoutType$FillToCol$extra = (value) => value.extra;
export const LayoutType$FillToCol$1 = (value) => value.extra;

export class Row extends $CustomType {}
export const LayoutType$Row = () => new Row();
export const LayoutType$isRow = (value) => value instanceof Row;

export class FillRow extends $CustomType {}
export const LayoutType$FillRow = () => new FillRow();
export const LayoutType$isFillRow = (value) => value instanceof FillRow;

export class FillToRow extends $CustomType {
  constructor(height_class, extra) {
    super();
    this.height_class = height_class;
    this.extra = extra;
  }
}
export const LayoutType$FillToRow = (height_class, extra) =>
  new FillToRow(height_class, extra);
export const LayoutType$isFillToRow = (value) => value instanceof FillToRow;
export const LayoutType$FillToRow$height_class = (value) => value.height_class;
export const LayoutType$FillToRow$0 = (value) => value.height_class;
export const LayoutType$FillToRow$extra = (value) => value.extra;
export const LayoutType$FillToRow$1 = (value) => value.extra;

export function layout_type_to_class(t) {
  let _block;
  if (t instanceof Col) {
    _block = "flex-col basis-min-content";
  } else if (t instanceof FillCol) {
    _block = "basis-0 flex-col flex-1 ";
  } else if (t instanceof FillToCol) {
    let w = t.width_class;
    let e = t.extra;
    if (e === "") {
      _block = "basis-0 flex-col flex-1  max-w-" + w;
    } else {
      _block = (("basis-0 flex-col flex-1  max-w-" + w) + " ") + e;
    }
  } else if (t instanceof Row) {
    _block = "flex-row basis-min-content";
  } else if (t instanceof FillRow) {
    _block = "basis-0 flex-row flex-1  basis-0";
  } else {
    let h = t.height_class;
    let e = t.extra;
    if (e === "") {
      _block = "basis-0 flex-row flex-1  max-h-" + h;
    } else {
      _block = (("basis-0 flex-row flex-1  max-h-" + h) + " ") + e;
    }
  }
  let specific = _block;
  let shared = "flex content-start content-start";
  return (shared + " ") + specific;
}

export function layout_type_attrs(layout_type) {
  return toList([class$(layout_type_to_class(layout_type))]);
}

export function col(attrs, children) {
  return div($list.append(layout_type_attrs(new Col()), attrs), children);
}

export function fill_col(attrs, children) {
  return div($list.append(layout_type_attrs(new FillCol()), attrs), children);
}

export function fill_to_col(width_class, extra, attrs, children) {
  return div(
    $list.append(layout_type_attrs(new FillToCol(width_class, extra)), attrs),
    children,
  );
}

export function row(attrs, children) {
  return div($list.append(layout_type_attrs(new Row()), attrs), children);
}

export function fill_row(attrs, children) {
  return div($list.append(layout_type_attrs(new FillRow()), attrs), children);
}

export function fill_to_row(height_class, extra, attrs, children) {
  return div(
    $list.append(layout_type_attrs(new FillToRow(height_class, extra)), attrs),
    children,
  );
}

export function wrap_row(attrs, children) {
  return div(
    $list.append(
      toList([
        class$(
          "flex flex-row flex-wrap h-full w-full min-h-content content-start",
        ),
      ]),
      attrs,
    ),
    children,
  );
}

export function in_front(child) {
  return div(
    toList([
      class$(
        "absolute inset-0 p-2 text-xs opacity-70 box-border pointer-events-none",
      ),
    ]),
    toList([child]),
  );
}
