import dream_test/reporter/gherkin
import dream_test/runner
import features/hot_reloading
import gleam/io
import gleam/option.{None, Some}
import gleeunit
import hot_skeleton/server

pub fn main() -> Nil {
  io.println("")
  io.println("hot_skeleton — Gherkin feature tests")
  io.println("====================================")

  let _results =
    hot_reloading.tests()
    |> runner.run_suite
    |> gherkin.report(io.print)

  // Fall through to any plain gleeunit tests in this module / folder.
  gleeunit.main()
}

// Plain gleeunit smoke test so the suite is never empty.
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"
  assert greeting == "Hello, Joe!"
}

pub fn streamable_content_type_test() {
  assert server.streamable_content_type("/a/track.MP3") == Some("audio/mpeg")
  assert server.streamable_content_type("/img/x.png") == Some("image/png")
  assert server.streamable_content_type("/notes.txt") == Some("text/plain; charset=utf-8")
  assert server.streamable_content_type("/bin.exe") == None
}
