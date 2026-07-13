# Lane Runtime And Execution

This context names execution targets, interpreter runtime concepts, builtin
runtime plugins, and runtime error boundaries.

## Language

**Execution Target**:
A way to execute a checked Lane program, such as an interpreter or a bytecode virtual machine.
_Avoid_: host target, MoonBit target, backend platform

**Reference Interpreter**:
The first execution target, currently evaluating verified Buslane programs, that defines observable Lane/Core behavior.
_Avoid_: source interpreter, bytecode VM

**Interpreter Entry Selection**:
The rule that a caller chooses which checked value or function to evaluate rather than the interpreter hard-coding `main`.
_Avoid_: built-in main, source entrypoint

**Run Entry Convention**:
The Lane Command convention that `lane run` selects an **Executable Entry Type** directly and `lane link` selects one for a linked artifact executed later by `lane exec`.
_Avoid_: language-level main semantics, project entrypoint, arbitrary value inspection

**Run Effect Convention**:
The Lane Command convention that an executable selected entry may leave a specific outer effect set for the command to handle.
_Avoid_: language-level main effect, Basic library effect, compiler-builtin effect

**Executable Entry Type**:
The function type shape accepted by `lane run` and by `lane link` when producing a runnable linked artifact.
_Avoid_: language main type, pure value entry, unchecked effectful entry

**Runtime Effect Handler**:
An execution-target handler for an operation that escapes all source-level lexical handlers to the outer runtime boundary.
_Avoid_: source effect handler, handler override, unsafe builtin plugin

**Runtime Effect Convention**:
A command/runtime rule that maps a source-level exported effect operation identity and signature to a host-provided **Runtime Effect Handler**.
_Avoid_: Buslane debug-name binding, operation-number API, official Basic-library pinning

**Interpreter Value**:
A uniform runtime value used by the reference interpreter.
_Avoid_: unboxed primitive special case, source AST node

**Global Environment**:
The interpreter environment containing initialized linked top-level values.
_Avoid_: module namespace, source scope

**Call Frame**:
The interpreter environment for a single function call or local evaluation scope.
_Avoid_: global scope, closure object

**Closure Environment**:
The immutable captured context stored with a first-class function value, represented in Wasm as a common ARC header followed by typed capture fields and required generic layout witnesses.
_Avoid_: call frame, lambda-lifted parameter list, mutable capture dictionary

**Tail-Call Optimization**:
The execution property where an explicit bytecode tail-call terminator replaces the current frame rather than adding a normal return continuation.
_Avoid_: automatic optimization of every returning call, source-level tail annotation, return followed by call

**Builtin Runtime Plugin**:
An execution-time extension that supplies behavior for unsafe builtin intrinsic names according to the compiler core contract.
_Avoid_: compiler intrinsic table, hard-coded primitive

**Builtin Dispatch Key**:
The intrinsic name and typed expected type used to select or call a builtin runtime plugin entry.
_Avoid_: name-only builtin lookup, type-checked intrinsic

**Runtime Error Report**:
An execution-target diagnostic result that reports interpreter or plugin failure without becoming a Lane language-level exception.
_Avoid_: catchable exception, panic

**Integer Undefined Behavior**:
Out-of-contract Lane v1 behavior caused by signed overflow, division by zero, or an invalid shift count, permitting direct wrapping or trapping execution.
_Avoid_: checked arithmetic, arbitrary precision integer, recoverable runtime result

**Non-Unwinding Arithmetic Trap**:
A direct engine trap from undefined integer division that bypasses private fatal cleanup and requires discarding the current execution instance.
_Avoid_: private Wasm exception, Lane error value, resumable execution

**Explicit Numeric Conversion**:
A bytecode conversion between Int and Double emitted only for an explicit Lane operation and governed by specified rounding or truncation.
_Avoid_: implicit promotion, erasure operation, bit reinterpretation

**Representation Erasure Bridge**:
A compiler-internal consuming conversion between a natural representation and erased `I64`, transferring ownership while changing width, bit interpretation, or cleanup interpretation.
_Avoid_: source conversion, generic box, runtime type reflection

**Non-Unwinding Conversion Trap**:
A direct invalid Double-to-Int trap that bypasses private cleanup and requires discarding the current execution instance.
_Avoid_: saturating result, exnref cleanup, recoverable conversion

**Canonical Boolean Scalar**:
The valid `I32 + Trivial` Bool representation restricted to zero or one.
_Avoid_: arbitrary nonzero truth, boxed Bool, host-language boolean

**Bytecode VM**:
A future execution target that runs a linked bytecode image while preserving the observable behavior of the reference interpreter.
_Avoid_: semantic source of truth, linker replacement, Buslane verifier

**LoisVM**:
The independent bytecode execution module containing the bytecode definition and bytecode interpreter packages.
_Avoid_: lanec internal VM, lane command runtime, Buslane interpreter

**Bytecode Image**:
The lowered execution payload stored in a linked program artifact for the bytecode VM.
_Avoid_: module object, interface artifact, canonical Buslane/core

**Executable-Only Linked Artifact**:
A `.lbp` artifact whose v1 payload contains only linked-program schema version 4 and one self-contained bytecode image, without embedded linked Buslane/core or duplicated entry and import metadata.
_Avoid_: semantic inspect artifact, section directory, module object bundle, debug source map

**Canonical Linked Disassembly**:
The deterministic lowered-code view produced by `lane inspect` for `.lbp`, including schema versions, selected entry, table summaries, and canonical bytecode instructions.
_Avoid_: raw byte dump, source reconstruction, Buslane pretty output

**Erased Bytecode**:
Bytecode that removes Lane source types, source-level type arguments, and debug metadata while retaining only representation signatures and hidden layout witnesses required for Wasm lowering and generic ownership.
_Avoid_: source-typed bytecode, bytecode verifier type system, full runtime type reflection

**Bytecode Function**:
A bytecode image component containing one function's instruction sequence, frame local layout, and capture layout.
_Avoid_: source function declaration, Buslane function expression, whole linked program

**Local Slot**:
A bytecode call-frame location that stores a runtime value and is addressed directly by register-style bytecode instructions.
_Avoid_: operand stack cell, Buslane value identity, source local variable

**VM Value**:
The uniform tagged runtime value stored in bytecode local slots, with primitive values represented as value cases rather than a typed unboxed slot ABI.
_Avoid_: Lane type object, per-slot static representation, heap-only boxed object

**Bytecode Block**:
A labeled straight-line instruction sequence with ordered parameter slots inside a bytecode function, ending in an explicit terminator instruction.
_Avoid_: source block, ANF expression body, lexical scope

**Block Edge Argument**:
A source local slot supplied by a bytecode control-flow edge for one ordered parameter slot of its target block.
_Avoid_: function call argument, operand stack value, implicit phi input

**Bytecode Terminator**:
A bytecode operation that transfers control out of the current block, such as a jump or branch with target edge arguments, a return, or a tail call.
_Avoid_: expression result, source return statement, implicit fallthrough

**Mid-Level Bytecode Instruction**:
A VM instruction that directly represents primitive arithmetic or a runtime semantic operation without exposing machine heap layout details.
_Avoid_: source operator syntax, builtin plugin call, raw tagged-word operation

**Direct Call Instruction**:
A returning non-terminating bytecode call whose target is an immediate function-table identifier, whose hidden closure-environment operand is present exactly when required, and whose destination exists only for a non-`Unit` result.
_Avoid_: closure-value call, dynamic dispatch, tail call, source call syntax

**Unified Bytecode Function Table**:
The image-global `FunctionId` index space containing tagged bytecode-body entries and runtime-import entries.
_Avoid_: bytecode-only function index, separate runtime-call table, effect operation table

**Selected Bytecode Entry**:
The nonzero FunctionId stored in executable bytecode for the link-validated no-context, witness-free, zero-argument Unit body invoked by execution.
_Avoid_: source export symbol, runtime entry selection, runtime import

**Runtime Import Entry**:
A function-table entry containing a stable runtime symbol and erased runtime ABI descriptor instead of a bytecode body.
_Avoid_: runtime effect operation, per-call plugin lookup, synthetic wrapper body

**Runtime Import ABI V1**:
The fixed-arity host-call contract where an implicit runtime context and uniform VM-value arguments produce exactly one owned VM value.
_Avoid_: source function type, varargs contract, typed unboxed bytecode ABI

**Runtime Symbol Registry**:
The runtime-owned mapping from a stable symbol and ABI major version to its primitive signature and host implementation.
_Avoid_: bytecode type table, per-call plugin lookup, duplicated compiler signature

**Runtime Context**:
Borrowed host state supplied implicitly to runtime imports for allocator, I/O, and other runtime services.
_Avoid_: Lane parameter, handler context, owned VM value

**Synchronous Primitive Host Call**:
A v1 runtime import that completes before VM execution continues, cannot re-enter Lane program execution, retains no VM values after return, and accepts or returns only primitive values; approved runtime-service nested calls are not Lane reentry.
_Avoid_: asynchronous import, host callback into Lane, closure argument, opaque handle result

**Runtime Import Failure**:
An out-of-band execution error from a runtime import that returns no Lane value and fatally terminates the current LoisVM execution.
_Avoid_: catchable Lane exception, effect operation, normal status result

**Loaded Executable Image**:
A reusable loaded bytecode product containing resolved imports and optional backend compilation state, from which a fresh execution instance is created for each run.
_Avoid_: active heap, partial loader result, mutable call stack

