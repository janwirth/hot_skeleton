import gleam/option
import lustre/element.{type Element}

pub type Config(msg, a) {
  Config(
    container_id: String,
    row_class: String,
    render_row: fn(a) -> Element(msg),
  )
}

pub type Model {
  Model(
    container_id: String,
    row_class: String,
    container_height: option.Option(Float),
    row_height: option.Option(Float),
    scroll_offset: Float,
    /// Monotonic timestamps (ms) for scroll input events, for rate display.
    event_timestamps: List(Float),
    cursor_y_relative: option.Option(Float),
    scrollbar_pressed: Bool,
    scrollbar_track_top: option.Option(Float),
    scrollbar_track_height: option.Option(Float),
    debug_enabled: Bool,
  )
}

pub type Msg {
  ParentResized
  Measured(Float, Float)
  DebugChanged(Bool)
  Wheel(Float)
  TrackPointerdown(Float, Float, Float)
  PointerMove(Float, Int)
  ScrollbarReleased
  NoOp
}
