# Lane Workspace

This repository groups the core Lane implementation modules that should evolve
together during early compiler and tooling development.

## Language

**Module**:
A Lane source-language namespace that owns declarations and forms a visibility boundary.
_Avoid_: source file, prelude, MoonBit package

**Module Declaration**:
The source declaration that gives a **Module** its language-level identity.
_Avoid_: file path, package name, implicit filename module

**Module Binding**:
A name made available by importing a **Module Path** for module-qualified access.
_Avoid_: value declaration, type declaration, filesystem directory component

**Source File**:
A non-interactive Lane source text that contains exactly one **Module**.
_Avoid_: module bundle, project, compilation unit

**Source Identity**:
The file or module identity attached to source locations and diagnostics.
_Avoid_: concatenated source offset, anonymous line range, prelude line shift

**Synthetic Module**:
A driver-supplied module identity for interactive or test snippets that are not ordinary source files.
_Avoid_: ordinary source file fallback, implicit filename module, compatibility mode

**Diagnostic Infrastructure**:
Reusable diagnostic data, source mapping, protocol conversion, and rendering primitives shared by Lane tools without knowing Lane compiler semantics.
_Avoid_: compiler diagnostic adapter, Lane error taxonomy, command report

**Module Path**:
A dotted name that identifies a **Module**.
_Avoid_: filesystem path, package URL, source filename

**Double**:
A Lane primitive type representing IEEE 754 binary64 floating-point values.
_Avoid_: Float, Float64, Basic library number type

**Double Literal**:
A source numeric literal containing digits with a decimal fraction or exponent and whose type is **Double**.
_Avoid_: overloaded numeric literal, Float literal, decimal arbitrary-precision value

**Basic Library Module**:
A normal library **Module** supplied explicitly as a **Library Input**.
_Avoid_: prelude, implicit builtin scope, compiler magic module

**Conventional Basic Module**:
A **Basic Library Module** whose module path and exported shapes are recognized by tools as conventions rather than by an official implementation fingerprint.
_Avoid_: pinned Basic library, compiler-owned module, trusted artifact

**Compilation Unit**:
One **Module** compiled by `lanec` against an **Imported Environment**.
_Avoid_: project, module graph, linked program

**Imported Environment**:
The externally supplied module interfaces visible while compiling one **Compilation Unit**.
_Avoid_: concatenated source, prelude text, linker output

**Module Interface**:
The compiler-readable interface artifact for a compiled **Module**, including its exported type, value, and offer surface plus downstream compilation metadata such as **Optimization Hints**.
_Avoid_: checked source body, private declarations, source AST

**Optimization Hint**:
Compiler-produced metadata stored in a **Module Interface** to help downstream compilation or optimization without changing source-language semantics.
_Avoid_: source declaration, module object code, linker-only metadata

**Module Object**:
The lowered link-time artifact for one compiled **Module**.
_Avoid_: module interface, imported environment, source API surface

**Compiled Module**:
The paired output of compiling one **Module**, containing its **Module Interface** and **Module Object**.
_Avoid_: module interface alone, module object alone, linked program

**Module Fingerprint**:
A stable identity for the **Compiled Module** produced by compiling a **Module Interface** against a specific set of **Imported Interface Fingerprints**.
_Avoid_: module path, source file path, linker symbol

**Module Interface Fingerprint**:
A semantic fingerprint of the exported interface surface alone.
_Avoid_: object code hash, filesystem path, modification time

**Imported Interface Fingerprint**:
The compilation-time fingerprint of an imported **Module Interface** recorded by a dependent **Compiled Module**.
_Avoid_: linked object hash, filesystem timestamp, import path match

**Private Lowered Definition**:
A non-exported lowered definition kept inside a **Module Object** for executing exported code.
_Avoid_: exported symbol, interface member, cross-module reference target

**Exported Symbol**:
A stable source-level identity for an exported declaration in a **Module Interface**.
_Avoid_: Buslane identity, local compiler temporary, runtime address

**Linked Program**:
A set of compiled modules whose imported references have been connected and whose executable entry has been selected by the link step.
_Avoid_: single compilation unit, source concatenation, unchecked module graph, run-time entry selection

**GHC-Like Artifact Layering**:
A compiler artifact strategy where interfaces carry public semantics and optimization metadata, objects carry linkable semantic core plus link metadata, and execution images are derived after linking.
_Avoid_: JVM-style runtime symbolic linking, bytecode-as-only-source, ANF-as-artifact-boundary

**Binary Artifact Container**:
The versioned on-disk container used by `.lmi`, `.lmo`, and `.lbp`, starting with Lane artifact magic, an artifact kind, and a structured binary payload.
_Avoid_: text artifact file, JSON wrapper, UTF-8 payload envelope

**Binary Artifact Payload**:
The structured binary record data inside a **Binary Artifact Container** that is the authoritative serialized form for artifact loading.
_Avoid_: artifact text roundtrip, human-readable dump, debug pretty output

**Minimal Linked Program Payload**:
The fixed-order `.lbp` payload containing `linked_program_schema_version:u32le = 4` followed by a LoisVM bytecode section occupying every remaining payload byte.
_Avoid_: section directory, duplicate entry metadata, module provenance record, nested bytecode length

**Canonical Linked Disassembly**:
The deterministic lowered-code projection used by `lane inspect` for `.lbp`, showing schema versions, the selected entry, table summaries, and canonical bytecode instructions without reconstructing source semantics.
_Avoid_: raw byte dump, Buslane reconstruction, source-debug view

**Artifact Text Format**:
A former human-readable artifact serialization that must not be part of the official artifact load path once binary artifact payloads are introduced.
_Avoid_: compatibility parser, canonical artifact schema, inspect output

**Bytecodec**:
A small reusable MoonBit module for strict byte-level binary readers, writers,
primitive little-endian codecs, length-prefixed strings, offset tracking, and
decode errors.
_Avoid_: Lane artifact schema, Buslane AST codec, generic serialization framework

**Canonical Core Artifact**:
The authoritative semantic payload of a compiled or linked Lane artifact, currently Buslane core plus the metadata needed to link, inspect, verify, or lower it.
_Avoid_: ANF cache, bytecode image, runtime execution layout

**Whole-Program Core Optimization**:
An optimization phase over a linked canonical core program after imported references have been resolved and before lowering to an execution image.
_Avoid_: bytecode-only optimization, source rewriting, interface type checking

**Core Occurrence Analysis**:
A read-only core analysis over a linked **Canonical Core Artifact** before final executable artifact emission that records how core values occur for later optimization decisions.
_Avoid_: source value-use analysis, unused-warning policy, type/effect symbol analysis, raw use-count-only pass, bytecode liveness, artifact payload

**Execution Image**:
A lowered representation for a concrete execution target, such as a portable bytecode image or native code, produced from a linked canonical core program.
_Avoid_: module interface, source API surface, canonical semantic payload

**Wasm Compiled Tier**:
An execution strategy that lowers a decoded trusted LoisVM bytecode execution image into a WebAssembly module and executes that module with a WebAssembly engine, using Milky2018/wasmoon as Lane's default engine.
_Avoid_: direct Buslane-to-Wasm lowering, direct ANF-to-Wasm lowering, MilkIR tier, bytecode verifier

**Extensible Wasmoon Engine**:
The project-controlled default WebAssembly engine whose interpreter, JIT, runtime integration, and supported WebAssembly capabilities may be extended alongside Lane instead of constraining Lane to the current feature set of unrelated engines.
_Avoid_: permission to silently emit non-WebAssembly bytecode, browser compatibility guarantee, fixed third-party engine capability matrix

**Lane Wasm Feature Profile**:
The Lane v1 compiled-output contract built on one canonical non-shared wasm32 linear memory. The emitter may use Multi-value, Reference Types, Typed Function References, Tail Call, Bulk Memory, Exception Handling with `exnref`, Sign-extension Operators, and Extended Constant Expressions. It excludes Stack Switching, Relaxed SIMD, Threads, Atomics, Multiple Memories, Memory64, Wasm GC, and Wasmoon-specific instructions, types, or non-standard module semantics.
_Avoid_: plain WebAssembly 1.0 label, Wasm GC profile, Lane-Wasmoon private opcode set

**Wasm Linear-Memory ARC Heap**:
The Lane-owned dynamic object heap implemented inside wasm32 linear memory. Lane supplies allocation, object layout, non-atomic reference counts, destruction, and recursive release; Wasm GC does not manage Lane objects.
_Avoid_: Wasm GC struct or array, host-managed Lane object, tracing collector

**Representation Erasure**:
The lowering that removes Lane source types and generic type arguments while preserving only the runtime representation information required by Wasm lowering and generic ARC. Monomorphic values use native Wasm representations; a representation-polymorphic value uses an `i64` erased payload together with a hidden layout witness.
_Avoid_: full runtime type reflection, whole-program monomorphization, deletion of all layout information

**Representation Layout Witness**:
A hidden runtime descriptor identified by `LayoutId` that supplies the layout and ownership operations required for an erased generic value without preserving its full Lane type.
_Avoid_: source type argument, dynamic type check, user-visible function parameter

**Image Layout Table**:
The image-owned static table of backend-independent Layout Recipes indexed by immediate `LayoutId` values; recipes derive representation, sizing, alignment, and ownership behavior without storing Wasm helper indices.
_Avoid_: runtime-created type object, source type registry, heap-owned descriptor

**Portable Layout Recipe**:
The tagged Unit, Bool, Int, Double, Callable, String, Data, or Environment execution recipe serialized for one LayoutId before backend-specific descriptor materialization.
_Avoid_: source type descriptor, materialized Wasm helper indices, raw object offsets

**Packed Wasm Callable**:
The Wasm `i64` representation of a Lane callable, with the low 32 bits holding the `FunctionId` and the high 32 bits holding the wasm32 closure-environment offset. Environment offset zero denotes a capture-free function and linear-memory address zero is therefore reserved.
_Avoid_: tagged VM value pair, Wasm GC function reference, heap-allocated closure shell

**Canonical Wasm Lane Entry ABI**:
The typed Wasm function ABI shared by direct, indirect, tail, and runtime-adapter entries: hidden `env:i32` first, required `LayoutId:i32` witnesses next, then user arguments in their erased Wasm representations, followed by zero or one current v1 result. Complete erased signatures are interned in the Wasm type section.
_Avoid_: LoisVM uniform VM-value ABI, caller-provided result cell, per-call closure adapter

**Structured Bytecode Addressing**:
The portable LoisVM encoding where functions contain ordered block tables and slot representation tables, fixed `BlockId = 0` is the entry, control flow targets `BlockId`, and operands reference `SlotId`; serialized branches never target byte offsets or relative instruction PCs.
_Avoid_: threaded bytecode address, branch displacement, Wasm label depth