**Single-Shot Execution Instance**:
The thread-confined call frames, dynamic heap, allocator, runtime context, and resource configuration consumed by exactly one selected-entry attempt.
_Avoid_: reusable loaded image, concurrent execution, resumed trap

**Execution Resource Limit**:
A host-configured logical call-depth or canonical live-heap-byte boundary that reports cleanup-capable fatal execution failure when exceeded.
_Avoid_: load-time ResourceLimit, malformed image, engine-native stack overflow

**Execution Interruption**:
An external host or engine stop that may bypass ARC cleanup and always invalidates the current execution instance.
_Avoid_: Lane exception, ordinary cancellation value, portable timeout opcode

**Engine Trap**:
A non-unwinding backend failure carrying best-effort implementation detail, such as native stack overflow or a direct Wasm trap.
_Avoid_: Runtime Import Failure, Execution Resource Limit, resumable execution

**Runtime String Object**:
An immutable ARC object with `byte_length:u32` at object offset eight and ASCII bytes beginning at offset twelve, rounded to eight-byte allocation alignment.
_Avoid_: mutable host buffer, C string, parent-retaining slice view

**String Primitive Instruction**:
A dedicated LoisVM instruction for immutable ASCII String length, concatenation, slicing, or equality.
_Avoid_: generic String dispatch, host text operation, raw memory access

**Borrowed Host String View**:
A zero-copy non-owning byte view of an owned String argument that is valid only during one synchronous runtime import.
_Avoid_: retained host pointer, copied input, owned result buffer

**Runtime Import Binding**:
The execution-target callable resolved from a runtime import entry while loading the linked bytecode image.
_Avoid_: serialized host pointer, runtime symbol string dispatch, Buslane external value

**Callable Value**:
A first-class bytecode function value represented by an immediate capture-free `FunctionId` or a reference-counted closure containing a function identifier and environment.
_Avoid_: separate runtime-function value, mandatory empty closure, source declaration

**Callable Construction**:
The creation of a no-context callable by `const_function` or a context-requiring callable by consuming one nonzero environment owner in `make_closure`.
_Avoid_: implicit environment retain, closure layout operand, mandatory shell allocation

**Value Call Instruction**:
A fused returning non-terminating bytecode call whose target is a callable value in a local slot, whose destination exists only for a non-`Unit` result, and whose tag dispatch and optional captured environment remain encapsulated by execution.
_Avoid_: closure unpack instruction, exposed environment argument, direct immediate target, closure-only call

**Consuming Callable Projection**:
The internal value-call operation that consumes one callable owner and obtains owned callee context through a unique closure move or shared closure retain.
_Avoid_: unique-only call, public closure projection, unconditional retain

**Function Context Kind**:
Function-table metadata declaring that a bytecode function either has no hidden context or requires an opaque closure environment reference.
_Avoid_: Lane function arity, runtime guess, environment field layout

**Closure Environment Reference**:
The opaque hidden context installed in a capturing lifted function's frame and used by capture access operations.
_Avoid_: user argument, closure object, flattened capture parameters

**Environment Construction Instruction**:
A consuming bytecode operation that fully initializes an immutable closure environment from an Environment Object Shape, runtime layout, stored witnesses, and captures before publication.
_Avoid_: separate uninitialized allocation, general mutation, closure creation

**Capture Projection Instruction**:
A borrowing or consuming bytecode operation that explicitly names an Environment Object Shape, environment source slot, and shape-local capture index.
_Avoid_: implicit current-frame access, raw heap offset, source name lookup

**Reference-Counted Object**:
A dynamically allocated LoisVM value whose lifetime is controlled by explicit compiler-inserted retain-copy and release operations.
_Avoid_: tracing-GC object, unmanaged pointer, source ownership annotation

**Ownership Transfer**:
A last-use movement of an owned reference into a destination without incrementing its reference count.
_Avoid_: retained copy, borrowed use, bitwise pointer move

**Trivial Slot Copy**:
The `copy(dst, src)` instruction that duplicates equal-representation `Trivial` slots without consuming the source or performing ARC.
_Avoid_: owned duplication, implicit retain, generic assignment

**Ownership Move**:
The `move(dst, src)` instruction transferring a compatible logical value and ownership to a dead destination without changing counts or clearing bits.
_Avoid_: retained copy, overwrite cleanup, memory move

**Retain Copy Instruction**:
The `retain_copy(dst, src)` operation that copies equal-representation bits and applies the destination cleanup category to establish one new owner.
_Avoid_: unary retain, trivial copy, ownership transfer

**Release Instruction**:
A compiler-inserted bytecode operation that removes one strong owner and destroys the object when its count reaches zero.
_Avoid_: tracing collection, cycle collection, source destructor

**Callee-Owned Call ABI**:
The bytecode calling convention where reference-bearing arguments and any required closure environment become owned by the callee and a returned value becomes owned by the caller.
_Avoid_: borrowed-argument convention, caller-released parameters, ownership-neutral return

**Owning Block Parameter**:
A bytecode block parameter that receives one owned reference from the selected incoming edge.
_Avoid_: borrowed phi value, implicit retained copy, source parameter

**Edge Ownership Transfer**:
The parallel control-flow transfer that consumes owned edge arguments and establishes ownership in the corresponding target block parameters.
_Avoid_: implicit retain, borrowed jump argument, sequential assignment

**Block-Local Borrow**:
A non-owning reference produced by a borrowing read whose owner remains live for all uses in the current basic block.
_Avoid_: owned slot value, borrowed block parameter, persisted borrow region

**Borrow Promotion**:
The compiler-generated retain that establishes owned lifetime before a borrowed reference crosses an ownership boundary.
_Avoid_: last-use ownership transfer, implicit copy, source clone

**Consuming Object Construction**:
The ownership convention where object-building instructions transfer reference-bearing operands into owned fields without implicitly retaining them.
_Avoid_: borrowed field storage, constructor-internal retain, ownership-neutral allocation

**Borrowing Data Projection**:
A data-field read that preserves the object owner and produces a block-local borrowed reference for a reference-bearing field.
_Avoid_: owned field result, consuming match, destructive read

**Consuming Data Projection**:
A runtime data operation that consumes one object ownership and returns selected payload fields as owned values through either a unique move path or a shared retain path.
_Avoid_: borrow-only field access, assumed uniqueness, unchecked field move

**Immediate VM Value**:
A tagged value stored directly in a local slot that requires no allocation or reference count.
_Avoid_: heap object, image constant, boxed primitive

**Image-Owned Static Object**:
An immutable constant-pool object retained by the loaded bytecode image for the full lifetime of values that may reference it.
_Avoid_: dynamic RC object, copied constant, independently unloadable allocation

**Thread-Confined VM Heap**:
A per-instance dynamic heap whose objects and reference counts are accessed by one thread at a time.
_Avoid_: shared concurrent heap, atomic RC, cross-thread VM value

**Continuation Closure**:
A reusable lowered continuation represented as an ordinary bytecode closure with captured state in its reference-counted environment.
_Avoid_: dedicated continuation object, VM stack snapshot, MoonBit closure

**Tail Call Terminator**:
A direct or callable-value call that ends the current bytecode block and has no normal return continuation in the current function.
_Avoid_: returning call instruction, return instruction, ordinary jump

**Return Terminator**:
The bytecode exit carrying one source OptionalSlot, consuming a non-Unit result owner or returning Unit when the field is zero.
_Avoid_: returning call, tail call, implicit frame cleanup

**Ownership-Empty Exit**:
A return or tail terminator reached only after explicit releases remove every current-frame owner not transferred by that exit.
_Avoid_: frame traversal, leaked owner, fatal cleanup handler

**Lowered Continuation**:
A continuation represented after compiler lowering as explicit bytecode control flow or a closure plus captured context.
_Avoid_: host-language closure, implicit VM stack snapshot, source resume binder

**Bytecode Closure**:
A runtime function value consisting of a lifted bytecode function reference and an explicit captured context value.
_Avoid_: nested bytecode function, MoonBit closure, source lambda

**Runtime Data Value**:
A VM value referencing a data object whose payload starts with a nominal-type-local compact constructor tag and whose hidden witnesses and user fields follow a typed bytecode data layout.
_Avoid_: Buslane data constructor identity, image-global constructor tag, flat field table

**Effect-Erased Bytecode Boundary**:
The execution-image invariant established by `mon-trans`, `open-resolve`, and `monadic-lift`: LoisVM receives only ordinary functions, closures, data, calls, control flow, and resolved runtime function or intrinsic calls.
_Avoid_: bytecode perform instruction, handler context, runtime operation table

**Bytecode Constant Pool**:
The image-global v1 table of deduplicated ASCII String constants addressed by zero-based constant identifiers.
_Avoid_: per-function constant table, debug side table, function table, constructor table

**Inline Scalar Constant**:
An Int, Double, or Bool literal encoded directly in its producing bytecode instruction rather than stored in the constant pool.
_Avoid_: numeric ConstantId, boxed primitive, native-endian encoding

**Image String Constant**:
A deduplicated ASCII literal materialized as an image-owned immortal runtime String.
_Avoid_: dynamic String allocation, inline String operand, host text object

**Wasm Compiled Tier**:
The compiled execution tier that lowers decoded LoisVM bytecode into a WebAssembly module and executes it with Milky2018/wasmoon by default.
_Avoid_: direct Buslane-to-Wasm backend, direct ANF-to-Wasm backend, MilkIR tier

