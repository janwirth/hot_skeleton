import * as $dynamic from "../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $float from "../../gleam_stdlib/gleam/float.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../../lustre/lustre/attribute.mjs";
import { class$, id } from "../../lustre/lustre/attribute.mjs";
import * as $effect from "../../lustre/lustre/effect.mjs";
import * as $element from "../../lustre/lustre/element.mjs";
import { map } from "../../lustre/lustre/element.mjs";
import * as $html from "../../lustre/lustre/element/html.mjs";
import { div } from "../../lustre/lustre/element/html.mjs";
import * as $event from "../../lustre/lustre/event.mjs";
import { advanced } from "../../lustre/lustre/event.mjs";
import * as $scroll_view_anchor from "../components/scroll_view/anchor.mjs";
import * as $codec from "../components/scroll_view/codec.mjs";
import * as $helpers from "../components/scroll_view/helpers.mjs";
import * as $parent_resize_observer from "../components/scroll_view/parent_resize_observer.mjs";
import * as $pointer_events_overlay from "../components/scroll_view/pointer_events_overlay.mjs";
import * as $scrollbar from "../components/scroll_view/scrollbar.mjs";
import * as $types from "../components/scroll_view/types.mjs";
import { Ok, toList, Empty as $Empty, prepend as listPrepend, divideFloat } from "../gleam.mjs";
import {
  measureScrollView as measure_scroll_view,
  performanceNow as performance_now,
} from "./scroll_view/scroll_view_ffi.mjs";

export function config(container_id, row_class, render_row) {
  return new $types.Config(container_id, row_class, render_row);
}

function record_scroll_event(model) {
  let now = performance_now();
  let kept = $list.filter(
    model.event_timestamps,
    (t) => { return (now - t) < 3000.0; },
  );
  return $list.append(kept, toList([now]));
}

/**
 * Counts wheel + scrollbar-track events in each of three 1s age buckets (3s window).
 */
export function event_rates_summary(model) {
  let now = performance_now();
  let ts = $list.filter(
    model.event_timestamps,
    (t) => { return (now - t) < 3000.0; },
  );
  if (ts instanceof $Empty) {
    return "(none)";
  } else {
    let count_age = (low, high) => {
      return $list.length(
        $list.filter(
          ts,
          (t) => {
            let age = now - t;
            return (age >= low) && (age < high);
          },
        ),
      );
    };
    let b_old = count_age(2000.0, 3000.0);
    let b_mid = count_age(1000.0, 2000.0);
    let b_new = count_age(0.0, 1000.0);
    return (((($int.to_string(b_old) + "/s · ") + $int.to_string(b_mid)) + "/s · ") + $int.to_string(
      b_new,
    )) + "/s";
  }
}

export function init(container_id, row_class) {
  $parent_resize_observer.init();
  $scroll_view_anchor.register();
  return [
    new $types.Model(
      container_id,
      row_class,
      new $option.None(),
      new $option.None(),
      0.0,
      toList([]),
      new $option.None(),
      false,
      new $option.None(),
      new $option.None(),
      false,
    ),
    $effect.after_paint(
      (dispatch, root) => {
        let $ = (() => {
          let _pipe = measure_scroll_view(root, container_id, row_class);
          return $decode.run(_pipe, $codec.measure_decoder());
        })();
        if ($ instanceof Ok) {
          let ch = $[0][0];
          let rh = $[0][1];
          return dispatch(new $types.Measured(ch, rh));
        } else {
          return undefined;
        }
      },
    ),
  ];
}

export function items_fit(container_height, row_height) {
  let $ = row_height > 0.0;
  if ($) {
    return $float.truncate(
      $float.ceiling(divideFloat(container_height, row_height)),
    );
  } else {
    return 0;
  }
}

export function max_scroll_offset(container_height, row_height, total_items) {
  let fit = items_fit(container_height, row_height);
  let $ = total_items > fit;
  if ($) {
    let items_fit_f = $float.ceiling(divideFloat(container_height, row_height));
    let total = $int.to_float(total_items);
    let max_start = total - items_fit_f;
    let base = $float.max(0.0, max_start * row_height);
    return base + (container_height * 0.5);
  } else {
    return 0.0;
  }
}

export function start_index(scroll_offset, row_height) {
  let $ = row_height > 0.0;
  if ($) {
    return $float.truncate($float.floor(divideFloat(scroll_offset, row_height)));
  } else {
    return 0;
  }
}

