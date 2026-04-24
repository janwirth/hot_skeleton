# hot_skeleton

Hot skeleton is a tool that allows you to build lustre applications with minimal boilerplate.

- **Development (file reload + browser refresh):** `gleam dev` —
  `src/hot_skeleton_dev.gleam` wraps the server with
  `src/hot_skeleton/hot_reload.gleam`, a local patched variant of
  [mist_reload](https://github.com/CrowdHailer/mist_reload) that hands
  [radiate](https://hexdocs.pm/radiate) an absolute path (required for
  fsevents on macOS; mist_reload 1.0.1 passes a relative `"src"` which
  silently does nothing there).

- **Production (no reloader):** `gleam run` — `src/hot_skeleton.gleam`.

- **Tests:** `gleam test` — `test/hot_skeleton_test.gleam` runs a
  [dream_test](https://hexdocs.pm/dream_test) Gherkin scenario
  (`test/features/hot_reloading.gleam`) that drives Chrome via
  [chrobot](https://hexdocs.pm/chrobot), edits
  `src/examples/counter.gleam` from `+3` to `+2`, waits for the hot
  reload, clicks the `+` button and asserts the new increment.
  `counter.gleam` is restored after the test runs.

  One-off setup before the first test run: install a local Chrome for
  Testing with `gleam run -m chrobot/install`.
