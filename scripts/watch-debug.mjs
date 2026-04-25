// Compare file noise vs Tailwind: uses @parcel/watcher (same as Tailwind’s native layer).
// Ignore list: `scripts/parcel-watcher-ignore.mjs` (paths relative to watch root, no `**/...` prefix).
// Gleam LSP writes to build/lsp/.../ _gleam_artefacts/ on every keypress analysis —
// that is *under build/*, not in src/ or dev/, so it does *not* match @source. If
// you watch "." with no filter you see the LSP storm; that is not what Tailwind
// scoped to @source sees.
//
//   bun run scripts/watch-debug.mjs                 # heuristics: hide build, LSP, tool dirs
//   bun run scripts/watch-debug.mjs --raw           # full firehose (old default)
//   bun run scripts/watch-debug.mjs --raw ../foo    # other root

import path from "node:path";
import fs from "node:fs";
import crypto from "node:crypto";
import watcher from "@parcel/watcher";
import { projectRootIgnore } from "./parcel-watcher-ignore.mjs";

const useRaw = process.argv.includes("--raw");
const args = process.argv.slice(2).filter((a) => a !== "--raw");
if (args[0] === "-h" || args[0] === "--help") {
  console.log(
    `bun run scripts/watch-debug.mjs [--raw] [dir]
  default dir: .   default: ignore build/, LSP, tool dirs (unlike the old "no filter" default)
  --raw: show everything under dir (you will see Gleam LSP _gleam_artefacts under build/lsp/)`,
  );
  process.exit(0);
}
const target = path.resolve(args[0] ?? ".");
const t0 = Date.now();
const seen = new Map();
let counter = 0;

const ignore = useRaw ? [] : projectRootIgnore;

console.log(`[watch-debug] watching: ${target}`);
console.log(
  `[watch-debug] ignore  : ${
    ignore.length
      ? projectRootIgnore.join(", ")
      : "none (--raw) — includes LSP build/lsp/ cache churn"
  }`,
);
console.log(`[watch-debug] backend : fs-events on macOS (default)`);
console.log(
  `[watch-debug] tip: LSP cache updates (build/lsp) look like "rebuilds" only when --raw. Tailwind @source is src+dev only.\n`,
);

function meta(p) {
  try {
    const st = fs.statSync(p);
    let hash = "";
    if (st.isFile() && st.size < 5_000_000) {
      const h = crypto.createHash("sha1");
      h.update(fs.readFileSync(p));
      hash = h.digest("hex").slice(0, 8);
    }
    return { mtime: Math.round(st.mtimeMs), size: st.size, hash };
  } catch {
    return null;
  }
}

function delta(p, cur) {
  const prev = seen.get(p);
  seen.set(p, cur);
  if (!prev || !cur) return "new";
  const dm = cur.mtime - prev.mtime;
  const ds = cur.size - prev.size;
  const sameHash = prev.hash && cur.hash && prev.hash === cur.hash;
  return sameHash ? `mtime-only Δm=${dm}` : `content    Δm=${dm} Δs=${ds}`;
}

const sub = await watcher.subscribe(
  target,
  (err, events) => {
    if (err) return console.error("[watch-debug] error:", err);
    const t = Date.now() - t0;
    counter++;
    console.log(
      `--- batch #${counter} t=${t}ms (${events.length} event${events.length === 1 ? "" : "s"}) ---`,
    );
    for (const e of events) {
      const m = meta(e.path);
      const d = delta(e.path, m);
      const tail = m
        ? `mtime=${m.mtime} size=${m.size} sha1=${m.hash}`
        : "(stat failed)";
      console.log(
        `  ${e.type.padEnd(6)} ${d.padEnd(28)} ${e.path}\n         | ${tail}`,
      );
    }
  },
  { ignore },
);

console.log(`[watch-debug] subscribed. ctrl-c to quit\n`);
process.on("SIGINT", async () => {
  await sub.unsubscribe();
  process.exit(0);
});
