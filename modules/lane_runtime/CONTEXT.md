# Lane Runtime

This module loads and executes compiler-generated WebAssembly through Wasmoon.
WebAssembly is Lane's only deployable execution language. The compiler-private
Physical Program is neither accepted nor executed here.

## Language

### WebAssembly Loading

**Wasm Artifact**:
A standards-valid raw WebAssembly module. Its import and export sections are
the complete public execution contract; no Lane manifest accompanies it.
_Avoid_: Physical Program, semantic runtime descriptor, linked container

**Core Wasm Host Import**:
An imported core WebAssembly function identified by module name, field name,
and exact core function type. Wasmoon Linker configuration supplies its host
implementation.
_Avoid_: source extern declaration, semantic host value category

**WASI Preview 1 Host**:
The standard host implementation registered for
`wasi_snapshot_preview1` imports. The shared ABI catalog validates the subset
emitted by Lane before instantiation.
_Avoid_: Basic API, semantic I/O registry

**Host Linker Configuration**:
An embedding callback that adds implementations for non-WASI core Wasm imports
to the Wasmoon Linker before instantiation. Wasmoon owns signature matching.
_Avoid_: Runtime Registry, per-call symbol lookup

**Loaded Wasm Executable**:
A parsed and validated Wasm Artifact whose selected engine mode is prepared for
fresh instantiation.
_Avoid_: active execution state, partially resolved semantic manifest

### WebAssembly Execution

**Guest Runtime Function**:
A compiler-selected Wasm function definition statically emitted into the
module for a builtin operation such as deterministic float formatting. It is
neither imported nor exported and therefore creates no host ABI.
_Avoid_: host callback, source extern, named runtime service

**Execution Mode**:
The engine selection for the same WebAssembly module: Wasmoon interpreter or
Wasmoon JIT. It changes implementation strategy, not Lane semantics or artifact
format.
_Avoid_: separate compiler backend, fallback execution language

**Execution Instance**:
The single-shot Wasm instance used by one execution attempt.
_Avoid_: Loaded Wasm Executable, reusable failed instance

**Process Exit**:
A `wasi_snapshot_preview1.proc_exit` status observed consistently from the
interpreter or JIT. Lane panic writes its message to standard error and exits
with status 1. It is an Execution Outcome, not an Execution Error; status zero
therefore remains distinct from ordinary `_start` return without becoming a
failure.
_Avoid_: engine trap, handleable Lane effect, recoverable exception

**Engine Trap**:
A WebAssembly engine failure outside portable Lane execution semantics,
reported with best-effort engine detail.
_Avoid_: Process Exit, source diagnostic
