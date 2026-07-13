# Wasm linear-memory ARC heap

Lane's Wasm compiled tier targets the wasm32 linear-memory model and does not use Wasm GC. Dynamic Lane Strings, data objects, closures, closure environments, and continuation closures are allocated in a Lane-owned heap inside WebAssembly linear memory. Lane defines their object layouts, allocation protocol, non-atomic strong reference counts, destruction behavior, and recursive release of owned fields.

Memory64 is outside Lane v1. Every Lane heap reference is a 32-bit offset into wasm32 linear memory, and one instance cannot address a Lane heap beyond that address space.

Lane output uses one canonical linear memory at memory index zero. Dynamic heap objects, image-owned constants, layout-table data, and runtime-visible byte buffers all reside in that memory. Multiple Memories is excluded because Lane references contain no memory index and must address static and dynamic objects uniformly.

The module defines this memory itself and exports it as `"lane.memory"`; it does not import host-owned memory. Address zero is reserved. Image-owned constants and layout data occupy low addresses, and immutable global `heap_base:i32` points to the first eight-byte-aligned dynamic heap address.

The canonical memory is non-shared. Lane v1 excludes Threads and Atomic instructions, and one Lane instance is not entered concurrently. Non-atomic ARC is therefore sufficient. Separate instances may still execute on different host threads.

Every Lane object reference is a nonzero eight-byte-aligned offset pointing to a common 8-byte header. The first word is `ref_count:u32`, the second is `LayoutId:u32`, and payload begins at offset eight. New dynamic allocations start with count one. The common header contains no flags, byte size, constructor tag, or allocator metadata.

Layout entries provide fixed allocation size or layout-specific variable-size calculation. Variable-size payloads such as String store their length according to their own layout. The allocator may keep block size or free-list metadata in a private prefix or side structure, but that metadata is not part of the Lane object ABI.

String uses the common header followed by `byte_length:u32` and inline ASCII bytes. Its total allocation size is `align_up(12 + byte_length, 8)`. Constant and empty Strings use the same physical layout with the immortal count.

Image-owned static objects use `0xFFFF_FFFF` as an immortal reference-count sentinel. Retain and release are no-ops for the sentinel. A dynamic count may not increment into it; such overflow is a fatal internal execution failure rather than unsigned wraparound. Releasing a dynamic object to zero runs its layout destructor before deallocating the block.

The Wasm backend preserves the compiler-directed ownership semantics already present in LoisVM bytecode. Retain increments a dynamic object's strong count, release destroys the object at zero and releases its owned fields, and compiler-proven last use transfers ownership without incrementing the count. Consuming object construction, projection, callable projection, block-edge transfer, and callee-owned calls keep the same semantic contracts in interpreted and Wasm-compiled execution.

Lane v1 does not represent Lane objects with Wasm GC structs or arrays and does not depend on a tracing collector for their reclamation. Maintaining Lane reference counts on Wasm GC objects would duplicate lifetime bookkeeping without allowing a zero count to reclaim the underlying object. A linear-memory heap instead preserves Lane-controlled lifetime and keeps ARC behavior independent of a host engine's tracing schedule.

The Wasm module includes its allocator and deallocator support rather than importing them. The v1 allocator combines a bump frontier with reusable free lists; size-class details and free-block metadata are private implementation choices. It invokes `memory.grow` when necessary. Wasmoon may recognize and optimize Lane allocation and ARC patterns in its JIT, but such optimization is not required for correctness and does not introduce non-standard Wasm instructions.

Freed payload bytes may hold allocator metadata after destruction. Reused allocations are not guaranteed to be zeroed, so every constructor and environment initializer writes all observable fields before publishing a reference. Allocation failure throws the private fatal Wasm exception and follows the same cleanup unwind as other fatal errors. Free, layout destruction, and cleanup are non-throwing and non-reentrant.

Monomorphic Lane values lower to their natural Wasm representations. Representation-polymorphic values use an `i64` erased payload together with a hidden `LayoutId` descriptor that supplies generic ownership and layout behavior. LoisVM's tagged value representation does not determine the Wasm function ABI or require a uniform Wasm memory cell.

The common object header, materialized layout table, String layout, typed data and environment layouts, and module-owned allocator are specified by subsequent Lane ADRs. Exact free-list size classes, coalescing policy, and memory growth tuning remain implementation choices.

Consequences:

- Lane v1 targets wasm32 linear memory rather than Wasm GC.
- Memory64 is excluded and heap references remain 32-bit offsets.
- Multiple Memories is excluded and all Lane references address memory zero.
- Threads and Atomics are excluded and canonical memory zero is non-shared.
- Object references point to a common 8-byte ARC and layout header.
- Dynamic allocation starts with one strong owner.
- Static objects use the immortal `0xFFFF_FFFF` count.
- Dynamic count overflow is fatal and cannot wrap into the sentinel.
- Layout-specific rules determine allocation size outside the common header.
- Dynamic Lane objects use a custom Lane heap and explicit non-atomic ARC.
- Interpreted and Wasm-compiled execution preserve the same ownership semantics.
- Wasm engines do not determine Lane object lifetime through tracing GC.
- Wasmoon may optimize standard-Wasm ARC patterns without being required for correctness.
- The Wasm module owns and exports its memory and allocator.
- Allocation uses bump growth plus reusable free lists.
- Reused blocks are not implicitly zeroed.
- OOM uses private fatal exception unwinding.
- Generic values use representation erasure rather than whole-program monomorphization.
- Object headers, allocation strategy, function tables, and host-memory ABI are
  delegated to the subsequent focused ADRs.
