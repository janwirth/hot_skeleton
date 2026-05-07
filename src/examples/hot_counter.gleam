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
import examples/counter/logic
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

pub fn register() {
  let app = lustre.simple(logic.init, logic.update, logic.view_nonrecursive)
  let res = lustre.register(app, "my-counter")
  io.print(string.inspect(res))
}
  
