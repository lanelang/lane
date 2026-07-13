# Typed nominal data layouts

Lane nominal data objects separate semantic constructor discrimination from physical layout identity. The common ARC object header contains only `ref_count` and `LayoutId`. The first word of a data object's payload is a dense `constructor_tag:u32` scoped to the owning nominal data type. Pattern decision-tree lowering loads this local tag into an `I32 + Trivial` slot and may select a dense `switch_tag` edge rather than comparing `LayoutId` or consulting Buslane constructor identities.

`LayoutId` identifies runtime allocation and destructor behavior. A separate zero-based `ObjectShapeId` selecting a Data shape identifies the static constructor schema: local tag, stored generic witnesses, and ordered field representations and cleanup categories. The interpreter and Wasm backend compute field offsets from canonical representation sizes and alignments rather than reading raw offsets from bytecode instructions. V1 linker recipe deduplication assigns one Data LayoutId to each used Data Object Shape.

Representation-polymorphic fields occupy `i64` erased storage. A data object also stores the hidden `LayoutId` witnesses required to retain, release, or destroy those fields after the constructing call has returned. Data Object Shape metadata associates each erased field with its stored witness ordinal. Offsets are deterministically computed from the common header, constructor tag, witness schema, field representations, and alignment.

Existential constructor type identities are erased after type checking. Their Type-kind parameters nevertheless contribute minimal stored LayoutId witnesses because an opened binder may require representation or ARC behavior even when no payload field directly has that binder. Stored witness order is owner Type-kind parameters in owner declaration order followed by constructor-hidden Type-kind parameters in constructor declaration order. Effect-kind parameters contribute no runtime witness and remain fully erased.

Data construction consumes its owned field operands. Reference-bearing fields transfer ownership into the new object without implicit retain, while compiler-inserted retain-copies establish any additional owners needed elsewhere. Stored generic witnesses are trivial `i32` values copied into the payload. The layout destructor releases every owned field according to its static representation or stored generic witness.

A constructor with no user fields and no generic layout witness that must survive for destruction uses an image-owned singleton object. Its header contains the immortal reference-count sentinel, so construction returns the same reference without allocation or ARC updates. Lane exposes no object pointer identity, making this sharing unobservable.

Consequences:

- Constructor tags are dense within a nominal data type, not image-global.
- Pattern matching dispatches on the payload constructor tag.
- Bytecode tag switches are individual decision-tree nodes, not complete patterns.
- `LayoutId` describes runtime allocation and destruction, not static field shape.
- A Data `ObjectShapeId` supplies static constructor field schema and offset computation.
- Fields use typed erased representations and alignment-specific offsets.
- Generic fields use `i64` storage plus stored layout witnesses where required.
- Data construction consumes owned field values.
- Eligible nullary constructors use immortal image-owned singleton objects.
- Buslane constructor identities and names do not enter the runtime ABI.
