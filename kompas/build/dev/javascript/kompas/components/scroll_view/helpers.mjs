import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import { divideFloat } from "../../gleam.mjs";

/**
 * Height in pixels of the scrollbar handle thumb.
 */
export function handle_height() {
  return 36.0;
}

/**
 * Converts a client Y position and track bounds to a scroll offset.
 * Uses the center of the handle for positioning.
 */
export function rel_to_offset(client_y, top, height, max_scroll) {
  let half_handle = handle_height() / 2.0;
  let usable_height = height - handle_height();
  let $ = usable_height > 0.0;
  if ($) {
    let rel_adjusted = divideFloat(
      ((client_y - top) - half_handle),
      usable_height
    );
    let clamped = $float.min(1.0, $float.max(0.0, rel_adjusted));
    return clamped * max_scroll;
  } else {
    return 0.0;
  }
}

/**
 * Clamps a scroll offset to the valid range [0, max].
 */
export function clamp_scroll(offset, max) {
  return $float.min(max, $float.max(0.0, offset));
}

/**
 * Returns the last n items from a list.
 * If the list has fewer than n items, returns the whole list.
 */
export function take_last(n, items) {
  let len = $list.length(items);
  let $ = len > n;
  if ($) {
    return $list.drop(items, len - n);
  } else {
    return items;
  }
}
