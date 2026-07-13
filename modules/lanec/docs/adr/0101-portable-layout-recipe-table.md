# Portable layout recipe table

Immediately after the function table, LoisVM bytecode stores `layout_count:u32le` and that many portable Layout Recipe entries. Table position zero corresponds to `LayoutId = 1`; `LayoutId = 0` is always invalid. A program that uses no layout may encode zero entries.

Each entry begins with `recipe_tag:u8`. V1 assignments are Unit `0x01`, Bool `0x02`, Int `0x03`, Double `0x04`, Callable `0x05`, String `0x06`, Data `0x07`, Environment `0x08`, and Reference `0x09`. Unit, Bool, Int, Double, Callable, String, and Reference carry no payload. Data and Environment append `ObjectShapeId:u32le`. Unknown tags are decoding errors. Loading rejects a Data recipe referencing an Environment shape, an Environment recipe referencing a Data shape, or any out-of-range shape reference.

Portable recipes contain no representation-kind word, size, alignment, byte offset, sizer index, retain helper index, release helper index, or destroy helper index. The interpreter and Wasm backend derive those details from the recipe and referenced Object Shape. Backend-specific values never flow back into portable bytecode.

Unit, Bool, Int, and Double recipes describe non-allocating values with no-op ownership behavior. Callable describes packed callable ownership over its nonzero environment component and no callable-shell allocation. String describes ordinary object-reference ARC, no owned payload fields, and variable allocation size `align_up(12 + byte_length, 8)`. It is the only variable-size v1 recipe.

Data and Environment recipes describe ordinary object-reference ARC. Their Object Shape determines fixed allocation size, alignment, stored witnesses, member offsets, and destruction behavior. OwnedErased members consult witnesses stored in each object. Callable has no object recipe because both execution tiers directly retain and release its packed environment component.

Reference is a witness-only ordinary object-reference recipe for nominal values crossing erased generic boundaries. Its retain and release behavior follows the concrete object's header LayoutId. It has no allocation shape, cannot appear in an object header, and does not identify a source nominal type or representative constructor.

LayoutId is not observable in Lane. The linker therefore deduplicates equal recipes. It emits actually used primitive recipes in Unit, Bool, Int, Double, Callable, String order, followed by Data recipes ordered by ObjectShapeId and Environment recipes ordered by ObjectShapeId. Each used Data or Environment Object Shape has one v1 LayoutId.

The Wasm backend materializes one unused zero descriptor followed by one 32-byte descriptor per portable recipe. It derives descriptor words and internal helper-table indices from the recipe and Object Shape. The descriptor address remains `layout_table_base + LayoutId * 32`.

Consequences:

- Portable LayoutId indexes semantic recipes rather than Wasm descriptors.
- V1 has nine closed recipe variants.
- Their wire tags are contiguous `0x01..0x09`.
- Data and Environment recipes reference typed Object Shapes.
- Closure shells have no portable layout recipe.
- String is the only variable-size v1 recipe.
- Reference is witness-only and never an allocated object's own LayoutId.
- Recipes contain no computed offsets, sizes, or helper indices.
- Equal recipes are deduplicated because LayoutId is unobservable.
- Recipe order and LayoutId assignment are deterministic.
- Each used Data or Environment shape has one LayoutId.
- Wasm descriptor materialization is a backend-only projection.
