import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../../../lustre/lustre/attribute.mjs";
import { class$ } from "../../../lustre/lustre/attribute.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import * as $html from "../../../lustre/lustre/element/html.mjs";
import { div } from "../../../lustre/lustre/element/html.mjs";
import * as $event from "../../../lustre/lustre/event.mjs";
import { advanced } from "../../../lustre/lustre/event.mjs";
import * as $codec from "../../components/scroll_view/codec.mjs";
import * as $types from "../../components/scroll_view/types.mjs";
import { toList } from "../../gleam.mjs";

export function view(_, model, _1) {
  let $ = model.container_height;
  let $1 = model.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let $2 = model.scrollbar_pressed;
    if ($2) {
      return toList([
        div(
          toList([
            class$("fixed inset-0 w-full h-full z-[9999]"),
            advanced("pointermove", $codec.overlay_pointer_move_decoder()),
            advanced("pointerup", $codec.pointer_up_decoder()),
          ]),
          toList([]),
        ),
      ]);
    } else {
      return toList([]);
    }
  } else {
    return toList([]);
  }
}
