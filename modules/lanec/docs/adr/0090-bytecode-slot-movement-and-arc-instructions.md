# Bytecode slot movement and ARC instructions

LoisVM v1 has no generic slot-assignment instruction. Every value-producing instruction names a destination whose previous logical value is dead. Assignment never implicitly releases an overwritten value; compiler ARC insertion emits any required release before the destination is reused.

`copy(destination, source)` duplicates bits without consuming the source and is valid only when both slots have the same representation and `Trivial` cleanup category. It cannot duplicate an owned value.

`move(destination, source)` transfers one logical value and any ownership to a dead destination without changing reference counts. Source and destination must have compatible representation, cleanup category, and erased companion relationship. The source becomes logically dead, but the interpreter and Wasm backend need not clear its stale physical bits.

`retain_copy(destination, source)` copies equal-representation bits and establishes one new owned destination. The destination cleanup category selects retain behavior: `OwnedRef` retains the object reference, `OwnedCallable` retains the packed nonzero environment, and `OwnedErased` uses the destination companion layout witness. For ordinary owned duplication, source and destination cleanup categories agree. For borrow promotion, a block-local `Trivial` source may feed the corresponding owned destination. Retain-copy into a `Trivial` destination is invalid trusted bytecode.

`release(slot)` consumes one owned slot. `OwnedRef`, `OwnedCallable`, and `OwnedErased` use their established cleanup paths. Releasing `Trivial` or an already logically dead slot is invalid trusted bytecode. Release does not clear the stale physical bits after consuming the owner.

`OwnedCallable` values never use `copy`. `move` transfers the callable owner, `retain_copy` establishes an additional callable owner, and `release` destroys one callable owner. For the interpreter this applies to the closure shell; for Wasm it applies directly to the packed callable's nonzero environment component.

The binary operand shapes are fixed: copy, move, and retain-copy each encode destination `SlotId` then source `SlotId`; release encodes one `SlotId`. All are ordinary non-terminating instructions.

The Wasm backend lowers bit transfer with typed `local.get` and `local.set`, surrounding retain-copy and release with the required direct or layout-driven ARC helpers. Plain local assignment has no ARC semantics. Backend optimization or Wasmoon may remove redundant moves and balanced retain-copy/release pairs when ownership equivalence is preserved.

Consequences:

- Generic ownership-aware assignment is absent.
- Every destination is logically dead before writing.
- Trivial copy is non-consuming and cannot copy owners.
- Move transfers ownership without reference-count changes.
- Retain-copy fuses owner creation with destination establishment.
- Borrow promotion uses retain-copy from trivial to owned cleanup.
- Release consumes one owned slot and never applies to trivial slots.
- Move and release need not clear stale physical bits.
- Wasm local operations remain ownership-neutral.
- Backend ARC optimization is optional and semantics-preserving.
