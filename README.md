# hot_skeleton

Hot skeleton is a tool that allows you to build lustre applications with
minimal boilerplate.

- **Development (BEAM hot code swap, state preserved):** `gleam dev` —
  `src/hot_skeleton_dev.gleam` wraps the server with
  `src/hot_skeleton/hot_reload.gleam`, which runs
  [radiate](https://hexdocs.pm/radiate) against an absolute path to the
  project `src/` (required for fsevents on macOS) and
  [tailwind\_wrapper](tailwind_wrapper/) to watch and rebuild CSS. When
  you edit a component, radiate recompiles and hot-loads the new module.
  The browser is **not** refreshed; the WebSocket stays open and the
  lustre-server-component actor's in-memory model survives the swap —
  the next message it handles dispatches into the new code.

- **Logging:** The server always prints a boot line
  (`[hot_skeleton] listening on …` and, when the Tailwind watch is
  ready, `[hot_skeleton] tailwind -> …`). For extra dev detail (HTTP
  lines, timings, HMR), set `HOT_SKELETON_LOG=debug`. To log only
  `tailwind_wrapper` events to a file, run the package CLI (see
  `tailwind_wrapper/README.md`).

- **Production (no reloader):** `gleam run` — `src/hot_skeleton.gleam`.

- **Tests:** `gleam test` — `test/hot_skeleton_test.gleam` runs a
  [dream_test](https://hexdocs.pm/dream_test) Gherkin scenario
  (`test/features/hot_reloading.gleam`) that drives Chrome via
  [chrobot](https://hexdocs.pm/chrobot) and verifies state preservation:

  1. Click `+` → count is `1` (using original `+ 1`).
  2. Edit `src/examples/counter/logic.gleam` so `+` increments by `2`.
  3. Count is **still** `1` — no page reload, state is kept.
  4. Click `+` → count is `3` (1 + 2 using hot-swapped code).

  `counter/logic.gleam` is restored to `+ 1` after the test.

  One-off setup before the first test run: install a local Chrome for
  Testing with `gleam run -m chrobot/install`.

## Making `update`/`view` hot-swappable

Gleam compiles same-module function references to **local** fun refs
(`fun update/2`). In Erlang those are pinned to the module version
active when the fun was captured, so `code:atomic_load/1` does not
update them — the Lustre runtime actor keeps calling the *old*
`update`. To get hot-swappable references you need **cross-module**
fun refs (`fun 'examples@counter@logic':update/2`), which Erlang
resolves through the code server on every call.

The fix is a two-file pattern: the wrapper module exposes
`component()`, the sibling `logic` module holds `init` / `update` /
`view`:

```15:25:src/examples/counter.gleam
import examples/counter/logic
import lustre.{type App}

pub type Model =
  logic.Model

pub type Message =
  logic.Message

pub fn component() -> App(Nil, Model, Message) {
  lustre.simple(logic.init, logic.update, logic.view)
}
```

That is the entire hack — no compiler plugins, no macros. Only the
types and `component()` entry point live in `counter.gleam`; business
logic goes in `counter/logic.gleam` and can be edited at runtime.