**Canonical Bytecode Function Body**:
The length-delimited body record ordered as slot table, function inputs, result descriptor, then nonempty block table, with no separately serialized entry-block identifier.
_Avoid_: extensible function record, entry BlockId field, block byte lengths

**Bytecode Edge Record**:
The explicit control-flow destination containing target BlockId, a counted ordered SlotId array, and parallel selected-edge transfer semantics.
_Avoid_: fallthrough, relative branch offset, implicit phi assignment

**Tag Switch Terminator**:
A decision-tree discriminator that reads an unsigned `I32 + Trivial` local tag and selects a possibly empty dense case array or mandatory default edge.
_Avoid_: complete pattern match, LayoutId dispatch, sparse source constructor map

**Trusted Unreachable Terminator**:
A zero-operand terminator for compiler-proven impossible control flow, allowed to trap directly if invalid trusted bytecode reaches it.
_Avoid_: recoverable failure, private fatal exception, source panic

**Representation-Homogeneous Slot**:
A bytecode `SlotId` assigned one erased Wasm representation and ownership category for its entire lifetime. Physical slot reuse may combine logical values only when those categories are compatible.
_Avoid_: full Lane type, dynamically tagged Wasm local, cross-representation slot reuse

**Slot Representation Tag**:
The physical scalar class of a bytecode slot: `I32`, `I64`, or `F64`; `Unit` has no slot representation.
_Avoid_: Lane source type, tagged VM value case, ownership behavior

**Slot Cleanup Category**:
The serialized runtime-cleanup behavior of a slot: `Trivial`, `OwnedRef`, `OwnedCallable`, or `OwnedErased`; it is not a source ownership type or borrow region.
_Avoid_: source lifetime, implicit retain policy, borrow checker annotation

**Erased Ownership Companion**:
The immutable `I32 + Trivial` layout-witness slot named by an `I64 + OwnedErased` slot so cleanup can dispatch through the correct `LayoutId`.
_Avoid_: source type argument, heap descriptor pointer, dynamic type tag

**Bytecode Function Inputs**:
The ordered initial slots established before a function enters its entry block: an optional owned environment, then trivial layout witnesses, then user arguments.
_Avoid_: entry-block parameters, source parameter binders, Wasm operand stack

**Optional Slot Reference**:
The canonical `slot_plus_one:u32le` field where zero denotes absence and nonzero N denotes `SlotId = N - 1`.
_Avoid_: presence byte plus SlotId, sentinel SlotId, nullable VM value

**Derived Indirect Call Shape**:
The exact Wasm function type reconstructed from callable-call argument slots plus a returning destination or the enclosing function's tail-result descriptor, without a serialized call-shape identifier.
_Avoid_: source function type, CallShapeId table, untyped indirect call

**Return Terminator**:
The function exit carrying one source OptionalSlot, consuming a non-Unit result owner or returning Unit when the field is zero.
_Avoid_: returning call, tail call, implicit frame sweep

**Ownership-Empty Exit**:
A normal return or tail transfer reached only after explicit releases have removed every current-frame owner not transferred by that exit.
_Avoid_: runtime frame scan, leaked local owner, exception cleanup handler

**LoisVM Bytecode Schema Version**:
The independent leading `u8` version, `0x01` for v1, governing bytecode tables, records, opcodes, and operand layouts without changing the outer artifact container version.
_Avoid_: artifact container version, Buslane codec version, source language version

**Atomic Bytecode Load**:
The all-or-nothing pipeline that fully decodes, checks local metadata, resolves imports, builds backend state, and publishes a reusable loaded executable image only after complete success.
_Avoid_: partial executable image, import resolution during parsing, Lane code during load

**Implementation Resource Limit**:
A host-specific load or compilation ceiling below schema capacity that may reject a valid image without making its encoding malformed.
_Avoid_: serialized bytecode budget, schema compatibility rule, semantic verifier

**Dense Bytecode Identifier Space**:
An ordered table whose entry position is its serialized identifier: `FunctionId` and `LayoutId` reserve zero, while `BlockId`, `SlotId`, `ConstantId`, and `ObjectShapeId` begin at zero.
_Avoid_: serialized redundant ID field, sparse map, byte offset

**Build-Local FunctionId**:
A dense FunctionId reproducible for an identical compiler build and link invocation but free to change after optimization, compiler, input, or option changes.
_Avoid_: module ABI symbol, persistent function identity, body hash

**Fixed-Shape Opcode Encoding**:
The packed bytecode instruction form where one `u8` opcode determines the exact following operand sequence and unknown opcodes are decoding errors.
_Avoid_: per-instruction length prefix, extensible tagged record, threaded code

**Bytecode Tag Namespace**:
One independently interpreted `u8` variant domain with explicit wire values, invalid `0x00` and `0xFF`, and no dependency on implementation enum ordinals.
_Avoid_: shared global enum, MoonBit variant ordinal, opcode escape byte

**Canonical V1 Opcode Table**:
The normative mapping of 66 instruction names to `0x01..0x42` and seven terminator names to an independent `0x01..0x07` namespace.
_Avoid_: Wasm opcode reuse, compiler enum order, operation subtag

**Inline Scalar Constant**:
An `Int`, `Double`, or `Bool` literal encoded directly in its producing instruction rather than assigned a `ConstantId`.
_Avoid_: constant-pool number, boxed primitive, host-native float serialization

**Integer Undefined Behavior**:
Execution outside the Lane v1 contract caused by signed overflow, division by zero, or an invalid shift count, permitting direct wrapping or trapping machine behavior.
_Avoid_: checked arithmetic, arbitrary precision, recoverable runtime error

**Non-Unwinding Arithmetic Trap**:
A direct engine trap from undefined integer division that does not run the private fatal-exception cleanup path and requires discarding the current instance.
_Avoid_: Private Wasm Fatal Exception, Lane exception, resumable failure

**Explicit Numeric Conversion**:
A source-authorized bytecode conversion between Int and Double with specified rounding or truncation, never inserted as an implicit coercion.
_Avoid_: representation erasure, numeric promotion, bit reinterpretation

**Representation Erasure Bridge**:
A compiler-internal consuming conversion between a natural representation and erased `I64`, transferring ownership while changing width, bit interpretation, or cleanup interpretation.
_Avoid_: source conversion, boxed generic value, runtime typecase

**Non-Unwinding Conversion Trap**:
A direct engine trap from invalid Double-to-Int conversion that bypasses private cleanup and invalidates the current instance.
_Avoid_: saturating conversion, private fatal exception, conversion result value

**Canonical Boolean Scalar**:
The `I32 + Trivial` Bool representation restricted to numeric zero or one at every bytecode-producing boundary.
_Avoid_: arbitrary nonzero truth value, tagged Bool object, host boolean reference

**Image String Constant**:
An ASCII byte sequence deduplicated in the image-global String pool and materialized as an immortal runtime String addressed by zero-based `ConstantId`.
_Avoid_: inline String bytes, dynamic String allocation, numeric constant entry

**Wasm CFG Structuring**:
The backend transformation that maps reducible bytecode CFGs to structured Wasm control and falls back to a `loop` plus `br_table` dispatcher for irreducible CFGs, while implementing bytecode block-parameter transfers through typed locals.
_Avoid_: rejection of irreducible bytecode, byte-offset patching, mandatory Multi-value block parameters

**Lane ARC Object Header**:
The common 8-byte header at every nonzero eight-byte-aligned Lane object reference in wasm32 memory: `ref_count:u32` at offset 0 and `LayoutId:u32` at offset 4, followed by payload at offset 8. Allocation size, flags, tags, and allocator metadata are layout-specific or allocator-private.
_Avoid_: payload pointer, Wasm GC header, universal object-size field

**Immortal Refcount Sentinel**:
The `0xFFFF_FFFF` count stored in image-owned static object headers. Retain and release are no-ops for this value; a dynamic count may never increment into it.
_Avoid_: saturated dynamic count, zero-owner marker, image pointer range check

**Local Constructor Tag**:
A dense `u32` discriminator scoped to one nominal data type and stored as the first word of a runtime data payload. Pattern matching branches on this tag; it is not image-global and is distinct from `LayoutId`.
_Avoid_: Buslane constructor identity, layout identifier, global constructor table index

**Object Shape**:
The canonical member schema indexed by `ObjectShapeId`: a Data variant includes local constructor tag, while an Environment variant has captures and no tag; both record stored-witness count, representations, cleanup, and witness ordinals without raw offsets or alignment fields.
_Avoid_: runtime LayoutId, raw field offset array, String layout

**Layout Operand**:
The five-byte operand whose tag is Immediate `0x01` with nonzero LayoutId or Witness `0x02` with an `I32 + Trivial` witness SlotId.
_Avoid_: ObjectShapeId, source type argument, descriptor pointer

**Field Projection Result**:
The destination record containing a value SlotId and witness-destination OptionalSlot, required only for an erased generic member.
_Avoid_: raw load result, source pattern binder, untyped VMValue

**Typed Data Payload Layout**:
The `ObjectShape::Data`-defined arrangement after the common ARC header: local constructor tag first, then hidden witnesses and user fields placed from representation, alignment, and cleanup.
_Avoid_: flat VMValue array, source field declaration order guarantee, universal payload stride

**Nullary Constructor Singleton**:
An image-owned immortal data object reused for a constructor with no user fields and no generic layout witnesses that must survive for destruction.
_Avoid_: per-construction allocation, source-level global value, singleton requiring pointer identity

**Typed Closure Environment Layout**:
The immutable layout of one closure environment after its common ARC header, containing captured values and any hidden generic `LayoutId` witnesses at erased-representation-aware offsets, with no constructor tag or member-callable backreferences.
_Avoid_: mutable lexical scope, flat user argument list, recursive closure cycle

**Materialized Layout Descriptor**:
The fixed 32-byte record in the image-owned Layout Table containing representation kind, size mode, fixed size or sizer table index, alignment, retain/release/destroy helper table indices, and one reserved word.
_Avoid_: source type metadata, dynamic descriptor object, variable-length table entry

**Layout Helper Entry**:
An internal function-table entry used by descriptor-driven retain, release, destroy, or variable-size calculation. It lives outside the valid Lane `FunctionId` range and cannot become a Lane callable.
_Avoid_: runtime import, bytecode function entry, source function value

**Canonical Lane Memory Export**:
The module-defined, non-shared wasm32 memory exported as `"lane.memory"`, containing reserved address zero, image-owned static data at low addresses, and the module-owned dynamic ARC heap beginning at immutable `heap_base:i32`.
_Avoid_: imported host memory, multiple-memory index, Memory64 address space

**Private Wasm Fatal Exception**:
The non-Lane `exnref` control channel used to unwind runtime-import failure, allocation failure, ARC overflow, and other fatal internal execution errors through generated cleanup handlers.
_Avoid_: Lane exception value, effect operation, recoverable result

