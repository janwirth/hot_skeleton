import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $element from "../../../lustre/lustre/element.mjs";
import { CustomType as $CustomType } from "../../gleam.mjs";

export class Config extends $CustomType {
  constructor(container_id, row_class, render_row) {
    super();
    this.container_id = container_id;
    this.row_class = row_class;
    this.render_row = render_row;
  }
}
export const Config$Config = (container_id, row_class, render_row) =>
  new Config(container_id, row_class, render_row);
export const Config$isConfig = (value) => value instanceof Config;
export const Config$Config$container_id = (value) => value.container_id;
export const Config$Config$0 = (value) => value.container_id;
export const Config$Config$row_class = (value) => value.row_class;
export const Config$Config$1 = (value) => value.row_class;
export const Config$Config$render_row = (value) => value.render_row;
export const Config$Config$2 = (value) => value.render_row;

export class Model extends $CustomType {
  constructor(container_id, row_class, container_height, row_height, scroll_offset, event_timestamps, cursor_y_relative, scrollbar_pressed, scrollbar_track_top, scrollbar_track_height, debug_enabled) {
    super();
    this.container_id = container_id;
    this.row_class = row_class;
    this.container_height = container_height;
    this.row_height = row_height;
    this.scroll_offset = scroll_offset;
    this.event_timestamps = event_timestamps;
    this.cursor_y_relative = cursor_y_relative;
    this.scrollbar_pressed = scrollbar_pressed;
    this.scrollbar_track_top = scrollbar_track_top;
    this.scrollbar_track_height = scrollbar_track_height;
    this.debug_enabled = debug_enabled;
  }
}
export const Model$Model = (container_id, row_class, container_height, row_height, scroll_offset, event_timestamps, cursor_y_relative, scrollbar_pressed, scrollbar_track_top, scrollbar_track_height, debug_enabled) =>
  new Model(container_id,
  row_class,
  container_height,
  row_height,
  scroll_offset,
  event_timestamps,
  cursor_y_relative,
  scrollbar_pressed,
  scrollbar_track_top,
  scrollbar_track_height,
  debug_enabled);
export const Model$isModel = (value) => value instanceof Model;
export const Model$Model$container_id = (value) => value.container_id;
export const Model$Model$0 = (value) => value.container_id;
export const Model$Model$row_class = (value) => value.row_class;
export const Model$Model$1 = (value) => value.row_class;
export const Model$Model$container_height = (value) => value.container_height;
export const Model$Model$2 = (value) => value.container_height;
export const Model$Model$row_height = (value) => value.row_height;
export const Model$Model$3 = (value) => value.row_height;
export const Model$Model$scroll_offset = (value) => value.scroll_offset;
export const Model$Model$4 = (value) => value.scroll_offset;
export const Model$Model$event_timestamps = (value) => value.event_timestamps;
export const Model$Model$5 = (value) => value.event_timestamps;
export const Model$Model$cursor_y_relative = (value) => value.cursor_y_relative;
export const Model$Model$6 = (value) => value.cursor_y_relative;
export const Model$Model$scrollbar_pressed = (value) => value.scrollbar_pressed;
export const Model$Model$7 = (value) => value.scrollbar_pressed;
export const Model$Model$scrollbar_track_top = (value) =>
  value.scrollbar_track_top;
export const Model$Model$8 = (value) => value.scrollbar_track_top;
export const Model$Model$scrollbar_track_height = (value) =>
  value.scrollbar_track_height;
export const Model$Model$9 = (value) => value.scrollbar_track_height;
export const Model$Model$debug_enabled = (value) => value.debug_enabled;
export const Model$Model$10 = (value) => value.debug_enabled;

export class ParentResized extends $CustomType {}
export const Msg$ParentResized = () => new ParentResized();
export const Msg$isParentResized = (value) => value instanceof ParentResized;

export class Measured extends $CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
}
export const Msg$Measured = ($0, $1) => new Measured($0, $1);
export const Msg$isMeasured = (value) => value instanceof Measured;
export const Msg$Measured$0 = (value) => value[0];
export const Msg$Measured$1 = (value) => value[1];

export class DebugChanged extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Msg$DebugChanged = ($0) => new DebugChanged($0);
export const Msg$isDebugChanged = (value) => value instanceof DebugChanged;
export const Msg$DebugChanged$0 = (value) => value[0];

export class Wheel extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Msg$Wheel = ($0) => new Wheel($0);
export const Msg$isWheel = (value) => value instanceof Wheel;
export const Msg$Wheel$0 = (value) => value[0];

export class TrackPointerdown extends $CustomType {
  constructor($0, $1, $2) {
    super();
    this[0] = $0;
    this[1] = $1;
    this[2] = $2;
  }
}
export const Msg$TrackPointerdown = ($0, $1, $2) =>
  new TrackPointerdown($0, $1, $2);
export const Msg$isTrackPointerdown = (value) =>
  value instanceof TrackPointerdown;
export const Msg$TrackPointerdown$0 = (value) => value[0];
export const Msg$TrackPointerdown$1 = (value) => value[1];
export const Msg$TrackPointerdown$2 = (value) => value[2];

export class PointerMove extends $CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
}
export const Msg$PointerMove = ($0, $1) => new PointerMove($0, $1);
export const Msg$isPointerMove = (value) => value instanceof PointerMove;
export const Msg$PointerMove$0 = (value) => value[0];
export const Msg$PointerMove$1 = (value) => value[1];

export class ScrollbarReleased extends $CustomType {}
export const Msg$ScrollbarReleased = () => new ScrollbarReleased();
export const Msg$isScrollbarReleased = (value) =>
  value instanceof ScrollbarReleased;

export class NoOp extends $CustomType {}
export const Msg$NoOp = () => new NoOp();
export const Msg$isNoOp = (value) => value instanceof NoOp;
