# Compiler-directed reference counting

LoisVM uses compiler-directed reference counting for dynamically allocated runtime values. Lane source does not require programmers to write retain and release operations in v1. After `mon-trans`, `open-resolve`, `monadic-lift`, and closure lifting erase effect-specific forms and make captured state and allocation boundaries explicit, `lanec` lowers into a compiler-private virtual-value CFG. Runtime ownership and last-use analysis plus ARC insertion run on that CFG before physical slot allocation and emit the reference-count operations required by the final bytecode image.

Ownership analysis does not run on serialized or physical-slot LoisVM bytecode. The compiler-private VM CFG retains logical values, explicit block parameters, allocation operations, and control-flow edges needed for precise liveness and ownership transfer. It belongs to `lanec`, is not the `loisvm/bytecode` data model, is not persisted in `.lmo` or `.lbp`, and is not the input to the Wasm compiled tier.

Borrowing is a compiler-private, block-local ownership fact. Capture and data-field reads may produce non-owning logical values while their owner remains live in the same basic block. Borrowed values do not cross block edges, consuming calls, returns, closure captures, or object-storage boundaries. Before such a boundary, ARC insertion retains the referenced object to establish an owned value unless ownership can instead be transferred from a separate owned last use. Function parameters, non-`Unit` results, block parameters, and stored object fields are owned. Final bytecode does not encode borrow regions or source ownership types; its physical slots do retain cleanup categories required by Wasm lowering and fatal unwinding.

Representation-polymorphic code retains a hidden layout witness after source type erasure. Static monomorphic ARC lowers directly according to the known representation. For an erased generic value, ARC insertion associates ownership operations with its `LayoutId`, allowing the Wasm tier to invoke descriptor-provided retain, release, destruction, and field-layout behavior over the value's `i64` erased payload. The witness is runtime representation metadata, not a source type or borrow region.

Object construction is consuming. Data constructors, closure-environment construction, closure creation, and continuation-closure construction transfer reference-bearing operands into owned fields without implicit retains. ARC insertion retains operands that must remain available elsewhere and promotes borrowed values before storage. Destroying a reference-counted object releases all reference-bearing fields owned by that object. `make_closure` consumes one ownership of its nonzero environment, so multiple closures sharing one environment require distinct strong environment owners.

Closure environments use typed immutable layouts after the common ARC header. A static `ObjectShapeId` naming an Environment shape determines capture placement, while runtime `LayoutId` determines allocation and ARC behavior. One-time initialization consumes captured owners into their fields and stores the `LayoutId` witnesses required for erased generic captures. Capture-free callables use environment zero and allocate no empty object. Wasm escape analysis may scalar-replace a non-escaping environment, but this is not required for correctness and preserves the same ownership transfers and destruction.

Data layout is typed after representation erasure. A static `ObjectShapeId` naming a Data shape identifies the constructor field schema used to compute canonical representation-specific offsets, while runtime `LayoutId` identifies allocation and ARC behavior. Erased generic fields occupy `i64`, and the object stores the hidden `LayoutId` witnesses its destructor needs. A fieldless constructor requiring no stored witness may use an immortal image singleton and consumes no dynamic allocation ownership.

Data decomposition has borrowing and consuming forms. Borrowing projection preserves the data owner and produces block-local borrowed references; an erased field also returns its stored layout witness. Consuming projection consumes one object ownership and returns selected payload fields and required witnesses as owned values. If the object has reference count one, the runtime moves selected fields, releases unselected owned fields, and frees the object shell. If the object is shared, the runtime retains selected fields and releases the consumed object ownership. The count check is an optimization path rather than a validity precondition. Match lowering chooses the consuming form only after constructor selection and when ownership analysis consumes the scrutinee.

Reference counting applies only to dynamically allocated objects. Tagged primitives and function identifiers are immediate values and require no reference-count operations. V1 constant-pool Strings are owned by the loaded bytecode image and are treated as static: retain-copy and release leave their immortal counts unchanged. Runtime-created strings, data, closures, environments, and continuation closures use ordinary strong reference counts. The image remains loaded while any execution value can refer to its static objects; v1 does not support unloading an image while such values remain live. Future static object kinds require an explicit bytecode schema extension.

