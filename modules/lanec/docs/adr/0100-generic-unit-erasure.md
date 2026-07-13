# Generic Unit erasure

Natural Lane Unit occupies no slot and produces no Wasm value. A representation-polymorphic value must nevertheless keep a fixed `i64` ABI independent of its runtime LayoutId. Unit therefore uses canonical erased payload `i64 0` together with a nonzero static Unit LayoutId.

The Unit layout descriptor has no-op retain and release behavior and does not describe a heap object. Generic slots still use `I64 + OwnedErased`, and generic data fields or closure captures instantiated with Unit still reserve the erased payload and stored witness required by their Object Shape. This keeps generic object offsets and destructor recipes independent of instantiation.

`erase_unit(destination)` has no source operand. Its logically dead destination is `I64 + OwnedErased`, its companion must already contain the Unit LayoutId, and execution writes canonical zero. `unerase_unit(source)` has no destination operand; it consumes one erased Unit payload and produces natural no-slot Unit.

Trusted bytecode guarantees that an erased Unit payload is zero and that its companion is the Unit LayoutId. LoisVM performs no dynamic payload check. The binary encoding of `erase_unit` contains only destination SlotId, while `unerase_unit` contains only source SlotId.

A natural Unit argument is erased explicitly before entering a generic parameter. A generic result used in natural Unit context is explicitly consumed by `unerase_unit`. Call instructions do not add or remove payload operands based on runtime witnesses.

Consequences:

- Natural Unit remains slotless.
- Representation-polymorphic Unit occupies canonical `i64 0`.
- Unit has a nonzero static no-op LayoutId.
- Generic Unit fields and captures retain fixed erased storage.
- `erase_unit` produces an erased payload without a source slot.
- `unerase_unit` consumes an erased payload without a destination slot.
- Payload and witness compatibility remain trusted compiler invariants.
- Generic call signatures remain independent of runtime type instantiation.
