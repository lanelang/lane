# Guest float runtime generator

This generator compiles the pinned Apache-2.0 Ryū implementation into the
guest-side WebAssembly functions used by Lane's `%f32_to_string` and
`%f64_to_string` builtins. The generated functions write canonical Lane text
directly into guest memory; they are definitions in the final module, not host
imports.

Ryū is Copyright 2018 Ulf Adams and licensed under Apache-2.0. Lane pins source
revision `4c0618b0e44f7ef027ebae05d2cc7812048f7c8f`; the repository's copy of the
Apache-2.0 license is at `modules/lanec/source_prettyprinter/LICENSE`.

Run `tools/generate-guest-float-runtime.sh` from any directory. Set
`LLVM_CLANG` when `clang` does not provide the `wasm32` target. The generated
MoonBit source is checked in so normal compiler builds do not require Clang,
Git, or network access.
