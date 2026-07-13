# Structured bytecode CFG to Wasm

LoisVM serializes a structured control-flow graph rather than a stream whose branches address instruction bytes. Each function contains a nonempty ordered block table and a slot representation table. Block-table order implicitly defines zero-based `BlockId` values, and `BlockId = 0` is always the entry, so no separate entry identifier is serialized. Each block stores its ordered parameter-slot list, an instruction count and instruction array, followed by one explicit terminator. Operands reference `SlotId`; jumps and branches reference `BlockId` and carry ordered edge argument slots. No portable bytecode branch contains a byte offset, relative PC, or Wasm nesting depth.

An EdgeRecord contains target `BlockId`, a counted ordered argument SlotId array, and no backend branch metadata. `jump` contains one edge. `branch_bool` contains one `I32 + Trivial` condition slot and two complete edges. `switch_tag` contains one `I32 + Trivial` constructor-tag slot, a possibly empty dense case-edge array indexed by unsigned local constructor tag, and one mandatory default edge. Blocks never fall through to the next serialized block.

`switch_tag` represents one discriminator node produced by pattern decision-tree lowering. It does not preserve source patterns or implement nested pattern matching as one flat VM operation. An exhaustive switch may route its impossible default to a block ending in the zero-operand `unreachable` terminator.

Function inputs are initialized frame slots rather than entry-block parameters. A bytecode body separately lists an optional environment slot, ordered representation-witness slots, and ordered user-argument slots. Fixed entry `BlockId = 0` declares no block parameters; parameters on other blocks continue to receive parallel edge transfers.

Slot-table order implicitly defines zero-based `SlotId` values. Each slot entry records one fixed scalar representation tag and cleanup-category tag. V1 representation tags are `I32`, `I64`, and `F64`; `Unit` occupies no slot. Physical slot allocation may reuse a slot only for compatible logical values. The metadata contains representation and cleanup information needed by typed Wasm lowering and fatal unwinding, not complete Lane source types or compiler-private borrow regions. `loisvm/interp` may continue storing tagged VM values in its slot array.

V1 cleanup categories are `Trivial`, `OwnedRef`, `OwnedCallable`, and `OwnedErased`. `OwnedRef` pairs only with `I32`. `OwnedCallable` and `OwnedErased` pair only with `I64`. An `OwnedErased` slot additionally names an `I32 + Trivial` layout-witness `SlotId`; that witness remains unchanged while the owned erased payload is live. A block-local non-owning reference temporary uses `Trivial`, but trusted lowering prevents it from crossing a block, call, return, or heap-storage boundary.

Each serialized function body is prefixed by its `u32le` byte length and must be consumed completely. Blocks do not carry separate byte lengths because their parameter and instruction counts plus the fixed-shape terminator determine their boundaries. Instruction and terminator tags occupy separate `u8` domains; each tag fixes its complete operand sequence, and individual instructions carry no length prefix.

The Wasm backend maps each bytecode slot to a typed Wasm local by default rather than allocating a linear-memory frame cell. Block edge arguments retain bytecode parallel-transfer semantics. Trivial sources may repeat, while owned sources may not repeat without prior retain-copy. The backend uses temporary locals where needed to avoid clobbering cycles, swaps, duplicated Trivial sources, and other overlapping assignments before entering the target block.

Reducible bytecode CFGs are restructured into nested Wasm `block`, `loop`, and `if` control. Irreducible CFGs remain valid LoisVM input and do not cause backend rejection. The fallback emits a dispatcher state local inside a Wasm `loop`, with `br_table` selecting the next bytecode block. The backend may use the same fallback selectively for CFG regions when that is simpler than whole-function dispatch.

Although the Lane Wasm profile includes Multi-value, canonical v1 CFG lowering does not require Wasm block parameters to mirror LoisVM block parameters. Typed locals and explicit parallel transfer are the stable mapping. Multi-value block parameters may be introduced later as a local optimization without changing serialized bytecode.

Consequences:

- Bytecode branches remain stable when instruction encodings change size.
- Decoders and bytecode rewrites do not recalculate branch displacements.
- Every function carries a nonempty ordered block table and slot representation table.
- Block zero is the fixed entry and has no serialized entry identifier.
- Function inputs are separate from block parameters, and the entry block has none.
- Function bodies are byte-length-delimited and completely consumed.
- Every block has an instruction array and explicit terminator.
- Jump, boolean branch, and tag switch use complete explicit edge records.
- Tag switch is a decision-tree node rather than a pattern-match instruction.
- Block-table order never implies control-flow fallthrough.
- Compiler-proven impossible blocks may end in `unreachable`.
- Block and slot IDs are zero-based ordered-table positions.
- Instruction and terminator tags use separate fixed-shape `u8` domains.
- Slot reuse is restricted to compatible erased representation and ownership categories.
- V1 slot representations are `I32`, `I64`, and `F64`; Unit has no slot.
- Cleanup categories are runtime metadata, not serialized borrow regions.
- Owned erased slots name stable trivial layout-witness slots.
- Wasm lowering uses typed locals rather than a mandatory linear-memory frame.
- Parallel edge transfer uses temporary locals when assignments overlap.
- Reducible CFGs use structured Wasm control.
- Irreducible CFGs use a `loop` and `br_table` dispatcher fallback.
- Multi-value block parameters are optional optimization rather than canonical ABI.
