# Lane runtime

This module validates and executes compiler-generated WebAssembly through
Wasmoon. WebAssembly is the only persisted and deployed execution language;
interpreter and JIT modes execute the same raw module.

WASI Preview 1 provides the standard system interface. Embedders may configure
additional direct core-Wasm function imports through Wasmoon's linker. Lane has
no semantic host registry or sidecar runtime-import manifest.

The compiler-private Physical Program, its verifier, ARC-final VM CFG, and slot
plan live under `Milky2018/lanec`; they are not artifact formats or public VMs.
