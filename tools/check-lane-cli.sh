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

expect_success_containing() {
  local expected="$1"
  shift
  local output
  if ! output="$("$lane_bin" "$@" 2>&1)"; then
    echo "error: lane $* failed" >&2
    echo "$output" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "error: lane $* omitted expected output: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure_containing() {
  local expected="$1"
  shift
  local output
  local status
  if output="$("$lane_bin" "$@" 2>&1)"; then
    echo "error: lane $* unexpectedly succeeded" >&2
    echo "$output" >&2
    exit 1
  else
    status=$?
  fi
  if [ "$status" -ne 1 ]; then
    echo "error: lane $* returned $status; expected 1" >&2
    echo "$output" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "error: lane $* omitted expected output: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
  printf '%s' "$output"
}

expect_success_containing 'Usage: lane <command>' --help
expect_success_containing \
  'Supply one object artifact for every module reachable from the selected entry.' \
  link --help

expect_failure_containing \
  "required argument was not provided: 'interface-output'" \
  compile Main.lane >/dev/null
expect_failure_containing \
  "required argument was not provided: 'output'" \
  explore Main.lane:main >/dev/null
expect_failure_containing \
  "required argument was not provided: 'entry'" \
  link Main.lmo >/dev/null
expect_failure_containing \
  'Supply one object artifact for every module reachable from the selected entry.' \
  link Main.lmo >/dev/null
expect_failure_containing \
  'invalid run target `Main.lane`' \
  run Main.lane >/dev/null

workspace="$(mktemp -d "${TMPDIR:-/tmp}/lane-cli.XXXXXX")"
trap 'rm -rf "$workspace"' EXIT
panic_source="$workspace/Panic.lane"
cat >"$panic_source" <<'EOF'
module Panic

import Basic.Io.{ panic, println }

pub fn main() -> Unit ! Io {
  panic("boom")
  println("after")
}
EOF

for mode in default no-jit; do
  args=(run "$panic_source:main")
  if [ "$mode" = no-jit ]; then
    args+=(--no-jit)
  fi
  panic_output="$(expect_failure_containing \
    'error[E6017]: Lane program panicked' \
    "${args[@]}")"
  if [[ "$panic_output" != *'message: boom'* ]]; then
    echo "error: panic message was not preserved in $mode mode" >&2
    echo "$panic_output" >&2
    exit 1
  fi
  if [[ "$panic_output" == *'RuntimeImportFailure'* ]] || \
    [[ "$panic_output" == *'symbol="panic"'* ]] || \
    [[ "$panic_output" == *'LoisVM execution failed'* ]]; then
    echo "error: panic leaked an internal runtime representation in $mode mode" >&2
    echo "$panic_output" >&2
    exit 1
  fi
  if [[ "$panic_output" == *'after'* ]]; then
    echo "error: statement-position panic continued in $mode mode" >&2
    echo "$panic_output" >&2
    exit 1
  fi
done
