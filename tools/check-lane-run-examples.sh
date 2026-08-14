#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/lane.exe" >&2
  exit 2
fi

lane_bin="$1"
if [ ! -x "$lane_bin" ]; then
  echo "error: lane executable is not executable: $lane_bin" >&2
  exit 1
fi

# The examples fixture is the pinned `basic` submodule, not the user-facing
# $LANE_HOME installation, so a run is reproducible against a recorded Basic
# revision. Bump the submodule (and commit the new gitlink) to move the pin.
if [ ! -e "$repo_root/basic/.git" ]; then
  echo "error: the pinned Basic fixture is not initialized" >&2
  echo "run: git submodule update --init --checkout basic" >&2
  exit 1
fi

fixture_rev="$(git -C "$repo_root/basic" rev-parse HEAD)"
pinned_rev="$(git -C "$repo_root" rev-parse :basic)"
if [ "$fixture_rev" != "$pinned_rev" ]; then
  echo "error: Basic is at ${fixture_rev:0:12}; the pinned revision is ${pinned_rev:0:12}" >&2
  echo "run: git submodule update --init --checkout basic" >&2
  exit 1
fi

if [ -n "$(git -C "$repo_root/basic" status --porcelain)" ]; then
  echo "error: the pinned Basic fixture has uncommitted changes" >&2
  echo "save or discard those changes, then run: git submodule update --init --checkout basic" >&2
  exit 1
fi

echo "basic fixture: ${fixture_rev:0:12}"

LANE_HOME="$repo_root" LANE_SMOKE_BIN="$lane_bin" \
  moon run --target native tools/check-lane-run-examples.mbtx
