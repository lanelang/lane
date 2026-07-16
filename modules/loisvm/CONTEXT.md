# LoisVM

LoisVM owns Lane's portable bytecode image, bytecode interpreter, runtime representation, host-call boundary, and bytecode-to-Wasm execution contract. Encoding and implementation detail belongs in ADRs; this file contains only the canonical vocabulary.

## Language

### Boundaries

**LoisVM**:
The independent MoonBit module that owns Lane's portable bytecode definition,
bytecode codec, and bytecode interpreter.
_Avoid_: lanec internal package, lane command implementation, Buslane core language

**LoisVM Bytecode**:
The register-style, erased, portable bytecode image consumed by the LoisVM
interpreter.
_Avoid_: Buslane/core, ANF, source syntax tree

**LoisVM Bytecode Package**:
The `loisvm/bytecode` package that owns bytecode image data structures,
instructions, function tables, layouts, and bytecode serialization.
_Avoid_: compiler lowering pass, command runtime handler, artifact wrapper

**LoisVM Bytecode Section**:
The execution-only current-format bytecode payload occupying every byte after the linked-program schema version inside a Lane `.lbp` payload and decoded by `loisvm/bytecode`.
_Avoid_: whole `.lbp` artifact, Lane artifact header, section directory, source map section

**LoisVM Interpreter Package**:
The `loisvm/interp` package that owns bytecode execution, VM values, call
frames, closures, and runtime-import invocation.
_Avoid_: bytecode data model, compiler optimization pass, CLI command parser

**Trusted Bytecode Image**:
A decoded LoisVM image assumed to satisfy bytecode invariants because it was
emitted by the matching Lane linker.
_Avoid_: verified bytecode, untrusted artifact, sandbox input

**LoisVM Bytecode Format Compatibility**:
The lockstep producer-consumer contract in which a bytecode section contains only the current canonical layout and carries no independent version field or backward-compatibility discriminator. Persisted `.lbp` compatibility is owned by the enclosing linked-program schema version.
_Avoid_: bytecode version negotiation, legacy bytecode decoder, optional old-format branch

**Loaded Executable Image**:
The reusable successfully decoded and bound bytecode product, including optional reusable backend compilation state, used to create fresh executions.
_Avoid_: active execution heap, partial load result, mutable call stack

**Single-Shot Execution Instance**:
The thread-confined frames, dynamic heap, allocator state, runtime context, and limits used by one selected-entry attempt and never reused afterward.
_Avoid_: loaded image, resumable failure, concurrent VM

### Image Model

**VM Value**:
The uniform tagged runtime value stored in bytecode local slots, including
primitive cases such as `Double`.
_Avoid_: Lane type object, typed unboxed slot, Buslane interpreter value

**Image Constant Pool**:
The single image-wide table of deduplicated ASCII String constants referenced
through zero-based `ConstantId` values.
_Avoid_: per-function constant table, function table, debug metadata

**Unified Function Table**:
The image-global `FunctionId` index space containing tagged bytecode-body and
runtime-import entries.
_Avoid_: bytecode-only function index, separate runtime-call table, operation table

**Selected Bytecode Entry**:
The nonzero FunctionId stored in executable bytecode for the link-validated
no-context, witness-free, zero-argument Unit body invoked by execution.
_Avoid_: source export symbol, runtime entry selection, runtime import

**Instance Global**:
An immutable per-execution value initialized exactly once before the selected entry and rooted outside ordinary call frames until instance lifecycle cleanup.
_Avoid_: Wasm global, mutable static variable, image constant

**GlobalId**:
The zero-based dense identifier of one Instance Global in a LoisVM bytecode image.
_Avoid_: Wasm global index, SlotId, source value symbol

**Instance Initializer**:
The optional no-context, witness-free, zero-argument Unit bytecode body that initializes all dynamic Instance Globals before the selected entry may run.
_Avoid_: Wasm start function, source effect handler, lazy global initializer

**Initialization Phase**:
The execution phase rooted at the Instance Initializer during which initializer code and its callees may initialize Instance Globals.
_Avoid_: Wasm instantiation, source module loading, selected-entry execution

**Instance Root Table**:
The per-execution linear-memory or interpreter-owned storage that roots initialized Instance Globals independently of ordinary call frames.
_Avoid_: bytecode local slots, Wasm global section, image constant pool

