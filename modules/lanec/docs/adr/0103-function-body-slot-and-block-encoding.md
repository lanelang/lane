# Function body, slot, and block encoding

Each BytecodeBody function-table entry begins with `body_length:u32le`. The length covers the complete body payload after the length field, and the body decoder must consume exactly that slice. The payload order is slot table, function inputs, result descriptor, then block table. No entry `BlockId` is serialized because `BlockId = 0` is always the function entry.

The slot table begins with `slot_count:u32le`; zero slots are permitted. Table position defines the zero-based `SlotId`. Each slot stores `representation_tag:u8` followed by `cleanup_tag:u8`. Only `OwnedErased` appends `companion_slot_id:u32le`.

V1 permits exactly these representation and cleanup combinations:

- `I32 + Trivial`
- `I64 + Trivial`
- `F64 + Trivial`
- `I32 + OwnedRef`
- `I64 + OwnedCallable`
- `I64 + OwnedErased`

An `OwnedErased` companion must identify an `I32 + Trivial` slot. Unknown tags, illegal representation-cleanup combinations, a missing companion, or an invalid companion kind make image loading fail. Full companion liveness remains a trusted compiler invariant.

Function inputs follow the slot table. `environment_slot_plus_one:u32le` uses zero for no environment and `N` for `SlotId = N - 1`. A nonzero environment must identify an `I32 + OwnedRef` slot. Witness inputs are encoded as `witness_count:u32le` followed by that many `SlotId:u32le` values, each naming an `I32 + Trivial` slot. User inputs are encoded as `user_parameter_count:u32le` followed by that many `SlotId:u32le` values; their representations and cleanup categories come from the slot table. Environment, witness, and user-input SlotIds must be pairwise distinct.

The result descriptor is one `result_tag:u8` with Unit `0x01`, I32 `0x02`, I64 `0x03`, and F64 `0x04`. Zero and `0xFF` are invalid. `Unit` carries no SlotId. The descriptor does not serialize cleanup because the return source and returning-call destination slots provide it under the trusted-bytecode contract.

The block table begins with nonzero `block_count:u32le`; table position defines the zero-based `BlockId`, and `BlockId = 0` is the entry block. Each block stores `parameter_count:u32le`, that many ordered parameter `SlotId:u32le` values, `instruction_count:u32le`, that many fixed-shape instructions, then exactly one fixed-shape terminator. Blocks have no byte length and never fall through to the next table entry.

The entry block has zero parameters. Parameters must be unique within one block, but the same physical slot may appear as a parameter in different blocks. Unknown tags and locally illegal slot metadata fail image loading. CFG targets, edge arity, slot data flow, ownership, call arity, and cross-record semantic agreement remain trusted compiler invariants rather than full bytecode verification.

Consequences:

- One function-body length provides local framing and complete-consumption checks.
- The body has one canonical field order and no serialized entry-block identifier.
- Slot and block identifiers are dense zero-based table positions.
- Slot zero and an empty slot table remain representable without sentinel conflicts.
- Optional environment encoding uses one-based `SlotId` plus zero as `None`.
- Slot metadata has a compact fixed prefix and only erased owners carry a companion operand.
- The loader rejects unknown tags and locally illegal representation-cleanup metadata.
- Function inputs are explicit, ordered, and pairwise distinct initial frame slots.
- Result representation uses one closed tag rather than an optional nested record.
- Every function has at least one block and enters `BlockId = 0`.
- Every block is count-delimited and ends in exactly one terminator.
- Bytecode loading remains strict framing validation rather than a full semantic verifier.
