#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APWW="$ROOT/../all-tuna-versions/tuna-gleam-monorepo/audio_player_with_waveform"
STATIC="$ROOT/priv/static"
OUT="$STATIC/audio_player_with_waveform.js"
WORKER_SRC="$APWW/src/waveform_worker.mjs"
WORKER_OUT="$STATIC/waveform_worker.mjs"

cd "$APWW"
git pull --ff-only
gleam build --target javascript
bunx esbuild build/dev/javascript/audio_player_with_waveform/audio_player_with_waveform.mjs \
  --bundle --format=esm --platform=browser --outfile="$OUT"
cp "$WORKER_SRC" "$WORKER_OUT"
echo "wrote $OUT"
echo "wrote $WORKER_OUT"