**Runtime Import Entry**:
A unified function-table entry produced from a Lane extern binding and containing
a stable runtime symbol and erased ABI descriptor instead of a LoisVM bytecode body.
_Avoid_: effect operation entry, per-call symbol lookup, synthetic bytecode stub

**Build-Local FunctionId**:
A dense execution-image function index reproducible for identical build inputs but permitted to change whenever the final optimized body list changes.
_Avoid_: stable ABI name, persisted function reference, call-graph hash

**Dense Bytecode Identifier Space**:
An ordered bytecode table whose entry position supplies its identifier, reserving zero for `FunctionId` and `LayoutId` but not for block, slot, constant, or object-shape identifiers.
_Avoid_: sparse map, repeated serialized ID, instruction offset

**Fixed-Shape Opcode Encoding**:
The instruction representation where one `u8` opcode or terminator tag selects an exact operand sequence and unknown tags are malformed bytecode.
_Avoid_: instruction byte length, unknown-opcode preservation, self-describing record

**Structured Bytecode Addressing**:
The serialized model where functions own ordered `BlockId` and `SlotId` spaces,
fix `BlockId = 0` as entry, and encode control-flow
targets as block identifiers rather than instruction byte offsets.
_Avoid_: relative PC, byte address, Wasm label depth

**Canonical Bytecode Function Body**:
The byte-length-delimited body payload ordered as slot table, inputs, result descriptor, then nonempty block table, with no entry-block field.
_Avoid_: entry BlockId operand, block length, extensible field map

**Block Parameter Transfer**:
The control-flow operation that assigns a target block's ordered parameter
slots from an incoming edge's ordered source slots in parallel.
_Avoid_: sequential move semantics, function call, operand-stack merge

**Representation-Homogeneous Slot**:
A `SlotId` with one fixed erased Wasm representation and ownership category.
Slot reuse is allowed only between compatible logical values.
_Avoid_: Lane source type, arbitrary tagged reuse, Wasm memory frame requirement

**Slot Cleanup Category**:
The serialized runtime cleanup behavior `Trivial`, `OwnedRef`, `OwnedCallable`, or `OwnedErased`, without encoding a source ownership type or borrow region.
_Avoid_: borrow checker state, implicit retain, source lifetime

**Erased Ownership Companion**:
The immutable `I32 + Trivial` layout-witness slot referenced by an `I64 + OwnedErased` slot for descriptor-directed cleanup.
_Avoid_: source type argument, owned metadata, dynamic typecase

**Object Shape**:
The zero-based canonical member schema whose Data variant includes constructor tag and fields and whose Environment variant includes captures without a tag, with stored-witness ordinals but no raw offsets or alignment fields.
_Avoid_: runtime LayoutId, raw offset list, variable-size String layout

**Layout Operand**:
The five-byte operand selecting Immediate `0x01` with nonzero LayoutId or Witness `0x02` with a trivial `I32` witness SlotId.
_Avoid_: ObjectShapeId, descriptor address, source type witness

**Image Layout Table**:
The image-owned static table of backend-independent Layout Recipes indexed by
immediate `LayoutId` values and used to derive representation, sizing, alignment,
and ownership behavior.
_Avoid_: dynamic type object, heap descriptor, reference-counted metadata

**Portable Layout Recipe**:
The tagged Unit, Bool, Int, Double, Callable, String, Data, Environment, or
Reference recipe
serialized for one LayoutId before backend-specific descriptor materialization.
_Avoid_: source type descriptor, Wasm helper index, raw member offset

**Erased Reference Layout**:
The canonical witness-only Reference recipe shared by nominal values at erased
generic boundaries; retain and release follow the referenced object's own
header LayoutId, and the recipe is never installed in an object header.
_Avoid_: representative constructor shape, String descriptor reuse, source nominal type

**Representation Layout Witness**:
A hidden `LayoutId` descriptor retained in erased bytecode for a generic runtime
representation. It provides the layout and ownership operations needed when the
Wasm tier lowers a generic value to an `i64` erased payload.
_Avoid_: full Lane type, source type argument, dynamic typecase

**Representation Erasure Bridge**:
A compiler-internal consuming operation between a natural representation and erased `I64` that transfers ownership while changing width, bit interpretation, or cleanup interpretation.
_Avoid_: source conversion, generic heap box, runtime typecase

### Calls And Closures