**Default Wasmoon Engine**:
The project-controlled WebAssembly engine used by Lane's compiled tier. Its interpreter, JIT, runtime integration, and supported WebAssembly capabilities may be extended alongside Lane.
_Avoid_: fixed third-party feature floor, browser compatibility guarantee, LoisVM interpreter

**Lane Wasm Feature Profile**:
The Lane v1 compiled-output contract based on one canonical non-shared wasm32 linear memory. The emitter may use Multi-value, Reference Types, Typed Function References, Tail Call, Bulk Memory, Exception Handling with `exnref`, Sign-extension Operators, and Extended Constant Expressions. It excludes Stack Switching, Relaxed SIMD, Threads, Atomics, Multiple Memories, Memory64, Wasm GC, and Wasmoon-specific module semantics.
_Avoid_: plain WebAssembly 1.0 label, Wasm GC profile, private Wasmoon opcode

**Wasm Linear-Memory ARC Heap**:
The Lane-owned dynamic object heap implemented in wasm32 linear memory, with explicit allocation, layout, non-atomic reference counts, destruction, and recursive release.
_Avoid_: Wasm GC object, host-owned object graph, tracing collector

**Representation Erasure**:
The lowering that maps monomorphic Lane values to natural Wasm representations while mapping a representation-polymorphic value to an `i64` erased payload plus a hidden layout witness, without preserving full source types.
_Avoid_: whole-program monomorphization, tagged pair for every Wasm value, runtime source typing

**Representation Layout Witness**:
A hidden descriptor identified by `LayoutId` that supplies generic value layout and ownership operations after source type erasure.
_Avoid_: source type argument, user-visible parameter, dynamic type check

**Image Layout Table**:
The image-global static table of backend-independent Layout Recipes indexed by immediate `LayoutId` values and used to derive representation, sizing, alignment, and ownership behavior.
_Avoid_: runtime-created type object, heap descriptor, source type registry

**Portable Layout Recipe**:
The tagged Unit, Bool, Int, Double, Callable, String, Data, or Environment execution recipe serialized for one LayoutId before backend-specific descriptor materialization.
_Avoid_: source type descriptor, Wasm helper index, raw member offset

**Packed Wasm Callable**:
The Wasm `i64` callable representation whose low 32 bits contain the `FunctionId` and whose high 32 bits contain a wasm32 closure-environment offset. Zero environment denotes a capture-free function.
_Avoid_: LoisVM closure object, tag-payload pair, Wasm GC function reference

**Canonical Wasm Lane Entry ABI**:
The typed Wasm function ABI with hidden `env:i32` first, hidden `LayoutId:i32` witnesses next, and user arguments in erased Wasm representations after them. Current v1 functions return zero or one Wasm result and complete signatures are interned in the type section.
_Avoid_: uniform VMValue host ABI, caller result pointer, closure-only adapter entry

**Structured Bytecode Addressing**:
The bytecode encoding where functions own ordered block and slot identifier spaces, fix `BlockId = 0` as entry, and encode branches with `BlockId` and `SlotId` rather than byte offsets.
_Avoid_: relative PC, threaded instruction address, Wasm label depth

**Canonical Bytecode Function Body**:
The byte-length-delimited body payload ordered as slot table, function inputs, result descriptor, then nonempty block table, with no serialized entry identifier.
_Avoid_: entry BlockId field, block byte length, extensible body record

**Bytecode Edge Record**:
The target BlockId plus counted ordered source SlotIds transferred in parallel when the edge is selected.
_Avoid_: fallthrough, relative branch, implicit phi assignment

**Tag Switch Terminator**:
A lowered decision-tree node interpreting an `I32 + Trivial` tag as unsigned and selecting a dense case or mandatory default edge.
_Avoid_: source pattern matcher, LayoutId dispatch, sparse constructor identity table

**Trusted Unreachable Terminator**:
An operand-free terminator for compiler-proven impossible flow that may trap directly if invalid trusted bytecode reaches it.
_Avoid_: recoverable runtime error, private fatal exception, Lane effect

**Representation-Homogeneous Slot**:
A bytecode slot assigned one erased Wasm representation and ownership category for all logical values allocated to it.
_Avoid_: source type slot, arbitrary representation reuse, mandatory memory frame

**Slot Representation Tag**:
The physical scalar class `I32`, `I64`, or `F64` assigned to a v1 bytecode slot; `Unit` occupies no slot.
_Avoid_: source type, interpreter value tag, cleanup behavior

**Slot Cleanup Category**:
The serialized cleanup rule `Trivial`, `OwnedRef`, `OwnedCallable`, or `OwnedErased` attached to a slot without encoding a source ownership type or borrow region.
_Avoid_: source lifetime, borrow checker state, implicit retain policy

**Erased Ownership Companion**:
The stable `I32 + Trivial` layout-witness slot associated with an `I64 + OwnedErased` payload for descriptor-directed cleanup.
_Avoid_: source generic argument, owned descriptor, runtime type object

**Bytecode Function Inputs**:
The ordered initial slots established before entry-block execution: optional environment, representation witnesses, then user arguments.
_Avoid_: entry-block parameters, source parameters, call-site argument list

**Optional Slot Reference**:
The uniform four-byte field where zero means absent and nonzero N means `SlotId = N - 1`.
_Avoid_: explicit option tag, reserved physical SlotId, nullable VM payload

**Derived Indirect Call Shape**:
The exact Wasm function type reconstructed from callable-call arguments plus a returning destination or current tail-result descriptor without a serialized shape identifier.
_Avoid_: source function signature, CallShapeId table, untyped indirect dispatch

**LoisVM Bytecode Schema Version**:
The independent leading `u8`, `0x01` for v1, governing one LoisVM bytecode section's tables, records, opcodes, and operand layouts.
_Avoid_: artifact container version, linked-program schema version, Buslane codec version

**Atomic Bytecode Load**:
The all-or-nothing pipeline from complete decoding through runtime binding and backend construction to publication of an executable instance.
_Avoid_: partially visible image, import lookup during parsing, Lane execution during load

**Implementation Resource Limit**:
A host-specific memory, count, size, or compilation ceiling below schema capacity that rejects loading without making the encoding malformed.
_Avoid_: portable budget table, schema-version feature, bytecode verifier

**Dense Bytecode Identifier Space**:
An ordered bytecode table whose entry position is its identifier, with zero reserved for `FunctionId` and `LayoutId` but valid for block, slot, constant, and object-shape identifiers.
_Avoid_: sparse map, repeated ID field, instruction address

**Build-Local FunctionId**:
A dense function-table index reproducible for one identical build but free to change with compiler, optimization, input, option, or selected-entry changes.
_Avoid_: cross-build function handle, module ABI symbol, hash ID

**Fixed-Shape Opcode Encoding**:
The bytecode form where one `u8` instruction or terminator tag determines the exact following operands and an unknown tag fails decoding.
_Avoid_: per-instruction byte length, unknown-opcode skipping, self-describing record

**Bytecode Tag Namespace**:
An independent `u8` variant domain with explicit serialized values, invalid `0x00` and `0xFF`, and no dependence on compiler enum ordering.
_Avoid_: one global tag enum, implicit variant ordinal, extension escape byte

**Canonical V1 Opcode Table**:
The normative v1 assignment of 66 instruction tags over `0x01..0x42` and seven terminator tags over independent `0x01..0x07`.
_Avoid_: Wasm opcode mapping, runtime dispatch ordinal, opcode synonym

**Wasm CFG Structuring**:
The backend mapping that uses typed locals and temporary parallel edge moves, structures reducible CFGs, and emits a `loop` plus `br_table` dispatcher for irreducible CFGs.
_Avoid_: bytecode CFG restriction, mandatory Multi-value block parameters, branch-offset patching

**Lane ARC Object Header**:
The common 8-byte wasm32 header at every nonzero eight-byte-aligned Lane object reference, containing `ref_count:u32` followed by `LayoutId:u32`; payload begins at offset eight.
_Avoid_: payload pointer, universal object-size field, allocator metadata

**Immortal Refcount Sentinel**:
The `0xFFFF_FFFF` count used by image-owned static objects so retain and release become no-ops without a pointer-range check.
_Avoid_: dynamic count, saturating overflow behavior, zero-owner state

**Local Constructor Tag**:
A dense `u32` discriminator scoped to one nominal data type and stored first in a runtime data payload for pattern matching.
_Avoid_: LayoutId, source constructor identity, global constructor index

**Object Shape**:
The zero-based canonical member schema whose Data variant contains constructor tag and fields and whose Environment variant contains captures without a tag, with stored-witness ordinals but no raw offsets or alignment fields.
_Avoid_: runtime LayoutId, raw offsets, String variable-size layout

**Layout Operand**:
The five-byte allocation operand choosing Immediate `0x01` with nonzero LayoutId or Witness `0x02` with an `I32 + Trivial` witness SlotId.
_Avoid_: ObjectShapeId, source type argument, descriptor pointer

**Field Projection Result**:
The value destination SlotId plus witness-destination OptionalSlot for one projected member.
_Avoid_: source binder, raw load result, hidden dynamic type

**Typed Data Payload Layout**:
The `ObjectShape::Data`-defined payload arrangement of local tag, stored generic witnesses, and user fields placed by representation, alignment, and cleanup.
_Avoid_: uniform VMValue array, source record ABI, flat constructor table

