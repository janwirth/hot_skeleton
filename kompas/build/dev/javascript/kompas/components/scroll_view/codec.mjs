import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $io from "../../../gleam_stdlib/gleam/io.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $event from "../../../lustre/lustre/event.mjs";
import { handler } from "../../../lustre/lustre/event.mjs";
import * as $helpers from "../../components/scroll_view/helpers.mjs";
import * as $types from "../../components/scroll_view/types.mjs";
import { Ok, toList, isEqual } from "../../gleam.mjs";
import { getBoundingClientRect as get_bounding_client_rect } from "./scroll_view_ffi.mjs";

function rect_decoder() {
  return $decode.field(
    "top",
    $decode.float,
    (top) => {
      return $decode.field(
        "height",
        $decode.float,
        (height) => { return $decode.success([top, height]); },
      );
    },
  );
}

export function measure_decoder() {
  return $decode.field(
    "containerHeight",
    $decode.float,
    (ch) => {
      return $decode.field(
        "rowHeight",
        $decode.float,
        (rh) => { return $decode.success([ch, rh]); },
      );
    },
  );
}

export function anchor_measured_decoder() {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let $ = $decode.run(
        event,
        $decode.at(toList(["detail", "containerHeight"]), $decode.float),
      );
      let $1 = $decode.run(
        event,
        $decode.at(toList(["detail", "rowHeight"]), $decode.float),
      );
      if ($ instanceof Ok) {
        if ($1 instanceof Ok) {
          let ch = $[0];
          let rh = $1[0];
          return $decode.success(
            handler(new $types.Measured(ch, rh), false, false),
          );
        } else {
          return $decode.failure(
            handler(new $types.NoOp(), false, false),
            "detail.rowHeight",
          );
        }
      } else {
        return $decode.failure(
          handler(new $types.NoOp(), false, false),
          "detail.containerHeight",
        );
      }
    },
  );
}

export function pointer_up_decoder() {
  return $decode.then$(
    $decode.dynamic,
    (_) => {
      return $decode.success(
        handler(new $types.ScrollbarReleased(), false, false),
      );
    },
  );
}

export function wheel_decoder(max_scroll) {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let ctrl = isEqual(
        $decode.run(event, $decode.at(toList(["ctrlKey"]), $decode.bool)),
        new Ok(true)
      );
      let delta_decoder = $decode.at(toList(["deltaY"]), $decode.float);
      if (ctrl) {
        return $decode.failure(
          handler(new $types.Wheel(0.0), true, false),
          "ctrlKey ignored",
        );
      } else {
        return $decode.map(
          delta_decoder,
          (delta) => {
            let prevent = max_scroll > 0.0;
            return handler(new $types.Wheel(delta), prevent, false);
          },
        );
      }
    },
  );
}

export function overlay_pointer_move_decoder() {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let $ = $decode.run(event, $decode.at(toList(["clientY"]), $decode.float));
      let $1 = $decode.run(event, $decode.at(toList(["buttons"]), $decode.int));
      if ($ instanceof Ok) {
        if ($1 instanceof Ok) {
          let client_y = $[0];
          let buttons = $1[0];
          return $decode.success(
            handler(new $types.PointerMove(client_y, buttons), false, false),
          );
        } else {
          return $decode.failure(
            handler(new $types.NoOp(), false, false),
            "buttons",
          );
        }
      } else {
        return $decode.failure(
          handler(new $types.NoOp(), false, false),
          "clientY",
        );
      }
    },
  );
}

export function track_pointerdown_decoder(max_scroll) {
  return $decode.then$(
    $decode.dynamic,
    (event) => {
      let $ = $decode.run(event, $decode.at(toList(["clientY"]), $decode.float));
      if ($ instanceof Ok) {
        let client_y = $[0];
        let $1 = (() => {
          let _pipe = get_bounding_client_rect(event);
          return $decode.run(_pipe, rect_decoder());
        })();
        if ($1 instanceof Ok) {
          let top = $1[0][0];
          let height = $1[0][1];
          let offset = $helpers.rel_to_offset(client_y, top, height, max_scroll);
          return $decode.success(
            handler(
              new $types.TrackPointerdown(offset, top, height),
              true,
              true,
            ),
          );
        } else {
          let e = $1[0];
          $io.println(
            ((("error, failed to get bounding client rect" + " clientY: ") + $float.to_string(
              client_y,
            )) + " error: ") + $string.join(
              $list.map(
                e,
                (e) => {
                  return (((e.expected + " ") + e.found) + " ") + $string.join(
                    e.path,
                    ".",
                  );
                },
              ),
              " ",
            ),
          );
          return $decode.success(
            handler(new $types.TrackPointerdown(0.0, 0.0, 1.0), true, true),
          );
        }
      } else {
        $io.println("error, failed to get clientY");
        return $decode.success(
          handler(new $types.TrackPointerdown(0.0, 0.0, 1.0), true, true),
        );
      }
    },
  );
}
