#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KOMPAS="$ROOT/kompas"
OUT="$ROOT/priv/static/kompas.js"

cd "$KOMPAS"
gleam build --target javascript
bunx esbuild "$KOMPAS/build/dev/javascript/kompas/kompas.mjs" \
  --bundle --format=esm --platform=browser --outfile="$OUT"

echo "wrote $OUT"