**Nullary Constructor Singleton**:
An image-owned immortal object reused by a constructor with no user fields and no generic layout witnesses needed by destruction.
_Avoid_: dynamic nullary allocation, pointer identity, source global

**Typed Closure Environment Layout**:
The environment-specific placement of erased capture fields and hidden generic layout witnesses after the common ARC header, with no constructor tag or recursive member-callable backreferences.
_Avoid_: data constructor payload, mutable environment map, recursive closure cycle

**Materialized Layout Descriptor**:
The fixed 32-byte record in canonical memory indexed by `LayoutId`, containing representation kind, size mode, size or sizer index, alignment, retain/release/destroy helper indices, and a reserved word.
_Avoid_: source type descriptor, heap object, variable-length metadata

**Layout Helper Entry**:
An internal entry in the canonical Wasm function table used by descriptor-driven ownership or sizing and excluded from valid Lane `FunctionId` values.
_Avoid_: Lane callable, runtime import identity, bytecode body

**Canonical Lane Memory Export**:
The module-defined non-shared wasm32 memory exported as `"lane.memory"`, with image-owned static regions below immutable `heap_base:i32` and the module-owned ARC heap above it.
_Avoid_: imported host memory, second Lane memory, Memory64

**Private Wasm Fatal Exception**:
The backend-only `exnref` channel used to unwind runtime-import failure, allocation failure, ARC overflow, and other fatal internal errors through ownership cleanup.
_Avoid_: Lane exception, effect operation, normal status result

**Lane Wasm Module ABI**:
The generated module boundary exporting `"lane.entry":() -> ()`, canonical memory, and restricted runtime-service helpers while importing stable registry symbols under `"lane.runtime.v1"`.
_Avoid_: source module exports, arbitrary Lane function exports, Component ABI

**Runtime Service Nested Call**:
A RuntimeContext invocation of an approved non-Lane service export such as `"lane.runtime.string.new"` during a host import, without permission to invoke Lane entry, closures, or ordinary functions.
_Avoid_: Lane callback, general same-instance reentry, asynchronous host call

**Static Wasm Image Initialization**:
The instantiation-time materialization of image-owned memory and function-table contents through active data and element segments, without a Wasm start function.
_Avoid_: Lane startup call, lazy image initialization, runtime linker

**Canonical Wasm Function Table**:
The single private fixed-capacity `funcref` table whose invalid zero entry precedes the contiguous Lane `FunctionId` range and internal layout-helper entries.
_Avoid_: exported table, table growth, multiple tables

**Trusted Bytecode Image**:
A decoded bytecode image assumed to satisfy LoisVM invariants because it was emitted by the matching Lane linker.
_Avoid_: verified bytecode, sandboxed input, stable untrusted interchange format

## Relationships

- The first **Execution Target** currently evaluates verified Buslane programs.
- The **Reference Interpreter** uses **Interpreter Entry Selection** over a whole checked compiler program.
- **Run Entry Convention** is a caller policy layered on top of **Interpreter Entry Selection**. `lane run` selects from the checked top-level environment, while `lane link` selects from linked exported entries before artifact emission.
- `lane run` and `lane link` accept only an **Executable Entry Type** for execution; `lane exec` executes the entry already selected in the linked artifact.
- `lane run` and `lane exec` do not print the `Unit` result of an executed entry; user-visible output comes from runtime implementations selected by the run or link effect convention.
- `lane inspect <artifact>` is the command-line path for reviewing the metadata
  available in that artifact. Module objects can expose semantic Buslane/core
  information; ordinary linked program artifacts are executable-only.
- **Run Effect Convention** belongs to `lane run` and `lane link`; it is not a Lane language prelude or Basic library injection rule. `lane exec` invokes already resolved runtime calls.
- The v1 **Executable Entry Type** is exactly a zero-argument function returning `Unit`; validation uses only the fully expanded closed concrete effect set, which may be empty or covered by registered runtime effect conventions such as `Basic.Io.Write`.
- A **Runtime Effect Handler** only handles operations that are not captured by source lexical handlers.
- A **Runtime Effect Convention** is validated against source-level exported module, effect, operation, and signature metadata before `lane run` interprets the residual operation or `lane link` lowers it to a runtime implementation.
- The initial built-in **Runtime Effect Convention** handles only `Basic.Io.Write.println(String) -> Unit`.
- Runtime convention validation belongs at `lane run` and `lane link` entry selection boundaries; `lane exec` executes an already validated and effect-erased linked artifact.
- Before LoisVM bytecode construction, `mon-trans`, `open-resolve`, and
  `monadic-lift` establish the **Effect-Erased Bytecode Boundary**. No handler,
  perform, resume, operation identity, handler context, or runtime operation
  table remains in the execution image.
- External runtime effects are lowered to ordinary runtime function or intrinsic
  calls. `lane exec` does not resolve Basic modules, effect operations, or
  operation names and performs no effect dispatch.
- Runtime failures inside the initial lowered `Basic.Io.Write.println`
  implementation are execution failures rather than Lane language-level effects
  or exceptions.
- The **Reference Interpreter** separates the **Global Environment**, **Call Frame**, and **Closure Environment**.
- The **Reference Interpreter** evaluates to **Interpreter Values**.
- Lane v1 does not require an execution target to discover tail position in
  ordinary returning calls, but every explicit **Tail Call Terminator** has
  proper **Tail-Call Optimization** semantics and replaces the current frame.
- An **Execution Target** consumes checked compiler output rather than raw source syntax.
- Runtime type arguments are erased before execution.
- **Builtin Runtime Plugins** are selected by a **Builtin Dispatch Key**.
- A **Runtime Error Report** is not a Lane language-level exception.
- Invalid `Int` arithmetic is **Integer Undefined Behavior** in v1.
- The future **Bytecode VM** is a register-style execution target. Its
  **Bytecode Functions** read and write **Local Slots** rather than relying on
  an operand stack as the primary value transport.
- The future **Bytecode VM** is implemented by **LoisVM**. The bytecode model
  belongs to `loisvm/bytecode`, and execution belongs to `loisvm/interp`.
- The bytecode image uses one **Unified Bytecode Function Table**. `FunctionId`
  may name a bytecode body or a **Runtime Import Entry**.
- It stores one **Selected Bytecode Entry** before the function count. FunctionId
  is one-based over zero-based table position, and zero function count is invalid.
- Bytecode bodies follow final deterministic post-optimization body-list order
  and precede runtime imports. Imports serialize ABI major, user arity, and
  nonempty case-sensitive ASCII symbol, are tuple-deduplicated, and sorted.
- FunctionIds are **Build-Local FunctionIds** reproducible only for identical
  compiler version, inputs, options, and selected entry. Build changes may
  renumber them; selected entry remains explicit rather than fixed to ID one,
  and FunctionId is not a persistent or module ABI identity.
- The loader resolves every runtime import to a **Runtime Import Binding** before
  execution. Missing or ABI-incompatible imports are load failures; resolved
  bindings are cached and calls do not dispatch by string.
- Runtime symbols carry an ABI major version. **Runtime Import ABI V1** records
  only a fixed explicit arity, and loading checks symbol, version, and arity.
- The **Runtime Symbol Registry** is the single authority for primitive argument
  and result kinds. Runtime-import descriptors do not serialize a second copy of
  the signature.
- `lanec` validates the registry signature before type erasure. Once the trusted
  image's symbol, version, and arity are bound, runtime calls assume the expected
  primitive VM tags rather than performing dynamic type dispatch.
- Runtime import invocation has the logical form `(RuntimeContext,
  VMValue...) -> VMValue`. The context is an implicit borrowed host parameter;
  explicit arguments and the single result use the uniform value ABI.
- V1 runtime imports have no varargs, multiple results, source types, or
  per-parameter unboxed representation descriptors. Reference-bearing explicit
  arguments are callee-owned and the result is owned.
- Every runtime import is a **Synchronous Primitive Host Call**. It cannot
  suspend, invoke Lane callbacks, re-enter Lane program execution, or retain VM
  values after returning. A restricted **Runtime Service Nested Call** may invoke
  an approved allocator or String service that cannot dispatch Lane code.
- Runtime-import arguments and results are limited to `Int`, `Double`, `Bool`,
  `String`, and `Unit`. Closures, nominal data, environments, function
  identifiers, and opaque host handles are outside the v1 host boundary.
- Runtime imports consume or release transferred arguments on both success and
  execution failure. `String` is reference-counted; the other permitted kinds
  are immediate.
- Runtime-created Strings are immutable **Runtime String Objects**. Image
  constant strings have the same logical length-and-bytes access contract but
  are static and require no retain or release. Neither is NUL-terminated by ABI.
- Dynamic, constant, and empty Strings share the same Wasm layout. Constant and
  empty forms use the immortal count; no String stores capacity or cached hash.
- Host bindings read String arguments through **Borrowed Host String Views**
  without copying. A view cannot escape the synchronous call and does not change
  the callee-owned argument contract.
- Returning a String copies host-provided bytes through the **Runtime Context**
  into a new owned VM String. Non-ASCII bytes violate Lane v1 String semantics
  and produce a **Runtime Import Failure**.
- The borrowed host view is `(string_ref + 12, byte_length)`.
- V1 **String Primitive Instructions** are `string_length`, `string_concat`,
  `string_slice`, and `string_eq`. Length and equality borrow their operands;
  concatenation consumes two owners and slicing consumes one.
