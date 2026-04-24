import dream_test/reporter/gherkin
import dream_test/runner
import features/hot_reloading
import gleam/io
import gleeunit

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
