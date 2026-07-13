# Effect erasure before bytecode

LoisVM bytecode is effect-erased. Before compiler-private VM CFG lowering or bytecode construction, `lanec` runs `mon-trans`, `open-resolve`, and `monadic-lift`. Their output contains no `perform`, `resume`, or `handle` form and requires no effect-specific LoisVM instruction or runtime dispatch structure.

The effect-erased program uses only ordinary functions, closures, data, calls, and control flow. Reusable continuations may survive as ordinary lifted closure values, but LoisVM does not distinguish those closures from other closures. Proven one-shot continuations may already be direct calls or linear control flow.

External runtime effects are also resolved before the bytecode boundary. They lower to ordinary runtime function or intrinsic calls rather than compact operation identifiers, a runtime operation table, or a LoisVM handler lookup mechanism. Linked bytecode therefore contains no Buslane `OperationId`, handler context, handler frame, handler layout, handler-context ABI, or effect-dispatch cache.

This boundary applies equally to interpretation and Wasm-compiled execution. `loisvm/interp` executes the same effect-erased bytecode that the Wasm compiled tier consumes. Neither tier scans a VM or host stack for handlers, restores effect contexts, or implements source effect semantics independently from compiler lowering.

Consequences:

- Effect semantics belong to pre-bytecode compiler lowering rather than LoisVM.
- LoisVM needs no `perform`, `resume`, or `handle` instruction.
- LoisVM function ABI has no handler-context parameter.
- Bytecode and `.lbp` need no operation identifier or runtime operation table.
- External runtime effects appear as already resolved ordinary runtime calls or intrinsics.
- Continuation closures use the ordinary closure and ARC contracts.
- The exact responsibilities and intermediate invariants of `mon-trans`, `open-resolve`, and `monadic-lift` are compiler-internal design decisions above the bytecode boundary.
