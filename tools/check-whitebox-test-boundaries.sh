#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

actual="$(mktemp "${TMPDIR:-/tmp}/lane-whitebox-actual.XXXXXX")"
documented="$(mktemp "${TMPDIR:-/tmp}/lane-whitebox-documented.XXXXXX")"
trap 'rm -f "$actual" "$documented"' EXIT

rg --files -g '*_wbtest.mbt' | LC_ALL=C sort >"$actual"
sed -n 's/^| `\([^`]*_wbtest\.mbt\)` | \([^|][^|]*\) |$/\1/p' \
  docs/whitebox-test-boundaries.md | LC_ALL=C sort >"$documented"

if duplicates="$(uniq -d "$documented")" && [ -n "$duplicates" ]; then
  echo "error: duplicate white-box suite entries:" >&2
  echo "$duplicates" >&2
  exit 1
fi

if ! diff -u "$documented" "$actual"; then
  echo "error: every white-box test file needs exactly one private-invariant justification" >&2
  echo "update docs/whitebox-test-boundaries.md" >&2
  exit 1
fi
