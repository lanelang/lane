# Lane runtime

This module supplies Lane's semantic host ABI and executes compiler-generated
WebAssembly through Wasmoon. WebAssembly is the only persisted and deployed
execution language. Interpreter and JIT modes execute the same Wasm module.

The compiler-private Physical Program, its verifier, ARC-final VM CFG, and slot
plan live under `Milky2018/lanec`; they are not artifact formats or public VMs.
