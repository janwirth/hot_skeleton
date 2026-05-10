//// Scroll list example — same hot-reload split-module pattern as [`hot_counter`](./hot_counter.gleam).

import examples/scroll/logic
import lustre.{type App}

pub fn trigger_rerender_view() -> Message {
  logic.trigger_rerender_view()
}

pub type Model =
  logic.Model

pub type Message =
  logic.Message

pub fn component() -> App(Nil, Model, Message) {
  lustre.simple(logic.init, logic.update, logic.view)
}
