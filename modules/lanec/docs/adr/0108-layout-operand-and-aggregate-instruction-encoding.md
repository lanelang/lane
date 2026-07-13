# Layout operand and aggregate instruction encoding

Every LoisVM v1 `LayoutOperand` has the exact form `layout_operand_tag:u8` followed by `payload:u32le`. The tag namespace is Immediate `0x01` and Witness `0x02`; `0x00`, `0xFF`, and every other value are invalid. An Immediate payload is a nonzero LayoutId. A Witness payload is the SlotId of an `I32 + Trivial` layout witness. The operand carries no representation, cleanup, ObjectShapeId, ownership, or borrowing flag.

ObjectShapeId operands are direct zero-based `u32le` values rather than OptionalSlot or plus-one encodings.

The complete `make_data` operands are:

1. `destination_slot_id:u32le`
2. `data_shape_id:u32le`
3. one LayoutOperand
4. `witness_count:u32le` and that many witness SlotIds
5. `field_count:u32le` and that many field SlotIds

The complete `make_env` operands are destination SlotId, Environment ObjectShapeId, LayoutOperand, counted witness SlotId array, then counted capture SlotId array. Both instructions serialize array counts even though their selected shapes declare the expected counts. This keeps function bodies independently framed before the later Object Shape table is parsed; count agreement remains a trusted compiler invariant.

Construction reads witness and Trivial member operands non-consumingly. Owned fields and captures transfer ownership into the new object. The destination is a logically dead `I32 + OwnedRef` slot. Execution initializes every observable header, witness, and member word before publishing the destination.

`load_tag` encodes destination SlotId then object SlotId. It reads the Data object non-consumingly and writes an `I32 + Trivial` destination.

`load_object_witness` encodes destination SlotId, ObjectShapeId, object source SlotId, then `witness_ordinal:u32le`. It reads either a Data or Environment object non-consumingly and copies the selected stored LayoutId into an `I32 + Trivial` destination. The ObjectShapeId fixes the static witness layout; the instruction does not recover a source type, compare types, or expose a backend byte offset.

Every ProjectionResult contains `value_destination_slot_id:u32le` followed by `witness_destination_slot_plus_one:u32le`. Zero means no witness destination; nonzero N means `SlotId = N - 1`. Both destinations are logically dead. An erased member requires a nonzero `I32 + Trivial` witness destination, while a non-erased member uses zero, under the trusted-bytecode contract.

`borrow_field` encodes Data ObjectShapeId, object source SlotId, `field_index:u32le`, then one ProjectionResult. `borrow_capture` encodes Environment ObjectShapeId, environment source SlotId, `capture_index:u32le`, then one ProjectionResult. Both preserve source-object ownership. Immediate members are copied; reference-bearing members produce block-local non-owning results.

`consume_fields` encodes Data ObjectShapeId, object source SlotId, `selected_count:u32le`, then exactly that many field-index and ProjectionResult pairs. `consume_captures` uses the same form with Environment shape and capture indices. Zero selected results are permitted. Indices in either instruction are strictly increasing and therefore cannot repeat. Both consume one source-object owner and produce owned selected results under equivalent unique-move or shared-retain behavior.

Decoding checks the LayoutOperand tag, rejects zero Immediate LayoutId, checks counted-array framing, and consumes each fixed instruction shape completely. ObjectShapeId range and variant, SlotId range and metadata, array-count agreement, member indices, LayoutId-shape compatibility, destination compatibility, and ownership remain trusted compiler invariants rather than load-time semantic verification.

Consequences:

- Layout operands have one tagged five-byte wire form.
- Immediate and witness layouts have explicit v1 tag values.
- ObjectShapeId operands remain direct zero-based integers.
- Data and Environment construction have symmetric counted operand arrays.
- Redundant construction counts preserve local function-body framing.
- Construction reads Trivial values and consumes owned members.
- Projection results use the canonical OptionalSlot encoding for witnesses.
- Borrowing projections preserve their source object.
- Consuming projections permit zero results and use canonical increasing indices.
- Aggregate instruction semantics expose no raw byte offsets or backend memory operations.
- Independent object-witness loads expose only representation and ARC metadata.
- Cross-record aggregate agreement remains trusted rather than load-verified.
