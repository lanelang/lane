# LoisVM

LoisVM is the portable bytecode and interpreter module used by Lane linked
program artifacts. It owns the bytecode execution model independently from the
Lane compiler front end and the Lane command-line tool.

## Language

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
The execution-only bytecode payload occupying every byte after the linked-program schema version inside a v1 Lane `.lbp` payload and decoded by `loisvm/bytecode`.
_Avoid_: whole `.lbp` artifact, Lane artifact header, section directory, source map section

**LoisVM Interpreter Package**:
The `loisvm/interp` package that owns bytecode execution, VM values, call
frames, closures, and runtime-import invocation.
_Avoid_: bytecode data model, compiler optimization pass, CLI command parser

**VM Value**:
The uniform tagged runtime value stored in bytecode local slots, including
primitive cases such as `Double`.
_Avoid_: Lane type object, typed unboxed slot, Buslane interpreter value

**Image Constant Pool**:
The single image-wide v1 table of deduplicated ASCII String constants referenced
through zero-based `ConstantId` values.
_Avoid_: per-function constant table, function table, debug metadata

**Inline Scalar Constant**:
An Int, Double, or Bool literal encoded directly in its producing instruction instead of the image constant pool.
_Avoid_: numeric ConstantId, boxed primitive, host-endian encoding

**Integer Undefined Behavior**:
Invalid Lane v1 integer execution such as signed overflow, zero division, or an out-of-range shift count, for which wrapping or trapping backend behavior is permitted.
_Avoid_: checked result, big integer semantics, recoverable error

**Non-Unwinding Arithmetic Trap**:
A direct execution-engine trap from undefined integer division that skips private fatal cleanup and invalidates the current instance.
_Avoid_: exnref cleanup, Lane exception, resumable trap

**Explicit Numeric Conversion**:
An Int/Double conversion opcode emitted only for explicit Lane conversion, with defined rounding or truncation semantics.
_Avoid_: implicit coercion, erasure bridge, bit reinterpretation

**Representation Erasure Bridge**:
A compiler-internal consuming operation between a natural representation and erased `I64` that transfers ownership while changing width, bit interpretation, or cleanup interpretation.
_Avoid_: source conversion, generic heap box, runtime typecase

**Non-Unwinding Conversion Trap**:
A direct trap from NaN, infinite, or out-of-range Double-to-Int conversion that bypasses private cleanup and invalidates the instance.
_Avoid_: saturation, private fatal exception, conversion status

**Canonical Boolean Scalar**:
The `I32 + Trivial` Bool value restricted to zero or one in valid bytecode execution.
_Avoid_: arbitrary nonzero truth, boxed Bool, host boolean object

**Image String Constant**:
A deduplicated ASCII literal whose runtime value is an image-owned immortal String object.
_Avoid_: dynamic String, inline String operand, host-managed text

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

**Representation Layout Witness**:
A hidden `LayoutId` descriptor retained in erased bytecode for a generic runtime
representation. It provides the layout and ownership operations needed when the
Wasm tier lowers a generic value to an `i64` erased payload.
_Avoid_: full Lane type, source type argument, dynamic typecase

**Image Layout Table**:
The image-owned static table of backend-independent Layout Recipes indexed by
immediate `LayoutId` values and used to derive representation, sizing, alignment,
and ownership behavior.
_Avoid_: dynamic type object, heap descriptor, reference-counted metadata

**Portable Layout Recipe**:
The tagged Unit, Bool, Int, Double, Callable, String, Data, or Environment recipe
serialized for one LayoutId before backend-specific descriptor materialization.
_Avoid_: source type descriptor, Wasm helper index, raw member offset

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

**Structured Bytecode Addressing**:
The serialized model where functions own ordered `BlockId` and `SlotId` spaces,
fix `BlockId = 0` as entry, and encode control-flow
targets as block identifiers rather than instruction byte offsets.
_Avoid_: relative PC, byte address, Wasm label depth

**Canonical Bytecode Function Body**:
The byte-length-delimited body payload ordered as slot table, inputs, result descriptor, then nonempty block table, with no entry-block field.
_Avoid_: entry BlockId operand, block length, extensible field map

**Bytecode Edge Record**:
The target BlockId and counted ordered source SlotIds transferred in parallel only when that edge is selected.
_Avoid_: fallthrough, branch byte offset, implicit operand-stack merge

**Tag Switch Terminator**:
The decision-tree terminator that interprets an `I32 + Trivial` tag as unsigned and selects a dense case edge or mandatory default.
_Avoid_: full pattern match, LayoutId branch, source constructor identity

**Trusted Unreachable Terminator**:
The zero-operand terminator for compiler-proven impossible paths, which may trap directly if malformed trusted execution reaches it.
_Avoid_: Runtime Import Failure, private fatal unwind, Lane exception

**Representation-Homogeneous Slot**:
A `SlotId` with one fixed erased Wasm representation and ownership category.
Slot reuse is allowed only between compatible logical values.
_Avoid_: Lane source type, arbitrary tagged reuse, Wasm memory frame requirement

**Slot Representation Tag**:
The physical scalar class `I32`, `I64`, or `F64` assigned to one v1 bytecode slot; `Unit` has no slot representation.
_Avoid_: Lane source type, interpreter VMValue tag, cleanup rule

**Slot Cleanup Category**:
The serialized runtime cleanup behavior `Trivial`, `OwnedRef`, `OwnedCallable`, or `OwnedErased`, without encoding a source ownership type or borrow region.
_Avoid_: borrow checker state, implicit retain, source lifetime

**Erased Ownership Companion**:
The immutable `I32 + Trivial` layout-witness slot referenced by an `I64 + OwnedErased` slot for descriptor-directed cleanup.
_Avoid_: source type argument, owned metadata, dynamic typecase

**Bytecode Function Inputs**:
The initial slots established before entry-block execution, ordered as optional environment, layout witnesses, then user arguments.
_Avoid_: block parameters, source binders, call operands

**Optional Slot Reference**:
The shared `slot_plus_one:u32le` encoding where zero is absent and nonzero N denotes `SlotId = N - 1`.
_Avoid_: presence tag, invalid SlotId sentinel, nullable tagged value

**Derived Indirect Call Shape**:
The exact Wasm function type obtained from value-call arguments plus a returning destination or enclosing tail-result descriptor without a serialized shape ID.
_Avoid_: source function type, CallShapeId table, unchecked table signature

**LoisVM Bytecode Schema Version**:
The independent leading `u8`, `0x01` for v1, governing the tables, records, opcodes, and operand layouts of one LoisVM bytecode section.
_Avoid_: artifact container version, linked-program schema version, Buslane codec version

**Atomic Bytecode Load**:
The all-or-nothing path from complete section decoding through import binding and backend construction to publication of one reusable loaded executable image.
_Avoid_: partial execution image, cached failed binding, Lane callback during load

**Implementation Resource Limit**:
A host-specific resource ceiling below the schema's `u32` capacity that rejects loading without declaring the image malformed.
_Avoid_: bytecode-declared quota, universal host maximum, type verifier

**Loaded Executable Image**:
The reusable successfully decoded and bound bytecode product, including optional reusable backend compilation state, used to create fresh executions.
_Avoid_: active execution heap, partial load result, mutable call stack

