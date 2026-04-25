//// MVU triple for the counter example. Kept in its own module so that
//// references from [`examples/counter`](../counter.gleam) compile to
//// cross-module (external) fun refs — see the note in `counter.gleam`
//// for why that matters for hot code reloading.

import lustre
import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model =
  Int

pub opaque type Message {
  UserClickedIncrement
  UserClickedDecrement
  /// Internal: re-run [`view`](../counter.gleam) with the current model after
  /// a BEAM code load so singleton server components remount with fresh vdom.
  DevRerenderView
}

pub fn init(_: Nil) -> Model {
  0
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserClickedIncrement -> model + 1
    UserClickedDecrement -> model - 1
    DevRerenderView -> model
  }
}

/// Message sent by dev tooling after `gleam build` + code reload so
/// `view` re-executes with the newly loaded module (singleton runtime).
pub fn dev_rerender_message() -> Message {
  DevRerenderView
}

pub fn view(model: Model) -> Element(Message) {
  let count = int.to_string(model)

  element.fragment([
    html.h1([attribute.class("text-xl font-medium")], [html.text("Hi you")]),
    html.div([attribute.class("flex justify-between gap-3 items-center bg-green-100")], [
      
      view_button(label: "-", on_click: UserClickedDecrement),
      html.p([], [html.text("Counter: "), html.text(count)]),
      view_button(label: "+", on_click: UserClickedIncrement),
      element.element("my-counter", [attribute.class("bg-orange-100")], [])
    ]),
  ])
}
pub fn view_nonrecursive(model: Model) -> Element(Message) {
  let count = int.to_string(model)
  element.fragment([
    html.h1([attribute.class("text-xl font-medium")], [html.text("Hi you")]),
    html.div([attribute.class("flex justify-between gap-3 items-center bg-reed-100")], [
      view_button(label: "-", on_click: UserClickedDecrement),
      html.p([], [html.text("Counter: "), html.text(count)]),
      view_button(label: "+", on_click: UserClickedIncrement),
    ]),
  ])
}

fn view_button(
  label label: String,
  on_click handle_click: message,
) -> Element(message) {
  html.button(
    [
      event.on_click(handle_click),
      attribute.class("border border-black px-2 py-1 text-sm hover:opacity-60"),
    ],
    [html.text(label)],
  )
}

