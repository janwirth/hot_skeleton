import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result

type State {
  State(next_id: Int, clients: List(#(Int, process.Subject(String))))
}

pub type Message {
  AddClient(bust: process.Subject(String), ack: process.Subject(Int))
  RmClient(id: Int)
  DoPush(t: String)
}

fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    AddClient(bust, ack) -> {
      let id = state.next_id
      process.send(ack, id)
      actor.continue(State(
        next_id: int.add(id, 1),
        clients: [#(id, bust), ..state.clients],
      ))
    }
    RmClient(id) -> {
      let rest = list.filter(state.clients, fn(p) { p.0 != id })
      actor.continue(State(..state, clients: rest))
    }
    DoPush(t) -> {
      let n = list.length(state.clients)
      io.println(
        "CSS cache bust (hub → "
        <> int.to_string(n)
        <> " ws client(s)) t="
        <> t,
      )
      list.each(state.clients, fn(p) { process.send(p.1, t) })
      actor.continue(state)
    }
  }
}

pub fn start() -> Result(process.Subject(Message), actor.StartError) {
  let init = State(next_id: 1, clients: [])
  actor.new(init)
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(s) { s.data })
}