**Direct Call**:
A returning non-terminating LoisVM instruction that calls an immediate function-table identifier, supplies a hidden closure environment exactly when required, and carries a destination only for a non-`Unit` result.
_Avoid_: closure-value call, dynamic function reference, tail call, source call

**Value Call**:
A fused returning non-terminating LoisVM instruction that calls a callable value
from a local slot, carries a destination only for a non-`Unit` result, and does
not expose callable-tag dispatch or closure-environment extraction to bytecode.
_Avoid_: closure unpack instruction, direct immediate target, closure-only call, tail call

**Callable Value**:
A first-class function value represented by an immediate capture-free
`FunctionId` or a reference-counted closure pair of `FunctionId` and environment.
_Avoid_: separate runtime-function value, mandatory empty closure, source function

**Callable Construction**:
The creation of a no-context callable by `const_function` or a context-requiring
callable by consuming one nonzero environment owner in `make_closure`.
_Avoid_: implicit environment retain, closure layout operand, mandatory shell allocation

**Erased Callable Adapter**:
A compiler-generated ordinary closure that recursively converts callable
parameters and results when representation erasure changes their physical call
ABI, capturing the source callable and any free layout witnesses it requires.
_Avoid_: bytecode typecase, universal monomorphic callable ABI, implicit call conversion

**Function Context Kind**:
Function-table metadata declaring whether a function has no hidden context or
requires an opaque closure environment reference.
_Avoid_: Lane user arity, runtime inference, capture field layout

**Closure Environment Reference**:
The opaque hidden context used by a capturing lifted function to access its
captured values.
_Avoid_: closure value, user parameter, flattened captures

**Environment Construction**:
A consuming LoisVM instruction that fully initializes an immutable closure
environment from an Environment Object Shape, runtime layout, stored witnesses,
and captures before publication.
_Avoid_: separate uninitialized allocation, general mutation, closure creation

**Capture Projection**:
A borrowing or consuming LoisVM operation that explicitly names an Environment
Object Shape, environment source slot, and shape-local capture index.
_Avoid_: implicit current-frame access, raw heap offset, source lookup

**Tail Call**:
A direct or callable-value call terminator with no normal return continuation in the
current bytecode function.
_Avoid_: value-producing call instruction, return, ordinary jump

**Return Terminator**:
The function terminator carrying one source OptionalSlot, consuming a non-Unit result owner or returning Unit when the field is zero.
_Avoid_: ordinary call, tail call, implicit frame cleanup

**Effect-Erased Image**:
A LoisVM bytecode image produced only after `mon-trans`, `open-resolve`, and
`monadic-lift` have eliminated effect-specific forms and dispatch structures.
_Avoid_: perform instruction, handler context, operation table

**Continuation Closure**:
A reusable lowered continuation represented by the ordinary LoisVM closure
pair of a function identifier and reference-counted environment.
_Avoid_: dedicated continuation object, captured VM stack, host closure

### Ownership

**Reference-Counted Object**:
A dynamically allocated LoisVM value whose lifetime is controlled by explicit
compiler-inserted retain-copy and release instructions.
_Avoid_: tracing-GC object, unmanaged pointer, source ownership annotation

**Ownership Transfer**:
A compiler-proven last-use movement that consumes an existing owned reference
without incrementing its count.
_Avoid_: retained copy, borrowed use, raw pointer move

**Trivial Slot Copy**:
The `copy(dst, src)` instruction that duplicates equal-representation `Trivial` slot bits without consuming the source.
_Avoid_: owned copy, implicit retain, generic assignment

**Ownership Move**:
The `move(dst, src)` instruction that transfers a compatible logical value and ownership to a dead destination without ARC or source-bit clearing.
_Avoid_: retained copy, overwrite cleanup, memory move

**Retain Copy**:
The `retain_copy(dst, src)` instruction that copies equal-representation bits and uses the destination cleanup category to establish one new owner.
_Avoid_: unary retain, trivial copy, ownership transfer

**Release**:
A LoisVM instruction that removes one strong owner and destroys the object when
its count reaches zero.
_Avoid_: tracing collection, cycle collection, source destructor

**Callee-Owned Call ABI**:
The LoisVM calling convention where reference-bearing arguments and any required
closure environment are consumed by the callee and a return produces an owned
result.
_Avoid_: borrowed-argument ABI, caller-owned parameters, ownership-neutral return

**Owning Block Parameter**:
A LoisVM block parameter that receives ownership from the selected incoming
control-flow edge.
_Avoid_: borrowed block input, implicit retained copy, source binder