**Lane Wasm Module ABI**:
The external module contract exporting `"lane.entry":() -> ()`, `"lane.memory"`, and restricted runtime-service helpers while importing registry symbols from module namespace `"lane.runtime.v1"`.
_Avoid_: exporting every Lane function, source module ABI, Component Model interface

**Runtime Service Nested Call**:
A host-import-time call through RuntimeContext to a designated non-Lane service export such as `"lane.runtime.string.new"`, permitted only for allocation or runtime integration and unable to invoke entry, closures, or ordinary `FunctionId` targets.
_Avoid_: Lane callback, general VM reentry, asynchronous continuation

**Static Wasm Image Initialization**:
The instantiation-time materialization of image-owned memory and function-table contents through active data and element segments, without executing a Wasm start function.
_Avoid_: runtime constructor, lazy image loading, Lane entry initialization

**Canonical Wasm Function Table**:
The single private fixed-capacity `funcref` table whose zero index is invalid, whose contiguous Lane range maps `FunctionId` directly to table index, and whose remaining entries are internal helpers.
_Avoid_: exported table, growable callable registry, multiple tables

**Trusted Execution Image**:
An execution image accepted under the contract that it was emitted by the matching Lane linker, allowing execution components to rely on its semantic invariants without a separate bytecode verifier.
_Avoid_: untrusted interchange format, sandbox input, verified bytecode

**Compiler-Directed Reference Counting**:
The automatic memory-management model where compiler ownership and last-use analysis inserts explicit reference-count operations into the execution image.
_Avoid_: tracing garbage collection, source-written retain/release, implicit retain on every slot copy

**Ownership Transfer**:
A value movement where an existing owned reference is consumed by its destination without incrementing the reference count.
_Avoid_: borrowed use, retained copy, raw pointer move

**Trivial Slot Copy**:
The `copy(dst, src)` instruction that duplicates bits between equal-representation `Trivial` slots without consuming the source or changing ownership.
_Avoid_: owned-value duplication, implicit retain, raw assignment

**Ownership Move**:
The `move(dst, src)` instruction that transfers a compatible logical value and any ownership to a dead destination without changing reference counts or clearing source bits.
_Avoid_: retained copy, destination overwrite, memory move

**Retain Copy**:
The `retain_copy(dst, src)` instruction that applies the destination's owned cleanup category to establish a new owner while copying equal-representation source bits.
_Avoid_: unary retain, trivial copy, ownership transfer

**Callee-Owned Call ABI**:
The bytecode calling convention where reference-bearing arguments and any required closure environment transfer ownership into the callee, while the returned value transfers owned ownership back to the caller.
_Avoid_: borrowed-argument ABI, caller-released arguments, ownership-neutral call

**Effect-Erased Execution Image**:
A bytecode execution image produced after `mon-trans`, `open-resolve`, and `monadic-lift` have eliminated all effect-specific forms, identities, contexts, and dispatch tables.
_Avoid_: bytecode perform, handler-context ABI, runtime operation table

**Unified Execution Function Table**:
The bytecode image function index space where one `FunctionId` may designate either a bytecode-defined function or a load-time-bound runtime import.
_Avoid_: separate runtime call opcode, runtime operation table, bytecode-only function id

**Selected Bytecode Entry**:
The nonzero FunctionId stored in executable bytecode for the link-validated no-context, witness-free, zero-argument Unit body invoked by execution.
_Avoid_: source export symbol, runtime-selectable entry catalog, runtime import

**Uniform Runtime Import ABI**:
The fixed-arity erased host-call contract where an implicit borrowed runtime context plus uniform VM-value arguments returns exactly one owned VM value.
_Avoid_: source type metadata, varargs, typed bytecode calling convention

**Synchronous Primitive Host Call**:
The v1 host boundary where runtime imports complete synchronously without Lane program reentry or retained VM values and exchange only `Int`, `Double`, `Bool`, `String`, or `Unit`; approved runtime-service nested calls are not Lane reentry.
_Avoid_: async FFI, host callback, closure crossing, opaque handle

**Runtime Symbol Registry**:
The runtime-owned source of truth mapping a versioned host symbol to its primitive signature and implementation contract.
_Avoid_: bytecode parameter-type list, per-call lookup, duplicated compiler registry

**Runtime Import Failure**:
The fatal out-of-band host-call error that produces no Lane value or bytecode exception edge and terminates the current execution.
_Avoid_: catchable exception, effect operation, recoverable primitive result

**Loaded Executable Image**:
A reusable successfully loaded product containing decoded bytecode, resolved runtime bindings, and any reusable backend compilation result, from which fresh execution instances are created.
_Avoid_: active call stack, mutable heap instance, partially loaded artifact

**Single-Shot Execution Instance**:
The thread-confined dynamic heap, frame stack, allocator state, runtime context, and resource configuration used by exactly one selected-entry attempt.
_Avoid_: reusable loaded image, concurrent VM, resumable failed instance

**Execution Resource Limit**:
A host-configured run-time bound such as logical call depth or live heap bytes whose exhaustion follows cleanup-capable fatal failure.
_Avoid_: malformed bytecode, load-time ResourceLimit, engine-native trap

**Execution Interruption**:
An out-of-band host or engine cancellation that may bypass ARC cleanup and always makes the current execution instance terminal.
_Avoid_: Lane exception, bytecode branch, portable timeout semantics

**Engine Trap**:
A non-portable execution-engine failure such as native stack overflow or a direct Wasm trap, carrying only best-effort backend detail and requiring instance discard.
_Avoid_: Runtime Import Failure, Execution Resource Limit, recoverable Lane value

**Consuming Callable Projection**:
The `call_value` ownership rule that consumes one callable owner, moves a unique closure environment, or retains a shared closure environment for the callee.
_Avoid_: unique-only indirect call, public closure unpack, unconditional environment retain

**Runtime String Object**:
The immutable ARC String layout with a common object header, `byte_length:u32` at payload offset 0, and ASCII bytes immediately after it; image-owned literals use the same layout with the immortal count.
_Avoid_: NUL-terminated string, mutable bytes, parent-backed slice view

**String Primitive**:
A dedicated LoisVM length, concatenation, slicing, or equality operation over immutable ASCII Runtime String Objects.
_Avoid_: generic String dispatch, host text operation, raw linear-memory access

**Borrowed Host String View**:
The zero-copy pointer-length view of an owned String argument that is valid only during a synchronous runtime import.
_Avoid_: retained host pointer, copied input, bytecode string pair

**Compiler-Private VM CFG**:
The non-serialized virtual-value control-flow representation used after continuation and closure lowering but before ownership lowering, physical slot allocation, and bytecode emission.
_Avoid_: LoisVM bytecode model, artifact payload, WebAssembly module

**Owning Block Parameter**:
A bytecode block parameter that receives ownership from the selected incoming control-flow edge.
_Avoid_: borrowed phi input, implicit retained copy, source binder

**Block-Local Borrow**:
A compiler-private non-owning reference use whose owner remains live and whose lifetime does not cross a control-flow, call, return, or heap-storage boundary.
_Avoid_: bytecode ownership type, borrowed block parameter, source lifetime annotation

**Consuming Object Construction**:
The runtime-object construction convention where each reference-bearing field operand transfers one owned reference into the new object without an implicit retain.
_Avoid_: borrowed field storage, constructor-internal retain, ownership-neutral allocation

**Consuming Projection**:
A data projection that consumes one owner of a runtime data object and returns selected payload fields as owned values, using a unique-reference move fast path and a shared-reference retain fallback.
_Avoid_: borrowing projection, unchecked destructive read, source pattern match

**Immediate VM Value**:
A non-allocating VM value represented directly in a tagged slot and excluded from reference counting.
_Avoid_: heap object, image-owned constant, boxed primitive

**Image-Owned Static Value**:
An immutable object whose lifetime is owned by the loaded bytecode image and whose retain and release operations are omitted or no-ops.
_Avoid_: dynamic reference-counted object, unloadable external resource, copied constant

**Thread-Confined VM Heap**:
A LoisVM instance heap whose dynamic values and non-atomic reference counts are accessed by only one thread.
_Avoid_: shared concurrent heap, atomic reference counting, cross-thread VM value

**Continuation Closure**:
A reusable lowered continuation represented by the ordinary closure pair of a function identifier and reference-counted environment.
_Avoid_: VM stack snapshot, dedicated continuation heap object, host closure

**Bytecode Cache**:
An optional, invalidatable build cache outside the authoritative module-object and linked-program payloads, used to avoid repeated lowering when the compiler version, target, options, and core fingerprint still match.
_Avoid_: `.lmo` payload, linked execution image, interface fingerprint source, cross-module semantic record

**NoBuild Model**:
A build philosophy where running a source file is direct and higher-level compile, link, optimize, and entrypoint policies are user-authored library workflows.
_Avoid_: hard-coded main rule, mandatory project manifest, compiler-owned build graph policy

**Build Workflow**:
A user-authored workflow that composes compilation, linking, optimization, and entrypoint selection.
_Avoid_: language semantics, fixed CLI convention, compiler phase

**Direct File Run**:
Running the module declared by a single source file without requiring a project manifest.
_Avoid_: script mode, anonymous module execution, project discovery

**Entry Selection**:
The workflow choice of which compiled value or function to inspect or execute.
_Avoid_: language-level main rule, implicit export, compiler-owned policy

**Public Entry**:
An exported value or function selected for execution or inspection by a workflow.
_Avoid_: private debug entry, implicit main, unexported root symbol

**Imported Reference Placeholder**:
A Buslane-level placeholder for an imported exported symbol before linking connects it to its defining module.
_Avoid_: source symbol, prelude text, final linked identity

**External Origin**:
The compiler-side classification of a Buslane external value as a runtime intrinsic or an imported reference.
_Avoid_: Buslane source syntax, module namespace in core, untyped runtime lookup

**Import Graph**:
The acyclic dependency graph between modules through their imports.
_Avoid_: recursive module group, textual include order, linker SCC

**Import Graph Check**:
The pre-compilation validation of duplicate modules, missing imports, and import cycles in a **Module Input Set**.
_Avoid_: linker error, filesystem path validation, recursive compilation fallback

**Transparent Export**:
An exported alias whose definition remains visible through a **Module Interface**.
_Avoid_: opaque type, abstract type, private alias

**Interface-Visible Type**:
A type that can appear in a **Module Interface** because it is exported or imported from another **Module Interface**.
_Avoid_: private representation type, local type, hidden implementation detail

**Interface-Visible Effect**:
An effect that can appear in a **Module Interface** because it is exported or imported from another **Module Interface**.
_Avoid_: private effect leak, implementation-only operation, runtime capability

