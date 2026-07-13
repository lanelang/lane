# CFG edge and control terminator encoding

Every ordinary LoisVM v1 control-flow destination uses one `EdgeRecord` with the exact wire form `target_block_id:u32le`, `argument_count:u32le`, then exactly that many `argument_slot_id:u32le` values. An empty argument array is valid. The edge carries no representation, cleanup, target-parameter, source-location, or byte-length fields.

The `jump` terminator contains exactly one EdgeRecord. The `branch_bool` terminator contains `condition_slot_id:u32le`, then true EdgeRecord, then false EdgeRecord. The condition is an `I32 + Trivial` non-consuming read.

The `switch_tag` terminator contains `tag_slot_id:u32le`, `case_count:u32le`, exactly that many EdgeRecords in dense tag order, then one mandatory default EdgeRecord. Case edge ordinal N selects local constructor tag N; case tags are not serialized separately. A zero case count is valid and routes every value to the default edge.

The switch tag is an `I32 + Trivial` non-consuming read interpreted as unsigned `u32`. A value less than `case_count` selects the edge at that ordinal. Every other bit pattern selects the default, including bit patterns that represent negative signed `i32` values. Even compiler-proven exhaustive switches encode a default edge, which may target a block ending in `unreachable`.

Control terminators encode no fallthrough, branch-likelihood flag, inversion flag, source constructor identity, sparse case key, instruction offset, or Wasm label depth. Serialized block order has no control-flow meaning beyond defining BlockId.

Only the selected EdgeRecord transfers arguments. Trivial sources are non-consuming reads. Owned sources are consumed into corresponding target parameters. One edge may repeat a Trivial source SlotId, but it may not repeat an owned source SlotId. Lowering must create distinct owners with `retain_copy` before an edge that needs the same logical owner more than once.

Edge transfer is parallel assignment. The interpreter and Wasm lowering must preserve all source values before overwriting any overlapping target slot, including swaps, cycles, repeated Trivial sources, and source-target aliasing.

Decoding checks the terminator tag, primitive framing, counted-array framing, and complete function-body consumption. Target BlockId range, argument SlotId range, edge arity, representation, cleanup, ownership, and target-parameter agreement remain trusted compiler invariants rather than image-load verification.

Consequences:

- Every ordinary destination has one canonical counted EdgeRecord.
- Jump, boolean branch, and tag switch have complete fixed operand orders.
- Dense switch cases omit redundant case tags and always include a default.
- A zero-case switch is a valid default-only dispatch.
- Switch tags use unsigned comparison against case count.
- Branch conditions and switch tags are non-consuming trivial reads.
- Only the selected edge has ownership effects.
- Repeating an owned edge source requires explicit prior retain-copy.
- Parallel transfer preserves swaps and overlapping assignments.
- Bytecode contains no fallthrough or backend-specific branch metadata.
- Edge semantic agreement remains trusted rather than load-verified.
