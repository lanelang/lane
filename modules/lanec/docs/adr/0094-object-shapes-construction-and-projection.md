# Object shapes, construction, and projection

LoisVM separates static fixed-size object shape from runtime layout behavior. Zero-based `ObjectShapeId` indexes an image-global table of tagged Object Shapes. A Data shape records local constructor tag, stored generic-witness count, and ordered user-field schemas. An Environment shape records stored generic-witness count and ordered capture schemas without a constructor tag. Each member schema contains representation tag, cleanup category, and optional stored-witness ordinal for an erased member. Shapes contain no object alignment or computed raw byte offsets.

`LayoutId` remains the runtime identity used for allocation size, retain/release behavior, destruction, and the common object header. An Object Shape gives the interpreter and Wasm backend enough static information to compute field or capture offsets. V1 linker deduplication assigns one Data or Environment Layout Recipe and LayoutId to each used Object Shape. Strings and other variable-size special objects remain outside the Object Shape table. The fixed 32-byte materialized Wasm layout descriptor is a runtime projection and does not embed Object Shape metadata.

Instructions that allocate by runtime layout use `layout_operand_tag:u8 + payload:u32le`. Immediate `0x01` carries a nonzero LayoutId; Witness `0x02` carries an `I32 + Trivial` witness SlotId. Zero, `0xFF`, and unknown tags are invalid. This permits generic construction to receive a runtime derived layout while direct zero-based ObjectShapeId still gives Wasm lowering a compile-time member schema.

`make_data(destination, shape, layout, witnesses, fields)` serializes destination, Data shape, LayoutOperand, counted witness array, then counted field array. The explicit counts preserve instruction framing before the Object Shape table is available. The shape determines payload organization and local constructor tag; the layout operand supplies the header LayoutId and size behavior. The instruction reads Trivial witnesses and fields, consumes owned fields, writes all observable words, and publishes a logically dead `I32 + OwnedRef` destination only after initialization completes.

For generic data, the witness array first contains Type-kind owner arguments and then Type-kind constructor-hidden arguments, each in declaration order. Effect-kind arguments are omitted. Pattern matching reconstructs no source type: a constructor branch maps each hidden Type-kind binder to the corresponding stored LayoutId and leaves hidden Effect-kind binders erased. Default branches open neither kind.

`make_env(destination, shape, layout, witnesses, captures)` uses the symmetric destination, Environment shape, LayoutOperand, counted witness array, and counted capture array form. The instruction reads Trivial witnesses and captures, consumes owned captures, writes the complete tagless payload, and publishes a logically dead `I32 + OwnedRef` destination only after initialization completes.

`load_tag(destination, object)` reads a data object's local constructor tag non-consumingly into `I32 + Trivial`. Pattern decision-tree lowering selects a constructor before any data-field projection.

`load_object_witness(destination, shape, object, witness_ordinal)` non-consumingly copies one stored LayoutId from either a Data or Environment object into `I32 + Trivial`. This supports opened representation-polymorphic binders even when no projected member directly carries that binder. The source existential type remains erased: the witness controls representation and ARC only and cannot be used for dynamic typecase.

A projection result contains value destination `SlotId:u32le` followed by `witness_destination_slot_plus_one:u32le`. Zero means no witness destination; nonzero N means `SlotId = N - 1`. The witness destination is required for an erased generic member and has `I32 + Trivial`; it receives the stored LayoutId associated with that member.

`borrow_field(shape, object, field_index, result)` preserves data-object ownership. Immediate fields are copied as trivial values. Reference-bearing field payloads enter `Trivial` destinations and remain valid only under the block-local borrow owner. Erased fields also copy their stored witness into the result's witness destination.

`consume_fields(shape, object, selected_results)` consumes one data-object ownership. Selected results are encoded as a possibly empty strictly increasing sequence of field-index and ProjectionResult pairs. A unique object moves selected owned fields, releases unselected owned fields, and frees the shell. A shared object retain-copies selected owned fields, releases the consumed object owner, and leaves other owners valid. Both paths produce equivalent owned results and copy required trivial witnesses.

`borrow_capture(shape, environment, capture_index, result)` preserves environment ownership and returns a block-local borrowed result using the same representation and witness conventions as borrowing data projection. `consume_captures(shape, environment, selected_results)` consumes one environment owner and returns a possibly empty strictly increasing sequence of selected captures as owned results using unique-move or shared-retain execution. Data-field indices and environment-capture indices are local to their selected shape variants.

Trusted lowering guarantees that constructor selection has occurred before data-field projection and that an object's runtime LayoutId is compatible with the supplied shape. Bytecode object instructions never expose wasm32 byte offsets, raw loads, or raw stores.

Consequences:

- ObjectShapeId and LayoutId have distinct static and runtime roles.
- Object Shapes are tagged Data or Environment schemas.
- Data shapes contain a local constructor tag; Environment shapes do not.
- Object Shapes contain member schemas but no raw byte offsets.
- Variable-size special objects remain outside the Object Shape table.
- Generic allocation combines static shape with a runtime layout operand.
- Owner witnesses precede constructor-hidden witnesses in declaration order.
- Hidden Effect-kind parameters remain fully erased.
- Construction operand arrays carry explicit counts for framing.
- Construction consumes owned members and copies trivial witnesses.
- Tag loading is non-consuming and applies only to data objects.
- Stored witnesses may be loaded independently without reifying erased types.
- Projection results explicitly return erased-member witnesses.
- Borrowing data projection produces block-local non-owning reference payloads.
- Consuming data projection preserves unique/shared ownership equivalence.
- Borrowing and consuming capture projection use the same ownership distinction.
- Member indices are shape-local.
- Consuming projection indices are strictly increasing and may be empty.
- Wasm lowering computes offsets without exposing machine memory operations in bytecode.
