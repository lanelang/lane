# Bytecode slot representation and cleanup

Every LoisVM v1 physical slot has one representation tag and one cleanup category for its entire lifetime. The representation tags are exactly `I32`, `I64`, and `F64`. `Unit` has no slot representation. A returning call encodes `Option<SlotId>` for its result: non-`Unit` calls use `Some(destination)`, while `Unit` calls use `None` and carry no destination identifier.

Their v1 wire values are I32 `0x01`, I64 `0x02`, and F64 `0x03`. Cleanup wire values are Trivial `0x01`, OwnedRef `0x02`, OwnedCallable `0x03`, and OwnedErased `0x04`. Zero and `0xFF` are invalid in both namespaces.

A bytecode body records one `result_tag:u8` in the closed domain `Unit`, `I32`, `I64`, and `F64`. `Unit` occupies no result slot. The descriptor does not duplicate cleanup behavior; the source slot of each return and the destination slot of each returning call carry their own cleanup categories under the trusted bytecode contract.

Cleanup categories describe runtime cleanup behavior, not Lane source ownership, compiler-private borrowing, or implicit retain behavior. V1 defines four categories:

- `Trivial` performs no cleanup.
- `OwnedRef` releases an `I32` Lane object reference through its common header and layout descriptor.
- `OwnedCallable` releases the nonzero environment offset packed into an `I64` callable.
- `OwnedErased` releases an `I64` erased payload through an associated layout witness.

`retain_copy(destination, source)` uses the destination cleanup category to establish the new owner. For ordinary owned duplication, source and destination have the same cleanup category. For borrow promotion, an equal-representation `Trivial` source may feed an owned destination. `release(slot)` dispatches through the slot's owned cleanup category. Emitting retain-copy into `Trivial` or releasing `Trivial` is invalid trusted bytecode.

`OwnedRef` pairs only with `I32`. The zero reference is permitted only where the ABI defines an absent environment and is a release no-op. Image-owned references use the immortal count and are also retain/release no-ops through the normal header path; no separate `StaticRef` category exists.

`OwnedCallable` and `OwnedErased` pair only with `I64`. An `OwnedCallable` ignores the low function-index half during cleanup and releases only a nonzero high environment half. An `OwnedErased` slot stores a companion `SlotId` in its slot metadata. The companion must have representation `I32`, cleanup category `Trivial`, and contain the applicable `LayoutId`. It remains unchanged for the complete live interval of the owned payload. Slot reuse may combine erased owners only when it preserves this companion relationship.

An `OwnedErased` payload always uses that cleanup category even when its LayoutId describes a no-op immediate such as Int, Bool, or Double. One immutable witness slot may be the companion of multiple simultaneously live erased payloads. The witness slot becomes reusable only after every such payload has been consumed.

The serialized slot table permits exactly `I32 + Trivial`, `I64 + Trivial`, `F64 + Trivial`, `I32 + OwnedRef`, `I64 + OwnedCallable`, and `I64 + OwnedErased`. Every slot entry stores `representation_tag:u8` and `cleanup_tag:u8`; only `OwnedErased` appends its companion `SlotId:u32le`. Unknown tags, illegal combinations, or an `OwnedErased` companion that does not name an `I32 + Trivial` slot make image loading fail.

There is no serialized `Borrowed` cleanup category and no bytecode borrow region. Compiler-private block-local non-owning reference values may be allocated to `Trivial` slots because they require no cleanup. Trusted lowering ensures such values never become block arguments, call arguments, return values, captures, or stored fields without first being promoted to an owned value.

The interpreter may still store tagged `VMValue` values internally. Slot representation and cleanup metadata exists to make the execution image sufficient for typed Wasm locals and precise fatal-exception cleanup without recovering source types or compiler ownership analysis.

Consequences:

- V1 slots use only `I32`, `I64`, and `F64` representations.
- Representation and cleanup categories have explicit v1 wire values.
- `Unit` occupies no slot and Unit calls have no destination identifier.
- Function result descriptors use one Unit/I32/I64/F64 tag without cleanup metadata.
- Cleanup categories are `Trivial`, `OwnedRef`, `OwnedCallable`, and `OwnedErased`.
- Cleanup metadata is distinct from source ownership and compiler borrow analysis.
- Static references require no separate cleanup category.
- Callable cleanup releases only the packed environment.
- Erased cleanup uses a stable trivial layout-witness companion slot.
- Only `OwnedErased` slot records append a companion SlotId.
- Loading rejects unknown or illegal representation-cleanup metadata.
- No borrow region or `Borrowed` category is serialized.
- Physical slot reuse preserves representation, cleanup, and companion compatibility.