**Single-Shot Execution Instance**:
The thread-confined frames, dynamic heap, allocator state, runtime context, and limits used by one selected-entry attempt and never reused afterward.
_Avoid_: loaded image, resumable failure, concurrent VM

**Execution Resource Limit**:
A configured logical call-depth or live-heap-byte boundary whose exhaustion uses private fatal cleanup and terminates the current execution.
_Avoid_: load-time ResourceLimit, native stack trap, serialized bytecode limit

**Execution Interruption**:
An out-of-band stop requested by the host or engine, with no guaranteed ownership unwind and no permission to resume the instance.
_Avoid_: Lane exception, runtime import result, bytecode fuel instruction

**Engine Trap**:
A non-unwinding backend failure such as native stack exhaustion or a direct Wasm trap, reported with non-portable best-effort detail.
_Avoid_: private fatal cleanup, recoverable result, reusable instance

**Dense Bytecode Identifier Space**:
An ordered bytecode table whose entry position supplies its identifier, reserving zero for `FunctionId` and `LayoutId` but not for block, slot, constant, or object-shape identifiers.
_Avoid_: sparse map, repeated serialized ID, instruction offset

**Build-Local FunctionId**:
A dense execution-image function index reproducible for identical build inputs but permitted to change whenever the final optimized body list changes.
_Avoid_: stable ABI name, persisted function reference, call-graph hash

**Fixed-Shape Opcode Encoding**:
The instruction representation where one `u8` opcode or terminator tag selects an exact operand sequence and unknown tags are malformed bytecode.
_Avoid_: instruction byte length, unknown-opcode preservation, self-describing record

**Bytecode Tag Namespace**:
An independently decoded `u8` variant domain with explicit wire assignments, invalid `0x00` and `0xFF`, and no dependence on implementation enum order.
_Avoid_: global tag space, enum ordinal serialization, escape opcode

**Canonical V1 Opcode Table**:
The fixed wire mapping of 66 instructions over `0x01..0x42` and seven terminators over an independent `0x01..0x07` namespace.
_Avoid_: interpreter dispatch index, Wasm opcode number, opcode alias

**Wasm CFG Structuring**:
The backend mapping from LoisVM CFG to typed Wasm locals and structured control,
with temporary locals for parallel edge transfer and a `loop` plus `br_table`
fallback for irreducible CFGs.
_Avoid_: bytecode verifier, irreducible-CFG rejection, mandatory Wasm block parameters

**Lane ARC Object Header**:
The common 8-byte header addressed by a nonzero eight-byte-aligned Wasm object
reference: `ref_count:u32`, then `LayoutId:u32`, then payload at offset eight.
_Avoid_: payload address, Wasm GC object, allocator metadata

**Immortal Refcount Sentinel**:
The `0xFFFF_FFFF` count stored in image-owned static object headers. Generic
retain and release leave such objects unchanged.
_Avoid_: dynamic count value, saturating ARC, pointer-range ownership test

**Local Constructor Tag**:
A dense `u32` discriminator scoped to one nominal data type and stored as the
first word of a data object payload. Match instructions branch on this value.
_Avoid_: LayoutId, Buslane constructor identity, global table index

**Object Shape**:
The zero-based canonical member schema whose Data variant includes constructor tag and fields and whose Environment variant includes captures without a tag, with stored-witness ordinals but no raw offsets or alignment fields.
_Avoid_: runtime LayoutId, raw offset list, variable-size String layout

**Layout Operand**:
The five-byte operand selecting Immediate `0x01` with nonzero LayoutId or Witness `0x02` with a trivial `I32` witness SlotId.
_Avoid_: ObjectShapeId, descriptor address, source type witness

**Field Projection Result**:
The value destination SlotId and witness-destination OptionalSlot produced for one selected member.
_Avoid_: raw heap load, source match binder, implicit erased companion

**Typed Data Payload Layout**:
The `ObjectShape::Data`-defined placement of local tag, stored generic layout witnesses,
and user fields according to erased Wasm representation, alignment, and cleanup.
_Avoid_: flat tagged-value table, uniform field stride, source object layout

**Nullary Constructor Singleton**:
An immortal image-owned data object used for a constructor with no user fields
and no generic layout witnesses required by later destruction.
_Avoid_: dynamic allocation, observable pointer singleton, source constant

**Typed Closure Environment Layout**:
The immutable erased-representation layout of captured fields and stored generic
layout witnesses after a common ARC header. It has no constructor tag and no
strong backreference to recursive group callables.
_Avoid_: mutable environment map, flattened user parameters, closure cycle

**Materialized Layout Descriptor**:
The 32-byte static record at `layout_table_base + LayoutId * 32` containing
representation, size, alignment, and typed ownership-helper table indices.
_Avoid_: full Lane type, dynamic object, variable-length descriptor

**Layout Helper Entry**:
An internal function-table entry used by layout-driven ARC, destruction, or
size calculation and excluded from the Lane callable `FunctionId` range.
_Avoid_: runtime import, bytecode target, first-class function value

**Canonical Lane Memory Export**:
The module-defined non-shared wasm32 memory exported as `"lane.memory"`, with
image static data below immutable `heap_base:i32` and the module-owned ARC heap
above it.
_Avoid_: imported host memory, Memory64, second Lane memory

**Private Wasm Fatal Exception**:
The backend-only `exnref` signal for runtime-import failure, OOM, ARC overflow,
and other fatal execution errors requiring ownership cleanup.
_Avoid_: Lane value, effect, recoverable status

**Lane Wasm Module ABI**:
The external module contract exporting `"lane.entry":() -> ()`, canonical
memory, and restricted runtime-service helpers while importing registry symbols
from `"lane.runtime.v1"`.
_Avoid_: source module exports, arbitrary Lane function exports, Component ABI

**Runtime Service Nested Call**:
A RuntimeContext call to an approved non-Lane service export such as
`"lane.runtime.string.new"` while a host import is active, without permission to
invoke entry, closures, or ordinary `FunctionId` targets.
_Avoid_: Lane callback, general same-instance reentry, asynchronous host call

**Static Wasm Image Initialization**:
The instantiation-time population of image-owned memory and function-table
contents through active data and element segments, without a Wasm start
function.
_Avoid_: Lane entry initialization, lazy static object creation, runtime linker

**Canonical Wasm Function Table**:
The single private fixed-capacity `funcref` table whose invalid zero entry is
followed by the Lane `FunctionId` range and then internal layout helpers.
_Avoid_: exported table, growable registry, multiple tables

**Block Parameter Transfer**:
The control-flow operation that assigns a target block's ordered parameter
slots from an incoming edge's ordered source slots in parallel.
_Avoid_: sequential move semantics, function call, operand-stack merge

**Trusted Bytecode Image**:
A decoded LoisVM image assumed to satisfy bytecode invariants because it was
emitted by the matching Lane linker.
_Avoid_: verified bytecode, untrusted artifact, sandbox input

**Direct Call**:
A returning non-terminating LoisVM instruction that calls an immediate function-table identifier, supplies a hidden closure environment exactly when required, and carries a destination only for a non-`Unit` result.
_Avoid_: closure-value call, dynamic function reference, tail call, source call

**Unified Function Table**:
The image-global `FunctionId` index space containing tagged bytecode-body and
runtime-import entries.
_Avoid_: bytecode-only function index, separate runtime-call table, operation table