export function update(model, msg, total_items) {
  if (msg instanceof $types.ParentResized) {
    return [
      model,
      $effect.after_paint(
        (dispatch, root) => {
          let $ = (() => {
            let _pipe = measure_scroll_view(
              root,
              model.container_id,
              model.row_class,
            );
            return $decode.run(_pipe, $codec.measure_decoder());
          })();
          if ($ instanceof Ok) {
            let ch = $[0][0];
            let rh = $[0][1];
            return dispatch(new $types.Measured(ch, rh));
          } else {
            return undefined;
          }
        },
      ),
    ];
  } else if (msg instanceof $types.Measured) {
    let ch = msg[0];
    let rh = msg[1];
    let max = max_scroll_offset(ch, rh, total_items);
    let clamped_offset = $helpers.clamp_scroll(model.scroll_offset, max);
    return [
      new $types.Model(
        model.container_id,
        model.row_class,
        new $option.Some(ch),
        new $option.Some(rh),
        clamped_offset,
        model.event_timestamps,
        model.cursor_y_relative,
        model.scrollbar_pressed,
        model.scrollbar_track_top,
        model.scrollbar_track_height,
        model.debug_enabled,
      ),
      $effect.none(),
    ];
  } else if (msg instanceof $types.DebugChanged) {
    let enabled = msg[0];
    return [
      new $types.Model(
        model.container_id,
        model.row_class,
        model.container_height,
        model.row_height,
        model.scroll_offset,
        model.event_timestamps,
        model.cursor_y_relative,
        model.scrollbar_pressed,
        model.scrollbar_track_top,
        model.scrollbar_track_height,
        enabled,
      ),
      $effect.none(),
    ];
  } else if (msg instanceof $types.Wheel) {
    let delta = msg[0];
    let _block;
    let $ = model.container_height;
    let $1 = model.row_height;
    if ($ instanceof $option.Some && $1 instanceof $option.Some) {
      let ch = $[0];
      let rh = $1[0];
      let max = max_scroll_offset(ch, rh, total_items);
      _block = $helpers.clamp_scroll(model.scroll_offset + delta, max);
    } else {
      _block = model.scroll_offset;
    }
    let new_offset = _block;
    let ts = record_scroll_event(model);
    return [
      new $types.Model(
        model.container_id,
        model.row_class,
        model.container_height,
        model.row_height,
        new_offset,
        ts,
        model.cursor_y_relative,
        model.scrollbar_pressed,
        model.scrollbar_track_top,
        model.scrollbar_track_height,
        model.debug_enabled,
      ),
      $effect.none(),
    ];
  } else if (msg instanceof $types.TrackPointerdown) {
    let offset = msg[0];
    let track_top = msg[1];
    let track_height = msg[2];
    let _block;
    let $ = model.container_height;
    let $1 = model.row_height;
    if ($ instanceof $option.Some && $1 instanceof $option.Some) {
      let ch = $[0];
      let rh = $1[0];
      _block = $helpers.clamp_scroll(
        offset,
        max_scroll_offset(ch, rh, total_items),
      );
    } else {
      _block = offset;
    }
    let clamped = _block;
    let ts = record_scroll_event(model);
    return [
      new $types.Model(
        model.container_id,
        model.row_class,
        model.container_height,
        model.row_height,
        clamped,
        ts,
        model.cursor_y_relative,
        true,
        new $option.Some(track_top),
        new $option.Some(track_height),
        model.debug_enabled,
      ),
      $effect.none(),
    ];
  } else if (msg instanceof $types.PointerMove) {
    let client_y = msg[0];
    let buttons = msg[1];
    let _block;
    let $ = model.scrollbar_track_top;
    let $1 = model.scrollbar_track_height;
    if ($ instanceof $option.Some && $1 instanceof $option.Some) {
      let track_top = $[0];
      let track_height = $1[0];
      let _block$1;
      let $2 = model.container_height;
      let $3 = model.row_height;
      if ($2 instanceof $option.Some && $3 instanceof $option.Some) {
        let ch = $2[0];
        let rh = $3[0];
        _block$1 = max_scroll_offset(ch, rh, total_items);
      } else {
        _block$1 = 0.0;
      }
      let max = _block$1;
      let _block$2;
      let $4 = track_height > 0.0;
      if ($4) {
        _block$2 = $float.min(
          1.0,
          $float.max(0.0, divideFloat((client_y - track_top), track_height)),
        );
      } else {
        _block$2 = 0.0;
      }
      let rel = _block$2;
      let $5 = buttons === 1;
      if ($5) {
        let offset = $helpers.rel_to_offset(
          client_y,
          track_top,
          track_height,
          max,
        );
        let clamped = $helpers.clamp_scroll(offset, max);
        _block = new $types.Model(
          model.container_id,
          model.row_class,
          model.container_height,
          model.row_height,
          clamped,
          model.event_timestamps,
          new $option.Some(rel),
          model.scrollbar_pressed,
          model.scrollbar_track_top,
          model.scrollbar_track_height,
          model.debug_enabled,
        );
      } else {
        _block = new $types.Model(
          model.container_id,
          model.row_class,
          model.container_height,
          model.row_height,
          model.scroll_offset,
          model.event_timestamps,
          new $option.Some(rel),
          model.scrollbar_pressed,
          model.scrollbar_track_top,
          model.scrollbar_track_height,
          model.debug_enabled,
        );
      }
    } else {
      _block = model;
    }
    let new_model = _block;
    return [new_model, $effect.none()];
  } else if (msg instanceof $types.ScrollbarReleased) {
    return [
      new $types.Model(
        model.container_id,
        model.row_class,
        model.container_height,
        model.row_height,
        model.scroll_offset,
        model.event_timestamps,
        model.cursor_y_relative,
        false,
        new $option.None(),
        new $option.None(),
        model.debug_enabled,
      ),
      $effect.none(),
    ];
  } else {
    return [model, $effect.none()];
  }
}

