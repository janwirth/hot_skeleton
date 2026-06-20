import * as $attribute from "../../../lustre/lustre/attribute.mjs";
import { class$ } from "../../../lustre/lustre/attribute.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import { element } from "../../../lustre/lustre/element.mjs";
import { toList, prepend as listPrepend } from "../../gleam.mjs";
import { register as register_anchor_element } from "./anchor_ffi.mjs";

export function register() {
  return register_anchor_element();
}

export function view(attrs) {
  return element(
    "scroll-view-anchor",
    listPrepend(
      class$(
        "block h-0 min-h-0 m-0 p-0 overflow-hidden opacity-0 pointer-events-none",
      ),
      attrs,
    ),
    toList([]),
  );
}
