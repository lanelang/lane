# Materialized Wasm layout table

The Wasm backend derives materialized descriptors from portable Layout Recipes and Object Shapes, then writes them as a static region in canonical memory. Immutable global `layout_table_base:i32` points to its base. `LayoutId` is a dense `u32` index, with zero reserved as invalid or no-layout. Descriptor address is `layout_table_base + LayoutId * 32`; the materialized region includes one unused zero descriptor before the portable entries.

Every descriptor is eight-byte-aligned and exactly 32 bytes:

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

For a fixed-size layout, `size_or_sizer_index` stores complete allocation size including the common ARC header. For a variable-size layout, it stores the canonical function-table index of a `(object_ref:i32) -> i32` sizer returning complete allocation size. `alignment` is the required byte alignment.

Retain and release helpers have Wasm signature `(payload:i64) -> ()`. Destroy helpers have `(object_ref:i32) -> ()`; they release owned fields but do not free the object. A release-to-zero path obtains allocation size, invokes destroy, then calls the allocator's free operation. The reserved word is not used for Lane v1 semantics.

All helper indices refer to the one private fixed-size canonical Wasm function table. Index zero is invalid. Contiguous indices `1..N` form the valid Lane `FunctionId` range, and internal retain, release, destroy, and sizer entries follow it. Helpers are not present as bytecode-defined or runtime-import function entries and cannot be constructed as Lane callables. `FunctionId` remains the direct table index only within its declared Lane range.

The table region is image-owned execution metadata. Generated Lane code does not mutate it, descriptors do not participate in ARC, and the loaded image remains alive while any object may consult them. Static `ObjectShapeId` metadata used by the compiler, interpreter, and Wasm lowering is not embedded in these 32-byte runtime descriptors and need not be materialized in linear memory.

Portable bytecode stores no rep-kind word, size, alignment, sizer index, or helper index. Unit, Bool, Int, and Double derive no-op ownership behavior; Callable derives packed-environment ownership; String derives variable sizing and ordinary reference ARC; Data and Environment derive fixed size, alignment, and destruction from their Object Shape. Backend-generated helper indices remain Wasm-local.

Consequences:

- Layout descriptors have fixed 32-byte stride and eight-byte alignment.
- `LayoutId = 0` is invalid.
- `layout_table_base` is an immutable Wasm `i32` global.
- Fixed and dynamic size paths return total allocation size including the header.
- Retain and release helpers accept one erased `i64` payload.
- Destroy helpers release fields but allocator free happens afterwards.
- Layout helpers share the canonical table but are not Lane functions.
- Layout helpers follow the contiguous Lane `FunctionId` range.
- Packed callables accept only indices in the valid Lane `FunctionId` range.
- Static object-shape metadata is separate from materialized runtime descriptors.
- Portable layout recipes contain no Wasm helper indices or computed sizes.
