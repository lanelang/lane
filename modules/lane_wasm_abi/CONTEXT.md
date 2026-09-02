# WebAssembly ABI

This package owns target ABI contracts shared by Physical Lowering, Physical
Program verification, and WebAssembly emission.

## Language

**Core Wasm Import Contract**:
The module name, field name, exact core value types, and required boundary
adaptation for one imported function. The Physical Program stores this fact;
the emitter only materializes it.
_Avoid_: source extern type, semantic runtime-import descriptor

**Guest Address Parameter**:
A source-facing raw-extern parameter whose value is the certified Canonical
Basic `WasmAddress` pair of owned `Bytes` storage and an in-frame offset.
Physical Lowering alone projects it to a core-Wasm `i32` immediately before the
synchronous host call and keeps the storage owner alive through that call.
_Avoid_: source-visible raw pointer, arbitrary nominal extern parameter, persistent host reference

**Core Contract Projection**:
The deterministic projection from a source-facing import contract to the exact
core-Wasm signature. It erases only compiler-owned guest-address carriers to
`i32`; it does not infer layouts or change scalar parameters.
_Avoid_: second import catalog, backend signature guess, platform policy

**Lane Runtime V1 Catalog**:
The versioned non-WASI host capability catalog implemented by the Lane Command
execution target. Its process capability consists of synchronous-guest
`lane_runtime_v1.run_command` and `lane_runtime_v1.take_command_output` imports.
The catalog owns their exact Core Wasm contracts and normative wire semantics.
Basic implements the guest encoder and the host uses the catalog decoder;
neither endpoint may infer or alter the protocol. Runtime adapters derive host
registration and response projection from the catalog rather than restating
those facts.
_Avoid_: compiler intrinsic, shell command string, Wasmoon-specific callback

**Run Command Request Frame**:
A little-endian guest-memory record containing flags, executable, argv, optional
working directory, environment overrides, and standard-input bytes. All strings
are length-delimited UTF-8 ranges relative to the frame start. The import
borrows the frame only for the duration of a synchronous guest call and never
invokes a shell.
_Avoid_: retained guest pointer, NUL-delimited command string, implicit argv parsing

**Command Output Handle**:
A host-owned, single-use identity for captured standard output and standard
error after a successful Run Command call. The response reports exact lengths;
Take Command Output copies `stdout || stderr` into an exact-size guest buffer
and consumes the identity.
_Avoid_: retained guest pointer, fixed output limit, truncated output, repeated process execution

The normative byte layout and result codes are defined in
[`run-command-v1.md`](run-command-v1.md).
