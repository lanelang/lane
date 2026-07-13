# Module-owned Wasm memory and allocator

A generated Lane Wasm module defines one canonical non-shared wasm32 memory and exports it under the stable internal ABI name `"lane.memory"`. The module does not import host-owned memory. Wasmoon runtime imports use the current RuntimeContext to access approved String and byte-buffer ranges through this export. RuntimeContext may also invoke a designated module-owned allocation service such as `"lane.runtime.string.new"` while ordinary Lane execution is paused.

Linear-memory address zero is reserved. Active data segments materialize image-owned pooled String objects, layout descriptors, and other static execution data at low addresses during instantiation. Immutable global `heap_base:i32` identifies the first eight-byte-aligned address available to the dynamic Lane heap. The module has no start function; allocator globals use constant initializers.

The memory's initial standard 64-KiB page count is the minimum that covers `heap_base`. Any bytes between `heap_base` and the initial page boundary are immediately available to the dynamic heap. The memory type declares no maximum; the allocator invokes `memory.grow` as needed and relies on the engine or embedding environment for the effective limit.

The module contains its own allocator and deallocator. Lane v1 uses a bump frontier for new space plus reusable free lists for reclaimed blocks. Exact size classes, coalescing policy, free-list organization, and allocator prefixes are private implementation details rather than Lane object ABI. The allocator invokes `memory.grow` when existing pages cannot satisfy an allocation.

An optional host-provided `max_live_heap_bytes` is enforced separately from
linear-memory page commitment. Allocation charges canonical Lane object size,
and final deallocation removes the same charge. Static image objects, free
blocks, fragmentation, and allocator-private metadata do not count toward this
logical limit. Exceeding it throws the private fatal exception as an execution
resource-limit failure.

Free may overwrite an already destroyed object's payload with allocator metadata. Reused blocks are not guaranteed to contain zero bytes. Data constructors and closure-environment construction must write every observable field before publishing the new reference; uninitialized object state is never visible to ordinary execution.

If allocation or `memory.grow` fails, the allocator leaves its metadata consistent and throws the private fatal Wasm exception. Generated frame handlers release remaining owners while unwinding. Deallocation, layout destruction, reference release, and cleanup are non-throwing. The allocator is thread-confined and non-reentrant, matching the Lane instance and non-atomic ARC contract. A restricted RuntimeContext service invocation is not recursive allocator entry: it enters the allocator once while the suspended Lane import adapter does not hold an active allocator operation.

Consequences:

- Lane modules define rather than import canonical memory.
- Canonical memory is exported as `"lane.memory"` for runtime integration.
- Restricted runtime services may allocate while ordinary Lane execution is paused.
- Address zero is reserved and `heap_base` is immutable and eight-byte aligned.
- Active data segments initialize static memory without a start function.
- Initial pages minimally cover `heap_base`, and memory declares no maximum.
- Static image data precedes the dynamic heap.
- Allocation uses a bump frontier and reusable free lists.
- Allocator organization is not part of the Lane object ABI.
- Reused blocks are not implicitly zeroed.
- Constructors fully initialize objects before publication.
- OOM and `memory.grow` failure use private fatal exception unwinding.
- Free, destruction, release, and cleanup cannot throw.