In the Wasm tier, dynamic and static references point to a common 8-byte header containing `ref_count:u32` and `LayoutId:u32`; payload begins at offset eight. Dynamic allocation starts at count one. Static image objects store `0xFFFF_FFFF`, making generic retain and release no-ops without a pointer-range test. Dynamic retain must fail fatally rather than incrementing into the sentinel or wrapping. Release to zero invokes the layout destructor and only then frees the allocation.

Reference counts are non-atomic in v1. Each LoisVM instance owns a thread-confined dynamic heap, its dynamic VM values and continuation closures do not cross threads, and the instance is not entered concurrently. Interpreted and Wasm-compiled execution share this contract. Future concurrency requires an explicit shared or atomic ownership boundary rather than imposing atomic operations on all existing objects.

The Lane Wasm output profile excludes Threads and Atomic instructions, and its canonical linear memory is not shared. Wasmoon may compile modules in parallel or run separate Lane instances on separate host threads, but one instance and its heap remain confined to one execution thread at a time.

The bytecode contains explicit `retain_copy(dst, src)` and `release(slot)` instructions rather than unary retain or ownership-aware assignment. Retain-copy increments according to the destination cleanup category before establishing another owner in the destination. A compiler-proven last use may use `move(dst, src)` to transfer existing ownership without incrementing the count. `copy(dst, src)` is restricted to equal-representation `Trivial` slots. Releasing the final strong owner destroys the object and releases the strong references owned by that object.

Every producing, copy, move, or retain-copy destination is logically dead before writing. No instruction implicitly releases an overwritten destination. Move and release consume logical source ownership but need not clear stale physical bits. LoisVM has no generic slot-assignment opcode.

Function calls use a callee-owned convention. Reference-bearing user arguments and any required hidden closure environment transfer ownership into the callee frame. If the caller still needs one of those values after a returning call, ownership analysis emits `retain_copy` into a fresh owner slot before the transfer; a last use transfers directly. A callable-value call consumes its callable operand. An immediate `FunctionId` is uncounted. For a unique closure, the fused call moves the environment into the callee and frees the closure shell. For a shared closure, it retains the environment for the callee and releases only the consumed closure owner. The count check is an optimization path rather than a validity precondition. Returning functions transfer one owned non-`Unit` result to the caller. Tail calls transfer arguments and required closure environment directly into the replacement frame and do not create an owned result in the current frame.

Normal exits do not scan a frame for live owners. ARC insertion emits releases for every owner not transferred by a return or tail-call terminator. A `return` consumes its optional non-`Unit` source owner. A tail call consumes its callable or environment and all reference-bearing arguments. Reaching either terminator with another owned slot still live is invalid trusted bytecode.

Control-flow edges use the same ownership-transfer model. The selected jump, boolean branch, or tag-switch edge consumes reference-bearing edge arguments and establishes owned target block parameters in parallel. Condition and tag slots are read non-consumingly. Control-flow instructions do not implicitly retain or release values. If one selected edge duplicates one source owner into multiple target parameters, explicit retain-copies establish the additional owners. Alternative edges are mutually exclusive and do not create simultaneous ownership. Loop backedges explicitly release overwritten logical parameter values when they are not transferred, and later slot allocation must preserve the ownership behavior of the logical edge moves.

Physical slot allocation also preserves erased representation and cleanup categories. One bytecode `SlotId` is representation-homogeneous, so logical values with incompatible Wasm representations or cleanup behavior cannot reuse the same physical slot. These categories are `Trivial`, `OwnedRef`, `OwnedCallable`, and `OwnedErased`; they are runtime cleanup metadata rather than compiler ownership-analysis state. This lets the Wasm backend map slots to typed locals and derive exception cleanup ownership without recovering source types.