export function view(data, model, config) {
  let container_id = config.container_id;
  let row_class = config.row_class;
  let render_row = config.render_row;
  let total_items = $list.length(data);
  let render_rows = (rows) => {
    return $list.index_map(
      rows,
      (item, i) => {
        let row = map(render_row(item), (_) => { return new $types.NoOp(); });
        let _block;
        let $ = i === 0;
        if ($) {
          _block = row_class + " border-b border-black/5 dark:border-white/5 px-2 py-1 text-sm";
        } else {
          _block = "border-b border-black/5 dark:border-white/5 px-2 py-1 text-sm";
        }
        let row_classes = _block;
        return div(toList([class$(row_classes)]), toList([row]));
      },
    );
  };
  let _block;
  let $ = model.container_height;
  let $1 = model.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let ch = $[0];
    let rh = $1[0];
    _block = max_scroll_offset(ch, rh, total_items);
  } else {
    _block = 0.0;
  }
  let max_scroll = _block;
  let _block$1;
  let $2 = model.scroll_offset > 0.0;
  let $3 = (max_scroll > 0.0) && (model.scroll_offset < max_scroll);
  if ($2) {
    if ($3) {
      _block$1 = " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3),inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45),inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]";
    } else {
      _block$1 = " [box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_6px_10px_-4px_rgba(251,146,60,0.45)]";
    }
  } else if ($3) {
    _block$1 = " [box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.3)] dark:[box-shadow:inset_0_-6px_10px_-4px_rgba(251,146,60,0.45)]";
  } else {
    _block$1 = "";
  }
  let shadow_classes = _block$1;
  let container_attrs = toList([
    id(container_id),
    class$("h-96 overflow-hidden" + shadow_classes),
    advanced("wheel", $codec.wheel_decoder(max_scroll)),
  ]);
  let _block$2;
  let $4 = model.container_height;
  let $5 = model.row_height;
  if ($4 instanceof $option.Some) {
    if ($5 instanceof $option.Some) {
      let ch = $4[0];
      let rh = $5[0];
      let unclamped_drop = start_index(model.scroll_offset, rh);
      let max_drop = $int.max(0, total_items - 1);
      let drop = $int.min(unclamped_drop, max_drop);
      let fit = items_fit(ch, rh);
      let available = total_items - drop;
      let _block$3;
      if (available === 0) {
        _block$3 = available;
      } else {
        let n = available;
        _block$3 = $int.max(1, $int.min($int.max(1, fit), n));
      }
      let take = _block$3;
      let visible = $list.take($list.drop(data, drop), take);
      _block$2 = render_rows(visible);
    } else {
      _block$2 = toList([]);
    }
  } else if ($5 instanceof $option.None) {
    let visible = $list.take(data, 1);
    _block$2 = render_rows(visible);
  } else {
    _block$2 = toList([]);
  }
  let content = _block$2;
  let resize_observer = $parent_resize_observer.view(
    (_) => { return new $types.ParentResized(); },
    content,
  );
  let scrollbar = $scrollbar.view(container_id, model, max_scroll);
  let overlay = $pointer_events_overlay.view(container_id, model, max_scroll);
  return div(
    toList([class$("flex-1 flex min-h-0")]),
    $list.append(
      toList([
        div(
          listPrepend(
            class$("flex-1 min-w-0 overflow-hidden h-full"),
            container_attrs,
          ),
          toList([resize_observer]),
        ),
        scrollbar,
      ]),
      overlay,
    ),
  );
}

export function anchor(attrs) {
  return $scroll_view_anchor.view(attrs);
}
