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

**WASI Preview 1 Catalog**:
The canonical identities, source-facing guest-address roles, source effects,
and exact core function types of the complete Snapshot Preview 1 surface
implemented by the pinned Wasmoon runtime. Basic exposes raw declarations from
this catalog; compiler and runtime consumers only validate, project, or resolve
those certified entries.
_Avoid_: Wasmoon callback registration, Basic function type

**Lane Runtime V1 Catalog**:
The versioned non-WASI host capability catalog implemented by the Lane Command
execution target. Its first operation is the synchronous
`lane_runtime_v1.run_command` import. The catalog owns the exact Core Wasm
contract and normative wire semantics. Basic implements the guest encoder and
the host uses the catalog decoder; neither endpoint may infer or alter the
protocol. Runtime adapters derive host registration and response projection
from the catalog rather than restating those facts.
_Avoid_: compiler intrinsic, shell command string, Wasmoon-specific callback

**Run Command Request Frame**:
A little-endian guest-memory record containing flags, executable, argv, optional
working directory, and environment overrides. All strings are length-delimited
UTF-8 ranges relative to the frame start. The import borrows the frame only for
the duration of a synchronous call and never invokes a shell.
_Avoid_: retained guest pointer, NUL-delimited command string, implicit argv parsing

The normative byte layout and result codes are defined in
[`run-command-v1.md`](run-command-v1.md).
