# Canonical Object Shape encoding

After the Layout Recipe table, LoisVM bytecode stores `object_shape_count:u32le` and that many Object Shape entries. Table position is the zero-based `ObjectShapeId`; a zero count is permitted. Each entry begins with `shape_tag:u8`: Data is `0x01`, and Environment is `0x02`.

A Data entry stores `constructor_tag:u32le`, `stored_witness_count:u32le`, `member_count:u32le`, and ordered field schemas. An Environment entry omits constructor tag and stores the same counts followed by ordered capture schemas. Shapes do not serialize object alignment or member offsets. All ARC objects are eight-byte aligned, and member size and alignment derive from representation.

Every member schema contains `representation_tag:u8`, `cleanup_tag:u8`, and `witness_ordinal_plus_one:u32le`. Zero means no stored witness; nonzero N selects ordinal `N - 1`. Trivial permits I32, I64, or F64 and no witness. OwnedRef requires I32 and no witness. OwnedCallable requires I64 and no witness. OwnedErased requires I64 and one in-range witness ordinal.

Canonical Data layout starts with the common eight-byte header, then `constructor_tag:u32`, then `stored_witness_count` contiguous `u32 LayoutId` values in ordinal order. Canonical Environment layout starts with the header and then the same witness array without a tag. Members follow in schema order. I32 has size and alignment four; I64 and F64 have size and alignment eight. Each member is aligned before placement, and total allocation size rounds up to eight bytes.

`make_data(destination, shape, layout, witnesses, fields)` no longer carries a constructor-tag operand. The Data shape supplies that value. `make_env` similarly follows its Environment shape. Both instructions serialize explicit witness and member counts for local framing; arrays match shape order and counts under the trusted contract. Field and capture projection indices address the member array directly; an OwnedErased projection obtains its companion through the schema's witness ordinal.

ObjectShapeId is not observable. The linker deduplicates exact canonical shape encodings. It sorts Data shapes lexicographically by canonical encoded bytes, followed by Environment shapes sorted the same way. Different source types may therefore share one ObjectShapeId when their complete runtime shape is identical.

Decoding rejects unknown shape tags and malformed primitive fields. Loading rejects illegal representation/cleanup combinations, missing or unexpected witness ordinals, and out-of-range witness ordinals. Bytecode exposes no raw offsets or alignment overrides.

Consequences:

- ObjectShapeId is a zero-based canonical table position.
- Data and Environment are the only v1 shape variants.
- Their wire tags are Data `0x01` and Environment `0x02`.
- Object alignment and member offsets are derived rather than serialized.
- Data stores a local constructor tag; Environment does not.
- Stored witnesses are contiguous u32 values in ordinal order.
- Member schemas have fixed representation, cleanup, and witness fields.
- Canonical placement uses representation-specific size and alignment.
- `make_data` derives constructor tag from its shape.
- Projection indices address shape-local members.
- Exact runtime shapes are deduplicated and deterministically sorted.
- Invalid cleanup combinations and witness references fail loading.