**Library Input**:
Explicitly supplied library source files or library directories made available to a **Build Workflow** or **Direct File Run**.
_Avoid_: implicit prelude, textual include, mandatory project manifest

**Module Input Set**:
The root source and supplied library modules available to one **Direct File Run**.
_Avoid_: global module search path, implicit Basic library, project registry

**Library Directory**:
A directory supplied as a **Library Input** whose source files can provide modules.
_Avoid_: project manifest, implicit Basic library, module identity source

**Open Import**:
An import that places exported members of another **Module** directly in local scope.
_Avoid_: textual include, module shorthand, hidden global scope

**Visible Offer**:
An exported offer available to contextual resolution in the current **Compilation Unit**.
_Avoid_: qualified-only offer, hidden candidate, trait instance

**Module Name Ambiguity**:
A module-level name conflict between local declarations and open imports, or between multiple open imports.
_Avoid_: import-order priority, implicit prelude shadowing, local block shadowing

**Duplicate Module Input**:
Two supplied source files declaring the same **Module Path**.
_Avoid_: library override, search path priority, last-one-wins

**Qualified Import**:
An import that makes an external **Module** name visible without placing its members directly in local scope.
_Avoid_: open import, textual include, prelude concatenation

**Import Section**:
The contiguous import declarations after a **Module Declaration** and before ordinary declarations.
_Avoid_: late import, local import, declaration interleaving

**Duplicate Import**:
Two structurally identical import declarations in the same **Import Section**.
_Avoid_: multi-form import, import-order conflict, last-one-wins

**Selective Import**:
An import that places named exported members of another **Module** directly in local scope.
_Avoid_: wildcard open import, module shorthand, member rename, private declaration access

**Qualified Access**:
Selection through a namespace. Module-qualified value and type access uses `.`, while nominal constructors and variants use `::`.
_Avoid_: implicit open lookup, shadowing rule

**Unambiguous Owner Elision**:
The source-language rule that enum variant and effect operation owners may be omitted when the visible variant or operation namespace contains exactly one matching member name, and must be rejected when no member or multiple members fit.
_Avoid_: expected-type disambiguation, overload resolution, first-match owner, mandatory qualification, delayed ambiguity

**Exported Declaration**:
A declaration explicitly made visible outside its defining **Module**.
_Avoid_: default-public declaration, implementation helper

**Visibility Modifier**:
The top-level declaration prefix that marks an **Exported Declaration**.
_Avoid_: local visibility, module visibility, export block

**Owner-Visible Member**:
A struct field, struct type member, or enum variant whose visibility follows its owning exported type.
_Avoid_: independently exported field, independently exported variant

**Exported Nominal Shape**:
The public fields, type members, and variants of an exported struct or enum.
_Avoid_: opaque representation, private constructor, hidden variant set

**Typed Algebraic Effect**:
A declared source-language operation whose use is statically tracked in effect sets and discharged by effect handlers.
_Avoid_: unchecked exception, runtime panic, implicit IO

**Effect Declaration**:
A top-level nominal declaration that owns a complete set of effect operations and any shared effect type parameters.
_Avoid_: value declaration, operation namespace, runtime plugin

**Interface-Visible Effect**:
An effect that can appear in a module interface because it is exported or imported from another module interface.
_Avoid_: private effect leak, implementation-only operation, runtime capability

**Effect Operation**:
A member of an effect declaration with a Lane function type signature such as `(String) -> Unit` or `() -> String`.
_Avoid_: top-level function, arbitrary expression payload, unchecked command

**Operation Type Parameter**:
A type parameter introduced by an **Effect Operation** and opened by handlers for each performed operation instance.
_Avoid_: effect type parameter, ordinary value parameter, generic function parameter, runtime tag

**Type Argument List**:
A non-empty bracketed list of type witnesses supplied to a generic type, nominal member, or effect operation call.
_Avoid_: empty brackets, omitted type arguments, type parameter binder list

**Effect Operation Call**:
An effectful operation invocation written with `!`, such as `Console::print!("hi")` or an unambiguous `print!("hi")`.
_Avoid_: ordinary function call, omitted call parentheses, implicit perform expression, unchecked command dispatch

**Effect Set**:
The finite, order-insensitive set of typed algebraic effects that an expression or function may perform.
_Avoid_: exception list, ordered runtime list, runtime capability bag, implicit ambient state

**Effect Set Alias**:
A transparent top-level alias whose expansion has **Effect Kind** and denotes an **Effect Set**.
_Avoid_: effect declaration alias, operation alias, nominal effect wrapper

**Effect Variable**:
A type-level variable ranging over effect sets in an effect-polymorphic function type.
_Avoid_: value parameter, contextual offer, dynamic capability token

**Effect Kind**:
The kind `Effect` whose inhabitants are effect sets and effect variables.
_Avoid_: value-level type, ordinary nominal type kind, runtime capability object

**Effect Polymorphism**:
The ability for a function type to quantify over an effect set and propagate that set through calls.
_Avoid_: effect subtyping, unchecked effect escape, implicit handler search

**Effect Row Unification**:
The equality-based inference process that solves effect variables inside effect sets, including decomposition into handled concrete effects plus a residual row.
_Avoid_: effect subtyping, implicit widening, containment constraint solving, multiple row tails

**Function Effect Annotation**:
The optional `!` suffix after a function result type that states a function's non-empty effect set.
_Avoid_: prefix effect marker, unchecked throws clause, handler declaration

**Effect Handler**:
An expression of the form `handle expression with { ... } with { ... }* final binder { ... }` that implements effect operations and computes one handler result.
_Avoid_: catch block, runtime error handler, implicit identity final branch, per-effect return branch

**Handler With Block**:
One non-empty `with { ... }` block in a handler expression; all arms in the block target the same handled effect.
_Avoid_: mixed-effect handler block, implicit global handler, exception catch group

**Handler Operation Arm**:
A handler pattern arm that matches one effect operation invocation, uses ordinary Lane patterns for operation arguments, and binds an explicit final resume continuation.
_Avoid_: catch clause, method override, optional resume, tupled operation arguments

**Handler Final Branch**:
The required `final binder { ... }` branch that handles ordinary return from the handled expression.
_Avoid_: operation arm, final pattern, match-arm arrow body, implicit identity result

**Resume Continuation**:
The explicit, first-class, multi-shot continuation binder in a handler operation arm.
_Avoid_: implicit resume keyword, one-shot continuation, stack-only continuation, unchecked jump

**Residual Effect Set**:
The effect set that remains on a handler expression after handled effects are removed and unhandled, final-branch, and operation-arm effects are preserved.
_Avoid_: swallowed handler effects, unchecked escape, operation-level leftovers

**Handler Coverage Check**:
The static check that each handled effect is covered as a whole and that each handled operation's argument pattern matrix is exhaustive and useful.
_Avoid_: partial handler, runtime missing-operation failure, duplicate-only rejection

**Deep Effect Handler**:
An effect handler whose resumed continuation remains under the same handler while effects produced directly by handler arm bodies are not self-captured.
_Avoid_: shallow handler, one-shot catch, implicit rehandle of arm bodies

**Buslane Effect Core**:
The Buslane `perform` and `handle` core forms produced by lowering source effect operation calls and handlers.
_Avoid_: source syntax, ordinary function call, exception catch frame

**Pre-Buslane Contract**:
The compiler-front-end contract that checked source must satisfy before semantic lowering into Buslane.
_Avoid_: Buslane verifier contract, whole-program core optimization, execution image lowering

**Unhandled Perform State**:
A stuck Buslane runtime state where a `perform` expression reaches no enclosing handler for its owning effect.
_Avoid_: unchecked exception, implicit runtime catch, successful effect propagation

**Unchecked Runtime Exception**:
A catchable language-level failure that can escape static effect tracking.
_Avoid_: typed algebraic effect, runtime error report, undefined behavior

**Lane Workspace**:
The MoonBit workspace that contains the compiler, Buslane, and command line
tool modules.
_Avoid_: single package, release artifact

**Module Repository Layout**:
The repository layout where each MoonBit module lives under `modules/`.
_Avoid_: `lane-tools`, root package layout

**Compiler Module**:
The `modules/lanec` MoonBit module that owns parsing, resolution, type
checking, source elaboration, and lowering.
_Avoid_: CLI tool, language server

**Buslane Module**:
The `modules/buslane` MoonBit module that owns the typed core language,
verifier, interpreter, and pretty printer.
_Avoid_: source AST, compiler front end

**Lane Command Module**:
The `modules/lane` native command module, including the `lane lsp` language
server subcommand.
_Avoid_: VS Code extension, compiler front end

## Relationships

- `modules/lanec` depends on `modules/buslane`.
- `modules/lane` depends on `modules/lanec` and `modules/buslane`.
- A **Compilation Unit** contains exactly one **Module**.
- Every non-interactive **Module** has an explicit **Module Declaration**.
- A **Source File** contains exactly one **Module**, and its **Module Declaration** is first.
- A **Module Declaration** names a **Module Path**.
- A **Module Declaration** does not create a value or type declaration.
- **Basic Library Modules** use ordinary **Module Paths** such as `Basic.Builtins`, `Basic.Ops`, and `Basic.Io`.
- A **Module Declaration** is a header declaration, not a braced block.
- **Synthetic Modules** are limited to interactive and test drivers.
- A **Source File** has an **Import Section** before ordinary declarations.
- Once an ordinary declaration appears, the **Import Section** is closed and later imports are invalid.
- The order of imports inside an **Import Section** does not affect semantics.
- Source locations carry **Source Identity**.
- A **Compilation Unit** may be checked against an **Imported Environment**.
- An **Imported Environment** is made of **Module Interfaces**.
- `lanec` core compiles one **Compilation Unit** without recursively resolving imports.
- CLI and **Build Workflows** construct the **Imported Environment** before calling `lanec`.
- A **Module Interface** is consumed during downstream compilation.
- A **Module Interface** may carry **Optimization Hints** for downstream compilation.
- A **Module Object** is consumed during linking.
- A **Module Object** carries a **Canonical Core Artifact**; ANF and bytecode are not its semantic source of truth.
- A **Compiled Module** pairs a **Module Interface** with a **Module Object**.
- The **Module Interface** and **Module Object** in one **Compiled Module** share a **Module Fingerprint**.
- A **Compiled Module** records the **Imported Interface Fingerprints** it used during compilation.
- A **Module Interface Fingerprint** is based on interface-visible semantic content, not filesystem metadata.
- A **Module Fingerprint** includes the imported interface fingerprints used by that module compilation.
- Linking rejects mismatched **Module Interface** and **Module Object** pairs.
- Linking rejects modules whose recorded **Imported Interface Fingerprints** do not match the linked **Module Interfaces**.
- Linking rejects imported reference placeholders whose recorded **Module Fingerprint** does not match the linked imported **Module Object**.
- A **Module Object** may contain **Private Lowered Definitions**.
- A **Qualified Import** exposes module-qualified names by default.
- A **Module** may explicitly use an **Open Import**.
- A **Module** may explicitly use a **Selective Import**.
- First-stage imports are qualified imports, open imports, and selective imports.
- A **Duplicate Import** is an error.
- The same **Module** may be imported through multiple non-identical import declarations.
- A default **Qualified Import** binds the full **Module Path** for **Qualified Access**.
- A **Module Binding** is separate from value and type namespaces.
- Value and type declarations do not shadow **Module Bindings**.
- Module-qualified value access is written as `Module.Path.name`.
- Module-qualified type access is written as `Module.Path.Type`.
- Module-qualified effect and **Effect Set Alias** access is written as `Module.Path.Name`.
- Module-qualified nominal member access combines both separators, such as `Module.Path.Type::{ ... }` and `Module.Path.Type::variant`.
- The left side of module-qualified access must be an imported complete **Module Path**.
- Importing `Module` does not make `Module.Child.name` or `Module.Child.Type` available.
- **Double Literals** produce **Double** values directly; Lane does not use
  numeric literal overloading or implicit conversion between `Int` and
  **Double**.
