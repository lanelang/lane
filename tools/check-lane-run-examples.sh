#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

moon build --target native --release modules/lane >/dev/null
lane_build="_build/native/release/build/Milky2018/lane/lane.exe"
lane_smoke_dir="_build/lane-smoke"
lane_smoke_bin="$lane_smoke_dir/lane.exe"

mkdir -p "$lane_smoke_dir"
cp "$lane_build" "$lane_smoke_bin"
chmod +x "$lane_smoke_bin"
trap 'rm -f "$lane_smoke_bin"' EXIT

LANE_SMOKE_BIN="$repo_root/$lane_smoke_bin" moon run --target native tools/check-lane-run-examples.mbtx
