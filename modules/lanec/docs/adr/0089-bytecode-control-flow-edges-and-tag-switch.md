# Bytecode control-flow edges and tag switch

Every ordinary bytecode control transfer uses an explicit EdgeRecord containing `target_block_id:u32le`, `argument_count:u32le`, then exactly that many ordered `argument_slot_id:u32le` values. Empty arrays are permitted. Edge records carry no representation, cleanup, target-parameter, source-location, or byte-length fields. Block-table order never implies fallthrough.

The block table begins with nonzero `block_count:u32le`. Table position defines zero-based `BlockId`, and `BlockId = 0` is always the entry block; no entry identifier is serialized. Each block stores a counted ordered parameter-slot list, a counted instruction array, then exactly one terminator. The entry block has no parameters. Parameter SlotIds are unique within one block, while the same physical slot may serve as a parameter in different blocks.

The `jump` terminator stores one edge. `branch_bool` stores one `I32 + Trivial` condition slot followed by true and false edges. The condition is read non-consumingly. No branch stores fallthrough, likelihood, or inversion metadata.

The `switch_tag` terminator stores one `I32 + Trivial` local constructor-tag slot, `case_count:u32le`, exactly that many dense case edges indexed from tag zero, and one mandatory default edge. Zero cases are permitted. The tag is read non-consumingly and interpreted as unsigned `u32`; values greater than or equal to case count select default, including negative signed `i32` bit patterns. `switch_tag` is one discriminator node in a lowered pattern decision tree; it does not preserve source patterns, recursively inspect fields, or replace decision-tree generation with one flat pattern table.

Only the selected edge executes its transfer. Trivial sources are non-consuming reads; owning argument slots are consumed and establish ownership in corresponding target block parameters. Unselected edges have no ownership effect. One edge may repeat a Trivial source but may not repeat an owned source. Explicit `retain_copy` instructions establish additional owners before the terminator. Transfer is parallel, so interpreter and Wasm lowering preserve swaps, cycles, repeated Trivial sources, and overlapping source-target slots. Representation tags, cleanup categories, and erased ownership-companion relationships must agree across each source/target pairing.

LoisVM also defines a zero-operand `unreachable` terminator for compiler-proven impossible paths, including an impossible default from an exhaustive tag switch. Valid trusted bytecode never executes it. The Wasm backend may lower it directly to `unreachable`; if malformed trusted code reaches it, the engine may trap without private fatal-exception cleanup.

The Wasm backend lowers boolean control with structured `if` or `br_if` as appropriate. Dense tag switches preferentially use `br_table`. These choices occur inside the existing CFG-structuring algorithm, including temporary locals for parallel edge transfer and dispatcher fallback for irreducible control flow.

Consequences:

- Every ordinary control transfer carries an explicit edge record.
- Edge records use one counted SlotId array and permit zero arguments.
- Every function has a nonempty block table and enters block zero.
- Block zero has no parameters and needs no serialized entry identifier.
- Parameter slots are unique within a block but reusable across blocks.
- Blocks never fall through according to serialization order.
- Boolean conditions and constructor tags are non-consuming `I32 + Trivial` reads.
- Tag switches contain dense case edges and one default edge.
- Zero-case switches are valid, and tag comparison is unsigned.
- Tag switch remains one node in a pattern decision tree.
- Only the selected edge transfers ownership.
- Duplicate owners on one selected edge require explicit retain-copies.
- Duplicate Trivial sources are permitted; duplicate owned sources are not.
- Selected-edge transfer is parallel.
- Edge representation, cleanup, and companion relationships must match.
- Trusted unreachable paths may trap directly without fatal cleanup unwinding.
- Wasm lowering may use `if`, `br_if`, and `br_table` within CFG structuring.