- **Typed Algebraic Effects** are the only planned language-level effect mechanism; **Unchecked Runtime Exceptions** are permanently outside the Lane language design.
- An **Effect Declaration** owns uniquely named **Effect Operations**; an **Effect Operation** may introduce **Operation Type Parameters**.
- An **Operation Type Parameter** is scoped only to its owning **Effect Operation** signature and may shadow an **Effect Declaration** type parameter by normal innermost-binder lookup.
- An **Effect Operation Call** may qualify a generic owning **Effect Declaration** with ordinary owner type arguments, and separately supplies **Operation Type Parameter** witnesses at the perform site.
- An **Effect Handler** must explicitly open **Operation Type Parameters** as fresh type binders for the matching handler arm.
- **Operation Type Parameters** follow the same witness/opened-binder split as existential enum variant type parameters.
- A written **Type Argument List** is always non-empty; omitting brackets is the only way to omit type arguments.
- Public **Effect Declarations** and their operation signatures enter module interfaces; exported function signatures may mention only **Interface-Visible Effects**.
- Public **Effect Set Aliases** enter module interfaces as transparent type aliases and may mention only **Interface-Visible Effects**.
- An **Effect Operation Call** invokes an **Effect Operation**, keeps ordinary call parentheses even for zero arguments, and contributes the owning **Typed Algebraic Effect** to the surrounding **Effect Set**.
- Source **Effect Operation Calls** lower to the `perform` part of **Buslane Effect Core**; source **Effect Handlers** lower to the `handle` part.
- **Effect Operation Lookup** is separate from ordinary value lookup and contextual offer lookup; qualified operation syntax is distinguished by `!` in calls and by handler-arm position.
- A **Function Effect Annotation** names an **Effect Set**; non-empty named function effects must be explicit, while function literals may use an explicit annotation or an expected function type.
- **Effect Sets** normalize by removing duplicates, ignoring order, expanding single-effect sugar, and allowing at most one row tail to solve to the empty effect set.
- An **Effect Set Alias** is a transparent **Top-Level Type Alias** of **Effect Kind**, not a new **Effect Declaration**.
- An **Effect Declaration** and an **Effect Set Alias** cannot share the same top-level name in one **Module**.
- **Effect Polymorphism** uses **Effect Variables** of **Effect Kind** and **Effect Row Unification**, not effect subtyping.
- An **Effect Handler** contains one or more **Handler With Blocks** and exactly one **Handler Final Branch**; each `with` block is non-empty, handles one effect, and cannot be duplicated for the same effect.
- **Handler Operation Arms** must target the block's handled effect, match operation arguments with ordinary Lane patterns, and place the **Resume Continuation** as the final binder.
- **Handler Coverage Check** covers every operation of the handled effect and uses the existing pattern usefulness, exhaustiveness, and first-match order rules; the resume binder is not part of the pattern matrix.
- A **Handler Final Branch** must use `final binder { ... }`, and the binder must be an identifier rather than a pattern.
- The **Residual Effect Set** keeps unhandled effects from the handled expression plus effects from handler arms and the final branch; closed effect sets reject absent handled effects.
- **Deep Effect Handlers** make resumed computation run under the same handler, but effects produced directly by handler arm bodies are not self-captured.
- A **Resume Continuation** is first-class and multi-shot; its type returns the handler result and carries only the handler's **Residual Effect Set**.
- An **Unhandled Perform State** is impossible for well-typed complete safe programs.
- Importing a module does not implicitly import its dotted child module paths.
- A **Selective Import** imports top-level **Exported Declarations**, not **Owner-Visible Members**.
- A **Selective Import** introduces selected exported declarations as unqualified names.
- A **Selective Import** may list exported value and type declarations together.
- A **Selective Import** item is ambiguous if the same imported name matches multiple namespaces without syntactic disambiguation.
- Import declarations do not support `as` aliases or renaming.
- An **Open Import** opens top-level **Exported Declarations**, not **Owner-Visible Members**.
- An **Open Import** contributes exported offers as **Visible Offers**.
- A **Selective Import** contributes selected exported offers as **Visible Offers**.
- **Module Name Ambiguity** is an error rather than a shadowing rule.
- **Module Name Ambiguity** includes dotted chains that could be both module-qualified access and value field projection.
- **Qualified Access** uses `.` for module members and `::` for nominal members.
- Module-level names remain separated by namespace; duplicate names in the same namespace are invalid.
- Declarations are module-private unless they are **Exported Declarations**.
- A **Visibility Modifier** applies only to top-level declarations.
- Type members, fields, and variants are **Owner-Visible Members**.
- A **Module Interface** includes each **Exported Nominal Shape**.
- Public type aliases are **Transparent Exports**.
- Public signatures only mention **Interface-Visible Types**.
- Public nominal shapes only mention **Interface-Visible Types**.
- A **Module Interface** records **Exported Symbols**, not Buslane identities.
- **Optimization Hints** do not change the source-language meaning of an imported **Module**.
- A compilation action produces a **Compiled Module**.
- Cross-module references target **Exported Symbols**, not **Private Lowered Definitions**.
- Module-level visibility is outside the **Module** milestone.
- Imported references lower to **Imported Reference Placeholders** before linking.
- **External Origin** distinguishes runtime intrinsics from imported references.
- A **Linked Program** connects imported references across compiled modules and records the executable entry selected by `link`.
- A build `link` primitive chooses the executable entry before **Core Occurrence Analysis** and whole-program optimization.
- A linked executable artifact exposes one selected entry, not a list of run-time selectable public entries.
- A link-time executable entry is selected through an **Exported Symbol**; private lowered definitions are not command-line entry contracts.
- Link validates the selected entry's executable type and supported runtime effects before producing a linked executable artifact.
- `runobj` must not rely on source-level type information to decide whether an entry is executable; a linked executable artifact may omit type information needed only for link-time validation.
- `runobj` executes the selected entry recorded in the **Linked Program**; it does not choose an entry at run time.
- Lane follows **GHC-Like Artifact Layering** for compile, link, optimization, and execution artifacts.
- **Optimization Hints** may guide downstream optimization like interface metadata, but they do not define source semantics.
- **Whole-Program Core Optimization** runs over a linked **Canonical Core Artifact**, not over source text or per-module bytecode alone.
- **Core Occurrence Analysis** is a **Whole-Program Core Optimization**
  analysis input, not a replacement for **Checked Value-Use Analysis**.
- **Core Occurrence Analysis** runs before final executable artifact emission,
  while type, effect, entry, and root metadata needed for optimization are still
  available.
- **Core Occurrence Analysis** produces optimizer-local derived facts; linked
  artifacts do not store those facts as semantic payload.
- **Core Occurrence Analysis** tracks value-level Buslane/core bindings and
  references, not source type or effect symbols.
- **Core Occurrence Analysis** records structured occurrence facts such as use
  count, call-position use, escape to non-call positions, effectful-context use,
  and reachability from the selected entry.
- **Core Occurrence Analysis** runs on linked Buslane/core, not on ANF; ANF is a
  lower derived form that may have its own later liveness or occurrence pass.
