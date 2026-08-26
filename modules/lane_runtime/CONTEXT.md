# Lane Runtime

This module owns the host ABI and execution of Lane-generated WebAssembly.
WebAssembly is Lane's only deployable execution language. The compiler-private
Physical Program is neither accepted nor executed here.

## Language

### Host ABI

**Runtime Import**:
A versioned synchronous host operation identified by symbol, parameter value
kinds, and result value kind.
_Avoid_: source effect operation, Wasm function type alone

**Runtime Value Kind**:
The semantic host category of a runtime-import operand: Unit, Bool, I64, F32,
F64, String, or Opaque. It preserves distinctions erased by core Wasm value
types.
_Avoid_: Lane source type, physical slot representation

**Runtime Registry**:
The host-owned set of typed Runtime Bindings supplied when a Wasm artifact is
loaded.
_Avoid_: compiler intrinsic table, per-call symbol lookup

**Runtime Binding**:
A host implementation paired with its complete Runtime Import contract.
_Avoid_: unchecked host callback, source extern declaration

**Runtime Import Contract Validation**:
The load-time equality check between every artifact Runtime Import and its
Runtime Binding before an executable is published.
_Avoid_: arity-only checking, source type checking

**Runtime Context**:
Borrowed execution-local host services supplied implicitly to Runtime Imports.
_Avoid_: Lane value, process-global state

**Opaque Host Object**:
A host-owned value represented in generated Wasm by an execution-local managed
handle.
_Avoid_: serialized host pointer, persistent identity

**Host Object Table**:
The execution-owned table connecting opaque handles to typed host payloads and
their cleanup behavior.
_Avoid_: process-global registry, Wasm linear-memory object

### WebAssembly Execution

**Lane Wasm Module ABI**:
The public contract between generated Lane WebAssembly and an embedding host:
the exported entry, named runtime-control globals, and versioned Runtime
Imports.
_Avoid_: source module exports, compiler-private helper indices

**Lane Wasm Internal Runtime ABI**:
The compiler-private named contract shared by Wasm emission and the matching
runtime adapter for internal helpers and control globals.
_Avoid_: numeric function/global offsets, public Runtime Registry

**Wasm Artifact**:
A standard WebAssembly module plus its semantic Runtime Import manifest. The
manifest is necessary because Wasm physical signatures cannot distinguish, for
example, String from Opaque when both use `i32`.
_Avoid_: Physical Program, independent VM image

**Loaded Wasm Executable**:
A validated Wasm Artifact whose Runtime Imports are resolved and whose selected
engine mode is ready to instantiate.
_Avoid_: partially loaded artifact, active execution state

**Execution Mode**:
The engine selection for the same WebAssembly module: Wasmoon interpreter or
Wasmoon JIT. It changes implementation strategy, not Lane semantics or artifact
format.
_Avoid_: separate backend, fallback execution language

**Execution Instance**:
The single-shot Wasm instance, Runtime Context, host-object table, and resource
limits used by one execution attempt.
_Avoid_: Loaded Wasm Executable, reusable failed instance

**Runtime Import Failure**:
A fatal out-of-band host-call failure that produces no Lane value and ends the
current execution.
_Avoid_: handleable Lane effect, recoverable result

**Engine Trap**:
A WebAssembly engine failure outside portable Lane execution semantics,
reported with best-effort engine detail.
_Avoid_: Runtime Import Failure, Lane panic
