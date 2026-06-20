import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $io from "../../gleam_stdlib/gleam/io.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import * as $attribute from "../../lustre/lustre/attribute.mjs";
import { class$, id } from "../../lustre/lustre/attribute.mjs";
import * as $component from "../../lustre/lustre/component.mjs";
import * as $effect from "../../lustre/lustre/effect.mjs";
import * as $element from "../../lustre/lustre/element.mjs";
import { map as element_map } from "../../lustre/lustre/element.mjs";
import * as $html from "../../lustre/lustre/element/html.mjs";
import { div, slot } from "../../lustre/lustre/element/html.mjs";
import * as $event from "../../lustre/lustre/event.mjs";
import { advanced } from "../../lustre/lustre/event.mjs";
import * as $random_id from "../components/random_id.mjs";
import * as $scroll_view from "../components/scroll_view.mjs";
import * as $anchor from "../components/scroll_view/anchor.mjs";
import * as $codec from "../components/scroll_view/codec.mjs";
import * as $debug from "../components/scroll_view/debug.mjs";
import * as $helpers from "../components/scroll_view/helpers.mjs";
import * as $pointer_events_overlay from "../components/scroll_view/pointer_events_overlay.mjs";
import * as $scrollbar from "../components/scroll_view/scrollbar.mjs";
import * as $types from "../components/scroll_view/types.mjs";
import * as $scroll_view_app from "../components/scroll_view_app.mjs";
import { Ok, Error, toList, prepend as listPrepend, CustomType as $CustomType } from "../gleam.mjs";
import { ensureThemeClassSync as ensure_theme_class_sync } from "./gesture_scroller_ffi.mjs";

export class Model extends $CustomType {
  constructor(scroll, total_items) {
    super();
    this.scroll = scroll;
    this.total_items = total_items;
  }
}
export const Model$Model = (scroll, total_items) =>
  new Model(scroll, total_items);
export const Model$isModel = (value) => value instanceof Model;
export const Model$Model$scroll = (value) => value.scroll;
export const Model$Model$0 = (value) => value.scroll;
export const Model$Model$total_items = (value) => value.total_items;
export const Model$Model$1 = (value) => value.total_items;

export class Scroll extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Msg$Scroll = ($0) => new Scroll($0);
export const Msg$isScroll = (value) => value instanceof Scroll;
export const Msg$Scroll$0 = (value) => value[0];

export class TotalItemsAttribute extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Msg$TotalItemsAttribute = ($0) => new TotalItemsAttribute($0);
export const Msg$isTotalItemsAttribute = (value) =>
  value instanceof TotalItemsAttribute;
export const Msg$TotalItemsAttribute$0 = (value) => value[0];

export class ScrollInstanceAttribute extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Msg$ScrollInstanceAttribute = ($0) =>
  new ScrollInstanceAttribute($0);
export const Msg$isScrollInstanceAttribute = (value) =>
  value instanceof ScrollInstanceAttribute;
export const Msg$ScrollInstanceAttribute$0 = (value) => value[0];

const default_row_class = "gesture-scroller-row";

const default_container_id = "gesture-scroller-container";

export const element_name = "gesture-scroller";

function scroll_ids_from_instance_slug(slug) {
  return [slug + "-vp", slug + "-row"];
}

function total_for_scroll_count(total_items) {
  return $option.unwrap(total_items, 0);
}

function window_from_model(model, total_items) {
  let $ = model.container_height;
  let $1 = model.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let ch = $[0];
    let rh = $1[0];
    if (total_items instanceof $option.Some) {
      let ti = total_items[0];
      let unclamped_drop = $scroll_view.start_index(model.scroll_offset, rh);
      let max_drop = $int.max(0, ti - 1);
      let drop = $int.min(unclamped_drop, max_drop);
      let fit = $scroll_view.items_fit(ch, rh);
      let available = ti - drop;
      let _block;
      if (available === 0) {
        _block = available;
      } else {
        let n = available;
        _block = $int.max(1, $int.min($int.max(1, fit), n));
      }
      let take = _block;
      return new $scroll_view_app.ScrollWindow(drop, take);
    } else {
      return new $scroll_view_app.ScrollWindow(0, 0);
    }
  } else {
    return new $scroll_view_app.ScrollWindow(0, 4);
  }
}

function decode_total_items_attr(value) {
  let $ = $int.parse(value);
  if ($ instanceof Ok) {
    let n = $[0];
    return new Ok(new TotalItemsAttribute($int.max(0, n)));
  } else {
    return new Error(undefined);
  }
}

function init(_) {
  ensure_theme_class_sync();
  $anchor.register();
  let container_id = (default_container_id + "-") + $random_id.random_id_5();
  $io.println("container_id: " + container_id);
  let $ = $scroll_view.init(container_id, default_row_class);
  let scroll = $[0];
  let eff = $[1];
  return [
    new Model(scroll, new $option.None()),
    new $option.None(),
    $effect.map(eff, (var0) => { return new Scroll(var0); }),
  ];
}

