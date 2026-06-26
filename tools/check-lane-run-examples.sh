#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

moon run --target native --build-only modules/lane -- --help >/dev/null
moon run --target native tools/check-lane-run-examples.mbtx
