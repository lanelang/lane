# Static Wasm image and function table

Lane Wasm modules use declarative instantiation rather than executable startup logic. Active data segments materialize static Strings, nullary constructor singletons, layout descriptors, and other image-owned bytes in canonical memory. Active element segments initialize the canonical function table. Immutable globals and allocator state use constant initializers. The module defines no Wasm start function.

The canonical function table is one private `funcref` table. It is not exported, generated code does not use `table.grow`, and its declared minimum and maximum are both the exact emitted entry count. Host code therefore cannot replace callable targets, and execution cannot add targets after instantiation.

Table index zero is reserved as invalid. Valid Lane `FunctionId` values form the contiguous range `1..N` and map directly to the same Wasm table indices. This range includes generated adapters for runtime-import entries because those entries may be called directly or represented as first-class capture-free callables. Packed callable zero is consequently invalid.

Internal layout retain, release, destroy, and sizing helpers occupy contiguous entries after the Lane `FunctionId` range. Their indices may appear in materialized layout descriptors but cannot appear in packed Lane callables. The exported `"lane.entry"` wrapper and restricted runtime-service helpers are direct Wasm functions outside the table and outside the Lane callable namespace.

Canonical memory uses standard 64-KiB pages. Its initial page count is the minimum integer count covering `heap_base`; any remaining bytes in the final initial page belong to the dynamic heap. The memory type declares no maximum. The module-owned allocator grows memory on demand, and allocation failure follows the private fatal exception path.

Consequences:

- Static memory and table contents are ready after successful instantiation.
- Generated modules have no Wasm start function.
- Active data and element segments perform image initialization.
- One private fixed-size `funcref` table contains all indirect targets.
- Table index and `FunctionId` zero are invalid.
- Lane `FunctionId` values occupy contiguous indices `1..N`.
- Runtime-import adapters are ordinary Lane function-table targets.
- Layout helpers follow the Lane range and cannot become callables.
- Entry and runtime-service wrappers remain outside the table.
- Initial memory minimally covers `heap_base` and declares no maximum.
