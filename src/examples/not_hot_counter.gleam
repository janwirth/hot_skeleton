//// Counter example. The MVU triple (`init`, `update`, `view`) lives in
//// [`counter/logic`](./counter/logic.gleam) so that Gleam emits them as
//// **cross-module** function references (`fun 'examples@counter@logic':update/2`).
//// External fun refs dispatch through the Erlang code server on every
//// call, which means radiate's hot code swap picks up new `update` logic
//// inside the already-running lustre-server-component actor — no
//// browser refresh, state preserved.
////
//// Gleam compiles bare, same-module references (`update`) to *local*
//// fun refs that are pinned to the module version active at capture
//// time, so they never hot-swap. Splitting into two modules is the
//// cheapest way to opt into hot-reloadable `update`/`view`.

import gleam/string
import gleam/io
import lustre.{type App}



pub fn component() -> App(Nil, Model, Message) {
  lustre.simple(init, update, view)
}

pub fn register() {
  let app = lustre.simple(init, update, view_nonrecursive)
  let res = lustre.register(app, "my-counter")
  io.print(string.inspect(res))
}
  
  
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
pub fn trigger_rerender_view() -> Message {
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

