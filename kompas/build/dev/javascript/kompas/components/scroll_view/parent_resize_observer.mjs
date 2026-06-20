import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../../../lustre/lustre/attribute.mjs";
import { class$ } from "../../../lustre/lustre/attribute.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import { element } from "../../../lustre/lustre/element.mjs";
import * as $event from "../../../lustre/lustre/event.mjs";
import { advanced, handler } from "../../../lustre/lustre/event.mjs";
import { Ok, toList } from "../../gleam.mjs";
import { register, getBoundingClientRect as get_bounding_client_rect } from "./parent_resize_observer_ffi.mjs";

export function init() {
  return register();
}

function rect_decoder() {
  return $decode.field(
    "width",
    $decode.float,
    (width) => {
      return $decode.field(
        "height",
        $decode.float,
        (height) => {
          return $decode.field(
            "x",
            $decode.float,
            (x) => {
              return $decode.field(
                "y",
                $decode.float,
                (y) => {
                  return $decode.field(
                    "rowHeight",
                    $decode.optional($decode.float),
                    (row_height) => {
                      return $decode.success([width, height, x, y, row_height]);
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

function parentresized_decoder(on_resize) {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let $ = (() => {
        let _pipe = get_bounding_client_rect(event);
        return $decode.run(_pipe, rect_decoder());
      })();
      if ($ instanceof Ok) {
        let rect = $[0];
        return $decode.success(handler(on_resize(rect), false, false));
      } else {
        return $decode.failure(
          handler(
            on_resize([0.0, 0.0, 0.0, 0.0, new $option.None()]),
            false,
            false,
          ),
          "rect",
        );
      }
    },
  );
}

export function view(on_resize, content) {
  return element(
    "parent-resize-observer",
    toList([
      class$("block h-full min-h-0"),
      advanced("parentresized", parentresized_decoder(on_resize)),
    ]),
    content,
  );
}
