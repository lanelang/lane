#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd)
tool_root="$repository_root/tools/guest-float-runtime"
work_root=$(mktemp -d "${TMPDIR:-/tmp}/lane-guest-float.XXXXXX")
trap 'rm -rf "$work_root"' EXIT

ryu_revision=4c0618b0e44f7ef027ebae05d2cc7812048f7c8f
git -C "$work_root" init -q ryu
git -C "$work_root/ryu" remote add origin https://github.com/ulfjack/ryu.git
git -C "$work_root/ryu" fetch -q --depth 1 origin "$ryu_revision"
git -C "$work_root/ryu" checkout -q FETCH_HEAD
cp "$tool_root/lane_wrapper.c" "$work_root/ryu/lane_wrapper.c"
cp -R "$tool_root/minimal" "$work_root/ryu/minimal"

if [[ -n "${LLVM_CLANG:-}" ]]; then
  clang_command=$LLVM_CLANG
elif [[ -x /opt/homebrew/opt/llvm/bin/clang ]]; then
  clang_command=/opt/homebrew/opt/llvm/bin/clang
else
  clang_command=clang
fi
clang_resource=$($clang_command -print-resource-dir)
$clang_command --target=wasm32 -O3 \
  -DRYU_OPTIMIZE_SIZE -DRYU_ONLY_64_BIT_OPS \
  -I"$work_root/ryu" -I"$work_root/ryu/minimal" \
  -nostdinc -isystem "$clang_resource/include" \
  -ffreestanding -fno-builtin -nostdlib \
  "$work_root/ryu/lane_wrapper.c" \
  "$work_root/ryu/ryu/f2s.c" \
  "$work_root/ryu/ryu/d2s.c" \
  -Wl,--no-entry \
  -Wl,--export=lane_f32_to_string \
  -Wl,--export=lane_f64_to_string \
  -Wl,--allow-undefined \
  -Wl,--import-memory \
  -o "$work_root/lane_ryu.wasm"

cp -R "$tool_root/generator" "$work_root/generator"
cp "$work_root/lane_ryu.wasm" "$work_root/generator/lane_ryu.wasm"
(
  cd "$work_root/generator"
  moon run --target native .
) > "$repository_root/modules/lanec/wasm_target/guest_float_runtime.generated.mbt"
moon fmt "$repository_root/modules/lanec/wasm_target/guest_float_runtime.generated.mbt"
