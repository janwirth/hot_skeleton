// Globs for parcel-watcher `ignore` when subscribing at the project root (".").
// Paths must be root-relative (e.g. ./build/...), not parent globs from any cwd.
// Shared with watch-debug; same style as Tailwind CLI parcel layer.
export const projectRootIgnore = [
  "./.git/**",
  "./node_modules/**",
  "./build/**",
  "./.hot_skeleton/**",
  "./.tailwind-wrapper/**",
]