**Selected Bytecode Entry**:
The nonzero FunctionId stored in executable bytecode for the link-validated
no-context, witness-free, zero-argument Unit body invoked by execution.
_Avoid_: source export symbol, runtime entry selection, runtime import

**Runtime Import Entry**:
A unified function-table entry containing a stable runtime symbol and erased ABI
descriptor instead of a LoisVM bytecode body.
_Avoid_: effect operation entry, per-call symbol lookup, synthetic bytecode stub

**Runtime Import ABI V1**:
The fixed-arity host-call ABI that receives an implicit runtime context followed
by uniform VM values and returns exactly one owned VM value.
_Avoid_: Lane source signature, varargs, typed unboxed bytecode ABI

**Runtime Symbol Registry**:
The runtime-owned mapping from a stable symbol and ABI major version to its
primitive signature and resolved host implementation.
_Avoid_: bytecode type metadata, per-call symbol lookup, duplicated signature table

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

**Runtime String Object**:
An immutable ARC object with `byte_length:u32` at object offset eight and ASCII
bytes at offset twelve, with total size rounded to eight-byte alignment.
_Avoid_: mutable bytes, NUL-terminated C string, parent-backed slice

**String Primitive**:
A dedicated LoisVM length, concatenation, slicing, or equality instruction over
immutable ASCII Runtime String Objects.
_Avoid_: generic String dispatch, host text operation, raw memory access

**Borrowed Host String View**:
A temporary non-owning view of a VM String's ASCII bytes exposed only during one
synchronous runtime-import invocation.
_Avoid_: retained host pointer, copied input, owned string result

**Resolved Runtime Binding**:
The loaded-image target obtained by resolving one runtime import entry before
execution begins.
_Avoid_: serialized host pointer, per-call plugin lookup, FunctionId

**Callable Value**:
A first-class function value represented by an immediate capture-free
`FunctionId` or a reference-counted closure pair of `FunctionId` and environment.
_Avoid_: separate runtime-function value, mandatory empty closure, source function

**Callable Construction**:
The creation of a no-context callable by `const_function` or a context-requiring
callable by consuming one nonzero environment owner in `make_closure`.
_Avoid_: implicit environment retain, closure layout operand, mandatory shell allocation

**Value Call**:
A fused returning non-terminating LoisVM instruction that calls a callable value
from a local slot, carries a destination only for a non-`Unit` result, and does
not expose callable-tag dispatch or closure-environment extraction to bytecode.
_Avoid_: closure unpack instruction, direct immediate target, closure-only call, tail call

**Consuming Callable Projection**:
The internal value-call step that consumes one callable owner and establishes an
owned callee environment through a unique move or shared retain path.
_Avoid_: uniqueness requirement, public closure unpack, unconditional environment retain

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

**Immediate Value**:
A directly tagged LoisVM value such as `Int`, `Double`, `Bool`, `Unit`, or a
function identifier that does not participate in reference counting.
_Avoid_: dynamic object, image-owned object, boxed primitive

**Image-Owned Static Object**:
An immutable constant-pool object whose lifetime is owned by the loaded LoisVM
image and whose retain and release operations are omitted or no-ops.
_Avoid_: dynamic RC object, copied literal, independently unloadable object

**Thread-Confined Heap**:
The dynamic heap owned by one LoisVM instance and accessed by only one thread,
allowing reference counts and uniqueness checks to be non-atomic.
_Avoid_: shared concurrent heap, atomic RC, cross-thread value

**Continuation Closure**:
A reusable lowered continuation represented by the ordinary LoisVM closure
pair of a function identifier and reference-counted environment.
_Avoid_: dedicated continuation object, captured VM stack, host closure

**Effect-Erased Image**:
A LoisVM bytecode image produced only after `mon-trans`, `open-resolve`, and
`monadic-lift` have eliminated effect-specific forms and dispatch structures.
_Avoid_: perform instruction, handler context, operation table

**Tail Call**:
A direct or callable-value call terminator with no normal return continuation in the
current bytecode function.
_Avoid_: value-producing call instruction, return, ordinary jump

**Return Terminator**:
The function terminator carrying one source OptionalSlot, consuming a non-Unit result owner or returning Unit when the field is zero.
_Avoid_: ordinary call, tail call, implicit frame cleanup

**Ownership-Empty Exit**:
A return or tail transfer reached after explicit releases remove every current-frame owner not transferred by that exit.
_Avoid_: frame scan, unconsumed owned local, fatal unwind

## Relationships

- `loisvm/bytecode` defines the portable bytecode image and binary codec.
- `loisvm/interp` executes a bytecode image and depends on
  `loisvm/bytecode`.
- `loisvm/bytecode` owns the **LoisVM Bytecode Section** format, not the whole
  `.lbp` linked artifact container.
- A v1 `.lbp` payload contains `linked_program_schema_version:u32le = 4` and then
  one bytecode section occupying the payload remainder. It has no nested length
  or section directory.
- The outer linked payload does not duplicate the selected entry or runtime
  imports and carries no module provenance or backend profile. Its in-memory
  artifact model contains the decoded bytecode image rather than opaque bytes.
- `lanec` lowers linked and optimized Buslane/core into **LoisVM Bytecode**,
  but does not own the bytecode data model.
- LoisVM v1 defines the final linked bytecode image stored in `.lbp`; it does
  not define a relocatable per-module bytecode form for `.lmo`.
- LoisVM v1 has one **Image Constant Pool** per bytecode image. Functions do
  not own local constant tables; their instructions refer to the image-wide
  String pool through constant identifiers. Numeric and function constants are
  encoded directly in producing instructions.
- LoisVM v1 has one **Unified Function Table**. `FunctionId` indexes either a
  bytecode body or a **Runtime Import Entry**; it does not imply that the target
  has bytecode instructions.
- The bytecode section stores one **Selected Bytecode Entry** before the function
  count. FunctionId is one-based over zero-based table position, and zero count
  is invalid.
- Bytecode bodies follow final deterministic post-optimization body-list order
  and precede runtime imports. Imports serialize ABI major, user arity, and
  nonempty case-sensitive ASCII symbol, are tuple-deduplicated, and sorted.
- FunctionIds are **Build-Local FunctionIds** reproducible only for identical
  compiler version, inputs, options, and selected entry. Build changes may
  renumber them; selected entry is explicit rather than forced to ID one, and
  FunctionId is not a persistent or module ABI identity.
- Loading an image resolves every runtime import's stable symbol and erased ABI
  descriptor into a **Resolved Runtime Binding**. Missing or incompatible
  imports fail image loading rather than becoming per-call lookup failures.
- A runtime import symbol carries its ABI major version, and **Runtime Import ABI
  V1** records one fixed explicit arity. Loading checks symbol, version, and
  arity before accepting the binding.
- The **Runtime Symbol Registry** alone defines each symbol's primitive argument
  and result kinds. Bytecode does not serialize those kinds again; its import
  descriptor contains only the versioned symbol and arity.
- `lanec` checks the registry signature before erasing types. A loaded trusted
  image therefore permits the runtime binding to assume that uniform VM value
  operands carry the registry-defined primitive tags.