**Edge Ownership Transfer**:
The parallel transfer that consumes owned edge arguments and establishes owned
target block parameters without implicit reference-count operations.
_Avoid_: retained jump copy, borrowed edge value, sequential move

**Borrowing Read**:
A LoisVM read operation whose reference-bearing result does not establish a new
strong owner and is valid only while its compiler-preserved owner remains live.
_Avoid_: owned projection, retained copy, borrow-region metadata

**Consuming Object Construction**:
The LoisVM convention where an object-building operation consumes each
reference-bearing operand into an owned field without an implicit retain.
_Avoid_: borrowed field storage, constructor-internal retain, ownership-neutral allocation

**Borrowing Data Projection**:
A LoisVM data-field read that preserves the object owner and yields a
non-owning block-local reference for a reference-bearing field.
_Avoid_: owned projection, consuming match, destructive field read

**Consuming Data Projection**:
A LoisVM data operation that consumes one object ownership and returns selected
payload fields as owned values using a unique move path or shared retain path.
_Avoid_: compiler-assumed uniqueness, borrow-only access, raw heap mutation

**Image-Owned Static Object**:
An immutable constant-pool object whose lifetime is owned by the loaded LoisVM
image and whose retain and release operations are omitted or no-ops.
_Avoid_: dynamic RC object, copied literal, independently unloadable object

**Immortal Refcount Sentinel**:
The `0xFFFF_FFFF` count stored in image-owned static object headers. Generic
retain and release leave such objects unchanged.
_Avoid_: dynamic count value, saturating ARC, pointer-range ownership test

**Thread-Confined Heap**:
The dynamic heap owned by one LoisVM instance and accessed by only one thread,
allowing reference counts and uniqueness checks to be non-atomic.
_Avoid_: shared concurrent heap, atomic RC, cross-thread value

**Ownership-Empty Exit**:
A return or tail transfer reached after explicit releases remove every current-frame owner not transferred by that exit.
_Avoid_: frame scan, unconsumed owned local, fatal unwind

### Runtime Imports

**Runtime Import ABI V1**:
The fixed-arity host-call ABI that receives an implicit runtime context followed
by uniform VM values and returns exactly one owned VM value.
_Avoid_: Lane source signature, varargs, typed unboxed bytecode ABI

**Runtime Symbol Registry**:
The runtime-owned mapping from a stable symbol and ABI major version to its
primitive signature and resolved host implementation.
_Avoid_: bytecode type metadata, per-call symbol lookup, duplicated signature table, host effect handler registry

**Runtime Context**:
Borrowed non-Lane host state supplied implicitly to runtime imports for services
such as allocation and I/O.
_Avoid_: local slot, handler context, reference-counted value

**Synchronous Primitive Host Call**:
A runtime import that returns before VM execution continues, cannot re-enter
Lane program execution, retains no VM values after return, and crosses only
primitive value kinds; approved runtime-service nested calls are not Lane
reentry.
_Avoid_: asynchronous import, VM callback, closure argument, opaque handle result

**Runtime Import Failure**:
A fatal out-of-band error from a runtime binding that returns no VM value and
terminates the current LoisVM execution without a bytecode exception edge.
_Avoid_: Lane exception, effect operation, recoverable primitive status

**Resolved Runtime Binding**:
The loaded-image target obtained by resolving one runtime import entry before
execution begins.
_Avoid_: serialized host pointer, per-call plugin lookup, FunctionId

**Runtime Service Nested Call**:
A RuntimeContext call to an approved non-Lane service export such as
`"lane.runtime.string.new"` while a host import is active, without permission to
invoke entry, closures, or ordinary `FunctionId` targets.
_Avoid_: Lane callback, general same-instance reentry, asynchronous host call

**Runtime String Object**:
An immutable ARC object with `byte_length:u32` at object offset eight and ASCII
bytes at offset twelve, with total size rounded to eight-byte alignment.
_Avoid_: mutable bytes, NUL-terminated C string, parent-backed slice

**Borrowed Host String View**:
A temporary non-owning view of a VM String's ASCII bytes exposed only during one
synchronous runtime-import invocation.
_Avoid_: retained host pointer, copied input, owned string result

### Loading And Failure

