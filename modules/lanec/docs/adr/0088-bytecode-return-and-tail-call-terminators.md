# Bytecode return and tail-call terminators

The `return` terminator encodes only `source_slot_plus_one:u32le`. Zero returns Unit. Nonzero N consumes source `SlotId = N - 1` and transfers one non-Unit result to the caller. The source representation must equal the function body's result descriptor.

Normal return performs no implicit frame traversal or cleanup sweep. Compiler ARC insertion emits explicit releases for every owned slot not transferred as the result. Reaching `return` with another current-frame owner still live is invalid trusted bytecode.

`tail_call_direct` encodes target `FunctionId`, `environment_slot_plus_one:u32le`, counted layout-witness SlotId array, and counted user-argument SlotId array. `tail_call_value` encodes callable SlotId, counted witness array, and counted user-argument array. Neither terminator has a destination. Witnesses and Trivial user arguments are non-consuming reads. The direct form consumes any supplied environment and owned user arguments. The value form consumes the callable, obtains and transfers its environment through consuming projection, and consumes owned user arguments.

Before either tail terminator, explicit release instructions dispose of every current-frame owner not transferred into the replacement callee. The tail target's result representation must equal the current function result descriptor. The replaced frame is therefore ownership-empty at the transfer point.

The Wasm backend lowers `tail_call_direct` to `return_call` and `tail_call_value` to `return_call_indirect`. An indirect-tail type is derived from the witness and user argument slot representations plus the current function result descriptor, then prepended with canonical `env:i32`. Wasm validation independently enforces the tail target's physical result compatibility.

Runtime-import entries may also be tail targets. Their arguments and any callable environment transfer under the same callee-owned rule. If a runtime-import adapter fails, it consumes or releases its transferred arguments and throws the private fatal exception. The replaced Lane frame has no remaining ownership and requires no cleanup handler after the tail transfer.

Consequences:

- `return` uses zero or `SlotId + 1` and consumes a non-Unit result owner.
- Normal exits never perform implicit frame cleanup.
- Direct tail calls carry optional explicit environments and no destination.
- Value tail calls consume their callable and carry no destination.
- Tail argument arrays are explicitly counted and match returning-call order.
- Explicit releases remove every untransferred owner before exit.
- Tail target results match the current function result descriptor.
- Direct and value tail calls lower to standard Wasm tail-call instructions.
- Indirect-tail result types come from the enclosing function descriptor.
- Runtime-import tail failure begins cleanup in the adapter, not the replaced frame.