- Runtime import invocation has the logical shape `(RuntimeContext,
  VMValue...) -> VMValue`. The context is implicit and borrowed, explicit
  arguments are uniform VM values, and the result is one owned VM value. V1 has
  no varargs, multiple results, source types, or per-parameter representation
  kinds.
- Runtime imports are **Synchronous Primitive Host Calls**. They cannot suspend,
  re-enter Lane program execution, callback into Lane code, or retain VM values
  beyond the call. A restricted **Runtime Service Nested Call** may invoke an
  approved allocator or String service that cannot dispatch a Lane callable.
- The only permitted argument and result kinds are `Int`, `Double`, `Bool`,
  `String`, and `Unit`. Closures, data values, environments, function
  identifiers, and opaque handles cannot cross the runtime-import boundary.
- Runtime binding state belongs to the loaded image and is not serialized as a
  host pointer. Ordinary calls dispatch by tagged function entry and use the
  cached binding without runtime string lookup.
- `lane exec` loads a linked artifact, extracts **LoisVM Bytecode**, and runs
  it through `loisvm/interp`.
- The **Wasm Compiled Tier** consumes the same decoded **LoisVM
  Bytecode** as `loisvm/interp`. LoisVM bytecode remains the common executable
  input rather than being bypassed by a parallel lowering from Buslane or ANF.
- Generated modules follow the **Lane Wasm Feature Profile**. Wasmoon may
  recognize and optimize Lane patterns or extend its implementation of standard
  capabilities, but those extensions do not change the generated module language.
- The profile admits Multi-value, Reference Types, Typed Function References,
  Tail Call, and Bulk Memory instructions while excluding Wasm GC.
- Memory64 is excluded. Lane heap and environment references remain wasm32
  offsets, preserving the packed 32-bit function/environment callable format.
- Multiple Memories is excluded from Lane output. Memory zero contains the
  dynamic heap, image-owned constants, layout metadata, and runtime-visible byte
  buffers, and every Lane reference is an offset into that memory.
- Threads and Atomics are excluded from Lane output. Memory zero is non-shared,
  a Lane instance is not entered concurrently, and all ARC operations remain
  non-atomic. Separate instances may execute on different host threads.
- Bulk Memory may initialize image data and tables, fill allocator storage, and
  copy raw bytes. It does not copy owned reference fields without the explicit
  ARC operations required to establish new owners.
- Exception Handling with `exnref` is used only by the Wasm tier to unwind fatal
  runtime-import failures. Cleanup handlers release frame-local owners and
  rethrow; the exception is not observable as a Lane value or bytecode edge.
- Sign-extension Operators and Extended Constant Expressions may appear in
  generated modules. Non-trapping Float-to-int, Fixed-width SIMD, Branch
  Hinting, Wide Arithmetic, Custom Page Sizes, and Memory Control are recognized
  future options but are not emitted or required by Lane v1.
- Stack Switching and Relaxed SIMD are excluded from Lane v1 output.
- Import/Export Mutable Globals, Compilation Hints, WASI Preview 1, the Component
  Model with WASI Preview 2, and JS BigInt-to-`i64` integration are aware-only
  host or deployment capabilities.
- Multiple Tables and Relaxed Dead-code Validation are excluded. Packed
  `FunctionId` values address one canonical table and generated code passes
  ordinary strict validation.
- JS Promise Integration, JS String Builtins or String References, and Custom
  Descriptors or JS Interop are excluded from the Lane runtime boundary.
- Extended Name Sections, Custom Annotations, Rounding Variants, Half Precision,
  Flexible Vectors, Type Imports, and the JIT Interface are aware-only features.
- Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are
  excluded from Lane v1 output.
- Dynamic Lane objects lower to the **Wasm Linear-Memory ARC Heap**. The Wasm
  tier implements the same explicit retain, release, ownership-transfer,
  construction, and consuming-projection semantics as the interpreter and does
  not use Wasm GC for Lane objects.
- Source types and source-level type arguments are erased before LoisVM, but
  representation signatures and hidden **Representation Layout Witnesses**
  remain where generic ownership or Wasm lowering needs them. Monomorphic
  values use native Wasm representations; generic values use `i64` erased
  payloads governed by their witnesses.
- A **Representation Layout Witness** is an immediate index into the **Image
  Layout Table** and has no ARC behavior. Generic objects retain the identifiers
  required to destroy erased fields, and the compiler passes any required
  derived layouts as additional hidden witnesses instead of constructing them
  at runtime.
- The Wasm tier represents both immediate function identifiers and closures as
  **Packed Wasm Callables**. It reserves linear-memory offset zero for the
  capture-free case, passes the unpacked environment as the hidden call
  argument, and uses the unpacked function identifier for typed
  `call_indirect`.
- Each owned packed callable with a nonzero environment directly owns one ARC
  reference to that environment. Retain and release operate on the environment,
  and consuming invocation transfers that owner into the callee without a
  closure-shell uniqueness branch.
- Although Typed Function References are allowed by the output profile, the
  canonical packed callable uses `call_indirect` and `return_call_indirect`.
  Backend-local uses of `call_ref` or `return_call_ref` must not change callable
  heap storage, ownership, or generic `i64` erasure.
- All Wasm Lane targets use the **Canonical Wasm Lane Entry ABI**. Direct and
  indirect calls share one entry shape, capture-free targets receive `env = 0`,
  generic witnesses are non-owning immediates, and runtime-import adapters expose
  the same entry ABI before invoking host imports.
- Each bytecode function uses **Structured Bytecode Addressing** and contains an
  ordered block table, **Representation-Homogeneous Slots**, instruction
  arrays, and explicit terminators. No branch stores a byte displacement.
- A bytecode section begins with **LoisVM Bytecode Schema Version** `0x01` for
  v1 and carries no duplicate magic inside the enclosing `.lbp` section.
- The Lane artifact codec supplies the exact remaining-payload slice and
  delegates decoding to `loisvm/bytecode`; successful linked-artifact decoding
  therefore yields a typed bytecode image.
- Canonical linked-artifact inspection shows schema versions, selected entry,
  table summaries, and bytecode disassembly. Malformed offsets remain relative
  to this section even when a CLI also reports an absolute file offset.
- Schema counts have no normative maxima below `u32`. Decoding uses checked
  arithmetic and minimum-size preflight, while **Implementation Resource Limits**
  may reject otherwise valid images.
- **Atomic Bytecode Load** finishes decoding before import resolution, executes
  no Lane code during binding, discards partial state after failure, and publishes
  a reusable **Loaded Executable Image** only after interpreter or Wasm backend
  construction succeeds.
- Every run creates a fresh **Single-Shot Execution Instance**. Success, runtime
  failure, resource exhaustion, interruption, or trap makes it terminal.
- `loisvm/interp` uses an explicit frame stack. Entry depth is one; returning
  bytecode-body calls increase depth, tail calls preserve it, and imports do not
  create Lane frames. Generated Wasm enforces the same logical depth rule.
- Per-execution call-depth and canonical live-heap-byte bounds are **Execution
  Resource Limits** and use private fatal cleanup. They are host configuration,
  not image fields.
- V1 has no bytecode fuel, instruction budget, deadline, or portable timeout.
  **Execution Interruption** and **Engine Traps** may skip cleanup and require
  whole-instance discard.
- Successful return performs no defensive ownership scan or release sweep before
  the single-shot instance is destroyed.
