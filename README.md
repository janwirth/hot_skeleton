# hot_skeleton

**Build local tools** — small Lustre apps that run on your machine: file
browsers, audio players, config editors, one-off dashboards, and other
utilities that need a browser UI wired to localhost, the filesystem, and
fast iteration. hot_skeleton strips the boilerplate (HTTP server, WebSocket
Lustre component, Tailwind watch, hot code swap) so you can focus on the
tool itself.

## Features

- 🔥 **Hot reload** — edit Gleam, keep UI state; no full page refresh
- 🎨 **Tailwind** — CSS rebuilds in dev via `tailwind_wrapper`
- 📁 **Local files** — `GET /reverse-proxy?path=…` streams audio, images, and text from disk
- 🔌 **Lustre server components** — one WebSocket, server-rendered vdom
- 🏭 **Production** — `gleam run` without the reloader
- 📋 **Logging** — boot lines by default; `HOT_SKELETON_LOG=debug` for HTTP/HMR detail
- 🧪 **Tests** — Gherkin + Chrome scenario for hot-reload state preservation

## Quick start

```bash
gleam dev    # hot reload + Tailwind watch (port 8080, or $PORT)
gleam run    # production entry: src/hot_skeleton.gleam
gleam test   # unit tests + hot-reload feature test
```

Point your app at `hot_skeleton.start(component, refresh_msg)` and use the
[counter example](src/examples/counter.gleam) split-module pattern for
hot-swappable `update` / `view` (see [Technical reference](#technical-reference)).

---

## Technical reference

### Development (BEAM hot code swap)

`gleam dev` runs `src/hot_skeleton_dev.gleam`, which wraps the server with
[`hot_reload`](src/hot_skeleton/hot_reload.gleam). That starts
[radiate](https://hexdocs.pm/radiate) on an absolute path to `src/` (needed
for fsevents on macOS) and
[`tailwind_wrapper`](tailwind_wrapper/) for CSS. When you edit a component,
radiate recompiles and hot-loads the new module. The browser is **not**
refreshed; the WebSocket stays open and the lustre-server-component actor's
in-memory model survives — the next message dispatches into the new code.

### Logging

The server prints `[hot_skeleton] listening on …` and, when Tailwind is
ready, `[hot_skeleton] tailwind -> …`. Set `HOT_SKELETON_LOG=debug` for HTTP
lines, timings, and HMR detail. To log only `tailwind_wrapper` events to a
file, use the package CLI (`tailwind_wrapper/README.md`).

### Local file streaming (`/reverse-proxy`)

`GET /reverse-proxy?path=…` streams a file from disk via `mist.send_file`
(audio, images, and common text types). `path` is absolute or cwd-relative
(URL-encode spaces and special characters).

| Status | Meaning |
|--------|---------|
| `400` | missing `path` |
| `404` | file not found |
| `415` | unsupported extension |

Example:

```text
curl "http://localhost:8080/reverse-proxy?path=/tmp/photo.png" -o photo.png
```

Supported extensions include mp3, m4a, wav, ogg, flac, png, jpg, gif, webp,
svg, txt, md, html, css, json, js, gleam, yaml, and csv. Full map:
[`streamable_content_type`](src/hot_skeleton/server.gleam) ·
[`serve_reverse_proxy`](src/hot_skeleton/server.gleam).

### Tests

`gleam test` runs `test/hot_skeleton_test.gleam` plus a
[dream_test](https://hexdocs.pm/dream_test) scenario in
`test/features/hot_reloading.gleam` (Chrome via
[chrobot](https://hexdocs.pm/chrobot)):

1. Click `+` → count is `1` (original `+ 1`).
2. Edit `src/examples/counter/logic.gleam` so `+` increments by `2`.
3. Count is **still** `1` — no reload, state kept.
4. Click `+` → count is `3` (1 + 2 with hot-swapped code).

`counter/logic.gleam` is restored after the test. One-off setup:
`gleam run -m chrobot/install`.

### Making `update` / `view` hot-swappable

Gleam compiles same-module function references to **local** fun refs
(`fun update/2`). In Erlang those are pinned to the module version active
when the fun was captured, so `code:atomic_load/1` does not update them —
the Lustre actor keeps calling the *old* `update`. Use **cross-module** fun
refs (`fun 'examples@counter@logic':update/2`), resolved through the code
server on every call.

Two-file pattern: wrapper exposes `component()`, sibling `logic` holds
`init` / `update` / `view`:

```gleam
import examples/counter/logic
import lustre.{type App}

pub type Model = logic.Model
pub type Message = logic.Message

pub fn component() -> App(Nil, Model, Message) {
  lustre.simple(logic.init, logic.update, logic.view)
}
```

No compiler plugins or macros — only types and `component()` live in
`counter.gleam`; business logic in `counter/logic.gleam` can change at
runtime.
