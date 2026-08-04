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

frame_lsp_message() {
  local message="$1"
  printf 'Content-Length: %s\r\n\r\n%s' "${#message}" "$message"
}

shutdown_message='{"jsonrpc":"2.0","id":1,"method":"shutdown","params":null}'
exit_message='{"jsonrpc":"2.0","method":"exit","params":null}'
if ! {
  frame_lsp_message "$shutdown_message"
  frame_lsp_message "$exit_message"
} | "$lane_bin" lsp --stdio >/dev/null; then
  echo "error: lane lsp rejected a graceful shutdown/exit session" >&2
  exit 1
fi

if frame_lsp_message "$exit_message" |
  "$lane_bin" lsp --stdio >/dev/null; then
  echo "error: lane lsp accepted exit before shutdown" >&2
  exit 1
else
  premature_status=$?
fi
if [ "$premature_status" -ne 1 ]; then
  echo "error: lane lsp returned $premature_status for exit before shutdown; expected 1" >&2
  exit 1
fi