- RuntimeImportFailure, ExecutionResourceLimit, Interrupted, EngineTrap, and
  InternalRuntimeFailure are shared execution categories across interpreter and
  Wasm tiers; backend trap text is supplementary.
- Failures distinguish unsupported schema, malformed encoding, unresolved import,
  ABI mismatch, resource limit, and backend compilation failure; diagnostics use
  section-relative offsets or runtime symbols as applicable.
- **Dense Bytecode Identifier Spaces** use `u32le` IDs. `FunctionId` and
  `LayoutId` begin at one, while `BlockId`, `SlotId`, `ConstantId`, and
  `ObjectShapeId` begin at zero. Counts and byte lengths also use `u32le`.
- Instructions and terminators have separate `u8` **Fixed-Shape Opcode
  Encodings**. Operand shape comes from the tag, unknown tags are rejected, and
  individual instructions have no byte-length prefix.
- Each **Bytecode Tag Namespace** assigns known values contiguously from `0x01`,
  reserves `0x00` and `0xFF`, and is immutable within one schema version. Any
  accepted-tag change requires a schema-version bump.
- V1 representation tags are I32/I64/F64 = `0x01`/`0x02`/`0x03`; cleanup tags
  are Trivial/OwnedRef/OwnedCallable/OwnedErased = `0x01` through `0x04`; result
  tags are Unit/I32/I64/F64 = `0x01` through `0x04`.
- Function-entry tags are BytecodeBody/RuntimeImport = `0x01`/`0x02`; Layout
  Recipe tags follow Unit through Environment at `0x01..0x08`; Object Shape and
  LayoutOperand tags are Data/Environment and Immediate/Witness, each
  `0x01`/`0x02`.
- The **Canonical V1 Opcode Table** maps instructions to `0x01..0x42` and
  terminators to independent `0x01..0x07`. Calls returning to their block are
  instructions; CFG transfers, returns, tail calls, and unreachable are final
  terminators excluded from `instruction_count`.
- Portable v1 contains no nop, opcode alias, generic operation subtag, embedded
  source location, profiling instruction, or debug instruction.
- A **Canonical Bytecode Function Body** is byte-length-delimited, completely
  consumed, and ordered as slot table, function inputs, result descriptor, then
  block table.
- Block count is nonzero; table order implies `BlockId`, block zero is entry and
  has no parameters, and each block stores counted unique parameter slots,
  counted instructions, then one terminator without a block length.
- Slot-table order implies `SlotId`, each slot stores representation and cleanup
  tags, and only `OwnedErased` appends a companion SlotId. Records have no
  alignment padding; `i64` and `f64`
  constants preserve raw little-endian bits.
- V1 **Slot Representation Tags** are exactly `I32`, `I64`, and `F64`. `Unit`
  occupies no slot; returning calls encode an optional result slot and use
  `None` when the target returns `Unit`.
- **Slot Cleanup Categories** are `Trivial`, `OwnedRef`, `OwnedCallable`, and
  `OwnedErased`. `OwnedRef` releases an `I32` object reference; `OwnedCallable`
  releases the packed `I64` environment; `OwnedErased` uses its **Erased
  Ownership Companion** to release an `I64` payload.
- The companion is an `I32 + Trivial` slot and remains unchanged while its
  payload owner is live. Final bytecode has no `Borrowed` category; block-local
  non-owning references use `Trivial` and cannot cross ownership boundaries.
- A bytecode body records **Bytecode Function Inputs** separately from block
  parameters. Environment uses zero or `SlotId + 1`; counted `I32 + Trivial`
  witness SlotIds precede counted user argument SlotIds, and all are distinct.
- The body result descriptor is one Unit/I32/I64/F64 tag. Unit has no result
  slot; return and destination slots, rather than the descriptor, carry
  cleanup categories.
- Every **Optional Slot Reference** is one `u32le` zero or `SlotId + 1`;
  environments, call destinations, return sources, and projection witness
  destinations use that form.
- Every other SlotId operand is direct zero-based `u32le`. SlotId zero remains
  valid for `make_closure`; the referenced owned environment value is nonzero.
- Slot arrays encode a `u32le` count followed by exact SlotIds. `call_direct`
  stores target, environment, witnesses, users, then destination; `call_value`
  stores callable, witnesses, users, then destination.
- Witness and Trivial user arguments are read non-consumingly. Owned user
  arguments transfer; direct calls consume a nonzero environment, and value
  calls consume the callable.
- There is no serialized call-shape table. Wasm value-call lowering constructs a
  **Derived Indirect Call Shape** from call-site slot tags. Runtime-import
  adapters use registry signatures, and all matching is trusted bytecode state.
- A **Return Terminator** carries one source OptionalSlot and consumes a non-Unit
  source owner into the caller. Normal return never scans the frame; explicit
  releases establish an **Ownership-Empty Exit** for all other owners.
- `tail_call_direct` carries target, environment OptionalSlot, counted witnesses,
  and counted user arguments. `tail_call_value` carries callable and both arrays.
  Neither has a destination, and each consumes all transferred operands.
- Untransferred owned slots are explicitly released before tail transfer. The
  target result representation equals the current function result descriptor,
  which supplies the result part of a derived indirect-tail call shape.
- Wasm uses `return_call` and `return_call_indirect`. Runtime-import tail calls
  obey the same transfer; adapter failure occurs after the replaced frame is
  ownership-empty.
- Explicit **Bytecode Edge Records** contain target, argument count, and exact
  SlotIds. `jump` has one edge; `branch_bool` has an `I32 + Trivial` condition
  followed by true and false edges.
- A **Tag Switch Terminator** is one discriminator in a lowered pattern decision
  tree. It uses unsigned comparison, permits zero dense cases, always stores a
  default edge, and never falls through by table order.
- Only the selected edge transfers arguments, in parallel. Trivial sources are
  read and may repeat; owned sources are consumed and may not repeat without
  prior retain-copy. Edge ranges, arity, representation, cleanup, and ownership
  matching remain trusted compiler invariants.
- A **Trusted Unreachable Terminator** may lower to direct Wasm `unreachable`
  without private exception cleanup. Boolean control uses `if` or `br_if`, while
  dense tag dispatch preferentially uses `br_table` during CFG structuring.
- LoisVM has no generic assignment. **Trivial Slot Copy** is non-consuming and
  restricted to `Trivial`; **Ownership Move** consumes a compatible source
  without ARC; **Retain Copy** establishes an owned destination and supports
  both owned duplication and borrow promotion.
- Every producing, copy, move, or retain-copy destination is logically dead.
  `release(slot)` consumes one owner. Move and release do not clear physical
  source bits, and overwriting never performs implicit release.
- Retain-copy and release dispatch through `OwnedRef`, `OwnedCallable`, or
  `OwnedErased`; erased operations use the companion witness. Applying ARC to a
  `Trivial` owner is invalid trusted bytecode, not no-op semantics.
- Wasm lowering uses typed local operations and ARC helpers. The backend or
  Wasmoon may remove redundant moves and balanced retain-copy/release pairs,
  while ordinary `local.set` remains ownership-neutral.
- `const_int`, `const_double`, and `const_bool` emit **Inline Scalar Constants**
  using `i64le`, raw binary64 bits, and canonical Bool byte zero or one. Other
  Bool bytes fail decoding; Unit has no slot and no constant instruction.
