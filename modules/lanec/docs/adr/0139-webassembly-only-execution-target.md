# ADR-0139: WebAssembly is the sole execution target

## Status

Accepted.

The executable-container and semantic runtime-manifest portions are superseded
by the implemented WASI Preview 1 WebAssembly Target RFC. The sole-target and
compiler-private Physical Program decisions remain in force.

## Context

Lane previously exposed a persisted LoisVM bytecode image, an independent
interpreter for that image, and a bytecode-to-WebAssembly compiler. The same
execution semantics therefore had three owners: the bytecode verifier, the
interpreter, and the Wasm backend. Artifact compatibility also tracked a
compiler-internal instruction language that no external deployment consumed.

The compiler still needs VM CFG, ARC-final control flow, physical-slot
allocation, and a verifier-checked physical representation before emitting
Wasm. Those are necessary compiler invariants; they do not imply a public VM.

## Decision

WebAssembly is Lane's only persisted and deployed execution language.

The compiler pipeline is:

```text
Runtime ANF
  -> VM CFG
  -> ARC-final VM CFG
  -> Physical Slot Plan
  -> verified Physical Program
  -> WebAssembly
```

The Physical Program is compiler-private and non-persisted. It has no decoder,
codec, public loader, or independent interpreter. The WebAssembly emitter is
its only consumer.

A linked executable artifact contains standard Wasm bytes and a semantic
runtime-import manifest. The manifest remains explicit because core Wasm value
types cannot preserve Lane host categories such as String and Opaque.

`lane run` and `lane exec` always load the same Wasm artifact. `--no-jit`
selects Wasmoon's interpreter; the default selects Wasmoon's JIT. Engine choice
does not select another compiler backend or artifact format.

Internal runtime helpers and runtime-control globals are identified by names
owned by the Lane Wasm Internal Runtime ABI. The runtime must discover them
from module imports and exports rather than reproduce compiler numeric indices.

The linked-program schema advances to 17 and rejects prior bytecode-bearing
schemas. There is no compatibility decoder or fallback execution path.

## Consequences

- The bytecode codec, decoder, public verifier boundary, and direct interpreter
  are deleted.
- VM CFG, ARC-final validation, slot planning, and Physical Program validation
  remain compiler-owned because each proves a distinct invariant.
- The Wasm emitter and runtime share only named Wasm ABI facts and the semantic
  runtime-import contract.
- Any future execution target must be introduced as a new explicit target with
  its own artifact and ABI decision; it cannot revive the Physical Program as a
  public compatibility layer.

## Supersedes

This decision supersedes the execution-format portions of ADR-0069, ADR-0071,
ADR-0085, ADR-0111, ADR-0116, ADR-0128, and ADR-0129. Their compiler-internal
representation and ABI rationale remains historical context where applicable.
