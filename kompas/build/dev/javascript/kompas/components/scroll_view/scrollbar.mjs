import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../../../lustre/lustre/attribute.mjs";
import { class$, id, style } from "../../../lustre/lustre/attribute.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import * as $html from "../../../lustre/lustre/element/html.mjs";
import { div } from "../../../lustre/lustre/element/html.mjs";
import * as $event from "../../../lustre/lustre/event.mjs";
import { advanced } from "../../../lustre/lustre/event.mjs";
import * as $codec from "../../components/scroll_view/codec.mjs";
import * as $helpers from "../../components/scroll_view/helpers.mjs";
import * as $types from "../../components/scroll_view/types.mjs";
import { toList, divideFloat } from "../../gleam.mjs";

export function view(container_id, model, max_scroll) {
  let $ = model.container_height;
  let $1 = model.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let $2 = max_scroll > 0.0;
    if ($2) {
      let handle_height = $helpers.handle_height();
      let n = divideFloat(model.scroll_offset, max_scroll);
      let top_calc = ((("calc(" + $float.to_string(n)) + " * (100% - ") + $float.to_string(
        handle_height,
      )) + "px))";
      let track_id = container_id + "-track";
      return div(
        toList([
          id(track_id),
          class$(
            " w-8 shrink-0 relative border-l border-black/10 dark:border-white/10",
          ),
          advanced("pointerdown", $codec.track_pointerdown_decoder(max_scroll)),
        ]),
        toList([
          div(
            toList([
              class$(
                "absolute left-0.5 right-0.5 bg-black dark:bg-white pointer-events-none",
              ),
              style("height", $float.to_string(handle_height) + "px"),
              style("top", top_calc),
            ]),
            toList([]),
          ),
        ]),
      );
    } else {
      return div(toList([class$("w-4 shrink-0")]), toList([]));
    }
  } else {
    return div(toList([class$("w-4 shrink-0")]), toList([]));
  }
}
