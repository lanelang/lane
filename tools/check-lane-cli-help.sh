#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/lane.exe" >&2
  exit 2
fi

lane_bin="$1"
if [ ! -x "$lane_bin" ]; then
  echo "error: lane executable is not executable: $lane_bin" >&2
  exit 1
fi

reachable_note='Supply one object artifact for every module reachable from the selected entry.'
help_output="$($lane_bin link --help 2>&1)"
if [[ "$help_output" != *"$reachable_note"* ]]; then
  echo "error: lane link help omits the reachable-module requirement" >&2
  exit 1
fi

if failure_output="$($lane_bin link Main.lmo 2>&1)"; then
  echo "error: lane link accepted missing required options" >&2
  exit 1
fi
if [[ "$failure_output" != *"$reachable_note"* ]]; then
  echo "error: lane link argument failure omits the reachable-module requirement" >&2
  exit 1
fi
