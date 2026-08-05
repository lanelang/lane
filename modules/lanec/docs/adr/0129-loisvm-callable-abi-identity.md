---
status: accepted
---

# LoisVM callable ABI identity

Every dynamically invoked LoisVM callable has one explicit execution ABI. A
`CallableAbi` contains the layout-witness count, the ordered user-parameter
`ValueAbi` values, and the complete `ResultAbi`. `ValueAbi` contains both
representation and cleanup. A `BytecodeImage` owns a canonical, duplicate-free
table of these descriptions, addressed by zero-based `CallableAbiId` values.

Every `CallValue` and `TailCallValue` names its expected `CallableAbiId`.
Every bytecode body and runtime import projects its actual `CallableAbi` from
its authoritative input and result declarations, and that description must
occur in the image table. A packed callable remains the pair of `FunctionId`
and optional environment reference; its function-table target therefore
determines its actual ABI without duplicating an ABI identifier in the runtime
value.

The hidden environment is deliberately not part of `CallableAbi`. All Wasm
callable entries use the same leading `env:i32` physical parameter, while the
target function's context kind independently determines whether zero or a
nonzero owned environment is legal. This lets capture-free and capturing
implementations of the same source callable type share one ABI.

## Validation and execution

The bytecode verifier checks that callable ABI identifiers are in range and
that every indirect call site's witness, parameter, destination, and tail
result slots match the named complete ABI. Direct calls use the target
function's projection and the same physical-shape checking operation.

The interpreter resolves the packed `FunctionId` safely and, before consuming
the callable or any argument owner, compares the target's projected ABI with
the call site's expected ABI. It also checks target range, environment
presence, counts, runtime value representations, cleanup metadata, and result
shape. Failure is the structured `InvalidCallableInvocation` execution error;
it is not an array failure or an internal representation error.

The Wasm backend associates each private callable-table index with its target's
`CallableAbiId`. Before any indirect call consumes operands, generated code
compares that identifier with the call site's expected identifier. This guard
is necessary because Wasm value types cannot distinguish equal representations
with different cleanup contracts. Ordinary function types, runtime-import
adapter types, `call_indirect`, and `return_call_indirect` types are then
generated from the same `CallableAbi` description, so Wasm's native type check
also enforces the representational portion of the identity.

## Persistence

The current-only bytecode format places the counted Callable ABI table after
the entry and initializer identifiers and before the Function table.
`CallValue` and `TailCallValue` encode a `CallableAbiId` immediately after the
callable slot. This incompatible change raises the enclosing linked-program
artifact schema from 9 to 10. No legacy decoder is retained under ADR 0116.

## Consequences

- Callable ABI agreement has one description shared by verification and both
  execution backends.
- Physical equality includes ownership cleanup, not only Wasm value types.
- Dynamic target validation happens before ownership transfer.
- Function context kind remains an independent invariant.
- Call sites no longer reconstruct ABI identity from local slot syntax.
- ADR 0087's trusted call-shape decision and ADR 0128's absence of a callable
  signature table are superseded.