- String indices are Lane Int ASCII byte indices. Empty concatenation and complete
  slicing may move an input owner without allocation; proper slices return
  independent copied Strings rather than objects retaining a parent String.
- Invalid ranges, length or address overflow, and allocation failure use the
  private fatal path and make the instance unusable.
- Successful imports return one owned primitive VM value. A **Runtime Import
  Failure** has no bytecode exceptional successor and terminates execution
  rather than becoming a Lane value, exception, or effect.
- The failing binding consumes or releases its transferred arguments before the
  VM releases remaining owned frame and slot values during aborted-execution
  unwinding.
- Recoverable host outcomes use a normal primitive result such as `Int` or
  `Bool`. The interpreter may model fatal failure as a runtime error result, and
  native bindings may use a status/out parameter or failure callback, but that
  physical channel is absent from bytecode descriptors.
- The **Wasm Compiled Tier** consumes the same decoded **Bytecode Image**
  as the interpreter. It does not bypass LoisVM bytecode by consuming linked
  Buslane/core or compiler-internal ANF.
- Compiled output follows the **Lane Wasm Feature Profile**. Wasmoon may extend
  its implementation and optimize recognized Lane patterns, but generated
  modules remain valid without Wasmoon-specific instructions or types.
- The profile permits Multi-value, Reference Types, Typed Function References,
  Tail Call, and Bulk Memory instructions while retaining wasm32 linear memory
  and excluding Wasm GC.
- Memory64 is excluded from Lane v1. Heap references and closure environments
  remain wasm32 offsets, and packed callables retain two 32-bit components.
- Multiple Memories is excluded from Lane output. Memory zero contains heap
  objects, image constants, layout metadata, and runtime-visible buffers, and
  every Lane reference addresses that canonical memory.
- Threads and Atomics are excluded from Lane output. Canonical memory zero is
  non-shared, each instance is thread-confined, and ARC counts remain
  non-atomic. This does not prevent parallel execution of separate instances.
- Bulk Memory may initialize image data and tables, fill allocator regions, and
  copy raw String bytes. It cannot establish ownership for reference-bearing
  object fields and therefore does not replace ARC-aware construction or copy.
- Exception Handling with `exnref` implements internal fatal-failure unwinding.
  Runtime-import adapters throw a private Wasm exception, frame handlers release
  their remaining owned values and rethrow, and the execution boundary reports
  failure out of band. This does not add a Lane exception or bytecode edge.
- Sign-extension Operators and Extended Constant Expressions are emitter
  features. Non-trapping Float-to-int, Fixed-width SIMD, Branch Hinting, Wide
  Arithmetic, Custom Page Sizes, and Memory Control are recognized but not
  emitted or required by v1.
- Stack Switching and Relaxed SIMD are excluded from Lane v1 output.
- Import/Export Mutable Globals, Compilation Hints, WASI Preview 1, the Component
  Model with WASI Preview 2, and JS BigInt-to-`i64` integration are recognized
  integration options but are not emitted or required by core lowering.
- Multiple Tables and Relaxed Dead-code Validation are excluded. The callable
  ABI uses one canonical function table and all emitted code passes strict Wasm
  validation.
- JS Promise Integration, JS String Builtins or String References, and Custom
  Descriptors or JS Interop are excluded. Host calls remain synchronous and
  Strings remain ASCII ARC objects in canonical linear memory.
- Extended Name Sections, Custom Annotations, Rounding Variants, Half Precision,
  Flexible Vectors, Type Imports, and the JIT Interface are recognized future
  options but are not emitted or required by Lane v1.
- Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are
  excluded from the output profile.
- The **Wasm Compiled Tier** stores dynamic Lane objects in the **Wasm
  Linear-Memory ARC Heap**. Compiler-emitted ARC and ownership-transfer
  operations remain responsible for reclamation; Wasm GC is not used.
- Under **Representation Erasure**, monomorphic values use natural Wasm types.
  A generic value crosses a representation-polymorphic boundary as one `i64`
  payload, with a hidden **Representation Layout Witness** supplying retain,
  release, destruction, and layout behavior.
- Each **Representation Layout Witness** is an immediate index into the **Image
  Layout Table** and is neither allocated nor reference-counted. Generic objects
  store identifiers needed by erased fields, while derived layout witnesses are
  threaded as hidden parameters rather than created at runtime.
- The Wasm tier lowers a first-class function value to a **Packed Wasm
  Callable**. `call_value` unpacks the typed table target and hidden environment
  argument before `call_indirect`. Each nonzero environment is one owned ARC
  reference, so Wasm retain, release, and consuming call operate directly on the
  environment without allocating or inspecting a closure shell.
- Typed Function References are profile capabilities rather than the canonical
  callable ABI. Canonical value calls use `call_indirect` and tail value calls
  use `return_call_indirect`; any backend-local `call_ref` use must preserve the
  packed heap and generic representations.
- Direct, indirect, tail, and runtime-adapter targets share the **Canonical Wasm
  Lane Entry ABI**. Monomorphic values use natural Wasm scalars, generic values
  use `i64`, `Unit` has no result, and capture-free functions receive a zero
  environment. Multi-value is available but current v1 Lane values require at
  most one Wasm result.
- Bytecode uses **Structured Bytecode Addressing**. Functions contain ordered
  blocks and **Representation-Homogeneous Slots**; fixed block zero is entry,
  blocks contain instruction
  arrays and explicit terminators, and branches target block identifiers.
- Each bytecode section starts with **LoisVM Bytecode Schema Version** `0x01`
  for v1 and no duplicate magic; the `.lbp` section provides outer framing.
- Schema counts have no normative maxima below `u32`. Checked arithmetic and
  minimum-size preflight protect framing, while **Implementation Resource Limits**
  may reject otherwise valid images.
- **Atomic Bytecode Load** completes decode before import resolution, performs no
  Lane execution during binding, discards partial state on failure, and publishes
  only after interpreter-image or Wasm construction succeeds.
- Load errors distinguish unsupported schema, malformed encoding, unresolved
  import, ABI mismatch, resource limit, and backend compilation failure;
  malformed errors carry bytecode-relative offsets and import errors symbols.
- **Dense Bytecode Identifier Spaces** use table position and `u32le`. Valid
  `FunctionId` and `LayoutId` values start at one; `BlockId`, `SlotId`, and
  `ConstantId` and `ObjectShapeId` start at zero. Counts and lengths also use
  `u32le`.
- Instruction and terminator domains use separate `u8` **Fixed-Shape Opcode
  Encodings** with no per-instruction length. Unknown tags are rejected.
- Every **Bytecode Tag Namespace** assigns known values contiguously from
  `0x01`, reserves `0x00` and `0xFF`, and is frozen within one schema version.
  Accepted-tag changes require a schema-version bump.
- V1 representation tags are I32/I64/F64 = `0x01`/`0x02`/`0x03`; cleanup tags
  are Trivial/OwnedRef/OwnedCallable/OwnedErased = `0x01` through `0x04`; result
  tags are Unit/I32/I64/F64 = `0x01` through `0x04`.
- Function-entry tags are BytecodeBody/RuntimeImport = `0x01`/`0x02`; Layout
  Recipe tags follow Unit through Environment at `0x01..0x08`; Object Shape and
  LayoutOperand tags are Data/Environment and Immediate/Witness, each
  `0x01`/`0x02`.
- The **Canonical V1 Opcode Table** fixes instructions at `0x01..0x42` and
  terminators at independent `0x01..0x07`. Normal calls are instructions; CFG
  transfers, returns, tail calls, and unreachable are terminators excluded from
  `instruction_count`.
- V1 defines no nop, opcode alias, generic operation-subtag instruction,
  source-location instruction, profiling instruction, or debug instruction.
- Each **Canonical Bytecode Function Body** is byte-length-delimited, completely
  consumed, and ordered as slot table, inputs, result, then block table.
- Block count is nonzero; table order implies IDs, block zero is entry with no
  parameters, and each block contains counted unique parameter SlotIds, counted
  instructions, and one terminator without fallthrough or a block length.
- Slot entries record representation and cleanup tags, and only `OwnedErased`
  appends a companion SlotId. Bytecode has no
  alignment padding, and `i64` and `f64` constants preserve raw little-endian
  bits.
- V1 **Slot Representation Tags** are `I32`, `I64`, and `F64`; Unit has no
  slot. Returning calls use zero destination OptionalSlot for Unit.
- **Slot Cleanup Categories** are `Trivial`, `OwnedRef`, `OwnedCallable`, and
  `OwnedErased`. They specify cleanup behavior rather than compiler-private
  ownership or borrowing state.
- `OwnedRef` pairs with `I32`; `OwnedCallable` and `OwnedErased` pair with `I64`.
  The latter names an **Erased Ownership Companion** whose `I32 + Trivial`
  witness remains unchanged while the owned payload is live.
- Bytecode has no `Borrowed` category. Non-owning reference temporaries may use
  `Trivial`, but the trusted contract prevents them from crossing block, call,
  return, or heap-storage boundaries.
- **Bytecode Function Inputs** are distinct from block parameters. Environment
  uses zero or `SlotId + 1`; counted `I32 + Trivial` witness SlotIds precede
  counted user parameter SlotIds, and all input SlotIds are pairwise distinct.
- A function result descriptor stores one Unit/I32/I64/F64 tag. Unit has no
  result slot; cleanup comes from actual return and destination slots.