**Bytecode Binary Adapter**:
The LoisVM-owned current-format decoder that composes the domain-independent Bytecodec reader, maps primitive framing failures into bytecode-relative MalformedEncoding or ResourceLimit failures, and retains all LoisVM tag and table semantics.
_Avoid_: duplicated byte cursor, Bytecodec-owned instruction schema, signed u32 interpretation

**Atomic Bytecode Load**:
The all-or-nothing path from complete section decoding through import binding and backend construction to publication of one reusable loaded executable image.
_Avoid_: partial execution image, cached failed binding, Lane callback during load

**Implementation Resource Limit**:
A host-specific resource ceiling below the schema's `u32` capacity that rejects loading without declaring the image malformed.
_Avoid_: bytecode-declared quota, universal host maximum, type verifier

**Execution Resource Limit**:
A configured logical call-depth or live-heap-byte boundary whose exhaustion uses private fatal cleanup and terminates the current execution.
_Avoid_: load-time ResourceLimit, native stack trap, serialized bytecode limit

**Execution Interruption**:
An out-of-band stop requested by the host or engine, with no guaranteed ownership unwind and no permission to resume the instance.
_Avoid_: Lane exception, runtime import result, bytecode fuel instruction

**Engine Trap**:
A non-unwinding backend failure such as native stack exhaustion or a direct Wasm trap, reported with non-portable best-effort detail.
_Avoid_: private fatal cleanup, recoverable result, reusable instance

**Private Wasm Fatal Exception**:
The backend-only `exnref` signal for runtime-import failure, OOM, ARC overflow,
and other fatal execution errors requiring ownership cleanup.
_Avoid_: Lane value, effect, recoverable status

### Wasm Backend

**Pure Wasm Compiler Package**:
The cross-target `loisvm/wasm/compiler` package that lowers a LoisVM Bytecode Image into a WebAssembly module without loading, instantiating, JIT-compiling, or executing it. The native `loisvm/wasm` package owns Wasmoon integration and delegates code generation to this package.
_Avoid_: Wasmoon loader, execution instance, browser host, direct Buslane-to-Wasm lowering

**Wasm Compiled Tier**:
The compiled execution path that lowers decoded LoisVM bytecode into a
WebAssembly module and executes it with Milky2018/wasmoon by default.
_Avoid_: direct Buslane-to-Wasm backend, direct ANF-to-Wasm backend, MilkIR tier

**Default Wasmoon Engine**:
The project-controlled WebAssembly engine used by default for Lane compiled
execution. Its interpreter, JIT, runtime integration, and supported WebAssembly
capabilities may evolve with Lane.
_Avoid_: fixed third-party feature matrix, browser portability guarantee, LoisVM interpreter

**Lane Wasm Feature Profile**:
The Lane v1 compiled-output contract using one canonical non-shared wasm32
linear memory. The emitter may use Multi-value, Reference Types, Typed Function
References, Tail Call, Bulk Memory, Exception Handling with `exnref`,
Sign-extension Operators, and Extended Constant Expressions. It excludes Stack
Switching, Relaxed SIMD, Threads, Atomics, Multiple Memories, Memory64, Wasm GC,
and Wasmoon-specific module semantics.
_Avoid_: plain WebAssembly 1.0 label, Wasm GC profile, private Wasmoon opcode

**Wasm Linear-Memory ARC Heap**:
The Lane-owned dynamic object heap implemented in wasm32 linear memory,
including allocation, object layout, non-atomic counts, destruction, and
recursive release.
_Avoid_: Wasm GC object, host-managed object graph, tracing collector

**Packed Wasm Callable**:
The Wasm `i64` lowering of one callable value: low 32 bits are the `FunctionId`
or Wasm table index and high 32 bits are the wasm32 environment offset. Zero
environment denotes a capture-free function.
_Avoid_: LoisVM closure heap layout, tag-payload pair, Wasm GC reference

**Canonical Wasm Lane Entry ABI**:
The typed Wasm ABI with hidden `env:i32` first, hidden `LayoutId:i32` witnesses
next, and user values in erased Wasm representations after them. V1 returns zero
or one result, and full signatures are interned for typed indirect calls.
_Avoid_: LoisVM VMValue ABI, result memory cell, untyped table call

**Lane Wasm Module ABI**:
The external module contract exporting `"lane.entry":() -> ()`, canonical
memory, and restricted runtime-service helpers while importing registry symbols
from `"lane.runtime.v1"`.
_Avoid_: source module exports, arbitrary Lane function exports, Component ABI
