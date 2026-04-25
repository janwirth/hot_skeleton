# tailwind_wrapper

Gleam helper that spawns a **Tailwind CSS v3** watch (via the official standalone CLI) and reports events to a callback.

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

- **Config:** `input_glob` (e.g. `"./src/**/*.gleam"`), `output_css` (e.g. `"priv/tailwind.css"`), `cwd` (project root; required on macOS for fsevents).
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