- Every **Optional Slot Reference** is one `u32le` zero or `SlotId + 1`;
  environments, call destinations, return sources, and projection witness
  destinations use this encoding.
- Every other SlotId operand is direct zero-based `u32le`. SlotId zero is valid
  for `make_closure`; the owned environment value stored there must be nonzero.
- Slot arrays use one `u32le` count followed by exact SlotIds. Direct calls store
  target, environment, witnesses, users, and destination; value calls store
  callable, witnesses, users, and destination.
- Witness and Trivial user arguments are non-consuming reads. Owned user
  arguments transfer into the callee; direct calls consume nonzero environments,
  and value calls consume their callable.
- There is no call-shape table. Wasm lowering builds a **Derived Indirect Call
  Shape** from call-site slot tags, runtime imports use registry signatures, and
  target matching remains a trusted bytecode invariant.
- A **Return Terminator** stores one source OptionalSlot and consumes a non-Unit
  result owner into the caller. Normal return performs no implicit frame sweep;
  explicit releases establish an **Ownership-Empty Exit** for all other owners.
- Direct tail calls encode target, environment OptionalSlot, counted witnesses,
  and counted user arguments. Value tail calls encode callable and both arrays.
  They have no destination and consume every transferred operand.
- Before tail transfer, explicit releases remove untransferred owners. The tail
  target result representation matches the current function descriptor, which
  provides the result type for an indirect-tail derived shape.
- Wasm lowers them to `return_call` and `return_call_indirect`. Tail runtime
  imports use the same transfer; adapter failure sees no replaced-frame owners.
- A **Bytecode Edge Record** contains target, argument count, and exact SlotIds.
  `jump` stores one edge; `branch_bool` stores an `I32 + Trivial` condition
  followed by true and false edges.
- A **Tag Switch Terminator** is one lowered decision-tree node rather than a
  complete pattern-match operation. It compares tags as unsigned, permits zero
  dense cases, always stores default, and never falls through by table order.
- Only the selected edge transfers arguments, in parallel. Trivial sources may
  repeat and are non-consuming; owned sources are consumed and may not repeat
  without prior retain-copy. Range, arity, representation, cleanup, and ownership
  matching remain trusted invariants.
- A **Trusted Unreachable Terminator** lowers to Wasm `unreachable` without the
  private fatal channel. Boolean branches use `if` or `br_if`, and dense tag
  switches preferentially use `br_table` during CFG structuring.
- Bytecode defines no generic slot assignment. **Trivial Slot Copy** duplicates
  only `Trivial` slots; **Ownership Move** consumes compatible values without
  ARC; **Retain Copy Instruction** creates an owned destination for duplication
  or borrow promotion.
- Instruction destinations are logically dead before writing. `release(slot)`
  consumes one owner; move and release leave stale bits but logically kill their
  source. No destination overwrite releases implicitly.
- Retain-copy and release use `OwnedRef`, `OwnedCallable`, or `OwnedErased`
  cleanup, including erased companion witnesses. ARC on `Trivial` is invalid
  trusted bytecode rather than no-op behavior.
- Wasm lowering uses typed local operations and ARC helpers. Backend and Wasmoon
  optimization may remove redundant moves and balanced retain-copy/release
  pairs; plain local assignment remains ownership-neutral.
- `const_int`, `const_double`, and `const_bool` create **Inline Scalar Constants**
  from `i64le`, raw binary64 bits, and canonical byte zero or one. Other Bool
  bytes fail decoding; Unit has no constant instruction.
- `const_function` creates a capture-free callable with environment zero, while
  `const_string` creates an owned logical reference to an **Image String
  Constant** selected by `ConstantId`.
- `const_layout` writes a nonzero image LayoutId into an `I32 + Trivial` witness
  slot without entering the String constant pool.
- V1 **Bytecode Constant Pool** entries are reachable Strings only. Exact ASCII
  bytes are deduplicated and sorted lexicographically as unsigned raw bytes;
  zero-based IDs are remapped into `const_string`, and empty String is ID zero
  when present.
- Active Wasm data segments materialize the immortal String objects, and
  `const_string` lowers directly to a static address without retain.
- Int primitives use signed `I64 + Trivial` arithmetic, remainder, bitwise,
  shift, and comparison instructions. Overflow and invalid shift counts remain
  **Integer Undefined Behavior**, allowing wrapping arithmetic and masked shifts.
- Division by zero, `MIN_INT / -1`, and remainder by zero may cause a
  **Non-Unwinding Arithmetic Trap**. Private fatal cleanup does not run, and the
  instance is discarded rather than resumed or reused.
- Int comparisons and Bool not/equality produce **Canonical Boolean Scalars**.
  Short-circuit conjunction and disjunction lower to CFG rather than eager ops.
- Double uses Wasm binary64 arithmetic and six comparisons. IEEE-754 division,
  signed-zero, infinity, and NaN comparison behavior applies; arithmetic need
  not preserve serialized NaN payloads.
- Int and Double have no implicit conversion in bytecode; only the defined
  **Explicit Numeric Conversion** opcodes cross those numeric types.
- **Explicit Numeric Conversion** provides signed `int_to_double` with IEEE
  nearest-ties-even rounding and `double_to_int` with truncation toward zero.
  Large Int precision loss is allowed.
- NaN, infinity, or out-of-range Double-to-Int conversion may cause a
  **Non-Unwinding Conversion Trap**. V1 has no saturating or non-trapping form,
  and the failed instance is discarded.
- Compiler-only **Representation Erasure Bridges** zero-extend or wrap `I32`,
  preserve `I64` bits while changing cleanup interpretation, or reinterpret
  `F64`/`I64` bits. They consume their source and transfer ownership without ARC.
- Int and Callable use identity-bit I64 bridges rather than ordinary movement.
  None of these bridge operations creates source-level implicit conversion.
- Every erased endpoint is `I64 + OwnedErased`, including no-op primitive
  layouts. Erase reads an initialized destination companion and unerase reads
  the source companion; neither carries a witness operand.
- One immutable companion may serve multiple live erased payloads and becomes
  reusable only after all are consumed. Calls perform no implicit erasure.
- Natural Unit has no slot, while generic Unit uses canonical `I64 0 +
  OwnedErased` with a nonzero no-op Unit LayoutId. `erase_unit` has only a
  destination and `unerase_unit` only a source.
- A zero-based `ObjectShapeId` selects an **Object Shape** independently from
  runtime `LayoutId`. Data and Environment variants determine field or capture
  offsets, while LayoutId controls allocation and ownership helpers.
- `make_env` carries destination, direct zero-based Environment shape, **Layout
  Operand**, counted witnesses, and counted captures. It reads Trivial inputs,
  consumes owned captures, and publishes a fully initialized dead
  `I32 + OwnedRef` destination.
- `borrow_capture` preserves its explicit environment source and produces a
  block-local borrowed result. `consume_captures` consumes one environment owner
  and returns selected captures as owners through equivalent unique/shared paths.
- Consuming capture indices are strictly increasing and may be empty.
- Capture-free functions use environment zero, have no Environment Object Shape,
  and execute no `make_env`.
- `make_data` carries destination, direct zero-based Data shape, **Layout
  Operand**, counted witnesses, and counted fields. The shape supplies constructor
  tag; Trivial inputs are read, owned fields are consumed, and the complete object
  is initialized before publication.
- `load_tag` is non-consuming. `borrow_field` preserves object ownership and
  writes a **Field Projection Result**, including a stored witness for erased
  fields. Reference-bearing borrowed payloads use `Trivial` slots.
- `consume_fields` consumes the object, returns a possibly empty strictly
  increasing selected-result sequence, releases unselected fields, and preserves
  unique-move/shared-retain equivalence.
- Field indices are shape-local and require constructor selection. Trusted
  metadata ensures shape/layout compatibility; bytecode exposes no raw heap
  offset, load, or store operation.
- Object Shapes omit alignment and offsets. Data layout is header, tag, contiguous
  u32 witnesses, then aligned fields; Environment omits the tag. I32 uses four-
  byte size/alignment, I64/F64 eight, and total size rounds to eight.
- Member schemas encode representation, cleanup, and witness ordinal plus one.
  Exact shapes are deduplicated and sorted Data-first, then Environment.
- **Wasm CFG Structuring** maps slots to typed locals, uses temporary locals for
  parallel edge transfer, structures reducible CFGs, and uses a dispatcher
  fallback for irreducible CFGs. Multi-value block parameters are not required
  by the canonical v1 lowering.
- Every dynamic reference points to a **Lane ARC Object Header**. Allocation
  produces a nonzero eight-byte-aligned pointer with count one, payload begins at
  offset eight, and size or allocator metadata stays outside the common header.
- Image-owned objects use the **Immortal Refcount Sentinel**. Dynamic overflow
  into that value is fatal, and release to zero runs the layout destructor before
  the allocator reclaims the block.
- Runtime data payloads begin with a type-local **Local Constructor Tag**.
  Pattern matching loads that tag; `LayoutId` selects the **Typed Data Payload
  Layout**, field offsets, and destructor rather than serving as constructor
  identity.
- Generic fields occupy `i64` erased storage and the object stores required
  layout witnesses. Eligible fieldless constructors use immortal **Nullary
  Constructor Singletons**.
- Closure environments use **Typed Closure Environment Layouts**. One-time
  initialization consumes owned captures, stores generic witnesses needed by
  destruction, and publishes an immutable object; capture-free callables use
  environment zero and allocate nothing.