- `const_function` writes a capture-free callable with environment zero.
  `const_string` writes an owned logical reference to an **Image String
  Constant** selected by `ConstantId`.
- `const_layout` writes a nonzero image LayoutId into an `I32 + Trivial` witness
  slot without using the String constant pool.
- V1 **Image Constant Pool** entries are reachable Strings only. Exact ASCII
  bytes are deduplicated and sorted lexicographically as unsigned raw bytes;
  zero-based IDs are remapped into `const_string`, and empty String is ID zero
  when present.
- Wasm active data segments materialize immortal pooled Strings, and
  `const_string` lowers to a static address without retaining it.
- Integer opcodes cover signed `I64 + Trivial` arithmetic, remainder, bitwise
  operations, shifts, and comparisons. Overflow and invalid shift counts are
  **Integer Undefined Behavior**, so Wasm wrapping and low-six-bit shift masking
  are valid implementations.
- Zero division, `MIN_INT / -1`, and zero remainder may cause a
  **Non-Unwinding Arithmetic Trap**. No private cleanup runs; the current
  instance is discarded and cannot resume or receive another entry call.
- Integer comparisons and `bool_not`, `bool_eq`, and `bool_ne` produce
  **Canonical Boolean Scalars**. Short-circuit Bool and/or use CFG terminators.
- Double opcodes use Wasm binary64 add, subtract, multiply, divide, negate, and
  six comparisons. IEEE-754 division, signed zero, infinity, and NaN comparison
  behavior applies; arithmetic may canonicalize or otherwise change NaN payloads.
- LoisVM bytecode performs no implicit Int/Double conversion; only the defined
  **Explicit Numeric Conversion** opcodes cross those numeric types.
- `int_to_double` is an **Explicit Numeric Conversion** using signed i64-to-f64
  nearest-ties-even rounding; precision loss is allowed. `double_to_int`
  truncates toward zero.
- Invalid Double-to-Int conversion may cause a **Non-Unwinding Conversion Trap**.
  No private cleanup runs, the instance is discarded, and v1 has no saturating
  conversion opcode.
- **Representation Erasure Bridges** are unsigned `erase_i32`/`unerase_i32`,
  identity-bit `erase_i64`/`unerase_i64`, and bitwise `erase_f64`/`unerase_f64`.
  Each consumes its source and transfers ownership without ARC.
- Trusted representation and companion metadata establishes bridge validity.
  Int and Callable use identity-bit I64 bridges rather than ordinary movement;
  erasure operations are never source-level implicit conversions.
- Every erased endpoint is `I64 + OwnedErased`, including no-op primitive
  layouts. Erase reads an initialized destination companion and unerase reads
  the source companion; bridge instructions carry no witness operand.
- One immutable companion may serve several live erased payloads and becomes
  reusable only after all are consumed. Calls perform no implicit erasure.
- Natural Unit has no slot, while generic Unit uses canonical `I64 0 +
  OwnedErased` with a nonzero no-op Unit LayoutId. `erase_unit` has only a
  destination and `unerase_unit` only a source.
- Zero-based `ObjectShapeId` selects an **Object Shape**, separate from runtime
  `LayoutId`. Data and Environment variants compute field or capture offsets;
  runtime layout metadata controls allocation and ARC.
- `make_env` encodes destination, direct zero-based Environment shape, **Layout
  Operand**, counted witness slots, and counted capture slots. It reads Trivial
  inputs, consumes owned captures, and publishes only a fully initialized dead
  `I32 + OwnedRef` destination.
- `borrow_capture` preserves its explicit environment source and returns a
  block-local borrowed result. `consume_captures` consumes one environment owner
  and returns selected captures as owners through equivalent unique/shared paths.
- Consuming capture indices are strictly increasing and may be empty.
- Capture-free functions use environment zero, have no Environment Object Shape,
  and execute no `make_env`.
- `make_data` encodes destination, direct zero-based Data shape, **Layout
  Operand**, counted witness slots, and counted field slots. The shape supplies
  constructor tag; Trivial inputs are read, owned fields are consumed, and all
  observable state is initialized before publication.
- `load_tag` reads without consuming object ownership. `borrow_field` preserves
  the object and writes a **Field Projection Result**; reference values use
  `Trivial`, and erased generic fields also return the stored witness.
- `consume_fields` consumes the object and writes a possibly empty strictly
  increasing selected-result sequence while releasing unselected fields, using
  equivalent unique-move and shared-retain execution paths.
- Field indices are local to a constructor shape and require prior constructor
  selection under the trusted contract. LoisVM data instructions contain no raw
  heap offsets, loads, or stores.
- Object Shapes omit alignment and offsets. Data layout is header, tag, contiguous
  u32 witnesses, then aligned fields; Environment omits the tag. I32 uses four-
  byte size/alignment, I64/F64 eight, and total size rounds to eight.
- Member schemas encode representation, cleanup, and witness ordinal plus one.
  Exact shapes are deduplicated and sorted Data-first, then Environment.
- **Wasm CFG Structuring** maps bytecode slots to typed locals, performs parallel
  block-parameter transfer through temporaries, emits structured control for
  reducible CFGs, and retains a dispatcher fallback for irreducible CFGs.
- Dynamic Wasm references point to a **Lane ARC Object Header**. Allocation
  returns a nonzero aligned pointer with count one, while layout-specific rules
  provide fixed or variable allocation size outside the common header.
- Static objects use the **Immortal Refcount Sentinel**. A dynamic retain cannot
  enter that value; overflow is fatal. Release to zero invokes the layout
  destructor before allocator free.
- Data payloads begin with a type-local **Local Constructor Tag**. Pattern
  matching reads that tag, while `LayoutId` identifies the **Typed Data Payload
  Layout** and destructor rather than the constructor's semantic identity.
- Generic data fields use `i64` erased storage and retain required hidden layout
  witnesses in the payload. Eligible fieldless constructors use **Nullary
  Constructor Singletons** and perform no dynamic allocation.
- Closure environments use **Typed Closure Environment Layouts**. Allocation and
  one-time initialization consume captures into typed fields, generic captures
  preserve required witnesses, and capture-free functions use environment zero.
- Recursive groups share an environment without storing member callables. Wasm
  may scalar-replace a non-escaping environment without changing LoisVM or ARC
  semantics.
- `LayoutId = 0` is invalid. The immutable global `layout_table_base:i32` points
  to static **Materialized Layout Descriptors** with 32-byte stride. Fixed and
  variable size paths report complete allocation size including the ARC header.
- Portable bytecode instead stores deduplicated **Portable Layout Recipes** after
  the function table. Used primitive recipes come first, followed by Data and
  Environment recipes ordered by ObjectShapeId; recipes contain no helper indices.
- Layout retain/release helpers use `(i64) -> ()`, destroy uses `(i32) -> ()`,
  and variable sizing uses `(i32) -> i32`. Their **Layout Helper Entries** occupy
  the canonical Wasm table but cannot be packed into Lane callables.
- Generated modules own and export the **Canonical Lane Memory Export**. Address
  zero is reserved, static data and layout descriptors occupy low addresses,
  and immutable `heap_base` begins the aligned dynamic heap.
