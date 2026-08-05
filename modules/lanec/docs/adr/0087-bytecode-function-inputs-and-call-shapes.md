# Bytecode function inputs and call shapes

The result-descriptor portions of this historical ADR are superseded by ADR
0128. Its trusted, call-site-derived callable-shape decision is superseded by
ADR 0129. Function inputs and context-kind decisions below remain historical
background for the current model.

A LoisVM bytecode body explicitly lists its initial frame slots in three groups: optional closure environment, representation-evidence inputs, and user arguments. `environment_slot_plus_one:u32le` is zero for no environment and N for `SlotId = N - 1`; a nonzero environment identifies an `I32 + OwnedRef` slot. Evidence inputs use `witness_count:u32le` followed by ordered SlotIds; the current Callable ABI records each slot's complete `ValueAbi`, so entries may be trivial `LayoutValue` values or owned `LayoutConstructorValue` callables. User inputs use `user_parameter_count:u32le` followed by ordered SlotIds whose representations and cleanup categories come from the slot table. All environment, evidence, and user-input SlotIds are pairwise distinct.

Function inputs are not block parameters. They are initialized by function entry before control reaches fixed entry `BlockId = 0`. The entry block therefore has an empty parameter list. Other blocks may declare parameters and receive their values through ordinary parallel edge transfer.

The function body records one `result_tag:u8` in the closed domain Unit `0x01`, I32 `0x02`, I64 `0x03`, and F64 `0x04`. Zero and `0xFF` are invalid. `Unit` has no result slot; the other tags define the physical result type. Cleanup is not duplicated in the function result descriptor. Each return source slot and call destination slot already carries the applicable cleanup category, and agreement is a trusted-bytecode invariant.

A returning `call_direct` instruction encodes target `FunctionId`,
`environment_slot_plus_one:u32le`, counted witness SlotId array, counted
user-argument SlotId array, then `destination_slot_plus_one:u32le`. Zero
environment denotes a capture-free target, for which Wasm lowering supplies
canonical `env = 0`. Under ADR 0129, a returning `call_value` additionally
encodes a `CallableAbiId` after its callable SlotId.

Zero destination denotes Unit; a nonzero value N names dead destination
`SlotId = N - 1`. Witnesses and Trivial user arguments are non-consuming reads.
Owned user arguments transfer into the callee. A direct call also consumes its
nonzero environment, while a value call consumes its callable. The Callable ABI
table owns indirect arity, parameter shape, and result identity; context kind
remains owned by the function target.

LoisVM serializes an image-global Callable ABI table. The Wasm backend obtains
both ordinary function types and indirect-call types from this table, prepends
canonical `env:i32`, and interns the complete type in the Wasm type section.

Runtime-import entries continue to store no separate representation list; their
`RuntimeValueKind` signature projects to the common Callable ABI. The verifier
checks static call-site shape. The interpreter validates the dynamically
selected target before consuming operands, while Wasm uses its normal
indirect-call type check over the same ABI-derived type.

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
- Bytecode contains one canonical Callable ABI table.
- Wasm function and indirect-call types are derived from the same descriptions.
- Runtime-import adapter types project from `RuntimeValueKind` into that table.
- Dynamic call-shape agreement is verified by each execution backend.
