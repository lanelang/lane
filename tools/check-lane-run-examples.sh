#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# The examples fixture is the pinned `basic` submodule, not the user-facing
# $LANE_HOME installation, so a run is reproducible against a recorded Basic
# revision. Bump the submodule (and commit the new gitlink) to move the pin.
if [ ! -e "$repo_root/basic/.git" ]; then
  git -C "$repo_root" -c protocol.file.allow=always submodule update --init -- basic
fi
fixture_rev="$(git -C "$repo_root/basic" rev-parse --short=12 HEAD)"
pinned_rev="$(git -C "$repo_root" rev-parse --short=12 :basic)"
fixture_note=""
if [ "$fixture_rev" != "$pinned_rev" ]; then
  fixture_note=" (pinned: $pinned_rev)"
fi
if [ -n "$(git -C "$repo_root/basic" status --porcelain)" ]; then
  fixture_note="$fixture_note (dirty)"
fi
echo "basic fixture: $fixture_rev$fixture_note"

moon build --target native --release modules/lane >/dev/null
lane_build="_build/native/release/build/Milky2018/lane/lane.exe"
lane_smoke_dir="_build/lane-smoke"
lane_smoke_bin="$lane_smoke_dir/lane.exe"

mkdir -p "$lane_smoke_dir"
cp "$lane_build" "$lane_smoke_bin"
chmod +x "$lane_smoke_bin"
trap 'rm -f "$lane_smoke_bin"' EXIT

LANE_HOME="$repo_root" LANE_SMOKE_BIN="$repo_root/$lane_smoke_bin" moon run --target native tools/check-lane-run-examples.mbtx