- The thread-confined allocator uses bump allocation, reusable free lists, and
  `memory.grow`. Reused payload is not zeroed; initialization completes before
  publication. OOM and ARC overflow throw a **Private Wasm Fatal Exception**;
  free, destruction, and cleanup do not throw.
- The **Lane Wasm Module ABI** exports only `"lane.entry":() -> ()` as a Lane
  program entry, plus `"lane.memory"` and restricted runtime-service exports. It
  imports stable runtime symbols from `"lane.runtime.v1"` using natural Wasm
  primitive signatures. No other Lane function is exported.
- `"lane.entry"` invokes the linked selected zero-argument `Unit` function.
  Private fatal exceptions may escape this wrapper for Wasmoon to catch and
  convert into fatal execution failure.
- **Static Wasm Image Initialization** uses active data and element segments and
  no start function. Instantiation establishes static memory, immutable globals,
  allocator state, and the **Canonical Wasm Function Table**.
- The function table is private and fixed at its exact emitted size. Index zero
  is invalid; indices `1..N` directly map Lane `FunctionId` values, including
  runtime-import adapters; layout helpers follow. Entry and runtime-service
  wrappers are not table entries or callable values.
- Canonical memory has no declared maximum. Its initial 64-KiB page count is the
  minimum covering `heap_base`; dynamic allocation grows memory as required.
- Every LoisVM bytecode payload is an **Effect-Erased Image**. Effect-specific
  forms and runtime operation dispatch have been replaced by ordinary functions,
  closures, data, calls, control flow, and runtime function or intrinsic calls
  before bytecode construction.
- Non-entry LoisVM blocks may declare parameter slots, and jumps or branches supply
  matching edge argument slots. `loisvm/interp` performs the resulting **Block
  Parameter Transfer** in parallel, while the **Wasm Compiled Tier** preserves
  the same parameter and edge relationships through Wasm CFG lowering.
- Reference-bearing block parameters are **Owning Block Parameters**. The
  selected edge performs **Edge Ownership Transfer** and does not implicitly
  retain or release its argument values.
- Supplying one owner to multiple parameters on the selected edge requires
  explicit **Retain Copies** for the additional owners. Merely mentioning
  the same value on mutually exclusive branch edges does not create multiple
  runtime owners.
- Loop backedges use the same ownership transfer. Compiler-inserted releases
  dispose of overwritten logical parameter ownership, and slot allocation must
  preserve that behavior when reusing physical slots.
- LoisVM v1 provides both **Direct Call** and **Value Call** instructions.
  Lowering uses **Direct Call** for a statically known function-table target and
  **Value Call** for a first-class **Callable Value** stored in a slot.
- Those instructions and **Tail Call** apply uniformly when the selected
  `FunctionId` names bytecode or a runtime import. LoisVM defines no
  `call_runtime` instruction and no separate runtime-function identifier space.
- Each function-table entry declares a **Function Context Kind** separately from
  its user arity. A **Direct Call** supplies a **Closure Environment Reference**
  exactly when the target requires one; capture-free entries receive no context
  operand.
- **Direct Call** and **Value Call** continue with the next instruction in their
  current block. A non-`Unit` call writes one owned destination slot; a `Unit`
  call carries no destination `SlotId`. They are not block terminators.
- **Direct Call**, **Value Call**, and **Tail Call** use the **Callee-Owned Call
  ABI**. Reference-bearing user arguments and a required closure environment
  transfer ownership into the callee; a returning non-`Unit` call places one
  owned result in its destination slot.
- `lanec` emits a **Retain Copy** into a fresh owner slot when the caller still
  needs a transferred argument. A compiler-proven last use transfers its
  existing ownership without incrementing the count.
- A **Callable Value** is either an immediate `FunctionId` or a closure. An
  immediate identifier must target an entry with no closure context; a closure
  supplies the identifier and required environment. The trusted bytecode
  contract establishes this correspondence.
- **Callable Construction** writes a logically dead `I64 + OwnedCallable` slot.
  `const_function` names a no-context target; `make_closure` names a
  context-requiring target and consumes one nonzero environment owner without
  layout, shape, or call-signature operands.
- The interpreter allocates a count-one closure shell for `make_closure`; Wasm
  packs FunctionId and environment into `i64` without allocation.
- Callable `copy` is invalid. `move`, `retain_copy`, and `release` explicitly
  transfer, duplicate, or destroy callable ownership.
- **Value Call** encapsulates callable-tag dispatch and closure extraction.
  LoisVM exposes no instruction that unpacks a closure into code and environment
  values; `loisvm/interp` obtains the identifier and optional **Closure
  Environment Reference** internally and enters the same function ABI as
  **Direct Call**.
- A runtime import target has no bytecode body. `loisvm/interp` invokes its
  **Resolved Runtime Binding**, while the **Wasm Compiled Tier** emits a Wasm
  import or an adapter to one for the same function entry.
- Reference-bearing runtime-import arguments use the **Callee-Owned Call ABI**.
  The **Runtime Context** is host state rather than an owned operand and does not
  participate in retain, release, or Lane-level arity.
- Runtime imports must consume or release every transferred argument on success
  and failure. `String` follows ordinary reference-count ownership; the other
  permitted host-call kinds are immediate.
- Dynamic Strings are immutable **Runtime String Objects**. Constant-pool
  strings are image-owned static values with the same logical length-and-bytes
  access contract. Neither form requires NUL termination.
- Dynamic, constant, and empty Strings use the same Wasm layout. Static forms
  use the immortal count; no form stores capacity or cached hash.
- A runtime import accesses an owned String argument through a **Borrowed Host
  String View**. This is a zero-copy read whose lifetime ends before the
  synchronous import returns; the host cannot retain the pointer or view.
- The borrowed view exposes `(string_ref + 12, byte_length)`. Returned host bytes
  are copied into one exact-size allocation and checked for ASCII. Physical Wasm
  imports receive String input as `(bytes_ptr:i32, byte_length:i32)`.
- A physical Wasm import returns String as one owned `string_ref:i32` already
  referring to a new Lane String. RuntimeContext obtains it through the approved
  `"lane.runtime.string.new":(i32) -> i32` service, writes validated bytes through
  `"lane.memory"`, and returns the reference. This **Runtime Service Nested Call**
  cannot invoke Lane entry, a closure, or an ordinary `FunctionId`.
- Invalid returned bytes or service failure produce a **Runtime Import Failure**
  through the **Private Wasm Fatal Exception**.
- V1 **String Primitives** are `string_length`, `string_concat`, `string_slice`,
  and `string_eq`. Length and equality borrow their operands; concatenation
  consumes two owners and slicing consumes one.
- String indices are Lane Int ASCII byte indices. Empty concatenation and complete
  slicing may move an input owner without allocation; proper slices create
  independent copies rather than parent-backed views.
- Invalid ranges, length or address overflow, and allocation failure use the
  private fatal path and make the instance unusable.
- A successful runtime import returns one owned primitive VM value. A **Runtime
  Import Failure** produces no value and aborts the current execution; LoisVM
  does not expose an exceptional successor, catch instruction, or effect path
  for that failure.
- After the failing binding consumes or releases its transferred arguments,
  LoisVM releases remaining owned call-frame and slot values while unwinding the
  aborted execution.