function component_view(model) {
  let count = total_for_scroll_count(model.total_items);
  let scroll = model.scroll;
  let _block;
  let $ = scroll.container_height;
  let $1 = scroll.row_height;
  if ($ instanceof $option.Some && $1 instanceof $option.Some) {
    let ch = $[0];
    let rh = $1[0];
    _block = $scroll_view.max_scroll_offset(ch, rh, count);
  } else {
    _block = 0.0;
  }
  let max_scroll = _block;
  let _block$1;
  let $2 = scroll.scroll_offset > 0.0;
  let $3 = (max_scroll > 0.0) && (scroll.scroll_offset < max_scroll);
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
  let cid = scroll.container_id;
  let scrollbar = $scrollbar.view(cid, scroll, max_scroll);
  let overlay = $pointer_events_overlay.view(cid, scroll, max_scroll);
  let _block$2;
  let $4 = scroll.debug_enabled;
  if ($4) {
    _block$2 = div(
      toList([class$("mb-2")]),
      toList([$debug.debug_info(scroll, count)]),
    );
  } else {
    _block$2 = div(toList([]), toList([]));
  }
  let debug_block = _block$2;
  let _pipe = div(
    toList([class$("flex flex-col min-h-0 h-full")]),
    toList([
      div(
        toList([class$("flex-1 flex min-h-0")]),
        listPrepend(
          div(
            toList([
              class$(
                "flex-1 min-h-0 min-w-0 overflow-hidden h-full " + shadow_classes,
              ),
              id(cid),
              advanced("wheel", $codec.wheel_decoder(max_scroll)),
              advanced("anchormeasured", $codec.anchor_measured_decoder()),
            ]),
            toList([slot(toList([]), toList([]))]),
          ),
          listPrepend(scrollbar, overlay),
        ),
      ),
      debug_block,
    ]),
  );
  return element_map(_pipe, (var0) => { return new Scroll(var0); });
}

function update(model, msg) {
  if (msg instanceof Scroll) {
    let inner = msg[0];
    let count = total_for_scroll_count(model.total_items);
    let $ = $scroll_view.update(model.scroll, inner, count);
    let next_scroll = $[0];
    let next_effect = $[1];
    return [
      new Model(next_scroll, model.total_items),
      window_from_model(next_scroll, model.total_items),
      $effect.map(next_effect, (var0) => { return new Scroll(var0); }),
    ];
  } else if (msg instanceof TotalItemsAttribute) {
    let n = msg[0];
    let total_items = new $option.Some($int.max(0, n));
    let scroll = model.scroll;
    let count = total_for_scroll_count(total_items);
    let _block;
    let $1 = scroll.container_height;
    let $2 = scroll.row_height;
    if ($1 instanceof $option.Some && $2 instanceof $option.Some) {
      let ch = $1[0];
      let rh = $2[0];
      let max = $scroll_view.max_scroll_offset(ch, rh, count);
      let clamped = $helpers.clamp_scroll(scroll.scroll_offset, max);
      _block = [
        new $types.Model(
          scroll.container_id,
          scroll.row_class,
          scroll.container_height,
          scroll.row_height,
          clamped,
          scroll.event_timestamps,
          scroll.cursor_y_relative,
          scroll.scrollbar_pressed,
          scroll.scrollbar_track_top,
          scroll.scrollbar_track_height,
          scroll.debug_enabled,
        ),
        $effect.none(),
      ];
    } else {
      _block = [scroll, $effect.none()];
    }
    let $ = _block;
    let next_scroll = $[0];
    let reclamp_eff = $[1];
    return [
      new Model(next_scroll, total_items),
      window_from_model(next_scroll, total_items),
      $effect.map(reclamp_eff, (var0) => { return new Scroll(var0); }),
    ];
  } else {
    let slug = msg[0];
    let $ = scroll_ids_from_instance_slug(slug);
    let cid = $[0];
    let rc = $[1];
    let $1 = (model.scroll.container_id === cid) && (model.scroll.row_class === rc);
    if ($1) {
      return [
        model,
        window_from_model(model.scroll, model.total_items),
        $effect.none(),
      ];
    } else {
      let $2 = $scroll_view.init(cid, rc);
      let next_scroll = $2[0];
      let eff = $2[1];
      return [
        new Model(next_scroll, model.total_items),
        window_from_model(next_scroll, model.total_items),
        $effect.map(eff, (var0) => { return new Scroll(var0); }),
      ];
    }
  }
}

export function component() {
  return new $scroll_view_app.ScrollViewApp(init, update, component_view);
}

function decode_scroll_instance_attr(value) {
  let slug = $string.trim(value);
  let $ = slug === "";
  if ($) {
    return new Error(undefined);
  } else {
    return new Ok(new ScrollInstanceAttribute(slug));
  }
}

export function register() {
  return $scroll_view_app.register_with_options(
    element_name,
    component(),
    toList([
      $component.on_attribute_change("total-items", decode_total_items_attr),
      $component.on_attribute_change(
        "scroll-instance",
        decode_scroll_instance_attr,
      ),
      $component.on_context_change(
        $debug.context_key,
        (() => {
          let _pipe = $decode.bool;
          return $decode.map(
            _pipe,
            (b) => { return new Scroll(new $types.DebugChanged(b)); },
          );
        })(),
      ),
    ]),
  );
}

export function view(on_scroll_window, attrs, children) {
  return $scroll_view_app.view(element_name, on_scroll_window, attrs, children);
}
