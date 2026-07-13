# Bytecode function inputs and call shapes

A LoisVM bytecode body explicitly lists its initial frame slots in three groups: optional closure environment, representation layout witnesses, and user arguments. `environment_slot_plus_one:u32le` is zero for no environment and N for `SlotId = N - 1`; a nonzero environment identifies an `I32 + OwnedRef` slot. Witness inputs use `witness_count:u32le` followed by ordered SlotIds, each identifying an `I32 + Trivial` slot. User inputs use `user_parameter_count:u32le` followed by ordered SlotIds whose representations and cleanup categories come from the slot table. All environment, witness, and user-input SlotIds are pairwise distinct.

Function inputs are not block parameters. They are initialized by function entry before control reaches fixed entry `BlockId = 0`. The entry block therefore has an empty parameter list. Other blocks may declare parameters and receive their values through ordinary parallel edge transfer.

The function body records one `result_tag:u8` in the closed domain Unit `0x01`, I32 `0x02`, I64 `0x03`, and F64 `0x04`. Zero and `0xFF` are invalid. `Unit` has no result slot; the other tags define the physical result type. Cleanup is not duplicated in the function result descriptor. Each return source slot and call destination slot already carries the applicable cleanup category, and agreement is a trusted-bytecode invariant.

A returning `call_direct` instruction encodes target `FunctionId`, `environment_slot_plus_one:u32le`, counted witness SlotId array, counted user-argument SlotId array, then `destination_slot_plus_one:u32le`. Zero environment denotes a capture-free target, for which Wasm lowering supplies canonical `env = 0`. A returning `call_value` encodes callable SlotId, counted witness array, counted user-argument array, then destination OptionalSlot. Consuming callable projection obtains and transfers the environment internally.

Zero destination denotes Unit; a nonzero value N names dead destination `SlotId = N - 1`. Witnesses and Trivial user arguments are non-consuming reads. Owned user arguments transfer into the callee. A direct call also consumes its nonzero environment, while a value call consumes its callable. Calls carry no duplicated arity, representation, cleanup, context-kind, result, or call-shape metadata.

LoisVM does not serialize an image-global `CallShapeId` table. For `call_indirect`, the Wasm backend derives the exact type from the call site's ordered witness and user argument slot representation tags plus its optional destination representation. For `return_call_indirect`, the current function result descriptor supplies the result representation because the tail terminator has no destination. The backend then prepends canonical `env:i32` and interns the complete derived type in the Wasm type section.

Runtime-import entries continue to store no per-parameter representation list. Their generated adapter signatures come from the runtime symbol registry. Trusted lowering guarantees that direct-call operands, callable-value call shapes, bytecode-body input metadata, function results, and registry-derived adapters agree. LoisVM performs no separate dynamic call-shape check; Wasm still performs its normal indirect-call type check.

Consequences:

- Function inputs are explicit initial frame slots.
- Capturing bodies have one owned environment slot; capture-free bodies have none.
- Optional environments encode zero or `SlotId + 1`.
- Layout witnesses precede user parameters and are trivial `I32` slots.
- Environment, witness, and user-input SlotIds are pairwise distinct.
- Entry blocks have no block parameters.
- Function results use one Unit/I32/I64/F64 representation tag.
- Direct calls carry optional explicit environments.
- Value calls obtain environments from callable projection.
- Call environments and destinations use zero or `SlotId + 1`.
- Witness and user argument arrays use explicit `u32le` counts.
- Trivial arguments are read while owned arguments transfer to the callee.
- Bytecode contains no `CallShapeId` table.
- Wasm indirect types are derived from call-site slot metadata and interned.
- Runtime-import adapter types remain registry-derived.
- Call-shape agreement is trusted compiler output rather than VM verification.