- Recoverable host outcomes use ordinary primitive results. The runtime
  registry may implement its physical native failure channel with a status and
  out parameter or a failure callback, but that choice is not bytecode ABI
  metadata.
- Dedicated VM primitives remain ordinary LoisVM opcodes. Runtime imports are
  reserved for host/runtime capabilities and do not replace arithmetic,
  comparison, closure, data, or reference-count instructions.
- The **Wasm Compiled Tier** reads known runtime symbols from the same **Runtime
  Symbol Registry** when constructing Wasm imports or adapters. The physical
  Wasm signature and String representation do not change serialized LoisVM
  bytecode and remain backend-profile decisions.
- **Value Call** consumes its callable operand. An immediate `FunctionId` has no
  ownership work. A closure uses **Consuming Callable Projection** internally.
- When the closure has reference count one, the VM moves its environment into
  the callee and frees the closure shell. When the closure is shared, the VM
  retains the environment for the callee and releases only the consumed closure
  owner, preserving other closure owners.
- The reference-count check selects an optimization path and is not a validity
  precondition for calling a shared closure.
- A **Closure Environment Reference** is hidden frame context, not a Lane-level
  function parameter. Captured values are accessed through dedicated capture
  operations rather than flattened call arguments.
- LoisVM v1 uses **Environment Construction** followed by closure creation.
  Recursive environments store shared outer captures but do not strongly store
  the group closure objects that reference the same environment.
- **Environment Construction** fully initializes every environment field in one
  operation. LoisVM exposes neither general environment mutation nor an
  explicit seal operation.
- **Capture Projection** explicitly names an environment source and shape-local
  capture index without exposing a physical heap offset.
- Dynamically allocated LoisVM values are **Reference-Counted Objects**. The
  execution image contains explicit **Retain Copy** and **Release** instructions
  inserted by `lanec`; `loisvm/interp` does not infer reference-count changes
  from ordinary slot assignments.
- `lanec` determines ownership on a compiler-private virtual-value CFG before
  physical slot allocation and LoisVM bytecode construction. LoisVM owns the
  emitted reference-count operations, not the ownership analysis or its
  intermediate representation.
- Capture and data-field projections may be **Borrowing Reads**. LoisVM does not
  encode a general borrowed-value type or borrow region; `lanec` guarantees that
  the owner stays live for every same-block use.
- A borrowing-read result never crosses a block edge, consuming call, return, or
  object-storage boundary without a preceding **Retain Copy** that establishes owned
  lifetime. Function parameters, results, block parameters, and object fields
  are owned.
- Data construction, **Environment Construction**, closure creation, and
  continuation-closure construction use **Consuming Object Construction**. Their
  reference-bearing operands transfer ownership into stored fields.
- `lanec` emits a **Retain Copy** when a construction operand remains needed elsewhere,
  and promotes a borrowing-read result before storing it. Object destruction
  releases every reference-bearing field owned by that object.
- Closure creation consumes one ownership of its **Closure Environment
  Reference**. Multiple closures sharing one environment therefore require
  distinct strong environment owners.
- **Borrowing Data Projection** leaves object ownership unchanged and follows
  the block-local borrowing contract. **Consuming Data Projection** consumes one
  object owner and yields owned selected payloads.
- For a uniquely owned data object, consuming projection moves selected fields,
  releases unselected owned fields, and frees the object shell. For a shared
  object, it retains selected fields and releases the consumed object owner.
  Both paths implement the same instruction semantics.
- The runtime reference-count check selects an optimization path and is not a
  bytecode validity precondition. Constructor-selected match arms may use the
  consuming form when `lanec` chooses to consume the scrutinee.
- Primitive tagged values and function identifiers are **Immediate Values** and
  carry no reference count.
- Constant-pool strings and future immutable constant entries are
  **Image-Owned Static Objects**. **Retain Copy** and **Release** do not modify their counts.
- Runtime-created strings, data values, closures, environments, and
  **Continuation Closures** are **Reference-Counted Objects**. A dynamic object's
  owned field may hold a static object without changing a count.
- A loaded LoisVM image outlives all execution values that can reference its
  static objects. V1 does not unload an image while those values remain live.
- Each LoisVM instance owns a **Thread-Confined Heap**. Dynamic values, closure
  environments, and continuation closures do not cross threads, and one instance
  is not entered concurrently.
- **Retain Copy**, **Release**, reference-count equality checks, and consuming
  projection fast paths use non-atomic counters. The **Wasm Compiled Tier** must
  preserve the same confinement semantics as `loisvm/interp`.
- Future concurrency requires a new explicit shared or atomic ownership
  boundary; it does not retroactively make all v1 counts atomic.
- A reusable resume value is a **Continuation Closure** and is invoked through
  ordinary **Value Call** or callable-value **Tail Call**. Multiple consuming resume
  uses require **Retain Copies** for all uses that must preserve a later owner.
- Proven one-shot continuations may lower to **Direct Call** or linear control
  flow and avoid closure allocation. LoisVM has no dedicated continuation
  object, stack snapshot, or continuation-specific RC instruction.
- LoisVM has no `perform`, `resume`, or `handle` instruction, no operation
  identifier or runtime operation table, and no handler-context object or call
  ABI. External runtime effects arrive only as already resolved ordinary runtime
  function or intrinsic calls.
- A retained copy executes **Retain Copy** to establish another owner. A
  compiler-proven last use may instead perform an **Ownership Transfer** and
  consume the source ownership without incrementing the count.
- Wasm lowering or the Wasmoon JIT may optimize redundant reference-count operations,
  but interpretation and unoptimized native lowering are already correct from
  the emitted ownership operations.
- The packed Wasm callable representation has no closure shell. Compiler-emitted
  callable retains establish additional environment owners, so consuming Wasm
  invocation transfers one environment owner without a shell-count branch.
- Recursive group calls use known function identifiers plus the shared
  environment, and first-class member values construct closures from that pair
  when required. The environment never strongly owns those group closures, so
  the closure-to-environment edge does not form a reference-count cycle.
- LoisVM v1 has no tracing collector or runtime cycle collector. Compiler
  lowering for closures and reusable continuations must avoid unreclaimable
  strong cycles.
- A direct call to a capturing function may avoid closure-object allocation and
  indirect dispatch, but it does not guarantee elimination of the environment.
- LoisVM uses distinct direct and callable-value **Tail Call** terminators for calls
  that have no normal return continuation in the current function.
- A **Tail Call** transfers argument and required closure-environment ownership
  directly into the replacement frame and does not return an owned value to the
  current frame.
- LoisVM v1 does not provide a bytecode verifier. `loisvm/interp` and the
  **Wasm Compiled Tier** consume a **Trusted Bytecode Image** and rely on `lane
  link` to establish control-flow, slot, arity, and table-reference invariants.
  The generated WebAssembly module must still satisfy WebAssembly validation.
- The bytecode codec still performs strict binary decoding. Successful decoding
  establishes that bytes match the serialized schema, not that the decoded
  bytecode is semantically well formed.
- LoisVM bytecode is not an untrusted-code or sandbox boundary. Behavior for a
  decodable image that violates bytecode invariants is outside the supported
  execution contract.
- Buslane remains the semantic core and reference-interpreter language; LoisVM
  is an execution target, not the source of Lane semantics.