- Recursive groups share one environment without storing strong member callable
  references. Non-escaping environment scalar replacement is a Wasm optimization
  and does not alter the bytecode ownership contract.
- The immutable global `layout_table_base:i32` addresses 32-byte
  **Materialized Layout Descriptors**; `LayoutId = 0` is invalid. Fixed size and
  dynamic sizer results include the common ARC header.
- Portable bytecode stores deduplicated **Portable Layout Recipes** after the
  function table. Used primitive recipes precede Data and Environment recipes
  ordered by ObjectShapeId; recipes contain no computed sizes or helper indices.
- Descriptor retain/release helpers use `(i64) -> ()`, destroy uses `(i32) ->
  ()`, and size uses `(i32) -> i32`. **Layout Helper Entries** share the one Wasm
  table but are outside the Lane callable identifier range.
- The module defines and exports the **Canonical Lane Memory Export**. Address
  zero is reserved; constants and layout data occupy low addresses; immutable
  `heap_base` starts the aligned dynamic heap; and runtime imports access bytes
  through the export.
- A module-owned bump allocator with reusable free lists grows memory as needed.
  Reused blocks are not zeroed, so construction initializes all observable state
  before publication. OOM and ARC overflow throw a **Private Wasm Fatal
  Exception**; free, destruction, and cleanup remain non-throwing.
- The **Lane Wasm Module ABI** exports only `"lane.entry":() -> ()` as a Lane
  program entry, plus canonical memory and restricted runtime services. It
  imports stable runtime symbols under `"lane.runtime.v1"` using natural Wasm
  primitive signatures and exports no other Lane functions.
- `"lane.entry"` invokes the linked selected zero-argument `Unit` function.
  Private fatal exceptions may escape that wrapper for Wasmoon to catch and
  convert into fatal execution failure.
- **Static Wasm Image Initialization** uses active data and element segments and
  no start function. Successful instantiation establishes static memory,
  immutable globals, allocator state, and the **Canonical Wasm Function Table**.
- The function table is private and fixed at its exact emitted size. Index zero
  is invalid; indices `1..N` map Lane `FunctionId` values directly, including
  runtime-import adapters; layout helpers follow. Entry and runtime-service
  wrappers remain outside the table and callable namespace.
- Canonical memory has no declared maximum. Its initial standard 64-KiB page
  count is the minimum covering `heap_base`; allocation grows it as needed.
- LoisVM v1 executes a **Trusted Bytecode Image** without a separate structural,
  data-flow, or type verifier. Both the interpreter and the **Wasm Compiled
  Tier** may rely on bytecode invariants established by `lane link`. Generated
  WebAssembly modules must still satisfy WebAssembly validation.
- Strict binary decoding and bytecode verification are separate concerns. The
  artifact codec still rejects malformed byte encodings, invalid schema tags,
  truncated sections, and trailing section bytes, but it does not prove decoded
  bytecode control-flow or slot invariants.
- A `.lbp` is not a sandbox boundary or a supported untrusted-code format.
  Behavior for a decodable but semantically malformed bytecode image is outside
  the execution contract and need not receive a stable diagnostic.
- Wasm lowering and Wasmoon JIT optimization improve only the compiled path. Lane
  semantic and whole-program optimization remains above bytecode lowering, and
  interpreter-specific dispatch or peephole work remains a LoisVM concern.
- Each **Local Slot** stores a **VM Value**. Bytecode v1 uses one uniform
  tagged value representation for primitives, data, closures, and
  continuations; `Double` is represented as a VM value case rather than through
  a separate unboxed register ABI.
- A **Bytecode Image** is an execution artifact derived from linked and
  optimized Buslane/core; it does not replace Buslane/core as the semantic
  source of truth.
- Lane v1 module objects store Buslane/core rather than bytecode. The
  **Bytecode Image** is produced only after `lane link` has linked and optimized
  the module objects.
- A linked `.lbp` is an **Executable-Only Linked Artifact**. The bytecode VM
  does not depend on embedded Buslane/core, and ordinary linked artifacts do not
  carry a Buslane/core snapshot for inspection.
- Its fixed-order payload is `linked_program_schema_version:u32le = 4` followed by
  one bytecode section consuming the payload remainder. It contains no section
  directory, nested bytecode length, module-path list, or outer entry/import
  records.
- The linked artifact stores a decoded bytecode image in memory, with nested
  encoding and decoding delegated to `loisvm/bytecode`.
- `lane inspect` uses **Canonical Linked Disassembly** for `.lbp`. Bytecode
  diagnostics remain section-relative and may additionally show an absolute
  file offset at the command boundary.
- Lane bytecode v1 is **Erased Bytecode**. Full runtime source types,
  source-level type arguments, and source-debug metadata are removed, while
  representation signatures and hidden **Representation Layout Witnesses** are
  retained only where Wasm lowering or generic ownership requires them.
- **Bytecode Functions** use explicit **Bytecode Blocks** and **Bytecode
  Terminators** for control flow. Structured Buslane or ANF forms such as
  matches and handlers are not preserved as structured bytecode nodes.
- Each non-entry **Bytecode Block** may declare ordered parameter slots. Every incoming
  jump or branch supplies an equal-length ordered list of **Block Edge
  Arguments**, and block entry copies all source values to parameter slots in
  parallel before executing the first instruction.
- Reference-bearing block parameters are **Owning Block Parameters**. The
  selected edge performs **Edge Ownership Transfer** from argument slots to
  parameter slots without implicit reference-count operations.
- If one selected edge supplies the same source owner to multiple target
  parameters, explicit **Retain Copy Instructions** establish the additional owners.
  Alternative branch edges are mutually exclusive and do not themselves create
  simultaneous owners.
- Loop backedges transfer ownership under the same rule. Ownership analysis
  releases any previous logical parameter value that is overwritten without
  being transferred, and slot allocation preserves the resulting move/release
  semantics even when physical slots are reused.
- The **Wasm Compiled Tier** preserves bytecode block-parameter and edge-argument
  relationships while structuring control flow for WebAssembly. The precise
  structuring strategy remains a backend decision.
- Primitive source and builtin operations execute through **Mid-Level Bytecode
  Instructions** rather than through runtime builtin-name dispatch. These
  instructions still operate on **VM Values** and do not expose raw heap layout
  or tagged-word implementation details.
- Bytecode uses a **Direct Call Instruction** when lowering knows the target
  function-table identifier. Calls through first-class function values use a
  **Value Call Instruction** instead.
- Direct, closure, and tail calls apply uniformly to bytecode and runtime-import
  entries. LoisVM has no separate `call_runtime` instruction or runtime-function
  identifier space.
- A function-table entry declares a **Function Context Kind** in addition to its
  Lane-level user arity. A direct call supplies a **Closure Environment
  Reference** exactly when the target entry requires one.
- A **Direct Call Instruction** or **Value Call Instruction** continues with the
  next instruction in the same block. A non-`Unit` call writes one destination
  slot; a `Unit` call carries no destination `SlotId`. Returning calls do not
  split the block around an explicit continuation.
- Returning and tail calls use the **Callee-Owned Call ABI**. Reference-bearing
  user arguments and a required **Closure Environment Reference** transfer
  ownership into the callee frame. A returning non-`Unit` call places one owned
  result in its destination slot.
- If the caller uses an argument after a returning call, the compiler emits a
  **Retain Copy Instruction** into a fresh owner slot before transferring one
  ownership into the callee. A last-use argument transfers directly.
- A **Callable Value** is either an immediate `FunctionId` or a closure. A bare
  identifier targets a no-context entry, while a closure supplies the identifier
  and required environment; trusted bytecode establishes the correspondence.
- **Callable Construction** writes a logically dead `I64 + OwnedCallable` slot.
  `const_function` names a no-context target; `make_closure` names a
  context-requiring target and consumes one nonzero environment owner without
  layout, shape, or call-signature operands.
- The interpreter allocates a count-one closure shell for `make_closure`; Wasm
  packs FunctionId and environment into `i64` without allocation.
- Callable `copy` is invalid. `move`, `retain_copy`, and `release` explicitly
  transfer, duplicate, or destroy callable ownership.
- The **Value Call Instruction** does not expose callable-tag dispatch or
  closure fields as bytecode operations. The interpreter obtains the function
  identifier and optional **Closure Environment Reference** internally and
  enters the same ABI used by a direct call. The **Wasm Compiled Tier** lowers
  the fused operation to a Wasm call sequence that preserves the same callable
  and optional-environment semantics.
- When a call targets a runtime import entry, the interpreter invokes
  the cached binding and the **Wasm Compiled Tier** emits a WebAssembly import or
  an adapter to one.
- The Wasm backend obtains a known runtime symbol's primitive signature from the
  **Runtime Symbol Registry**, not extra type metadata in bytecode. A borrowed
  String lowers to `(bytes_ptr:i32, byte_length:i32)` while bytecode continues to
  carry one String `VMValue`. A String result is one owned `string_ref:i32`.
- RuntimeContext produces a returned String through the restricted
  `"lane.runtime.string.new":(i32) -> i32` service and writes validated bytes via
  `"lane.memory"`. This **Runtime Service Nested Call** cannot invoke Lane entry,
  a closure, or an ordinary `FunctionId`; helper or validation failure uses the
  **Private Wasm Fatal Exception**.
