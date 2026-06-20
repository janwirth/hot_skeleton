import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../../../lustre/lustre/attribute.mjs";
import { class$ } from "../../../lustre/lustre/attribute.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import { text } from "../../../lustre/lustre/element.mjs";
import * as $html from "../../../lustre/lustre/element/html.mjs";
import { div } from "../../../lustre/lustre/element/html.mjs";
import * as $scroll_view from "../../components/scroll_view.mjs";
import { toList, CustomType as $CustomType } from "../../gleam.mjs";

export class DebugConfig extends $CustomType {
  constructor(enabled) {
    super();
    this.enabled = enabled;
  }
}
export const DebugConfig$DebugConfig = (enabled) => new DebugConfig(enabled);
export const DebugConfig$isDebugConfig = (value) =>
  value instanceof DebugConfig;
export const DebugConfig$DebugConfig$enabled = (value) => value.enabled;
export const DebugConfig$DebugConfig$0 = (value) => value.enabled;

export const context_key = "scroll-view/debug";

export function debug_info(model, total_items) {
  let item_class = "text-xs font-mono opacity-70";
  let events_line = div(
    toList([class$(item_class + " col-span-2")]),
    toList([
      text(
        "scroll events/s (3×1s windows, oldest→newest): " + $scroll_view.event_rates_summary(
          model,
        ),
      ),
    ]),
  );
  let _block;
  let $ = model.container_height;
  let $1 = model.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let ch = $[0];
    let rh = $1[0];
    let drop = $scroll_view.start_index(model.scroll_offset, rh);
    let fit = $scroll_view.items_fit(ch, rh);
    let max = $scroll_view.max_scroll_offset(ch, rh, total_items);
    _block = toList([
      events_line,
      div(
        toList([class$(item_class)]),
        toList([
          text(
            (((("offset: " + $int.to_string($float.round(model.scroll_offset))) + " | container_height: ") + $float.to_string(
              ch,
            )) + " | row_height: ") + $float.to_string(rh),
          ),
        ]),
      ),
      div(
        toList([class$(item_class)]),
        toList([
          text(
            (((("drop: " + $int.to_string(drop)) + " | items_fit: ") + $int.to_string(
              fit,
            )) + " | max_scroll: ") + $float.to_string(max),
          ),
        ]),
      ),
    ]);
  } else {
    _block = toList([
      events_line,
      div(toList([class$(item_class)]), toList([text("measuring...")])),
    ]);
  }
  let items = _block;
  return div(
    toList([]),
    toList([
      div(
        toList([
          class$("mt-2 pt-2 opacity-30 hover:opacity-100 transition-opacity"),
        ]),
        toList([div(toList([class$("grid grid-cols-2 gap-1")]), items)]),
      ),
    ]),
  );
}

export function events_display(model) {
  return div(
    toList([class$("text-xs font-mono opacity-70 m-1")]),
    toList([
      text("scroll events/s (3s): " + $scroll_view.event_rates_summary(model)),
    ]),
  );
}