This model applies to dynamically allocated data, closures, and closure environments. Reusable continuations become ordinary continuation closures before ownership analysis, so they use the same environment, call, retain, release, and ownership-transfer rules. Resume sites have already become callable-value calls, callable-value tail calls, direct calls, or linear control flow before VM CFG lowering; ARC insertion retains a continuation closure before a consuming invocation when later uses remain. LoisVM has no dedicated continuation heap object, runtime stack snapshot, handler context, or effect-specific reference-count operation. The interpreter executes the emitted ordinary operations directly. Wasm lowering or the Wasmoon JIT may remove redundant retain/release pairs or promote non-escaping allocations, but those optimizations are not required for correctness and do not change the bytecode ownership contract.

The Wasm tier represents a callable as one packed `i64` containing its function-table index and environment offset, rather than allocating the interpreter's closure shell. Each owned packed callable with a nonzero environment directly owns one strong environment reference. Retaining or releasing the callable retains or releases that environment, and consuming invocation transfers the environment owner into the callee. This is ownership-equivalent to the interpreter's unique-or-shared closure-shell projection but requires no dynamic shell-count branch in Wasm code.

LoisVM v1 has no tracing garbage collector and no runtime cycle collector. Effect erasure and closure lowering must therefore avoid creating strong cycles that ordinary reference counting cannot reclaim. In particular, a recursive closure group uses a shared environment for outer captures, but that environment does not strongly store the group closure objects that point back to it. Calls between known group members use direct function identifiers with the shared environment; when a group member is needed as a first-class value, lowering constructs a closure from that function identifier and environment.

Bytecode remains trusted compiler output. LoisVM does not verify retain/release balance, ownership transfers, or cycle-freedom before execution. Incorrect ownership bytecode is an internal compiler bug rather than a supported artifact diagnostic.

## Consequences

- Lane source remains automatically memory managed in v1 without mandatory ownership annotations.
- `lanec` owns the compiler-private VM CFG, runtime ownership analysis, and ARC insertion; LoisVM owns execution of the resulting operations.
- Ownership analysis runs before physical slot allocation and final bytecode construction, not over persisted bytecode.
- Borrow regions are compiler-private; bytecode serializes only physical cleanup categories.
- Borrowed references require promotion before block, call, return, or object-storage boundaries.
- Function parameters, results, block parameters, and stored object fields are owned.
- Object construction consumes reference-bearing operands into owned fields.
- Object destruction releases every owned reference-bearing field.
- Closures sharing one environment each own a strong reference to that environment.
- Data projection has separate borrowing and consuming ownership semantics.
- Consuming projection is valid for both unique and shared objects and always returns owned fields.
- A unique consuming projection moves selected fields and releases unselected fields without redundant retains.
- Immediate values do not participate in reference counting.
- Constant-pool objects are image-owned static values with no per-value reference-count updates.
- Dynamically allocated runtime objects use ordinary strong reference counts.
- Bytecode images remain loaded while execution values can reference their static objects.
- Dynamic heaps and VM values are thread-confined in v1.
- Reference-count updates and uniqueness checks are non-atomic.
- Future concurrency requires an explicit shared or atomic ownership boundary.
- Retain-copy and release are explicit bytecode semantics rather than implicit effects of assignment.
- Trivial copy, ownership move, retained copy, and release are distinct instructions.
- Last-use information can eliminate retains through ownership transfer before Wasm lowering.
- Calls consume reference-bearing arguments and any required closure environment; non-`Unit` returns produce owned results.
- Reusing an argument after a call requires a compiler-inserted retain-copy before ownership transfer.
- Tail calls transfer ownership directly into the replacement frame.
- Normal return and tail transfer require all other owners to be explicitly released.
- Selected control-flow edges transfer ownership into block parameters without implicit retains.
- Duplicating one owner into multiple parameters on one selected edge requires explicit retain-copies.
- Slot allocation must preserve logical edge-transfer and release behavior across physical slot reuse.
- Wasm lowering and Wasmoon JIT optimization may improve generated code but are not responsible for reference-count correctness.
- Recursive closure lowering must break strong environment-to-closure cycles statically.
- Reusable continuations are ordinary closures and use the same reference-count and call contracts.
- Proven one-shot continuations may avoid closure allocation through direct or linear lowering.
- `.lbp` is not an untrusted ownership-safe format and receives no ownership verifier in v1.
