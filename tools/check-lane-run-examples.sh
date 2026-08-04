#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

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

moon build --target native --release modules/lane >/dev/null
lane_build="_build/native/release/build/Milky2018/lane/lane.exe"
lane_smoke_dir="_build/lane-smoke"
lane_smoke_bin="$lane_smoke_dir/lane.exe"

mkdir -p "$lane_smoke_dir"
cp "$lane_build" "$lane_smoke_bin"
chmod +x "$lane_smoke_bin"
trap 'rm -f "$lane_smoke_bin"' EXIT

frame_lsp_message() {
  local message="$1"
  printf 'Content-Length: %s\r\n\r\n%s' "${#message}" "$message"
}

shutdown_message='{"jsonrpc":"2.0","id":1,"method":"shutdown","params":null}'
exit_message='{"jsonrpc":"2.0","method":"exit","params":null}'
if ! {
  frame_lsp_message "$shutdown_message"
  frame_lsp_message "$exit_message"
} | "$repo_root/$lane_smoke_bin" lsp --stdio >/dev/null; then
  echo "error: lane lsp rejected a graceful shutdown/exit session" >&2
  exit 1
fi

if frame_lsp_message "$exit_message" |
  "$repo_root/$lane_smoke_bin" lsp --stdio >/dev/null; then
  echo "error: lane lsp accepted exit before shutdown" >&2
  exit 1
else
  premature_status=$?
fi
if [ "$premature_status" -ne 1 ]; then
  echo "error: lane lsp returned $premature_status for exit before shutdown; expected 1" >&2
  exit 1
fi

LANE_HOME="$repo_root" LANE_SMOKE_BIN="$repo_root/$lane_smoke_bin" moon run --target native tools/check-lane-run-examples.mbtx