- ANF is a derived normalization layer below Buslane and may be regenerated from the **Canonical Core Artifact**.
- An **Execution Image** is produced from linked core after optimization; it may be the primary payload used by `runobj`, but it is not the public interface contract.
- The LoisVM bytecode **Execution Image** is the input to both interpretation and the **Wasm Compiled Tier**. Compiled execution lowers decoded bytecode into a WebAssembly module rather than bypassing it through compiler-internal Buslane or ANF.
- Lane v1 compiled output follows the **Lane Wasm Feature Profile**. Wasmoon may extend its implementation and optimize Lane-generated modules, but those modules do not depend on Wasmoon-specific instructions, types, or non-standard module semantics.
- The profile permits Multi-value, Reference Types, Typed Function References, Tail Call, and Bulk Memory instructions. It remains wasm32 linear-memory based and explicitly excludes Wasm GC.
- Memory64 is excluded from Lane v1. Heap references, closure environments, function identifiers, layout identifiers, and packed-callable components remain 32-bit quantities, and one Lane instance cannot address a heap beyond the wasm32 linear-memory space.
- Multiple Memories is excluded from Lane v1 output. Memory index zero is the canonical Lane memory containing dynamic heap objects, image-owned static data, layout metadata, and runtime-visible byte buffers; every Lane pointer is an offset into that memory.
- Threads and Atomic instructions are excluded from Lane v1 output. The canonical memory is not shared, one Lane instance is not entered concurrently, and non-atomic ARC remains valid. Wasmoon may still compile in parallel or execute separate instances on different threads.
- Bulk Memory operations may initialize static data and tables, fill allocator regions, and copy raw bytes such as String contents. They do not clone reference-bearing objects or replace field-wise retain, release, and ownership-transfer semantics.
- Wasm Exception Handling is reserved for out-of-band runtime-import failure unwinding. Private Wasm exceptions trigger frame-local ARC cleanup and rethrow until the execution boundary converts them to **Runtime Import Failure**; they are not Lane values, effects, exceptions, or bytecode exceptional edges.
- Lane v1 may emit Sign-extension Operators and Extended Constant Expressions. Non-trapping Float-to-int, Fixed-width SIMD, Branch Hinting, Wide Arithmetic, Custom Page Sizes, and Memory Control are profile-aware but not emitted or required by the v1 backend.
- Stack Switching and Relaxed SIMD are excluded. Continuations are already lowered before bytecode, and Lane v1 does not accept platform-dependent relaxed-vector results as default execution semantics.
- Import/Export Mutable Globals, Compilation Hints, WASI Preview 1, the Component Model with WASI Preview 2, and JS BigInt-to-`i64` integration are profile-aware integration options but are not emitted or required by Lane v1 core lowering.
- Multiple Tables and Relaxed Dead-code Validation are excluded from Lane v1 output. The canonical callable ABI uses one function table, and every generated function body must pass ordinary strict Wasm validation.
- JS Promise Integration, JS String Builtins or String References, and Custom Descriptors or JS Interop are excluded. Runtime imports remain synchronous, Strings remain ASCII ARC objects in canonical linear memory, and JavaScript objects do not enter the Lane value ABI.
- Extended Name Sections, Custom Annotations, Rounding Variants, Half Precision, Flexible Vectors, Type Imports, and the JIT Interface are profile-aware but are not emitted or required by Lane v1.
- Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are excluded. They conflict respectively with thread confinement, the Wasmoon-centered host boundary, and the linear-memory ARC object model.
- The **Wasm Compiled Tier** implements dynamic Lane objects in a **Wasm Linear-Memory ARC Heap**. Compiler-emitted retain, release, ownership-transfer, construction, and consuming-projection semantics remain authoritative; Wasm GC is not used for Lane objects.
- Lane uses **Representation Erasure**, not whole-program monomorphization. Monomorphic values lower to native Wasm scalar or reference representations, while representation-polymorphic values cross generic boundaries as an `i64` erased payload accompanied by a hidden **Representation Layout Witness**.
- A **Representation Layout Witness** contains only layout and ownership behavior needed for generic values. It is preserved in LoisVM bytecode as execution metadata or a hidden call operand even though source types and source-level type arguments are erased.
- Every `LayoutId` indexes an image-global **Portable Layout Recipe**. Equal recipes are deduplicated and ordered deterministically; generic objects store the `LayoutId` values needed to destroy erased fields. When generic code needs a derived layout such as `List[T]`, the compiler threads that precomputed witness rather than constructing a descriptor at runtime.
- Wasm lowers every first-class callable to a **Packed Wasm Callable**. `call_value` unpacks its table index and environment offset, then uses typed `call_indirect`; each nonzero environment offset represents one owned environment reference. Wasm retain and release operate directly on that environment and no closure shell is allocated.
- Typed Function References are permitted by the **Lane Wasm Feature Profile** but do not define the canonical Lane callable ABI. Canonical value and tail calls use `call_indirect` and `return_call_indirect`; `call_ref` and `return_call_ref` remain available only for backend-local cases that do not change callable storage or generic erasure.
- Every compiled Lane target uses the **Canonical Wasm Lane Entry ABI**. Capture-free calls pass zero for `env`; representation witnesses are non-owning immediates; monomorphic values use natural Wasm types; generic values use `i64`; and `Unit` returns no result. Multi-value remains available for a future Lane value requiring several physical scalars but is not needed by current v1 value representations.
- LoisVM uses **Structured Bytecode Addressing**. Each function has ordered blocks and **Representation-Homogeneous Slots**; fixed `BlockId = 0` is the entry, blocks contain instruction arrays plus explicit terminators, and no serialized control edge depends on instruction byte position.
- Each bytecode section begins with **LoisVM Bytecode Schema Version** `0x01` for v1 and no duplicate magic. The containing `.lbp` section supplies kind and length framing.
- A `.lbp` uses a **Minimal Linked Program Payload**: `linked_program_schema_version:u32le = 4` followed by one bytecode section consuming the payload remainder. It has no section directory, nested bytecode length, module paths, semantic core, or outer copies of entry and runtime-import data.
- The in-memory linked artifact carries a decoded bytecode image. The artifact codec owns outer framing and delegates the nested image codec to `loisvm/bytecode`.
- `lane inspect` presents `.lbp` through **Canonical Linked Disassembly**. Bytecode errors retain section-relative offsets, while CLI presentation may additionally derive an absolute file offset.
- Schema counts have no normative maxima below `u32`; checked arithmetic and minimum-size preflight protect framing, while **Implementation Resource Limits** may reject otherwise valid images.
- **Atomic Bytecode Load** completes decoding before import resolution, permits no Lane execution during resolution, discards all partial state on failure, and publishes nothing before backend construction succeeds.
- Successful loading publishes a reusable **Loaded Executable Image**. Each run creates a fresh **Single-Shot Execution Instance**, and every successful or failed selected-entry attempt terminates that instance.
- `loisvm/interp` uses an explicit frame stack. The selected entry starts at logical call depth one; returning bytecode-body calls increase depth, returns decrease it, tail calls preserve it, and runtime imports do not create Lane frames.
- Host execution configuration may bound call depth and canonical live dynamic heap bytes. Both interpreter and Wasm enforce these **Execution Resource Limits** through private fatal cleanup; the limits are not serialized in `.lbp`.
- V1 defines no portable instruction fuel, deadline, or timeout semantics. **Execution Interruption** may bypass cleanup, and the interrupted instance is discarded.
- Successful return performs no defensive frame or heap sweep. ARC insertion must already establish an ownership-empty exit before whole-instance teardown.
- Execution failures use shared top-level categories: RuntimeImportFailure, ExecutionResourceLimit, Interrupted, EngineTrap, and InternalRuntimeFailure. Backend trap text is diagnostic detail rather than portable semantics.
- Load failures distinguish unsupported schema, malformed encoding, unresolved import, ABI mismatch, resource limit, and backend compilation failure; malformed diagnostics use section-relative offsets and import failures identify symbols.
- The schema version is followed by the **Selected Bytecode Entry** and function count. FunctionId is one-based over zero-based table position, and zero function count is invalid.
- Bytecode tables use **Dense Bytecode Identifier Spaces**. `FunctionId` and `LayoutId` start at one; `BlockId`, `SlotId`, `ConstantId`, and `ObjectShapeId` start at zero. IDs, counts, and byte lengths use `u32le`.
- Instructions and terminators use **Fixed-Shape Opcode Encoding** with separate `u8` tag domains. Each **Canonical Bytecode Function Body** begins with a payload byte length and is completely consumed.
- Every **Bytecode Tag Namespace** assigns known values contiguously from `0x01`, reserves `0x00` and `0xFF`, and is frozen within one bytecode schema version. Any accepted-tag change bumps the schema version.
- V1 representation tags are I32/I64/F64 = `0x01`/`0x02`/`0x03`; cleanup tags are Trivial/OwnedRef/OwnedCallable/OwnedErased = `0x01` through `0x04`; result tags are Unit/I32/I64/F64 = `0x01` through `0x04`.
- Function-entry tags are BytecodeBody/RuntimeImport = `0x01`/`0x02`; Layout Recipe tags follow Unit through Environment at `0x01..0x08`; Object Shape tags are Data/Environment = `0x01`/`0x02`; LayoutOperand tags are Immediate/Witness = `0x01`/`0x02`.
- The **Canonical V1 Opcode Table** assigns instructions `0x01..0x42` and terminators `0x01..0x07`. Normal calls are instructions; CFG transfers, returns, tail calls, and unreachable are terminators, excluded from `instruction_count`.
- Portable v1 bytecode has no nop, opcode alias, generic arithmetic operation subtag, source-location instruction, profiling instruction, or debug instruction.
- A function-body payload stores slot table, inputs, result descriptor, then a nonempty block table. Slot and block order imply their zero-based IDs; block zero is the entry and has no parameters. Each block stores a counted parameter-slot list, counted instructions, then one terminator, without fallthrough or a block length.
- Each slot record stores representation and cleanup tags; only `OwnedErased` appends a companion SlotId. V1 permits only Trivial with I32/I64/F64, OwnedRef with I32, and OwnedCallable or OwnedErased with I64.
- V1 **Slot Representation Tags** are exactly `I32`, `I64`, and `F64`. Unit occupies no slot; a returning call uses zero destination OptionalSlot for Unit.
- **Slot Cleanup Categories** describe cleanup only. `Trivial` performs no cleanup; `OwnedRef` releases an `I32` object reference; `OwnedCallable` releases the nonzero environment packed into `I64`; and `OwnedErased` releases an `I64` payload through its **Erased Ownership Companion**.
- An **Erased Ownership Companion** remains unchanged while its owned payload is live, and physical slot reuse preserves that relationship. There is no `Borrowed` category: compiler-proven non-owning reference temporaries use `Trivial` and cannot cross block, call, return, or heap-storage boundaries.
- A bytecode body records **Bytecode Function Inputs** separately from block parameters. Environment uses zero for absent or `SlotId + 1`; witnesses are counted `I32 + Trivial` SlotIds followed by counted user parameter SlotIds. All input SlotIds are pairwise distinct.
- A body result descriptor is one closed Unit/I32/I64/F64 tag. Unit has no result slot; cleanup behavior comes from the actual return and destination slots rather than the descriptor.
- Every **Optional Slot Reference** is one `u32le` zero or `SlotId + 1`; function environments, direct-call environments, call destinations, return sources, and projection witness destinations share this encoding.
- Every other SlotId operand is a direct zero-based `u32le`, so SlotId zero is valid. `make_closure` may name environment SlotId zero even though the owned environment value stored there must be nonzero.
- Slot arrays use `count:u32le` followed by exact SlotIds. `call_direct` stores target, environment OptionalSlot, witness array, user array, and destination OptionalSlot; `call_value` stores callable, witness array, user array, and destination OptionalSlot.
- Witness and Trivial user arguments are non-consuming reads. Owned user arguments transfer into the callee; direct calls consume a nonzero environment and value calls consume their callable.
- LoisVM serializes no `CallShapeId` table. The Wasm backend uses the **Derived Indirect Call Shape** for `call_indirect`; runtime-import adapters derive their host shape from the registry. Call-site and target agreement remains a trusted-bytecode invariant.
- A **Return Terminator** stores one source OptionalSlot and consumes its non-Unit result owner into the caller. Normal execution performs no implicit frame sweep; explicit releases establish an **Ownership-Empty Exit** for all non-result owners.
- `tail_call_direct` stores target, environment OptionalSlot, counted witnesses, and counted user arguments. `tail_call_value` stores callable and the two counted arrays. Neither has a destination.
- Before either tail terminator, explicit releases remove all untransferred current-frame owners. The tail target result representation equals the current function descriptor; indirect-tail shape derivation uses that descriptor.
- Wasm lowers direct and value tail calls to `return_call` and `return_call_indirect`. Tail runtime imports follow the same ownership rule; a failing adapter throws after the replaced frame has no remaining ownership.
- Ordinary control flow uses explicit **Bytecode Edge Records** containing target, count, and exact argument SlotIds. `jump` stores one edge; `branch_bool` stores an `I32 + Trivial` condition plus true and false edges.
- A **Tag Switch Terminator** stores an unsigned `I32 + Trivial` tag, possibly empty dense case edges for tags `0..case_count-1`, and one mandatory default. Out-of-range bit patterns select default; blocks never fall through.
- Only the selected edge transfers values, in parallel. Trivial sources are non-consuming and may repeat; owned sources are consumed and may not repeat without prior **Retain Copies**. Edge target, range, arity, representation, cleanup, and ownership agreement remain trusted invariants.
- A **Trusted Unreachable Terminator** lowers to Wasm `unreachable` and may trap without private fatal cleanup because valid compiler output never executes it. CFG lowering uses `if` or `br_if` for boolean branches and prefers `br_table` for dense tag switches.
- LoisVM has no generic slot assignment. **Trivial Slot Copy** is non-consuming and limited to `Trivial`; **Ownership Move** consumes a compatible source without ARC; **Retain Copy** establishes an owned destination and serves both owned duplication and borrow promotion.
- `release(slot)` consumes one owned slot. Every instruction destination is logically dead before writing, so overwrite never releases implicitly. Move and release leave stale physical bits but make their source logically dead.
- `retain_copy` and `release` dispatch through `OwnedRef`, `OwnedCallable`, or `OwnedErased`; erased operations use the companion witness. Emitting either operation for a `Trivial` destination or released slot is invalid trusted bytecode rather than no-op semantics.
- Wasm lowering uses typed local get/set plus ARC helpers. The backend and Wasmoon may eliminate redundant moves and balanced retain-copy/release pairs, but ordinary `local.set` never implies ARC.
- `const_int`, `const_double`, and `const_bool` produce **Inline Scalar Constants** using `i64le`, raw binary64 bits, and canonical byte `0` or `1`; another Bool byte is a decoding error, and Unit has no constant instruction.
- `const_layout(dst, LayoutId)` writes a nonzero image layout identifier into an `I32 + Trivial` witness slot as an inline compiler constant; it does not enter the String pool.
- `const_function(dst, FunctionId)` produces a capture-free packed callable with environment zero. `const_string(dst, ConstantId)` produces an owned logical reference to an **Image String Constant**, whose immortal count makes retain and release no-ops.
- `make_closure(dst, FunctionId, env)` produces a capturing callable in a logically dead `I64 + OwnedCallable` destination and consumes one nonzero environment owner. It carries no layout, object-shape, or call-signature operand.
- Trusted function metadata requires `const_function` to name a no-context target and `make_closure` to name a context-requiring target. The interpreter allocates a count-one closure shell; Wasm packs the pair into `i64` without allocation.
- Callable `copy` is invalid. `move`, `retain_copy`, and `release` transfer, duplicate, or destroy callable ownership according to the interpreter shell or packed Wasm environment representation.
- Recursive closure groups establish one shared-environment owner per published callable; earlier `make_closure` operations consume retained copies and the final construction may consume the original owner.
- The v1 image constant pool contains only reachable Strings after whole-program optimization. The linker deduplicates exact ASCII bytes, sorts unsigned raw bytes lexicographically, assigns zero-based IDs, and remaps `const_string`; empty String is ID zero when present.
- Wasm active data segments materialize pooled String objects. `const_string` lowers to their static addresses without a retain operation.
- Integer arithmetic uses `int_add`, `int_sub`, `int_mul`, `int_neg`, `int_div`, and `int_rem` over `I64 + Trivial`. Overflow and invalid shift counts are **Integer Undefined Behavior**; wrapping Wasm add/sub/mul/neg and masked shift behavior are permitted.
- Signed integer division by zero and `MIN_INT / -1`, plus remainder by zero, may produce a **Non-Unwinding Arithmetic Trap**. It bypasses private fatal cleanup, and the embedding discards the instance rather than resuming or invoking it again.
- Integer bitwise instructions are `int_and`, `int_or`, `int_xor`, and `int_not`; shifts are `int_shl` and `int_shr_s`. Signed comparisons produce a **Canonical Boolean Scalar**.
- Bool primitives are `bool_not`, `bool_eq`, and `bool_ne`. Source short-circuit conjunction and disjunction lower to CFG rather than eager boolean opcodes.
- Double primitives are add, subtract, multiply, divide, negate, and six comparisons over Wasm binary64. Division by zero follows IEEE-754; NaN comparisons follow Wasm rules, `+0` equals `-0`, and arithmetic need not preserve NaN payload bits.
- Bytecode performs no implicit Int/Double conversion; only the defined **Explicit Numeric Conversion** opcodes cross those numeric types.
- **Explicit Numeric Conversion** uses `int_to_double` with signed IEEE round-to-nearest-ties-even and `double_to_int` with truncation toward zero. Int-to-Double precision loss is allowed.
- NaN, infinity, or out-of-range `double_to_int` may cause a **Non-Unwinding Conversion Trap**. The instance is discarded, and v1 emits no saturating or non-trapping float-to-int conversion.
- Compiler-internal **Representation Erasure Bridges** are `erase_i32`/`unerase_i32`, identity-bit `erase_i64`/`unerase_i64`, bitwise `erase_f64`/`unerase_f64`, and slot-asymmetric `erase_unit`/`unerase_unit`.
- Erasure bridges consume the source and transfer any ownership without ARC. Trusted metadata establishes the correct natural and erased representations; preserving the source requires a prior retain-copy where ownership applies.
- Int and Callable already occupy `I64`, so their bridges preserve bits while transferring cleanup interpretation. Ordinary `move` does not perform erasure, and erasure bridges never create source-level implicit numeric conversion.
- Every erased endpoint is `I64 + OwnedErased`, including primitive no-op layouts. Erase reads an already initialized destination companion; unerase reads the source companion; bridge instructions carry no witness operand.
- A companion may serve multiple erased payloads but remains unchanged until all are consumed. Calls never perform implicit erasure or unerasure.
- Natural Unit has no slot, while generic Unit uses canonical `I64 0 + OwnedErased` with a nonzero no-op Unit LayoutId. `erase_unit` has only a destination and `unerase_unit` only a source.
- `ObjectShapeId` is a zero-based static identity distinct from runtime `LayoutId`. **Object Shape** variants supply Data field or Environment capture schemas and offset computation, while one deduplicated Data or Environment Layout Recipe per used shape supplies runtime size and ARC/destructor behavior.
- Data construction encodes destination, direct zero-based ObjectShapeId, **Layout Operand**, counted witnesses, then counted fields. The shape supplies constructor tag; Trivial inputs are read, owned fields are consumed, and a dead `I32 + OwnedRef` destination is published only after initialization.
- Environment construction uses the symmetric destination, shape, Layout Operand, counted witnesses, and counted captures form. Trivial inputs are read, owned captures are consumed, and the complete tagless payload precedes publication.
- `borrow_capture` explicitly names an Environment shape, environment source, and shape-local capture index. It preserves environment ownership and produces block-local borrowed reference payloads plus any erased witness.
- `consume_captures` consumes one environment owner and returns a possibly empty strictly increasing sequence of owned projection results through equivalent unique-move/shared-retain paths.
- Capture-free functions use environment zero, have no Environment Object Shape, and execute no `make_env`.
- `load_tag` non-consumingly reads an object into an `I32 + Trivial` destination. `borrow_field` preserves object ownership and writes a **Field Projection Result** whose reference payload is `Trivial`; erased fields also return their stored witness.
- `consume_fields` carries shape, object, count, and a possibly empty strictly increasing field/result sequence. It consumes the object, returns selected fields as owners, releases unselected fields, and preserves unique-move/shared-retain equivalence.
- Object Shapes omit alignment and offsets. Data layout is header, tag, contiguous u32 witnesses, then aligned fields; Environment omits the tag. I32 uses size/alignment four, I64/F64 eight, and total size rounds to eight.
- Member schemas encode representation, cleanup, and `witness_ordinal_plus_one`; exact shapes are deduplicated and sorted with Data variants before Environment variants.
- Field indices are local to the selected `ObjectShape::Data`. Trusted lowering ensures the constructor was selected and shape/layout are compatible. LoisVM exposes no raw heap-offset, load, or store opcode.
- Bytecode has no alignment padding. Signed 64-bit and `Double` constants preserve their raw little-endian bits, and incompatible or unknown tags are rejected rather than skipped.
- **Wasm CFG Structuring** maps slots to typed Wasm locals, realizes parallel edge transfer with temporary locals, structures reducible CFGs, and uses a dispatcher fallback for irreducible CFGs. Multi-value block parameters are optional future optimization rather than the v1 canonical mapping.
- Every dynamic Lane reference addresses a **Lane ARC Object Header**. Allocation returns a nonzero eight-byte-aligned header offset with count one; layout metadata determines fixed size or a layout-specific variable-size calculation, and allocator metadata is outside the Lane object ABI.
- Image-owned static objects use the **Immortal Refcount Sentinel**. Dynamic retain that would enter the sentinel value is a fatal internal execution failure. Release to zero runs the layout destructor before returning the allocation to the allocator.
- Runtime data uses a **Local Constructor Tag** independent of `LayoutId`. Pattern matching reads the tag, `ObjectShape::Data` metadata defines typed field offsets, and runtime layout defines allocation and destruction.
- A fieldless constructor that needs no stored witness uses a **Nullary Constructor Singleton** with the immortal count. Data construction otherwise consumes owned field operands into the new object without implicit retains.
- Capturing closures use a **Typed Closure Environment Layout**. Allocation and one-time initialization consume capture ownership, generic captures store the witnesses required by destruction, and capture-free callables use environment zero without allocation. Recursive groups share one environment but never store strong references back to member callables.
- Wasm lowering may scalar-replace a non-escaping environment, but observable ownership remains equivalent to allocating and destroying the ordinary immutable ARC object.
- The image layout table is a static canonical-memory array of **Materialized Layout Descriptors**, addressed through immutable `layout_table_base:i32` and 32-byte stride. `LayoutId = 0` is invalid; fixed sizes include the common header, and variable layouts use typed size helpers returning total allocation size.
- Portable bytecode stores recipes rather than descriptor words. Wasm adds an unused zero descriptor and derives sizes, alignments, and helper indices without writing them back into bytecode.
- Descriptor retain and release helpers use `(payload:i64) -> ()`; destroy uses `(object_ref:i32) -> ()` and releases fields without freeing; size uses `(object_ref:i32) -> i32`. Their **Layout Helper Entries** share the canonical Wasm table but are outside the Lane `FunctionId` range.
- Lane modules define and export the **Canonical Lane Memory Export** instead of importing memory. Static objects and layout data precede immutable `heap_base`; the in-module thread-confined allocator uses bump allocation plus reusable free lists and grows memory when needed.
- Reused blocks need not be zeroed, so constructors initialize every observable field before publication. Allocation failure or ARC overflow throws a **Private Wasm Fatal Exception** and unwinds cleanup; free, destructors, and cleanup are non-throwing and may reuse dead payload bytes for allocator metadata.
- The **Lane Wasm Module ABI** exports only the selected zero-argument `Unit` wrapper as `"lane.entry"`, canonical memory, and restricted runtime services. Runtime imports use `"lane.runtime.v1"` and natural Wasm primitive signatures; String input expands to pointer-length and String output is an owned `i32` reference.
- RuntimeContext may perform a **Runtime Service Nested Call** to `"lane.runtime.string.new":(i32) -> i32` and write validated bytes through `"lane.memory"`. This exception to non-reentry never invokes Lane code. Private fatal exceptions may escape `lane.entry` for Wasmoon to convert into execution failure.
- **Static Wasm Image Initialization** uses active data and element segments and no start function. Static objects, descriptors, globals, allocator state, and the **Canonical Wasm Function Table** are ready when instantiation succeeds.
- The **Canonical Wasm Function Table** is private and fixed at its exact emitted size. Index zero is invalid; indices `1..N` are the Lane `FunctionId` range, including runtime-import adapters; layout helpers follow that range. Entry wrappers and runtime-service helpers are not table entries or Lane callables.
- Canonical memory has no declared maximum. Its initial 64-KiB page count is the minimum covering `heap_base`; the allocator grows it on demand.
- The LoisVM bytecode **Execution Image** is a **Trusted Execution Image**. Binary decoding still rejects malformed framing and schema encodings, but interpretation and native lowering do not run a separate structural, data-flow, or type verifier over decoded bytecode.
- LoisVM uses **Compiler-Directed Reference Counting** for dynamically allocated runtime values. `lanec` inserts explicit **Retain Copies** and releases, while last-use moves use **Ownership Transfer** to avoid redundant increments.
- LoisVM calls use the **Callee-Owned Call ABI**. Callers retain values needed after a call, otherwise argument and required closure-environment ownership transfers into the callee; returned values are owned by the caller.
- Compiler ownership and last-use analysis runs on the **Compiler-Private VM CFG**, not on serialized or physical-slot LoisVM bytecode. The resulting retain, release, and transfer decisions are then emitted into the execution image.
- LoisVM block parameters are **Owning Block Parameters**. The selected jump or branch edge transfers ownership from its edge arguments without implicit reference-count changes.
- Borrowing is represented during ownership lowering as a **Block-Local Borrow**, not as a persisted bytecode ownership type. Crossing a block, call, return, or heap-storage boundary requires an owned value established by retain or ownership transfer.
- Dynamically allocated data, closure environments, and closures use **Consuming Object Construction**. Reusable continuations are **Continuation Closures** and therefore use the same construction and ownership rules.
- LoisVM supports **Consuming Projection** for last-use data decomposition. It is correct for both unique and shared objects; reference-count equality with one only selects the move-and-reuse fast path.
- Primitive cases and function identifiers are **Immediate VM Values**. Constant-pool objects are **Image-Owned Static Values**, while dynamically allocated strings, data, closures, environments, and continuation closures use ordinary reference counts.
- The bytecode image remains alive while any value produced by its execution can reference an **Image-Owned Static Value**. Lane v1 does not unload an image while such values remain live.
- LoisVM v1 uses a **Thread-Confined VM Heap** with non-atomic reference counts. Dynamic VM values do not cross threads, and both interpreted and native execution preserve that confinement.
- A reusable `resume` value is a **Continuation Closure**. Resume invocation uses the ordinary callable-value call ownership convention, while proven one-shot continuation lowering may use direct calls or linear control flow.
- `mon-trans`, `open-resolve`, and `monadic-lift` establish an **Effect-Erased Execution Image** before compiler-private VM CFG lowering and bytecode construction.
- LoisVM bytecode contains no `perform`, `resume`, or `handle` form, no Buslane operation identity, no handler context or layout, no handler-context call ABI, and no runtime operation table.
- External runtime effects lower before bytecode to ordinary runtime function or intrinsic calls. LoisVM interpretation and Wasm lowering do not implement source effect dispatch.
- LoisVM uses a **Unified Execution Function Table** with tagged bytecode-body and runtime-import entries. Direct, callable-value, and tail calls use the same `FunctionId` namespace and call ABI; there is no `call_runtime` instruction.
- Bytecode bodies follow final deterministic post-optimization body-list order and precede runtime imports. Imports serialize ABI major, user arity, and a nonempty case-sensitive ASCII symbol, are deduplicated by that tuple, and are deterministically sorted.
- FunctionIds are **Build-Local FunctionIds**: identical compiler version, inputs, options, and selected entry reproduce them, while build changes may renumber them. The explicit selected entry need not be FunctionId one; no FunctionId is a persistent or module ABI identity.
- Runtime imports are no-context and witness-free; parameter and result kinds remain owned by the runtime symbol registry. Unknown tags and incompatible imports fail decoding or loading.
- First-class callable values are either immediate capture-free `FunctionId` values or reference-counted closures. Indirect invocation uses `call_value` or `tail_call_value`; consuming an immediate identifier is free, while consuming a closure uses the unique-or-shared projection rule.
- `call_value` uses **Consuming Callable Projection** for closures. A unique closure moves its environment and frees its shell; a shared closure retains the environment for the callee and releases only the consumed owner. Uniqueness is an optimization, not a precondition.
- Runtime imports carry stable runtime symbols and erased ABI descriptors and resolve once when the image loads. Their physical Wasm import and adapter representation remains a Wasm-backend decision. Dedicated VM primitives remain opcodes rather than runtime imports.
- Runtime Import ABI v1 records fixed arity only: `(RuntimeContext, VMValue...) -> VMValue`. Symbols carry an ABI major version; loading checks symbol, version, and arity. The runtime context is borrowed host state, explicit reference arguments are callee-owned, and the result is owned.
- Bytecode carries no source types or per-parameter unboxed runtime-import kinds. A Wasm backend may use runtime-registry information when selecting a physical import adapter without changing the portable bytecode ABI.
- The **Runtime Symbol Registry** uniquely defines each versioned symbol's primitive parameter and result kinds. `lanec` checks that signature before erasure; bytecode stores only symbol and arity, runtime calls trust the resulting VM tags, and the Wasm backend consults the same registry when constructing imports or adapters.
- V1 runtime imports are **Synchronous Primitive Host Calls**. They cannot re-enter Lane program execution, call Lane closures, suspend, or retain VM values, and their parameters and result are restricted to `Int`, `Double`, `Bool`, `String`, and `Unit`. Restricted runtime-service nested calls do not count as Lane reentry.
- Runtime imports consume or release transferred arguments on success and execution failure. `String` uses ordinary ARC ownership; the other permitted host-call kinds are immediate.
- Dynamic Strings use immutable **Runtime String Objects** with length at object offset 8 and bytes at offset 12; total allocation size rounds up to eight bytes. Constant and empty Strings use the same layout as image-owned immortal objects, and no form carries capacity, cached hash, or trailing NUL.
- Host imports borrow `(string_ref + 12, byte_length)` only for the synchronous call. Returned bytes are copied into one exact-size allocation and ASCII-validated.
- V1 **String Primitives** are `string_length`, `string_concat`, `string_slice`, and `string_eq`. Length and equality borrow their operands; concatenation consumes two String owners and slicing consumes one.
- String indices are signed Lane Int values interpreted as ASCII byte indices. Empty concatenation and complete slicing may move an input owner without allocation; other slices are independent copies rather than parent-backed views.
- Invalid String ranges, length or address overflow, and allocation failure use the private fatal path and require the host to discard the instance.
- A **Runtime Import Failure** produces no result and fatally aborts the current execution without a bytecode exception edge. The failing import releases transferred arguments, then LoisVM releases remaining owned frame values; recoverable host outcomes must use normal primitive results.
- LoisVM does not use tracing garbage collection or a runtime cycle collector in v1. Effect erasure and closure lowering must avoid constructing strong reference cycles that ordinary reference counting cannot reclaim.
- Lane v1 **Module Objects** contain linkable **Canonical Core Artifacts**, not per-module bytecode or a **Bytecode Cache**.
- `lane link` links **Module Objects**, performs **Whole-Program Core Optimization**, and only then lowers the linked core into the **Execution Image** stored in the **Linked Program**.
- A future **Bytecode Cache** must remain outside the authoritative `.lmo` and `.lbp` contracts and be guarded by fingerprints, compiler version, target, and lowering options.
- `inspect` exposes semantic metadata and Buslane/core for artifacts that carry
  them. Executable-only `.lbp` files instead expose **Canonical Linked
  Disassembly** as explicitly lowered code.
