import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $lustre from "../../lustre/lustre.mjs";
import * as $attribute from "../../lustre/lustre/attribute.mjs";
import * as $effect from "../../lustre/lustre/effect.mjs";
import * as $element from "../../lustre/lustre/element.mjs";
import * as $event from "../../lustre/lustre/event.mjs";
import { emit, on } from "../../lustre/lustre/event.mjs";
import * as $server_component from "../../lustre/lustre/server_component.mjs";
import { Ok, toList, prepend as listPrepend, CustomType as $CustomType } from "../gleam.mjs";

export class ScrollWindow extends $CustomType {
  constructor(drop, take) {
    super();
    this.drop = drop;
    this.take = take;
  }
}
export const ScrollWindow$ScrollWindow = (drop, take) =>
  new ScrollWindow(drop, take);
export const ScrollWindow$isScrollWindow = (value) =>
  value instanceof ScrollWindow;
export const ScrollWindow$ScrollWindow$drop = (value) => value.drop;
export const ScrollWindow$ScrollWindow$0 = (value) => value.drop;
export const ScrollWindow$ScrollWindow$take = (value) => value.take;
export const ScrollWindow$ScrollWindow$1 = (value) => value.take;

export class ScrollViewApp extends $CustomType {
  constructor(init, update, view) {
    super();
    this.init = init;
    this.update = update;
    this.view = view;
  }
}
export const ScrollViewApp$ScrollViewApp = (init, update, view) =>
  new ScrollViewApp(init, update, view);
export const ScrollViewApp$isScrollViewApp = (value) =>
  value instanceof ScrollViewApp;
export const ScrollViewApp$ScrollViewApp$init = (value) => value.init;
export const ScrollViewApp$ScrollViewApp$0 = (value) => value.init;
export const ScrollViewApp$ScrollViewApp$update = (value) => value.update;
export const ScrollViewApp$ScrollViewApp$1 = (value) => value.update;
export const ScrollViewApp$ScrollViewApp$view = (value) => value.view;
export const ScrollViewApp$ScrollViewApp$2 = (value) => value.view;

function emit_scroll_window(drop, take) {
  return emit(
    "scroll-window",
    $json.object(toList([["drop", $json.int(drop)], ["take", $json.int(take)]])),
  );
}

export function to_lustre_app(app) {
  let init_adapted = (_) => {
    let $ = app.init(undefined);
    let $1 = $[1];
    if ($1 instanceof $option.Some) {
      let model = $[0];
      let effect = $[2];
      let window = $1[0];
      return [
        model,
        $effect.batch(
          toList([effect, emit_scroll_window(window.drop, window.take)]),
        ),
      ];
    } else {
      let model = $[0];
      let effect = $[2];
      return [model, effect];
    }
  };
  let update_adapted = (model, msg) => {
    let $ = app.update(model, msg);
    let model$1 = $[0];
    let window = $[1];
    let effect = $[2];
    return [
      model$1,
      $effect.batch(
        toList([effect, emit_scroll_window(window.drop, window.take)]),
      ),
    ];
  };
  return $lustre.component(init_adapted, update_adapted, app.view, toList([]));
}

export function register_with_options(name, app, options) {
  let $ = $lustre.is_registered(name);
  if ($) {
    return new Ok(undefined);
  } else {
    let init = app.init;
    let update = app.update;
    let view$1 = app.view;
    let init_adapted = (_) => {
      let $1 = init(undefined);
      let $2 = $1[1];
      if ($2 instanceof $option.Some) {
        let m = $1[0];
        let eff = $1[2];
        let window = $2[0];
        return [
          m,
          $effect.batch(
            toList([eff, emit_scroll_window(window.drop, window.take)]),
          ),
        ];
      } else {
        let m = $1[0];
        let eff = $1[2];
        return [m, eff];
      }
    };
    let update_adapted = (model, msg) => {
      let $1 = update(model, msg);
      let m = $1[0];
      let window = $1[1];
      let eff = $1[2];
      return [
        m,
        $effect.batch(
          toList([eff, emit_scroll_window(window.drop, window.take)]),
        ),
      ];
    };
    return $lustre.register(
      $lustre.component(init_adapted, update_adapted, view$1, options),
      name,
    );
  }
}

export function register(name, app) {
  return register_with_options(name, app, toList([]));
}

function scroll_window_decoder() {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let $ = $decode.run(
        event,
        $decode.at(toList(["detail", "drop"]), $decode.int),
      );
      if ($ instanceof Ok) {
        let drop = $[0];
        let $1 = $decode.run(
          event,
          $decode.at(toList(["detail", "take"]), $decode.int),
        );
        if ($1 instanceof Ok) {
          let take = $1[0];
          return $decode.success(new ScrollWindow(drop, take));
        } else {
          return $decode.failure(new ScrollWindow(0, 0), "detail.take");
        }
      } else {
        return $decode.failure(new ScrollWindow(0, 0), "detail.drop");
      }
    },
  );
}

/**
 * Type-safe wrapper around the scroll-view custom element.
 * attrs: additional attributes (e.g. layout_type_attrs, event.on("scroll-window", decoder))
 * children: slotted content (parent slices data and renders the window)
 */
export function view(element_name, on_scroll_window, attrs, children) {
  return $element.element(
    element_name,
    listPrepend(
      (() => {
        let _pipe = on(
          "scroll-window",
          (() => {
            let _pipe = scroll_window_decoder();
            return $decode.map(_pipe, on_scroll_window);
          })(),
        );
        return $server_component.include(
          _pipe,
          toList(["detail.drop", "detail.take"]),
        );
      })(),
      attrs,
    ),
    children,
  );
}
