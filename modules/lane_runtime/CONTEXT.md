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

**Lane Wasm Internal Runtime ABI**:
The compiler-private named contract shared by Wasm emission and the matching
runtime adapter for deterministic float formatting, fatal control, and runtime
control globals.
_Avoid_: public host ABI, numeric function or global offsets

**Execution Mode**:
The engine selection for the same WebAssembly module: Wasmoon interpreter or
Wasmoon JIT. It changes implementation strategy, not Lane semantics or artifact
format.
_Avoid_: separate compiler backend, fallback execution language

**Execution Instance**:
The single-shot Wasm instance and resource limits used by one execution
attempt.
_Avoid_: Loaded Wasm Executable, reusable failed instance

**Fatal Outcome**:
Compiler-owned terminal control carrying a validated UTF-8 message after Lane
cleanup has run.
_Avoid_: handleable Lane effect, host import error

**Engine Trap**:
A WebAssembly engine failure outside portable Lane execution semantics,
reported with best-effort engine detail.
_Avoid_: Fatal Outcome, source diagnostic