- The **NoBuild Model** leaves build policy to **Build Workflows**.
- A **Module Input Set** is parsed for module declarations and import sections before module compilation.
- An **Import Graph Check** runs before compiling any module in the **Module Input Set**.
- A module importing itself is an **Import Graph** cycle.
- Modules in a valid **Module Input Set** compile in topological import order.
- A **Direct File Run** still requires a **Module Declaration**.
- A **Direct File Run** compiles the requested source file without discovering a project graph.
- A **Direct File Run** has no implicit library imports and receives libraries only through **Library Inputs**.
- A **Direct File Run** resolves imports only within its **Module Input Set**.
- A **Library Input** can be a source file or a **Library Directory**.
- Source-file and directory **Library Inputs** follow the same compile, import-resolution, and link-reachability rules.
- A **Library Directory** recursively discovers Lane source files.
- A **Library Directory** skips hidden directories and build output directories during CLI discovery.
- Source files discovered from a **Library Directory** must be valid **Source Files**.
- Filesystem paths do not define or validate **Module Paths**.
- A **Basic Library Module** is never injected implicitly by compiler or command tooling; users provide its interface, object, or source as ordinary inputs.
- A **Conventional Basic Module** may be implemented by any user-provided artifact whose exported shapes satisfy the tool convention.
- A **Duplicate Module Input** is an error, including duplicates between the root source and libraries.
- All modules supplied by **Library Inputs** are compiled, even when they are not imported by the root source.
- Every compiled module must resolve its imports within the **Module Input Set**.
- A **Direct File Run** links the modules reachable from the root source, not every compiled library object.
- Direct run link reachability is computed over the **Import Graph** at module granularity.
- **Entry Selection** is explicit workflow policy rather than a language-level `main` rule.
- Direct **Entry Selection** is limited to **Public Entries**.
- The **Import Graph** is acyclic.
- Buslane core remains independent of **Module** and **Source Identity** concepts.
- The **Pre-Buslane Contract** belongs to `lanec`; it documents checked-source
  invariants, type/effect canonicalization ownership, and source-origin side
  data before Buslane lowering.
- The workspace root owns cross-module development layout only; module-specific
  design notes stay inside each module directory.
