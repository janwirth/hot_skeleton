# tailwind_wrapper

Gleam helper that spawns a **Tailwind CSS v4** watch (via the official standalone CLI) and reports events to a callback.

`config_hot_skeleton` puts the **entry under `src/`** (e.g. `src/tw-entry.css`) and spawns the CLI with **`--cwd=src`**, `‑i=tw-entry.css`, and `‑o` / `‑o` as paths **relative to that directory**. That narrows the native file watcher: Tailwind/Parcel can still subscribe a broad tree ([upstream issue](https://github.com/tailwindlabs/tailwindcss/issues/15750)); `source(none)` + `@source not` do **not** stop those watches. The generated CSS also uses `source(none)`, `@source` (under `src` and `../dev`), and `@source not` for the output, `build/`, and `node_modules/`.

## Use

```sh
# From your gleam app (e.g. hot_skeleton)
gleam add path tailwind_wrapper
```

```gleam
import tailwind_wrapper as tw

pub fn main() {
  let config = tw.config_hot_skeleton()
  // or: tw.default_config()  // input ./src, output priv/tailwind.css
  tw.start(config, fn(e) {
    case e {
      tw.Initialized -> // watch ready
      tw.Failed(msg) -> // spawn / compile error
      tw.Built(line, output_path) -> // one line of CLI output, resolved CSS path
    }
  })
}
```

- **Config:** `generated_input`, `output_css`, and optional `app_input`; see `default_config` / `config_hot_skeleton`.
- **Output path:** `tw.output_path_for(config)` and `tw.css_cache_bust(config)`.

## Debug CLI (log events to a file)

Appends every event to a file and prints the same lines to stdout. The process runs until you stop it (Ctrl+C).

```sh
cd path/to/tailwind_wrapper
# default: .tailwind-wrapper/events.log in cwd
gleam run -m cli

# custom file
TAILWIND_WRAPPER_LOG=/tmp/tw.log gleam run -m cli
```

## Development

```sh
gleam test
```
