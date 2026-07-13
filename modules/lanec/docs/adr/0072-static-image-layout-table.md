# Static image layout table

Lane stores representation layout recipes in one image-global static layout table. A `LayoutId` is an immediate `u32` index into that table. Portable entries are tagged semantic recipes rather than Wasm descriptors. They belong to the loaded image, remain valid for its lifetime, and are never dynamically allocated, composed, retained, or released.

The Wasm module materializes the table in canonical memory through an active data segment and exposes its base through immutable global `layout_table_base:i32`. `LayoutId = 0` is reserved as invalid or no-layout. Entry address is `layout_table_base + LayoutId * 32`, and generated Lane code never mutates this static region.

V1 recipe variants are Unit, Bool, Int, Double, Callable, String, Data(ObjectShapeId), and Environment(ObjectShapeId). Primitive recipes have no payload; Data and Environment carry their shape identifier. Representation, size, alignment, and retain, release, and destruction behavior are derived from the recipe and shape. This is execution metadata rather than a full Lane type: it does not preserve source names, generic syntax, type equality, reflection, or dynamic typechecking.

Each materialized descriptor is eight-byte-aligned and has a fixed 32-byte layout:

```text
+0  rep_kind:u32
+4  size_kind:u32
+8  size_or_sizer_index:u32
+12 alignment:u32
+16 retain_func_index:u32
+20 release_func_index:u32
+24 destroy_func_index:u32
+28 reserved:u32
```

For fixed-size layouts, the materialized `size_or_sizer_index` stores total allocation size including the common object header. For variable-size layouts, it stores a canonical-table index for a `(object_ref:i32) -> i32` helper returning that total size. Retain and release helpers use `(payload:i64) -> ()`. Destroy helpers use `(object_ref:i32) -> ()`, release owned fields, and do not free the allocation; the release path invokes allocator free afterwards. These derived numbers and helper indices do not appear in portable bytecode.

A fixed-size layout entry records its allocation size directly. A variable-size layout supplies the layout-specific rule needed to compute allocation size from object payload metadata, such as a String byte length. The common object header does not duplicate size information.

A generic function receives the `LayoutId` witnesses needed by its body as hidden parameters. If its implementation needs a derived representation such as the layout of `List[T]`, the compiler supplies the corresponding precomputed derived `LayoutId` as an additional hidden witness. Generic code does not allocate or dynamically compose a new descriptor from the witness for `T`.

A generic heap object stores the `LayoutId` values required to manage its erased fields after the constructing call returns. Its destructor uses those identifiers to find ownership behavior in the image layout table. The loaded image therefore remains alive while any execution value can refer to an object whose destruction depends on its layout table.

For fixed-size ARC objects, `LayoutId` supplies runtime size and ownership behavior but does not provide the backend's static member-schema identity. A separate zero-based `ObjectShapeId` names either a Data shape containing constructor tag and fields or an Environment shape containing captures without a tag. Both variants record stored witnesses and ordered member representations and cleanup. Member alignment follows canonical representation rules, and every object is eight-byte aligned. Linker recipe deduplication gives each Data or Environment shape one LayoutId in v1. Strings and other variable-size special objects remain outside the Object Shape table. A data object's type-local constructor tag remains a separate payload word used by pattern matching and is not replaced by either identifier.

For a closure environment, an Environment Object Shape describes erased capture representations, alignments, stored generic witnesses, and ownership behavior without storing raw offsets. The corresponding runtime layout descriptor supplies allocation and destruction behavior. Environment shapes have no constructor tag and do not contain recursive member-callable backreferences.

Consequences:

- `LayoutId` is an immediate non-owning `u32` value.
- Layout descriptors are static image metadata and do not participate in ARC.
- Portable layout entries are semantic recipes, not materialized Wasm descriptors.
- V1 recipes are primitive, Callable, String, Data, or Environment variants.
- Identical recipes are deduplicated deterministically.
- Generic retain, release, field layout, and destruction consult the layout table.
- Generic objects store the layout identifiers needed by erased owned fields.
- Derived layouts are precomputed and dictionary-passed as hidden witnesses.
- Runtime descriptor allocation and composition are absent from Lane v1.
- Layout entries do not provide full runtime type reflection or dynamic typechecking.
- ObjectShapeId, not LayoutId, provides static data-field and environment-capture schemas.
- Layout descriptors have a fixed 32-byte canonical-memory format.
- Active data segments materialize descriptors during instantiation.
- `LayoutId = 0` is invalid and `layout_table_base` is immutable.
- Descriptor helper indices refer to internal canonical-table entries outside the Lane `FunctionId` range.
