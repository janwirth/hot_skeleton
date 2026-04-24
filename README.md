# hot_skeleton

Hot skeleton is a tool that allows you to build lustre applications with minimal boilerplate.

- **Development (file reload + browser refresh):** `gleam dev` — uses [mist_reload](https://github.com/CrowdHailer/mist_reload) (`src/hot_skeleton_dev.gleam`).

- **Production (no reloader):** `gleam run` — `src/hot_skeleton.gleam`.
