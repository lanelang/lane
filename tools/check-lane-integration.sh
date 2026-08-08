#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

moon build --target native --release modules/lane >/dev/null
lane_build="$repo_root/_build/native/release/build/Milky2018/lane/lane.exe"
integration_dir="$repo_root/_build/lane-integration"
lane_bin="$integration_dir/lane.exe"

mkdir -p "$integration_dir"
cp "$lane_build" "$lane_bin"
chmod +x "$lane_bin"
trap 'rm -f "$lane_bin"' EXIT

"$repo_root/tools/check-lane-run-examples.sh" "$lane_bin"
"$repo_root/tools/check-lane-cli-help.sh" "$lane_bin"
"$repo_root/tools/check-lane-lsp-cli.sh" "$lane_bin"
