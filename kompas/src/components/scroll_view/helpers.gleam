import gleam/float
import gleam/list

/// Height in pixels of the scrollbar handle thumb.
pub fn handle_height() -> Float {
  36.0
}

/// Converts a client Y position and track bounds to a scroll offset.
/// Uses the center of the handle for positioning.
pub fn rel_to_offset(
  client_y: Float,
  top: Float,
  height: Float,
  max_scroll: Float,
) -> Float {
  let half_handle = handle_height() /. 2.0
  let usable_height = height -. handle_height()
  case usable_height >. 0.0 {
    True -> {
      let rel_adjusted = { client_y -. top -. half_handle } /. usable_height
      let clamped = float.min(1.0, float.max(0.0, rel_adjusted))
      clamped *. max_scroll
    }
    False -> 0.0
  }
}

/// Clamps a scroll offset to the valid range [0, max].
pub fn clamp_scroll(offset: Float, max: Float) -> Float {
  float.min(max, float.max(0.0, offset))
}

/// Returns the last n items from a list.
/// If the list has fewer than n items, returns the whole list.
pub fn take_last(n: Int, items: List(a)) -> List(a) {
  let len = list.length(items)
  case len > n {
    True -> list.drop(items, len - n)
    False -> items
  }
}