- Arithmetic, comparison, data, closure, and reference-count operations chosen
  as VM semantics remain dedicated bytecode instructions. Runtime imports serve
  host capabilities rather than replacing core VM primitives.
- A **Value Call Instruction** consumes its callable operand. Immediate function
  identifiers require no ARC operation; closure values use **Consuming Callable
  Projection** internally.
- A unique closure moves its environment into the callee and frees its shell. A
  shared closure retains the environment for the callee and releases only the
  consumed closure owner, preserving other owners.
- Closure uniqueness is an interpreter fast path, not a call precondition. The
  packed Wasm representation has no closure shell: compiler-inserted retains
  establish separate environment owners, so consuming invocation always moves
  one environment owner without a shell-count branch.
- The hidden **Closure Environment Reference** does not count toward source or
  Lane-level function arity. Captured values are read through dedicated capture
  operations rather than flattened into user parameters.
- Recursive closure groups use one shared environment created by an
  **Environment Construction Instruction** from shared outer captures before
  closure values are published; the environment does not strongly store its
  own group closure objects.
- **Environment Construction Instruction** fully initializes every environment
  field. There is no general environment mutation or explicit seal operation
  in v1.
- A **Capture Projection Instruction** explicitly names an environment source
  and shape-local capture index without exposing physical heap offsets.
- Dynamically allocated data, closures, environments, and continuation closures
  are **Reference-Counted Objects** rather than tracing-GC objects. The compiler
  first completes effect erasure and closure lowering into a compiler-private
  virtual-value CFG, then performs ownership analysis and inserts **Retain
  Instructions** and **Release Instructions** before physical slot allocation
  and bytecode emission.
- Final LoisVM bytecode is the result of ownership lowering, not the input to
  it. `loisvm/bytecode` does not own the compiler-private CFG or the ARC analysis.
- Capture and data-field reads may be modeled as **Block-Local Borrows** during
  runtime ownership analysis. Their owners remain live until the borrowed uses
  finish in the same block.
- A **Block-Local Borrow** cannot cross a block edge, consuming call, return, or
  object-storage boundary. **Borrow Promotion** establishes an owned reference
  before such a use.
- Data construction, environment construction, closure creation, and
  continuation-closure construction use **Consuming Object Construction**.
  Reference-bearing operands transfer ownership into the new object's fields.
- If a construction operand is needed later, the compiler emits a **Retain
  Instruction** before transferring one ownership. A borrowed operand undergoes
  **Borrow Promotion** before it can be stored.
- Destroying a **Reference-Counted Object** releases every reference-bearing
  field owned by that object. `make_closure` consumes one environment ownership,
  so closures sharing one environment each require their own strong owner.
- A **Borrowing Data Projection** preserves its scrutinee and follows the
  block-local borrow rules. A **Consuming Data Projection** consumes one
  scrutinee ownership and returns owned selected fields.
- If the consumed data object has reference count one, a consuming projection
  moves selected fields, releases unselected owned fields, and frees the object
  shell. If the count is greater than one, it retains selected fields and
  releases only the consumed object ownership.
- The reference-count test is an implementation fast path, not a precondition.
  Match lowering uses consuming projection after constructor selection when the
  scrutinee ownership is consumed; otherwise it uses borrowing projections.
- `Int`, `Double`, `Bool`, `Unit`, and function identifiers are **Immediate VM
  Values** and do not participate in reference counting.
- V1 constant-pool Strings are **Image-Owned Static Objects**. Retain-copy and
  release leave their immortal counts unchanged. Future static object kinds
  require an explicit bytecode schema extension.
- Runtime-created strings, data, closures, environments, and **Continuation
  Closures** are ordinary **Reference-Counted Objects**. Their fields may
  reference static objects without changing a count.
- The bytecode image remains loaded while any execution value may reference an
  **Image-Owned Static Object**. V1 does not support unloading such an image
  while related values remain alive.
- Each LoisVM instance owns a **Thread-Confined VM Heap**. Dynamic values and
  continuation closures do not cross threads, and the same instance is not entered
  concurrently.
- Atomic loading publishes a reusable **Loaded Executable Image**. Each run
  creates a fresh **Single-Shot Execution Instance**, and every entry attempt
  makes that instance terminal whether it succeeds or fails.
- The interpreter uses an explicit VM frame stack. The selected entry has
  logical depth one; returning bytecode-body calls increment depth, tail calls
  preserve it, and runtime imports create no Lane frame. Generated Wasm enforces
  the same logical depth boundary.
- Host execution configuration may set call-depth and canonical live-heap-byte
  **Execution Resource Limits**. These limits use private fatal cleanup and are
  not serialized in `.lbp`.
- Lane v1 defines no portable fuel, instruction-count, deadline, or timeout
  semantics. **Execution Interruption** and **Engine Traps** may bypass cleanup
  and always discard the instance.
- Successful entry return performs no defensive frame scan, heap scan, or
  implicit release sweep before whole-instance teardown.
- Interpreter and Wasm execution expose RuntimeImportFailure,
  ExecutionResourceLimit, Interrupted, EngineTrap, and InternalRuntimeFailure
  as shared top-level categories; backend trap detail is non-portable.
- **Retain Copy Instructions**, **Release Instructions**, uniqueness checks, and
  consuming projections use non-atomic reference counts in v1. The interpreter
  and **Wasm Compiled Tier** implement the same confinement contract.
- Future concurrent execution requires an explicit shared or atomic object
  boundary rather than changing every existing object to atomic RC.
- A reusable resume value is a **Continuation Closure**. `resume` lowers to the
  ordinary **Value Call Instruction**, or to a callable-value tail call in tail
  position, and follows the callee-owned ownership convention.
- Multiple resume uses retain the continuation closure before consuming calls
  when later uses remain. The final use may transfer ownership directly.
  Proven one-shot continuations may lower to direct calls or linear control flow.
- LoisVM does not capture VM or host call stacks and has no continuation-specific
  heap object or reference-count operations.
- Function parameters, results, block parameters, closure captures, environment
  fields, and data fields are owned. Final bytecode does not carry borrow-region
  metadata; its read, retain, release, and consuming-operation semantics encode
  the result of ownership lowering.
- Local-slot copies do not implicitly update reference counts. A retained copy
  has an explicit **Retain Copy Instruction**, while a compiler-proven last use may
  perform an **Ownership Transfer** without incrementing the count.
- LoisVM executes compiler-directed reference counting as emitted. Wasm lowering
  or the Wasmoon JIT may remove redundant retain/release pairs, but such
  optimization is not required for memory-management correctness.
- Recursive group member references do not create an environment-to-closure
  strong cycle. Known calls use a direct function identifier with the shared
  environment, and first-class member values construct a closure from that pair
  when needed.
- LoisVM v1 has neither tracing garbage collection nor runtime cycle collection.
  Effect erasure and closure lowering must avoid unreclaimable strong cycles by
  construction.
- A direct call with a **Closure Environment Reference** can avoid closure-object
  allocation and indirect dispatch, but environment construction is a separate
  lowering and optimization concern.
- Tail position uses distinct direct and callable-value **Tail Call Terminators**.
  Those terminators have no result destination or normal successor in the
  current function.
- A **Tail Call Terminator** transfers all argument and required closure-
  environment ownership into the replacement callee frame. The current frame
  does not retain an owned continuation result.
- The bytecode VM executes **Lowered Continuations** produced before bytecode
  emission. It should not rely on MoonBit closures or implicit host-stack
  capture to implement Lane `resume`.
- Runtime function values are **Bytecode Closures**. The bytecode image stores
  lifted functions in a flat function table, and closures carry only a function
  reference plus captured context.
- Nominal data at runtime is a **Runtime Data Value**. Bytecode instructions
  construct and branch on type-local compact constructor tags assigned during
  bytecode data layout instead of consulting Buslane constructor identities,
  layout identifiers, or names.
- LoisVM bytecode contains no effect operations or effect-dispatch metadata.
  The **Effect-Erased Bytecode Boundary** permits only ordinary calls and runtime
  function or intrinsic calls produced by earlier lowering.
- The **Bytecode Constant Pool** is image-global in v1. All **Bytecode
  Functions** reference the same pool through constant identifiers, allowing
  link-time String deduplication across functions. Numeric and function
  constants remain instruction operands, while constructors use local tags and
  data-layout metadata.

## Example dialogue

> **Dev:** "Does the interpreter decide which `main` to run?"
> **Domain expert:** "No. **Interpreter Entry Selection** belongs to the caller or linker, not to the reference interpreter."

> **Dev:** "Can single-file `lane run` execute `main` by default?"
> **Domain expert:** "No. The **Run Entry Convention** requires `FILE:ENTRY` and executes only an **Executable Entry Type**."

> **Dev:** "Can `lane run` inspect a selected public value such as `sample : Int`?"
> **Domain expert:** "No. **Run Entry Convention** executes an **Executable Entry Type**; arbitrary value inspection belongs to inspect tooling."

> **Dev:** "Can a runtime effect handler intercept operations already handled by source code?"
> **Domain expert:** "No. A **Runtime Effect Handler** only handles the outer residual operations that escape source lexical handlers."

> **Dev:** "Does LoisVM dispatch `perform` through a handler table?"
> **Domain expert:** "No. `mon-trans`, `open-resolve`, and `monadic-lift` erase effect-specific forms before bytecode construction; LoisVM sees only ordinary lowered calls and control flow."
