//// MVU triple for the counter example. Kept in its own module so that
//// references from [`examples/counter`](../counter.gleam) compile to
//// cross-module (external) fun refs — see the note in `counter.gleam`
//// for why that matters for hot code reloading.

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
}

pub fn init(_: Nil) -> Model {
  0
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserClickedIncrement -> model + 1
    UserClickedDecrement -> model - 1
  }
}

pub fn view(model: Model) -> Element(Message) {
  let count = int.to_string(model)
  let styles = [#("display", "flex"), #("justify-content", "space-between")]

  element.fragment([
    html.h1([], [html.text("Hi there wassup")]),
    html.div([attribute.styles(styles)], [
      view_button(label: "-", on_click: UserClickedDecrement),
      html.p([], [html.text("Count: "), html.text(count)]),
      view_button(label: "+", on_click: UserClickedIncrement),
    ]),
  ])
}

fn view_button(
  label label: String,
  on_click handle_click: message,
) -> Element(message) {
  html.button([event.on_click(handle_click)], [html.text(label)])
}
