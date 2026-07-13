# Lane Compiler

The Lane compiler repository owns parsing, resolution, type checking, source
elaboration, and lowering from Lane source into Buslane and ANF.

## Language

**Compiler Front End**:
The target-independent MoonBit implementation that accepts source text and
produces checked semantic artifacts.
_Avoid_: CLI tool, LSP server, Basic library

**Source Elaboration**:
The compiler phase that resolves names, typechecks source constructs, supplies
contextual arguments, and produces checked source.
_Avoid_: pure parser, Buslane verifier

**Semantic Lowering**:
The boundary that translates checked source into Buslane.
_Avoid_: source desugaring, ANF normalization

**Pre-Buslane Contract**:
The explicit invariant set that a successful checked source result satisfies before Buslane lowering, including resolved identities, filled contextual arguments, canonical type/effect objects, and source-only forms with known lowering rules.
_Avoid_: Buslane verifier contract, whole-program optimization, ANF normalization

**Compiler Analysis API**:
An in-memory API used by tools and LSP code without owning file IO or process
IO.
_Avoid_: native command implementation, editor extension

**Compiler Diagnostic Adapter**:
A compiler-owned translation from Lane compiler diagnostics into generic diagnostic infrastructure.
_Avoid_: terminal renderer, LSP diagnostic, command report

**Source-Aware Diagnostic Rendering**:
Diagnostic presentation that combines a compiler diagnostic with its source text before rendering source locations and guidance.
_Avoid_: compact diagnostic pretty print, debug diagnostic output, command report

**Width-Sensitive Formatting**:
Formatter output that uses syntax-aware pretty-printing breakpoints to prefer lines within a configured width while allowing indivisible source atoms to exceed it.
_Avoid_: hard line wrapping, post-render text wrapping, token splitting

**Concrete Syntax Layer**:
The formatter-facing source representation that preserves tokens, comments, whitespace, and source spans alongside parse structure.
_Avoid_: semantic AST, checked source, resolved AST

**Parsed Source**:
The successful parser payload that pairs the syntax AST with concrete syntax sidecars for formatting and source-preserving tooling.
_Avoid_: ParseResult, checked source, formatter output

**Concrete Syntax**:
The token and trivia sidecar produced with a parsed source file, without owning the semantic syntax AST.
_Avoid_: SourceFile, resolved AST, checked source

**Trivia Span**:
A source span plus trivia kind that references text stored by **Concrete Syntax** rather than copying comment or whitespace text.
_Avoid_: copied comment text, formatter string, AST span

**Gap-Indexed Trivia**:
A trivia fact that records its source span, kind, and position in the concrete token gap between two tokens, including EOF.
_Avoid_: token-owned trivia arrays, AST-owned comments, inferred source gaps

**Trivia View**:
A formatter-local query view over **Gap-Indexed Trivia** that classifies trivia as leading, trailing, or detached for rendering.
_Avoid_: second trivia store, lexer policy, AST attachment

**EOF Token**:
The non-printing end-of-file token kept in the concrete token stream as the anchor for final trivia.
_Avoid_: printable token, boundary array, missing final trivia

**Parse Result**:
The parser domain result that is either a successfully **Parsed Source** or a structured parse failure.
_Avoid_: optional parsed field, generic result, syntax AST

**Parse Failure**:
The parser domain failure that distinguishes lexical failure from grammar failure, preserving concrete syntax sidecars only when lexing succeeded.
_Avoid_: nullable source, mixed error arrays, formatter diagnostic

**Trivia-Preserving Formatting**:
Full-file source formatting that requires successful parsing and renders canonical source text without dropping comments or meaningful blank lines.
_Avoid_: partial formatting, error-tolerant formatting, comment reinsertion

**Trivia-Aware Pretty Printing**:
Pretty-printing that renders syntax-owned documents through a formatting context capable of consuming attached trivia at token boundaries.
_Avoid_: second formatter, string post-processing, comment merge pass

**Formatter Verification Oracle**:
The formatter test contract that combines comment no-loss checks, AST roundtrip equivalence, and formatting idempotence.
_Avoid_: snapshot-only testing, visual inspection, string contains checks

**Trivia Stream**:
The ordered non-semantic source material between tokens, including line comments, blank lines, newlines, and spacing needed to preserve user-written layout intent.
_Avoid_: AST comments, semantic nodes, formatter output

**Line Comment Trivia**:
A `//` source comment preserved by formatting without assigning declaration documentation semantics.
_Avoid_: doc comment, block comment, AST attribute

**Trivia Attachment**:
The formatter relation that associates trivia from the **Trivia Stream** with token boundaries or syntax tree positions before rendering source text.
_Avoid_: comment parsing, AST fields, post-render reinsertion

**Token Boundary Trivia**:
Trivia whose primary location is the gap between two concrete tokens, classified before formatting as leading, trailing, or detached material.
_Avoid_: node-owned comments, post-render comments, semantic attachment

**Trailing Comment**:
A line comment that appears on the same source line as the preceding token and remains bound to that preceding token or syntax unit during formatting.
_Avoid_: leading comment, detached comment, documentation comment

**Meaningful Blank Line**:
A blank line preserved as source grouping trivia while its exact repeated count is canonicalized by the formatter.
_Avoid_: raw whitespace, vertical padding, empty statement

**Parsed Double Literal**:
A source `Double` literal after validation, retaining the original source text for diagnostics and a binary64 value for semantic lowering.
_Avoid_: string-only float literal, arbitrary-precision decimal constant, overloaded numeric literal

**Double Literal Pattern**:
A refutable pattern that matches a `Double` value by floating-point equality without making `Double` an exhaustively enumerable primitive.
_Avoid_: exhaustive numeric pattern set, NaN pattern literal, arbitrary-precision decimal pattern

**Semantic Completion**:
A compiler-analysis completion result derived from Lane symbols, types, effects, modules, and source context.
_Avoid_: keyword snippet, editor-side text scan, LSP-only completion

**Completion Trigger**:
The user or editor event context supplied to a compiler completion query.
_Avoid_: completion kind, parser recovery mode, LSP item category

**Completion Entry**:
A semantic candidate returned by a compiler completion query before any editor protocol mapping.
_Avoid_: LSP completion item, text snippet, raw symbol

**Completion Query**:
A position-specific compiler analysis request that computes semantic completion candidates for one source location.
_Avoid_: full analysis index, precomputed completion cache, editor request handler

**Unused Local Value Binding**:
A value binder introduced inside an executable expression body that has no resolved `ValueSymbolId` reference within its lexical scope after source elaboration.
_Avoid_: unused private declaration, unused type parameter, unused import, unreachable code

**Checked Value-Use Analysis**:
A source-elaboration follow-up analysis over checked AST that records local value binders and resolved `ValueSymbolId` references with their definition-body origin.
_Avoid_: type scope, lexical scope tree, dead-code elimination, textual name scan

**Intentionally Ignored Local Binding**:
A named local value binder whose source name starts with `_`; unused-local-value warnings do not fire for these binders.
_Avoid_: wildcard pattern, dead binding, generated temporary

**GHC-Like Artifact Layering**:
The compiler artifact policy where interfaces carry public semantics and optimization hints, module objects carry linkable Buslane/core, and execution images are produced after linking.
_Avoid_: JVM-style runtime linking model, ANF artifact boundary, bytecode-only compiler contract

**Binary Artifact Payload**:
The structured binary serialization of a Lane compiler artifact used by the official `.lmi`, `.lmo`, and `.lbp` load paths.
_Avoid_: artifact text parser, inspect output, UTF-8 payload wrapper

**Execution Image Lowering**:
The lowering from linked and optimized Buslane/core into a target execution image such as portable bytecode.
_Avoid_: semantic lowering, source elaboration, module interface generation

**Register Bytecode Lowering**:
The execution-image lowering strategy that maps ANF values and temporaries to bytecode frame local slots instead of rebuilding an operand-stack program.
_Avoid_: stack bytecode lowering, source lowering, Buslane verification

**Flat Bytecode Control Flow**:
The execution-image control-flow strategy that lowers ANF control constructs into labeled blocks and explicit jumps.
_Avoid_: structured ANF nodes, expression-tree bytecode, source control flow

**Bytecode Block Parameter**:
A function-local destination slot declared by a bytecode block and assigned from the corresponding edge argument whenever control enters that block.
_Avoid_: source parameter, function parameter, implicit phi node

**Bytecode Edge Argument**:
A source slot supplied by a jump or branch edge for the corresponding target block parameter.
_Avoid_: call argument, operand-stack merge, hidden slot mutation

**Erased Bytecode Image**:
An execution image that removes Lane source types, source-level type arguments, and debug metadata while retaining only representation signatures and hidden layout witnesses required for Wasm lowering and generic ownership operations.
_Avoid_: source-typed bytecode, full runtime type reflection, debug metadata payload

**Uniform VM Value ABI**:
The bytecode value representation where every local slot stores one tagged VM value, including primitive cases such as `Double`.
_Avoid_: typed unboxed slot ABI, heap-only boxed representation, NaN-boxing commitment

**Mid-Level Bytecode Instruction**:
A bytecode instruction that makes primitive operations explicit while keeping functions, data constructors, closures, and ordinary calls as VM-level semantic operations after effect erasure.
_Avoid_: source operator call, builtin dispatch call, machine-layout instruction

**Direct Bytecode Call**:
A returning non-terminating instruction whose target is an immediate function-table identifier, whose hidden closure-environment operand is present exactly when required, and whose destination exists only for a non-`Unit` result.
_Avoid_: callable-value call, dynamic function reference, tail-call terminator, source call expression

**Unified Bytecode Function Table**:
The image-global `FunctionId` index space whose tagged entries are either executable bytecode function bodies or load-time-bound runtime imports.
_Avoid_: bytecode-only function index, separate runtime-call index, operation dispatch table

**Selected Bytecode Entry**:
The nonzero FunctionId stored in executable bytecode for the link-validated no-context, witness-free, zero-argument Unit body invoked by execution.
_Avoid_: source export symbol, runtime entry selection, runtime import

**Runtime Import Function Entry**:
A function-table entry containing a stable runtime symbol and erased runtime ABI descriptor instead of a bytecode body.
_Avoid_: effect operation entry, per-call string lookup, bytecode wrapper function

**Runtime Import ABI V1**:
The erased fixed-arity host-call contract where a runtime import receives one non-Lane runtime context plus its declared number of uniform VM values and returns exactly one owned VM value.
_Avoid_: source type signature, varargs ABI, typed unboxed bytecode ABI

**Runtime Symbol Registry**:
The runtime-owned mapping from a stable symbol plus ABI major version to its primitive parameter/result signature and host binding contract.
_Avoid_: bytecode type table, per-call string dispatch, compiler-owned duplicate signature

**Runtime Context**:
The non-Lane host capability passed implicitly to runtime imports for services such as allocation and I/O.
_Avoid_: Lane argument, handler context, reference-counted VM value

**Synchronous Primitive Host Call**:
The v1 runtime-import boundary that completes before returning to LoisVM, cannot re-enter Lane program execution, cannot retain VM values after return, and accepts or returns only `Int`, `Double`, `Bool`, `String`, or `Unit`; restricted runtime-service nested calls are not Lane reentry.
_Avoid_: asynchronous import, callback into Lane code, closure argument, opaque handle result

**Runtime Import Failure**:
An out-of-band fatal execution error from a runtime import that produces no Lane value or bytecode exceptional successor and terminates the current LoisVM execution.
_Avoid_: Lane exception, effect perform, recoverable result value

**Loaded Executable Image**:
The reusable result of atomic bytecode loading, runtime-import binding, and optional backend compilation from which fresh execution instances are created.
_Avoid_: partial loader state, active VM heap, one selected-entry invocation

**Single-Shot Execution Instance**:
The frame stack, dynamic heap, allocator state, runtime context, and execution limits owned by exactly one entry attempt.
_Avoid_: loaded image, reusable Wasm instance, concurrent entry execution

**Execution Resource Limit**:
A host-supplied run-time bound on logical call depth or canonical live heap bytes that fails through private cleanup rather than malformed-image handling.
_Avoid_: load ResourceLimit, native stack overflow, bytecode verifier rule

**Execution Interruption**:
An external cancellation or engine stop that may skip ARC unwind and makes the current single-shot instance unusable.
_Avoid_: Lane control flow, runtime import status, portable bytecode timeout

**Engine Trap**:
A non-unwinding backend failure with best-effort diagnostic detail, including an engine-native stack overflow or direct Wasm trap.
_Avoid_: cleanup-capable resource limit, Lane exception, resumable instance

**Runtime String Object**:
An immutable ARC object whose payload stores `byte_length:u32` followed immediately by ASCII bytes, with no capacity, cached hash, trailing NUL, or parent-backed slice state.
_Avoid_: NUL-terminated host string, mutable byte buffer, String view object

**String Primitive Instruction**:
A dedicated LoisVM instruction for immutable ASCII String length, concatenation, slicing, or equality.
_Avoid_: generic String dispatch, host text operation, raw memory access

**Borrowed Host String View**:
A temporary non-owning byte view exposed from an owned runtime-import String argument and valid only for the duration of that synchronous host call.
_Avoid_: retained host pointer, copied input string, owned VM value

**Callable Value**:
A first-class bytecode function value represented either by an immediate capture-free `FunctionId` or by a reference-counted closure containing a `FunctionId` and environment reference.
_Avoid_: runtime-function value kind, mandatory empty closure, source function declaration

**Callable Construction**:
The creation of a no-context callable by `const_function` or a context-requiring callable by consuming one nonzero environment owner in `make_closure`.
_Avoid_: implicit environment retain, closure layout operand, mandatory closure-shell allocation

**Callable Value Call**:
A fused returning non-terminating instruction whose target is a callable value in a local slot, whose destination exists only for a non-`Unit` result, and whose callable tag and optional closure environment remain internal to execution lowering.
_Avoid_: public closure unpack instruction, direct immediate target, tail-call terminator, closure-only operand

**Consuming Callable Projection**:
The fused `call_value` operation that consumes one callable owner, moves a unique closure environment or retains a shared closure environment, and establishes owned callee context.
_Avoid_: uniqueness precondition, always-retained environment, public closure unpack

**Function Context Kind**:
Function-table metadata declaring whether a bytecode function has no hidden context or requires an opaque closure environment reference.
_Avoid_: Lane function parameter, inferred runtime closure shape, capture count

**Closure Environment Reference**:
An opaque VM reference that supplies a capturing lifted function's hidden context without exposing the environment's field layout in call instructions.
_Avoid_: user argument, flattened capture list, closure object

**Closure Environment Construction**:
The consuming bytecode operation that fully initializes an immutable closure environment from its static Environment Object Shape, runtime layout, stored witnesses, and captures before publication.
_Avoid_: separate uninitialized allocation, general environment mutation, closure allocation

**Capture Projection**:
A borrowing or consuming bytecode operation that explicitly names an Environment Object Shape, environment source, and shape-local capture index.
_Avoid_: implicit current-frame read, raw heap offset, source variable lookup

**Compiler-Private VM CFG**:
The `lanec`-owned virtual-value control-flow representation produced after effect erasure and closure lowering and before physical slot allocation or LoisVM bytecode construction.
_Avoid_: persisted bytecode, `loisvm/bytecode` data model, WebAssembly module

**Runtime Ownership Analysis**:
The analysis over the compiler-private VM CFG that classifies reference-bearing uses as borrowed, retained copies, releases, or ownership transfers.
_Avoid_: final-bytecode analysis, source ownership checker, bytecode verifier

**ARC Insertion**:
The compiler transformation that applies runtime ownership analysis by adding retain and release operations and recording ownership transfers in the VM CFG before slot allocation.
_Avoid_: LoisVM interpreter behavior, Wasm-tier RC optimization, implicit slot semantics

**Block-Local Borrow**:
A compiler-private VM CFG value use that does not own its referenced object, remains dominated by a live owner, and cannot cross the current basic-block boundary.
_Avoid_: owned block parameter, bytecode ownership annotation, source borrow

**Borrow Promotion**:
The ARC insertion step that establishes owned lifetime for a borrowed reference, normally by retaining it before a consuming or cross-boundary use.
_Avoid_: ownership transfer from an owned last use, implicit retain, source clone

**Consuming Object Construction**:
The VM ownership convention where data construction, environment construction, closure creation, and continuation-closure construction consume reference-bearing operands into owned object fields.
_Avoid_: constructor-internal retain, borrowed stored field, ownership-neutral allocation

**Borrowing Data Projection**:
A block-local read of a data payload field that leaves object ownership unchanged and produces a borrowed logical value for reference-bearing payloads.
_Avoid_: owned projection, consuming match, field move

**Consuming Data Projection**:
A data operation that consumes one object ownership and returns selected payload fields as owned values, dynamically moving fields when the object is unique and retaining them when it is shared.
_Avoid_: borrow-only projection, compiler-assumed uniqueness, raw heap mutation

**Immediate Bytecode Value**:
A non-allocating tagged value such as `Int`, `Double`, `Bool`, `Unit`, or a function identifier that does not participate in reference counting.
_Avoid_: boxed primitive, dynamic object, constant-pool object

**Image-Owned Static Object**:
An immutable constant-pool object whose lifetime is bounded by the loaded bytecode image rather than an individual runtime reference count.
_Avoid_: dynamic RC allocation, copied literal, independently unloadable object

**Thread-Confined Reference Counting**:
The v1 runtime contract where each LoisVM instance and its dynamic heap remain on one thread and use non-atomic reference-count operations.
_Avoid_: atomic RC, cross-thread value transfer, shared mutable VM heap

**Continuation Closure**:
A reusable continuation lowered into an ordinary lifted bytecode function plus a closure environment containing its captured state.
_Avoid_: dedicated continuation object, VM stack snapshot, host-language closure

**Effect-Erased Bytecode Boundary**:
The invariant established by `mon-trans`, `open-resolve`, and `monadic-lift` before VM CFG lowering: effect handlers, performs, resumes, operation identities, handler contexts, and runtime operation tables have become ordinary functions, closures, data, calls, control flow, or runtime function/intrinsic calls.
_Avoid_: bytecode perform instruction, handler-context ABI, runtime operation dispatch table

**Trivial Slot Copy**:
The `copy(dst, src)` instruction for equal-representation `Trivial` slots, preserving the source without ARC behavior.
_Avoid_: owned copy, retain, generic assignment

**Ownership Move**:
The `move(dst, src)` instruction that transfers a compatible logical value and ownership to a dead destination without changing counts or clearing source bits.
_Avoid_: retained copy, overwrite cleanup, memory copy

**Retain Copy Instruction**:
The `retain_copy(dst, src)` instruction that copies equal-representation bits while using the destination cleanup category to establish a new strong owner.
_Avoid_: unary retain, trivial copy, ownership transfer

**Release Instruction**:
An explicit bytecode instruction inserted when an owned reference reaches the end of its compiler-determined lifetime.
_Avoid_: tracing collection, scope-exit guess, source destructor

**Cycle-Free Recursive Closure Lowering**:
The closure-conversion rule that represents recursive group member references through known function identifiers plus the shared environment rather than storing strong group-closure references inside that environment.
_Avoid_: EnvRef-to-closure ownership cycle, runtime cycle collector, weak-reference source semantics

**Callee-Owned Bytecode ABI**:
The call ownership convention where reference-bearing user arguments and any required closure environment are consumed by the callee and the result is returned as an owned value.
_Avoid_: universally borrowed arguments, caller-owned call frame, ownership-neutral result

**Edge Ownership Transfer**:
The control-flow rule where the selected edge consumes ownership from its edge argument slots and establishes ownership in the corresponding target block parameter slots.
_Avoid_: implicit retain on jump, borrowed block parameter, sequential slot copy

**Bytecode Tail Call Terminator**:
A direct or callable-value call terminator that transfers execution without a normal return continuation in the current bytecode function.
_Avoid_: value-producing call instruction, return followed by call, ordinary jump

**Return Terminator**:
The bytecode function exit carrying one source OptionalSlot, consuming a non-Unit result owner or returning Unit when the field is zero.
_Avoid_: returning call instruction, tail transfer, frame cleanup loop

**Ownership-Empty Exit**:
A return or tail terminator reached after explicit releases have removed every current-frame owner that is not transferred by the terminator.
_Avoid_: implicit frame sweep, abandoned owned slot, fatal unwind handler

**Effect-Erasure Pipeline**:
The pre-bytecode `mon-trans`, `open-resolve`, and `monadic-lift` sequence that removes all effect-specific forms and runtime effect-dispatch structures before compiler-private VM CFG lowering.
_Avoid_: LoisVM effect instruction, bytecode handler lowering, runtime stack capture

**One-Shot Continuation Analysis**:
A conservative analysis that may classify a resume continuation as linearly used only when repeated or escaping resume is impossible.
_Avoid_: heuristic one-shot guess, effect typing, dead-code analysis

**Closure Lifting**:
The pre-bytecode lowering pass that turns nested functions and continuation closures into lifted bytecode functions plus explicit captured context.
_Avoid_: runtime code generation, nested bytecode function, source lambda lifting

**Bytecode Data Layout**:
The link-time mapping from Buslane constructors to local tags, `ObjectShapeId` Data schemas, compatible runtime `LayoutId` entries, hidden witness storage, and instruction arities.
_Avoid_: Buslane identity ABI, image-global flat constructor table, source enum layout

**Bytecode Constant Pool**:
The image-global v1 table of deduplicated ASCII String constants referenced by zero-based `ConstantId` values.
_Avoid_: per-function constant table, symbol table, function table, debug metadata

**Inline Scalar Constant**:
An Int, Double, or Bool literal carried directly by its bytecode instruction rather than stored in the constant pool.
_Avoid_: numeric ConstantId, boxed scalar, platform-native encoding

**Integer Undefined Behavior**:
The out-of-contract result of signed overflow, zero division, or invalid shift counts in Lane v1 integer execution.
_Avoid_: checked arithmetic result, arbitrary precision, Lane exception

**Non-Unwinding Arithmetic Trap**:
An engine trap from undefined integer division that bypasses private fatal cleanup and makes the current execution instance unusable.
_Avoid_: private exnref unwind, recoverable status, source exception

**Explicit Numeric Conversion**:
A bytecode Int/Double conversion emitted only for an explicit Lane conversion and governed by defined rounding or truncation.
_Avoid_: implicit promotion, representation erasure, bit cast

**Representation Erasure Bridge**:
A compiler-only consuming operation between a natural representation and erased `I64` that transfers ownership while changing width, bit interpretation, or cleanup interpretation.
_Avoid_: source conversion, generic boxing, dynamic type check

**Non-Unwinding Conversion Trap**:
A direct invalid Double-to-Int engine trap that skips private cleanup and makes the current instance unusable.
_Avoid_: saturating conversion, recoverable error, exnref unwind

**Canonical Boolean Scalar**:
The `I32 + Trivial` Bool representation whose value is always zero or one when produced by valid bytecode.
_Avoid_: arbitrary truthy integer, boxed Bool, tagged host value

**Image String Constant**:
A deduplicated ASCII byte sequence represented at runtime by an image-owned immortal String object.
_Avoid_: dynamically allocated String, inline instruction bytes, host string reference

**Bytecode Lowering Pipeline**:
The ordered compiler path from linked Buslane/core through optimization, ANF, the effect-erasure pipeline, closure lifting, compiler-private VM CFG lowering, runtime ownership analysis, ARC insertion, slot allocation, and bytecode emission.
_Avoid_: source elaboration pipeline, runtime execution loop, artifact parser

**LoisVM Bytecode Target**:
The compiler execution-image target that emits bytecode owned by the independent `loisvm/bytecode` package.
_Avoid_: lanec-owned bytecode model, lane command runtime, Buslane artifact payload

**Wasm Backend Path**:
The compiled execution path that consumes decoded LoisVM bytecode, lowers it into a WebAssembly module, and executes it with a WebAssembly engine, using Milky2018/wasmoon by default.
_Avoid_: direct Buslane-to-Wasm lowering, direct ANF-to-Wasm lowering, MilkIR backend

**Extensible Wasmoon Backend**:
The Lane-controlled default WebAssembly execution backend whose interpreter, JIT, runtime integration, and supported WebAssembly capabilities may be extended as Lane's Wasm lowering evolves.
_Avoid_: current third-party engine feature floor, automatic browser portability, unspecified non-Wasm execution format

**Lane Wasm Feature Profile**:
The Lane v1 backend contract based on one canonical non-shared wasm32 linear memory. The emitter may use Multi-value, Reference Types, Typed Function References, Tail Call, Bulk Memory, Exception Handling with `exnref`, Sign-extension Operators, and Extended Constant Expressions. It excludes Stack Switching, Relaxed SIMD, Threads, Atomics, Multiple Memories, Memory64, Wasm GC, and Wasmoon-specific module semantics.
_Avoid_: plain WebAssembly 1.0 label, Wasm GC profile, private Wasmoon opcode

**Wasm Linear-Memory ARC Heap**:
The backend implementation of Lane dynamic objects in wasm32 linear memory, with Lane-owned allocation, layout, non-atomic reference counting, destruction, and recursive release.
_Avoid_: Wasm GC object, host-owned Lane heap, tracing collection

**Representation Erasure**:
The post-typechecking lowering that removes source types and generic arguments but preserves erased representation signatures and hidden layout witnesses. Monomorphic values use native Wasm representations; generic values use `i64` payloads governed by layout witnesses.
_Avoid_: whole-program monomorphization, complete loss of layout information, runtime source typing

**Representation Layout Witness**:
A hidden `LayoutId` descriptor passed to representation-polymorphic code to provide generic value layout, retain, release, and destruction behavior without carrying the full source type.
_Avoid_: source type witness, user parameter, bytecode verifier type

**Image Layout Table**:
The image-global static table of backend-independent Layout Recipes indexed by immediate `LayoutId` values and used to derive representation, sizing, alignment, and ownership behavior.
_Avoid_: dynamically allocated descriptor, source type table, reference-counted metadata

**Portable Layout Recipe**:
The tagged Unit, Bool, Int, Double, Callable, String, Data, or Environment execution recipe serialized for one LayoutId before backend-specific descriptor materialization.
_Avoid_: source type descriptor, Wasm helper index, raw field offset

**Packed Wasm Callable**:
The Wasm `i64` representation whose low 32 bits contain a `FunctionId` and whose high 32 bits contain a wasm32 closure-environment offset. Offset zero denotes no environment.
_Avoid_: LoisVM closure object layout, two-result Wasm value, Wasm GC closure

**Canonical Wasm Lane Entry ABI**:
The typed backend ABI whose parameters are hidden `env:i32`, then hidden `LayoutId:i32` witnesses, then user arguments in erased Wasm representations. Current v1 results use zero or one Wasm value, and complete signatures are interned for typed calls.
_Avoid_: uniform LoisVM VMValue ABI, result pointer ABI, per-call adapter for capture-free functions

**Structured Bytecode Addressing**:
The bytecode format where ordered blocks are identified by `BlockId`, fixed `BlockId = 0` is the entry, operands are identified by `SlotId`, and branches never serialize instruction byte offsets.
_Avoid_: relative PC, encoded instruction address, Wasm nesting depth

**Canonical Bytecode Function Body**:
The length-delimited body payload ordered as slot table, function inputs, result descriptor, then nonempty block table, with entry fixed to block zero.
_Avoid_: entry BlockId field, per-block byte length, open-ended body fields

**Bytecode Edge Record**:
The target BlockId plus counted ordered source SlotIds transferred in parallel when that edge is selected.
_Avoid_: implicit fallthrough, branch displacement, unordered phi inputs

**Tag Switch Terminator**:
The decision-tree terminator selecting an unsigned dense local-tag edge or mandatory default from an `I32 + Trivial` slot.
_Avoid_: high-level pattern match, LayoutId switch, source constructor table

**Trusted Unreachable Terminator**:
The operand-free terminator emitted only for compiler-proven impossible flow and permitted to trap directly if reached.
_Avoid_: runtime import failure, Lane exception, cleanup unwind

**Representation-Homogeneous Slot**:
A physical bytecode slot whose erased Wasm representation and ownership category remain fixed. Slot allocation may reuse it only for compatible logical values.
_Avoid_: full source type, unrestricted slot reuse, dynamically typed Wasm local

**Slot Representation Tag**:
The v1 physical scalar class `I32`, `I64`, or `F64` assigned to a bytecode slot; `Unit` has no slot.
_Avoid_: source type, VMValue tag, cleanup behavior

**Slot Cleanup Category**:
The runtime cleanup rule `Trivial`, `OwnedRef`, `OwnedCallable`, or `OwnedErased` attached to a physical slot, distinct from compiler-private ownership and borrowing facts.
_Avoid_: borrow region, source ownership annotation, implicit assignment semantics

**Erased Ownership Companion**:
The fixed `I32 + Trivial` layout-witness slot associated with an `I64 + OwnedErased` payload slot for descriptor-directed cleanup.
_Avoid_: source generic parameter, dynamic type object, owned witness

**Bytecode Function Inputs**:
The initial frame slots listed by a bytecode body in environment, layout-witness, then user-argument order before entry-block execution begins.
_Avoid_: entry-block parameters, source binders, call-site operands

**Optional Slot Reference**:
The four-byte optional-slot encoding where zero is absent and nonzero N identifies `SlotId = N - 1`.
_Avoid_: option tag, reserved SlotId value, optional VMValue

**Derived Indirect Call Shape**:
The typed Wasm signature reconstructed from callable-call arguments plus a returning destination or enclosing tail-result descriptor instead of a serialized table.
_Avoid_: source function type, CallShapeId, untyped table call

**LoisVM Bytecode Schema Version**:
The independent leading `u8` version, `0x01` for v1, governing a LoisVM bytecode section's tables, records, opcodes, and operand layouts.
_Avoid_: artifact container version, linked-program schema version, Buslane codec version

**Atomic Bytecode Load**:
The all-or-nothing sequence of complete decode, local metadata checks, import resolution, backend image construction, and reusable loaded-image publication.
_Avoid_: partial binding reuse, Lane execution during load, visible half-image

**Implementation Resource Limit**:
A loader or backend ceiling below `u32` schema capacity that can reject a valid image without changing bytecode compatibility.
_Avoid_: serialized budget field, portable fixed maximum, semantic validation

**Dense Bytecode Identifier Space**:
An ordered serialized table whose position supplies its identifier, with reserved zero only for `FunctionId` and `LayoutId`; `ObjectShapeId` is zero-based.
_Avoid_: explicit repeated ID field, sparse identifier map, instruction offset

**Build-Local FunctionId**:
A dense function-table index stable for one identical compiler/link invocation but not across optimizer, input, option, or compiler changes.
_Avoid_: stable module symbol, persisted callable identity, hash-derived ID

**Fixed-Shape Opcode Encoding**:
The compact bytecode form where a `u8` instruction or terminator tag determines its complete operand layout and unknown tags fail decoding.
_Avoid_: per-instruction byte length, unknown-opcode skipping, self-describing instruction

**Bytecode Tag Namespace**:
An independent `u8` variant domain with normative wire assignments, invalid `0x00` and `0xFF`, and no relationship to compiler enum ordinals.
_Avoid_: shared tag enum, generated variant number, extension escape opcode

**Canonical V1 Opcode Table**:
The normative instruction mapping over `0x01..0x42` and independent terminator mapping over `0x01..0x07` used by every v1 encoder and decoder.
_Avoid_: backend dispatch ordinal, Wasm opcode value, aliased encoding

**Wasm CFG Structuring**:
The lowering that maps bytecode slots to typed locals, implements parallel edge arguments with temporaries, structures reducible control flow, and uses a `loop` plus `br_table` dispatcher for irreducible CFGs.
_Avoid_: irreducible-CFG rejection, mandatory Multi-value block parameters, byte-offset rewriting

**Lane ARC Object Header**:
The common 8-byte wasm32 object header containing `ref_count:u32` and `LayoutId:u32`, addressed directly by every nonzero eight-byte-aligned Lane reference and followed by payload at offset eight.
_Avoid_: payload pointer, object-size field, allocator block header

**Immortal Refcount Sentinel**:
The `0xFFFF_FFFF` count assigned to image-owned static objects so generic retain and release can recognize them without a pointer-range test.
_Avoid_: valid dynamic count, saturating retain, zero count

**Local Constructor Tag**:
A dense `u32` runtime discriminator scoped to one nominal data type and stored at the beginning of a data payload for pattern matching.
_Avoid_: LayoutId, Buslane DataConId, image-global constructor index

**Object Shape**:
The canonical `ObjectShapeId`-indexed member schema whose Data variant contains constructor tag and fields and whose Environment variant contains captures without a tag, with stored-witness ordinals but no raw offsets or alignment fields.
_Avoid_: runtime LayoutId, raw offsets, String variable-size layout

**Layout Operand**:
The `tag:u8 + payload:u32le` operand using Immediate `0x01` with nonzero LayoutId or Witness `0x02` with a trivial witness SlotId.
_Avoid_: ObjectShapeId, type argument, memory address

**Field Projection Result**:
The value destination SlotId plus witness-destination OptionalSlot required for an erased generic member.
_Avoid_: source binder, raw memory load, implicit companion

**Typed Data Payload Layout**:
The `ObjectShape::Data`-defined payload arrangement containing a local tag, stored generic witnesses, and user fields at representation-aware offsets.
_Avoid_: uniform VMValue field array, source-level record ABI, flat constructor table

**Nullary Constructor Singleton**:
An image-owned static data object reused for a constructor with no user fields and no layout witnesses that must be retained for destruction.
_Avoid_: dynamic nullary allocation, pointer-identity value, global source binding

**Typed Closure Environment Layout**:
The immutable representation-erased arrangement of captured fields and hidden generic layout witnesses after a common ARC header, with offsets and drop behavior owned by the environment's `LayoutId` entry.
_Avoid_: constructor-tagged data payload, mutable capture dictionary, recursive member-closure storage

**Materialized Layout Descriptor**:
The fixed 32-byte Wasm memory record indexed by `LayoutId`, containing representation kind, size mode, size or sizer index, alignment, retain/release/destroy helper indices, and a reserved word.
_Avoid_: compiler source type, heap descriptor, variable-size record

**Layout Helper Entry**:
An internal canonical-table function used by a layout descriptor and deliberately excluded from the valid Lane `FunctionId` namespace.
_Avoid_: callable Lane target, runtime import identity, bytecode function body

**Canonical Lane Memory Export**:
The module-defined non-shared wasm32 memory exported as `"lane.memory"`, with image static data at low addresses and the module-owned heap beginning at immutable `heap_base:i32`.
_Avoid_: imported memory, multiple memories, host-owned allocator

**Private Wasm Fatal Exception**:
The internal `exnref` signal used for runtime-import failure, out-of-memory, ARC overflow, and similar fatal execution errors while generated handlers release owned values.
_Avoid_: Lane exception, effect dispatch, recoverable status

**Lane Wasm Module ABI**:
The generated module boundary exporting `"lane.entry":() -> ()`, canonical memory, and restricted runtime-service helpers, while importing stable registry symbols under `"lane.runtime.v1"`.
_Avoid_: source module exports, arbitrary Lane function exports, Component ABI

**Runtime Service Nested Call**:
A RuntimeContext invocation of an approved service export such as `"lane.runtime.string.new"` during a host import, without permission to invoke Lane entry, closures, or ordinary functions.
_Avoid_: Lane callback, general same-instance reentry, asynchronous host call

**Static Wasm Image Initialization**:
The instantiation-time population of image-owned memory and function-table entries by active data and element segments, with no Wasm start function.
_Avoid_: Lane startup function, lazy descriptor construction, runtime image loader

**Canonical Wasm Function Table**:
The one private fixed-size `funcref` table whose invalid zero entry precedes the contiguous Lane `FunctionId` range and internal layout-helper range.
_Avoid_: exported table, table growth, multiple tables

**Trusted Bytecode Contract**:
The execution-image contract where `lane link` establishes bytecode invariants and downstream interpreters or native lowerers rely on those invariants without re-verifying the decoded image.
_Avoid_: bytecode sandbox, untrusted artifact validation, duplicated Buslane verification

**Linked Program Container**:
The Lane `.lbp` artifact wrapper whose v1 payload stores linked-program schema version 4 followed by one decoded LoisVM bytecode image.
_Avoid_: section directory, duplicate entry metadata, module object, raw VM image

**Executable-Only Linked Artifact**:
A linked program artifact policy where `.lbp` stores only execution-required payloads and omits linked Buslane/core snapshots.
_Avoid_: inspectable semantic artifact, module object bundle, debug build

**Canonical Linked Disassembly**:
The deterministic `lane inspect` projection for executable-only `.lbp` artifacts, containing schema versions, selected entry, table summaries, and canonical bytecode instructions.
_Avoid_: raw bytes, reconstructed Buslane, source-level debug output

## Relationships

- `lanec` implements the language contract from `spec`.
- `lanec` consumes `buslane` as the semantic core target.
- The **Pre-Buslane Contract** is documented in
  `modules/lanec/docs/pre-buslane-contract.md`; it separates source
  elaboration and canonicalization from Buslane, ANF, and execution
  optimization.
- `lane` and future tools should call compiler APIs instead of importing
  internal packages when possible.
- Platform services such as filesystem access belong in tools, not in the
  compiler core.
- A **Compiler Diagnostic Adapter** may depend on **Diagnostic Infrastructure**
  but must not own terminal, JSON-RPC, or editor presentation.
- **Source-Aware Diagnostic Rendering** is the only user-facing presentation
  path for compiler and formatter source diagnostics.
- **Width-Sensitive Formatting** belongs to compiler syntax pretty-printing,
  not to command-line post-processing.
- **Width-Sensitive Formatting** applies first to syntax-owned list and head
  structures; it does not split source atoms such as identifiers, module paths,
  comments, or string literals.
- A complete comment-preserving formatter consumes a **Concrete Syntax Layer**
  and **Trivia Stream** rather than adding comment fields to semantic AST nodes.
- **Parse Result** is a domain enum rather than an optional parsed field; a
  successful **Parsed Source** carries syntax plus **Concrete Syntax**, while a
  failure carries lexical and parse diagnostics.
- **Parse Failure** distinguishes lexical and grammar failures: grammar
  failures may still carry reliable **Concrete Syntax**, while lexical failures
  do not.
- **Concrete Syntax** keeps token and trivia sidecars beside the syntax AST;
  yacc grammar actions should not carry formatter trivia through semantic AST
  fields.
- The lexer owns **Concrete Syntax** token and **Gap-Indexed Trivia**
  extraction; the parser consumes a trivia-free token view and produces syntax
  AST or parse diagnostics.
- **Concrete Syntax** owns the original source text used for formatting;
  **Gap-Indexed Trivia** values reference that text by source span and
  classified trivia kind instead of copying comment text.
- **Trivia View** is derived from **Gap-Indexed Trivia** at formatting time;
  concrete tokens do not store leading or trailing trivia arrays directly.
- The concrete token stream includes an **EOF Token**; formatting consumes its
  attached trivia but renders no token text for EOF.
- **Trivia Attachment** is a formatting concern; source elaboration, type
  checking, and semantic lowering should continue to consume comment-free AST
  data.
- **Trivia Attachment** is based first on **Token Boundary Trivia**; node-level
  formatting helpers may consume attached trivia, but AST nodes do not own
  comments directly.
- A **Trailing Comment** should remain trailing on the syntax unit it originally
  followed; the formatter should not silently convert it into a leading or
  detached comment when a group breaks.
- The formatter preserves comments and meaningful blank lines from the
  **Trivia Stream**, but ordinary spacing, indentation, and line breaks remain
  generated by **Width-Sensitive Formatting**.
- **Line Comment Trivia** is source layout trivia for formatter purposes; doc
  comment binding is a separate language/tooling feature and should not be
  introduced implicitly by comment preservation.
- A **Meaningful Blank Line** records grouping intent, not exact vertical
  padding; repeated blank lines should be canonicalized before rendering.
- **Trivia-Preserving Formatting** still requires parse success; preserving
  trivia does not imply partial or error-tolerant formatting.
- **Trivia-Preserving Formatting** is a full-file operation in v1; range
  formatting requires separate boundary-expansion rules and is out of scope for
  this formatter architecture.
- **Trivia-Aware Pretty Printing** extends the current width-sensitive syntax
  pretty-printer; comment preservation should not be implemented as a second
  formatter or as post-render string merging.
- A **Formatter Verification Oracle** is required for trivia-preserving
  formatting so comment preservation, AST equivalence, and idempotence are
  checked structurally rather than by snapshots alone.
- **Semantic Completion** belongs to the **Compiler Analysis API**; LSP adapters
  only transport it as protocol-specific completion items.
- A **Completion Trigger** informs a **Semantic Completion** query but does not
  decide completion semantics outside the compiler analysis layer.
- A **Completion Entry** carries Lane semantic identity, display text, and edit
  range without depending on editor protocol fields.
- A **Completion Query** reuses compiler analysis inputs but does not require
  every ordinary **Compiler Analysis API** result to precompute completion
  scopes.
- An **Unused Local Value Binding** warning is a compiler semantic diagnostic,
  not a control-flow reachability analysis or an API export check.
- **Checked Value-Use Analysis** may be reused by future optimization work, but
  warning policy such as underscore suppression must stay outside the reusable
  use-collection core.
- **Checked Value-Use Analysis** is a symbol identity graph over resolved
  binders and references; reference origin identifies the local binder whose
  definition body contains the reference, when any, so self-recursive and
  mutually recursive local definitions can be distinguished from external uses.
  It should not grow a lexical scope tree unless a separate source-tooling
  problem explicitly requires one.
- **Core Occurrence Analysis** is a core optimization analysis over linked
  Buslane/core identities; it is not an extension point for source-level unused
  warnings or editor facts owned by **Checked Value-Use Analysis**.
- **Core Occurrence Analysis** runs after link-time entry validation and before
  final executable artifact emission, while optimization still has access to
  type, effect, entry, and root metadata.
- **Core Occurrence Analysis** results are optimizer-local derived facts, not
  persisted linked-artifact semantic payload.
- Lane bytecode v1 uses **Register Bytecode Lowering**. ANF value and temporary
  identities are lowered to frame-local slots, then later slot allocation may
  compact those slots. The lowering should not first convert ANF into an
  operand-stack program.
- Lane bytecode v1 uses **Flat Bytecode Control Flow**. Match, handle, and
  other structured ANF control forms are lowered into bytecode blocks, labels,
  branches, and jumps rather than persisted as structured bytecode AST nodes.
- Non-entry bytecode blocks may declare ordered **Bytecode Block Parameters**, and every
  incoming control-flow edge supplies an equal-length ordered list of
  **Bytecode Edge Arguments**. Entering a block assigns all parameter slots
  from the edge argument slots in parallel before executing the block body.
- Reference-bearing block parameters use **Edge Ownership Transfer**. The
  selected jump or branch edge consumes each owned edge argument and establishes
  ownership in the matching target parameter without an implicit retain or
  release in the control-flow instruction.
- Passing one source owner to multiple parameters on the same selected edge
  requires explicit **Retain Copy Instructions** for every additional owner. Passing the same source
  on alternative conditional edges does not require a retain merely because the
  edges are both encoded; only one edge executes.
- Loop backedges follow the same rule. Ownership analysis releases any previous
  logical parameter ownership that is neither transferred nor otherwise used
  before the backedge overwrites its allocated slot. Slot allocation must
  preserve these logical transfer and release relationships.
- Explicit block parameters preserve control-flow merge information for the
  Wasm backend. Wasm CFG structuring must preserve those parameter and edge
  relationships rather than reconstructing merges from implicit mutable slot
  state.
- Lane bytecode v1 emits an **Erased Bytecode Image**. Source type applications,
  full generic arguments, and source-debug facts are absent, but erased
  representation signatures and hidden **Representation Layout Witnesses**
  remain where Wasm lowering or generic ownership requires them. Inspectable
  semantic type information still belongs to Buslane/core artifacts.
- Lane bytecode v1 uses a **Uniform VM Value ABI**. Slot allocation assigns
  VM-value slots, not statically typed unboxed machine slots. Primitive values,
  including `Double`, are represented as tagged VM value cases in v1.
- Lane bytecode v1 uses **Mid-Level Bytecode Instructions**. Primitive
  operations such as integer and floating-point arithmetic lower to explicit
  opcodes, while functions, closures, data construction, and calls remain
  bytecode VM semantic operations rather than machine-layout steps. Effect forms
  have already been erased.
- Statically known calls lower to **Direct Bytecode Calls** carrying compact
  function-table identifiers. Calls through first-class function values lower
  to **Callable Value Calls** carrying a callable source slot.
- The **Unified Bytecode Function Table** gives bytecode-defined functions and
  runtime imports one `FunctionId` index space. Each entry is tagged as a
  bytecode body or **Runtime Import Function Entry**.
- Bytecode stores one **Selected Bytecode Entry** before the function table. It
  must identify a no-context, witness-free, zero-argument Unit bytecode body;
  source export name and type do not survive link-time validation.
- Bytecode bodies follow final deterministic post-optimization body-list order
  and precede runtime imports. Imports serialize ABI major, user arity, and
  nonempty case-sensitive ASCII symbol, are tuple-deduplicated, and sorted.
- FunctionIds are **Build-Local FunctionIds** reproducible only for identical
  compiler version, inputs, options, and selected entry. Build changes may
  renumber them; the selected entry need not be FunctionId one, and FunctionId
  is not a persistent or module ABI identity.
- A runtime import entry stores a stable runtime symbol plus the erased ABI
  metadata required for load-time binding, including its arity. The loaded image
  caches the resolved runtime target; calls do not perform string lookup.
- **Runtime Import ABI V1** contains only fixed arity. Its logical callable shape
  is `(RuntimeContext, VMValue...) -> VMValue`: the context is implicit and does
  not count toward Lane or function-table arity, all explicit operands use the
  uniform VM value representation, and every call returns exactly one value.
- Runtime import symbols carry an ABI major version. Image loading checks the
  symbol, version, and fixed arity before installing the runtime binding. V1 has
  no varargs, multiple-result, source-type, or per-parameter representation
  descriptor.
- The **Runtime Symbol Registry** is the sole authority for a runtime import's
  primitive parameter and result kinds. The serialized descriptor repeats only
  the versioned symbol and arity; it does not duplicate that signature.
- `lanec` checks the registry-defined primitive signature before type erasure and
  emits trusted uniform-value calls. After loading checks symbol, ABI major, and
  arity, the runtime binding may assume the VM value tags are correct.
- Reference-bearing explicit arguments and the result follow the
  **Callee-Owned Bytecode ABI**. The **Runtime Context** is borrowed host state,
  is not a Lane value, and does not participate in ARC.
- Every v1 runtime import is a **Synchronous Primitive Host Call**. It cannot
  invoke or re-enter Lane program execution, suspend asynchronously, or retain
  an argument or other VM value after returning. A restricted **Runtime Service
  Nested Call** may invoke an approved allocator or String service that cannot
  call Lane code.
- Runtime-import parameters and results are restricted to the primitive value
  kinds `Int`, `Double`, `Bool`, `String`, and `Unit`. Closures, nominal data,
  environments, function identifiers, and opaque host handles cannot cross this
  boundary in v1.
- A runtime import owns its explicit arguments after entry and must consume or
  release them on both success and execution failure. `String` is the only
  permitted reference-counted boundary kind; the other permitted kinds are
  immediate values.
- Dynamic String values use immutable **Runtime String Objects**. Constant-pool
  strings expose the same logical length-and-bytes interface but remain
  image-owned static objects. Neither representation requires a trailing NUL.
- In Wasm, String length is at object offset eight and bytes begin at offset
  twelve. Allocation size is `align_up(12 + byte_length, 8)`. Constant and empty
  Strings use the same physical layout with the immortal count.
- A runtime import reads an owned String argument through a **Borrowed Host
  String View** without copying its ASCII bytes. The view cannot outlive the
  synchronous import call and does not alter the argument's ownership transfer.
- A runtime import returning String creates an owned runtime String through the
  **Runtime Context**, copying returned bytes into the VM heap and validating
  the ASCII invariant. Non-ASCII return bytes cause a **Runtime Import Failure**.
- The borrowed host view is exactly `(string_ref + 12, byte_length)` and ends
  with the synchronous call.
- V1 **String Primitive Instructions** are `string_length`, `string_concat`,
  `string_slice`, and `string_eq`. Length and equality borrow their operands;
  concatenation consumes two owners and slicing consumes one.
- String indices are Lane Int ASCII byte indices. Empty concatenation and complete
  slicing may move an input owner without allocation; proper slices create
  independent String objects rather than retaining a parent view.
- Invalid ranges, length or address overflow, and allocation failure use the
  private fatal path and make the instance unusable.
- A successful runtime import returns one owned primitive VM value. A **Runtime
  Import Failure** returns no value, has no bytecode exceptional edge, and aborts
  the current execution rather than becoming a Lane exception or effect.
- The failing import first consumes or releases its transferred arguments. The
  LoisVM execution boundary then releases remaining owned frame and slot values
  while unwinding the aborted execution.
- Recoverable host outcomes must use the import's normal primitive result, such
  as an `Int` or `Bool` status. The physical native failure channel belongs to
  the runtime binding contract and is not serialized in the bytecode ABI
  descriptor.
- **Direct Bytecode Calls**, **Callable Value Calls**, and tail calls use the
  same instructions and ownership ABI for bytecode and runtime-import targets.
  LoisVM has no separate `call_runtime` instruction or runtime-function value
  category.
- Every function-table entry declares its **Function Context Kind** independently
  from its Lane-level user arity. A capture-free entry has no hidden context; a
  capturing entry requires one **Closure Environment Reference**.
- A **Direct Bytecode Call** to a capturing entry carries the required opaque
  environment source slot. A direct call to a capture-free entry carries no
  environment operand. This requirement is statically determined from the
  target function-table entry rather than selected dynamically at runtime.
- **Direct Bytecode Calls** and **Callable Value Calls** continue at the next
  instruction in the same block. Non-`Unit` calls write one result slot; `Unit`
  calls carry no destination `SlotId`. Ordinary returning calls do not terminate
  bytecode blocks or create explicit continuation blocks.
- **Direct Bytecode Calls**, **Callable Value Calls**, and their tail-call
  forms use the **Callee-Owned Bytecode ABI**. Reference-bearing arguments and a
  required closure environment transfer ownership into the callee frame; the
  non-`Unit` returned value transfers ownership into the destination slot.
- When a caller needs a reference-bearing argument after a returning call,
  **ARC Insertion** emits a **Retain Copy Instruction** into a fresh owner slot.
  A compiler-proven last use transfers the existing ownership without one.
- A **Callable Value** is either an immediate `FunctionId` or a closure. A bare
  identifier must target an entry with no closure context; a closure supplies the
  required identifier and environment. Violating this correspondence is invalid
  trusted bytecode rather than a dynamically supported coercion.
- **Callable Construction** writes a logically dead `I64 + OwnedCallable` slot.
  `const_function` names a no-context target; `make_closure` names a
  context-requiring target and consumes one nonzero environment owner without
  carrying layout, shape, or call-signature operands.
- The interpreter implements `make_closure` with a count-one closure shell. Wasm
  instead packs FunctionId and environment into `i64` without allocation.
- `copy` is invalid for callable owners; `move`, `retain_copy`, and `release`
  provide their explicit transfer, duplication, and destruction operations.
- A **Callable Value Call** consumes its callable operand. Consuming an immediate
  `FunctionId` has no ARC effect. Consuming a closure uses **Consuming Callable
  Projection** to establish an owned callee environment.
- If the consumed closure is unique, `call_value` moves its environment and
  frees the closure shell. If the closure is shared, it retains the environment
  for the callee and releases only the consumed closure owner, leaving other
  closure owners unchanged.
- Closure uniqueness is an implementation fast path rather than a validity
  precondition. A shared closure is always a valid `call_value` operand.
- A **Callable Value Call** does not expose instructions for extracting a
  closure's function reference or environment. The VM inspects the callable tag
  internally, obtains the identifier and optional **Closure Environment
  Reference**, then enters the same function ABI used by a direct call.
- Primitive arithmetic, comparison, reference-counting, and other operations
  selected as LoisVM semantics remain dedicated bytecode instructions. Host
  capabilities such as I/O use runtime-import function entries instead of
  expanding the VM opcode set.
- A **Closure Environment Reference** is hidden calling context and does not
  count toward Lane-level function arity. Function bodies access captured values
  through dedicated capture operations rather than ordinary user parameters or
  exposed environment fields.
- Closure conversion emits **Closure Environment Construction** before closure
  creation. Recursive groups construct one environment from shared outer
  captures before publishing closures; group members are not stored as strong
  closure values in their own environment.
- **Closure Environment Construction** fully initializes every environment
  field in one operation. LoisVM v1 has no general environment mutation or
  environment-sealing instruction.
- **Capture Projection** explicitly names an environment source and shape-local
  capture index without exposing the environment's physical heap layout.
- Lane uses compiler-directed reference counting rather than tracing garbage
  collection. The **Effect-Erasure Pipeline** and closure lifting first remove
  effect-specific forms and make allocations and captured state explicit, then
  lowering produces the **Compiler-Private VM CFG** with logical values and
  block parameters.
- **Runtime Ownership Analysis** and **ARC Insertion** run on that CFG before
  physical slot allocation or construction of the `loisvm/bytecode` data model.
  They insert **Retain Copy Instructions** for owned copies and **Release
  Instructions** at compiler-determined lifetime ends.
  Last-use transfers consume existing ownership without a retain-copy. LoisVM does
  not automatically retain and release every local-slot assignment.
- Non-owning reads such as capture and data-field projection may produce a
  **Block-Local Borrow** in the compiler-private VM CFG. Runtime ownership
  analysis requires the owner to remain live through every use in that block.
- A **Block-Local Borrow** cannot become a block edge argument, consuming call
  argument, return value, closure capture, environment field, or data field.
  **Borrow Promotion** first establishes ownership, while a separate owned
  last-use value may instead transfer its existing ownership.
- Runtime objects use **Consuming Object Construction**. Data payloads,
  environment fields, closure environments, and **Continuation Closure**
  captures receive ownership from their construction operands without an
  implicit retain.
- ARC insertion retains an operand before construction when another use must
  remain live. A borrowed operand is promoted before storage. When an object is
  destroyed, its runtime destructor releases every reference-bearing field that
  the object owns.
- Data-field reads that preserve the scrutinee use **Borrowing Data Projection**
  and remain block-local under the borrow rules. A last-use data decomposition
  may instead use **Consuming Data Projection**.
- **Consuming Data Projection** is semantically valid at every positive
  reference count. When the consumed object has count one, the runtime moves
  selected fields out, releases unselected owned fields, and frees the object
  shell without retaining moved fields. When the count is greater than one, it
  retains selected reference-bearing fields and releases the consumed object
  ownership, leaving other owners unchanged.
- Every value produced by **Consuming Data Projection** is owned. Match lowering
  may use it only after selecting the constructor arm and only when ownership
  analysis chooses to consume the scrutinee; otherwise the arm uses borrowing
  projections.
- **Immediate Bytecode Values** do not participate in reference counting.
  Ownership analysis treats their copies and transfers as operationally free.
- V1 constant-pool Strings are **Image-Owned Static Objects**. Their retain-copy
  and release operations leave the immortal count unchanged. Future static
  object kinds require an explicit bytecode schema extension.
- Dynamically allocated strings, data values, closures, closure environments,
  and **Continuation Closures** are reference-counted objects. Dynamic object
  fields may store static objects without acquiring or releasing a count.
- The linked bytecode image remains loaded for the lifetime of every execution
  value that may refer to one of its static objects. V1 does not support image
  unloading while such values remain live.
- LoisVM v1 uses **Thread-Confined Reference Counting**. `retain`, `release`,
  uniqueness checks, and consuming projections use ordinary non-atomic counts.
- A dynamic VM value, closure environment, or continuation closure does not cross
  threads, and one VM instance is not entered concurrently. The Wasm backend
  must preserve the same runtime contract.
- Future concurrency requires an explicit shared or atomic ownership boundary;
  it must not silently change all existing v1 objects to atomic reference counts.
- Reusable continuations lower to **Continuation Closures** before ownership
  analysis. `resume` uses the ordinary callable-value ABI; ARC insertion retains
  the continuation before a consuming invocation when later uses remain.
- A final consuming resume transfers the existing continuation ownership.
  Proven one-shot continuations may instead lower to direct calls or linear
  control flow and avoid constructing a closure.
- LoisVM has no dedicated continuation heap object, continuation-specific RC
  instructions, or runtime stack-capture mechanism.
- The **Effect-Erased Bytecode Boundary** holds before ownership analysis and
  bytecode construction. LoisVM receives no `perform`, `resume`, `handle`,
  operation identifier, handler context, handler layout, or runtime operation
  table.
- External runtime effects are resolved before the boundary into ordinary
  runtime function or intrinsic calls. LoisVM executes those calls without an
  effect-dispatch subsystem.
- `make_closure` consumes one ownership of its **Closure Environment Reference**.
  Creating multiple closures over one environment therefore requires one owned
  environment reference per closure, established by retain or ownership
  transfer.
- Function parameters, function results, block parameters, and values stored in
  reference-counted objects are owned in v1. Borrow facts and regions are not
  encoded in the `loisvm/bytecode` data model or checked by LoisVM.
- The **Compiler-Private VM CFG** belongs only to `lanec`. It is not serialized
  in `.lmo` or `.lbp`, exposed as LoisVM bytecode, or used as the Wasm backend
  input.
- Reference-count correctness is established by compiler lowering, not by a
  bytecode verifier. The interpreter executes the emitted operations directly,
  while the Wasm lowering or Wasmoon JIT may eliminate redundant retain/release pairs without
  being required for correctness.
- **Cycle-Free Recursive Closure Lowering** prevents a shared recursive
  environment from strongly owning closure objects that themselves own the same
  environment. Calls between known group members use direct function identifiers
  with the shared environment; first-class group member values create closures
  from that identifier and environment when needed.
- LoisVM v1 has no tracing collector or runtime cycle collector. Lowering for
  closures and reusable continuations must preserve semantics without creating
  unreclaimable strong-reference cycles.
- Directly calling a capturing function can avoid allocating a closure object
  and avoid indirect dispatch, but it does not by itself eliminate creation of
  the closure environment.
- The Wasm backend lowers a **Callable Value Call** by unpacking the callable's
  `FunctionId` table index and optional environment offset, then issuing typed
  `call_indirect` with the environment as the hidden first argument.
- The packed Wasm representation has no closure shell. Compiler-emitted retains
  establish additional environment owners, so consuming invocation transfers
  one owner without a unique-versus-shared shell-count branch.
- A runtime-import function entry becomes a WebAssembly import or an adapter to
  one. It does not require a separate runtime-call bytecode path.
- The Wasm backend obtains a known import's primitive signature from the same
  **Runtime Symbol Registry** rather than from bytecode type metadata. Its
  physical Wasm signature and String representation remain backend decisions.
- Tail position uses dedicated direct and callable-value **Bytecode Tail Call
  Terminators** rather than changing the continuation behavior of ordinary call
  instructions.
- A **Bytecode Tail Call Terminator** transfers argument and required closure-
  environment ownership directly into the replacement callee frame and returns
  no owned value to the current frame.
- The **Effect-Erasure Pipeline** runs before compiler-private VM CFG and
  bytecode lowering. Its `mon-trans`, `open-resolve`, and `monadic-lift` passes
  leave only ordinary functions, closures, data, calls, and control flow for
  LoisVM lowering.
- **One-Shot Continuation Analysis** must be sound: uncertain continuations are
  treated as reusable or escaping. Proven one-shot resumes may lower to linear
  continuation blocks or functions; other resumes lower to continuation
  closures that later closure lifting turns into functions plus context.
- **Closure Lifting** is complete before bytecode emission. A bytecode image
  contains one flat unified table of lifted bytecode functions and runtime
  imports; function values and continuation closures are represented as callable
  references plus captured context rather than nested bytecode function
  literals.
- **Bytecode Data Layout** is assigned at link-time lowering. Bytecode data
  values use compact constructor tags and payload fields; Buslane `DataConId`
  values are lowering inputs, not VM ABI values or runtime dispatch keys.
- The **Bytecode Constant Pool** is image-global in v1. Every bytecode function
  references the single pool through constant identifiers, allowing link-time
  String deduplication across functions. Numeric and function constants remain
  instruction operands; constructor tags belong to data-layout metadata.
- The v1 **Bytecode Lowering Pipeline** is linked Buslane/core, core
  optimization, ANF lowering, ANF simplification, `mon-trans`, `open-resolve`,
  `monadic-lift`, closure lifting, layout assignment, compiler-private VM CFG
  lowering, runtime ownership analysis, ARC insertion, slot allocation,
  bytecode emission, then bytecode peephole and jump cleanup. Semantic
  optimizations should run before lowering loses Buslane/core type and effect
  information; physical layout and ownership work should stay close to bytecode
  emission.
- The **Bytecode Lowering Pipeline** targets **LoisVM Bytecode Target**.
  `lanec` owns lowering into bytecode, but the bytecode data model and
  interpreter belong to the independent `loisvm` module.
- The **Wasm Backend Path** starts from decoded LoisVM bytecode,
  not from `lanec`-internal Buslane, ANF, or another parallel executable IR.
  This keeps the `.lbp` bytecode image as the common executable input for both
  interpretation and native or JIT execution.
- Lane v1 emits the **Lane Wasm Feature Profile**. Wasmoon remains extensible as
  an implementation and optimization platform, but generated modules do not
  require Wasmoon-specific instructions, types, or non-standard module semantics.
- The profile includes Multi-value, Reference Types, Typed Function References,
  Tail Call, and Bulk Memory while retaining wasm32 linear memory and excluding
  Wasm GC.
- Memory64 is outside Lane v1. All linear-memory references and packed-callable
  components remain 32-bit, and the backend does not emit 64-bit memory types or
  memory addresses.
- Multiple Memories is outside Lane v1 output. Memory zero contains the Lane
  heap, image-owned constants, layout data, and runtime-visible bytes; all Lane
  references are offsets into that one canonical memory.
- Threads and Atomics are outside Lane v1 output. The canonical memory is not
  shared, the same Lane instance is not concurrently entered, and compiler-
  directed ARC continues to use non-atomic counts. Separate Wasm instances may
  still execute on different host threads.
- Bulk Memory may implement static data or table initialization, allocator
  filling, and raw-byte String copies. Reference-bearing object construction and
  duplication still follow explicit ARC ownership operations rather than raw
  `memory.copy`.
- Exception Handling with `exnref` is an internal fatal-unwind mechanism only.
  Runtime-import adapters throw a private Wasm exception after consuming
  transferred arguments; generated cleanup handlers release each frame's
  remaining owners and rethrow. No Lane effect, exception value, or bytecode
  exceptional successor is introduced.
- Sign-extension Operators and Extended Constant Expressions are available to
  Lane v1 emission. Non-trapping Float-to-int, Fixed-width SIMD, Branch Hinting,
  Wide Arithmetic, Custom Page Sizes, and Memory Control are known optional
  capabilities but are neither emitted nor required by v1.
- Stack Switching and Relaxed SIMD are excluded. Lane continuations have already
  lowered to ordinary functions and closures, and relaxed platform-dependent
  vector results are not part of Lane v1 execution semantics.
- Import/Export Mutable Globals, Compilation Hints, WASI Preview 1, the Component
  Model with WASI Preview 2, and JS BigInt-to-`i64` integration are known host or
  deployment options but are not emitted or required by core lowering.
- Multiple Tables and Relaxed Dead-code Validation are excluded. `FunctionId`
  addresses one canonical function table, and generated code must satisfy normal
  Wasm validation even in unreachable regions.
- JS Promise Integration, JS String Builtins or String References, and Custom
  Descriptors or JS Interop are excluded. They do not replace the synchronous
  Runtime Import ABI or linear-memory ASCII String representation.
- Extended Name Sections, Custom Annotations, Rounding Variants, Half Precision,
  Flexible Vectors, Type Imports, and the JIT Interface are known optional
  capabilities but are not emitted or required by Lane v1.
- Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are
  excluded because they conflict with thread confinement, the Wasmoon-centered
  host boundary, or the linear-memory ARC heap.
- The Wasm backend lowers dynamic Lane objects into the **Wasm Linear-Memory ARC
  Heap**. It preserves compiler-emitted ARC and ownership-transfer semantics and
  does not map Lane objects to Wasm GC structs or arrays.
- **Representation Erasure** lets monomorphic values lower to natural Wasm
  types such as `i32`, `i64`, and `f64`. A representation-polymorphic value uses
  one `i64` erased payload, and its hidden **Representation Layout Witness**
  supplies generic retain, release, destruction, and field-layout behavior.
- `LayoutId` is an immediate index into the **Image Layout Table** and does not
  participate in ARC. Generic objects store the layout identifiers required by
  their erased fields. Derived layouts are precomputed and passed as additional
  hidden witnesses rather than allocated or composed at runtime.
- Portable entries are deduplicated **Portable Layout Recipes**. Primitive recipes
  precede Data recipes ordered by ObjectShapeId and Environment recipes ordered
  by ObjectShapeId; recipes contain no computed size or helper index.
- A first-class callable lowers to a **Packed Wasm Callable**. Its `FunctionId`
  is the Wasm table index used by typed `call_indirect`, and its environment
  offset is the hidden first argument. Every nonzero packed environment is one
  owned ARC reference; retain and release act directly on that environment, so
  Wasm lowering allocates no independent closure shell.
- Typed Function References belong to the allowed Wasm feature profile, but the
  canonical closure ABI remains packed and table-indexed. `call_value` and its
  tail form lower to `call_indirect` and `return_call_indirect`; `call_ref` and
  `return_call_ref` may be used only as backend-local optimizations that do not
  alter heap storage or the erased generic `i64` representation.
- Every bytecode function lowers to the **Canonical Wasm Lane Entry ABI**.
  Monomorphic arguments and results use `i32`, `i64`, or `f64`; generic values
  use `i64`; `Unit` has no result; and the type section interns each complete
  erased signature. Runtime imports receive adapters with the same Lane entry
  ABI before crossing to their host signature.
- Bytecode emission uses **Structured Bytecode Addressing**. Each function stores
  an ordered block table and a slot representation table; `BlockId = 0` is entry;
  each block stores an instruction array and explicit terminator. Branches carry
  block identifiers and edge argument slots rather than byte offsets.
- A bytecode section starts with **LoisVM Bytecode Schema Version** `0x01` for
  v1 and no duplicate magic. Outer `.lbp` section framing supplies kind
  and byte length.
- Schema counts have no normative maxima below `u32`. Checked arithmetic and
  minimum-size preflight protect framing; **Implementation Resource Limits** may
  reject otherwise valid images without changing schema compatibility.
- **Atomic Bytecode Load** completes decode before import resolution, performs no
  Lane execution during resolution, discards partial state on failure, and
  publishes only after interpreter-image or Wasm construction succeeds.
- Successful loading publishes a reusable **Loaded Executable Image**. Every run
  creates a fresh **Single-Shot Execution Instance** that becomes terminal after
  its one successful or failed selected-entry attempt.
- The interpreter uses an explicit LoisVM frame stack. Returning bytecode-body
  calls increase logical depth, tail calls preserve it, and runtime imports do
  not create Lane frames.
- Host execution configuration may set logical call-depth and canonical
  live-heap-byte **Execution Resource Limits**. Both execution tiers enforce
  them through cleanup-capable fatal failure, without serializing them in
  `.lbp`.
- V1 has no portable fuel, instruction budget, deadline, or timeout semantics.
  **Execution Interruption** and **Engine Traps** may bypass ARC cleanup and
  always discard the execution instance.
- Successful entry return performs no frame scan, heap scan, or implicit
  release sweep; ARC insertion must already establish ownership-empty exit.
- Interpreter and Wasm execution share RuntimeImportFailure,
  ExecutionResourceLimit, Interrupted, EngineTrap, and InternalRuntimeFailure
  top-level categories. Backend trap strings are supplementary diagnostics.
- Load failures distinguish unsupported schema, malformed encoding, unresolved
  import, ABI mismatch, resource limit, and backend compilation failure;
  malformed diagnostics carry bytecode-relative offsets and import symbols.
- **Dense Bytecode Identifier Spaces** derive IDs from table order. `FunctionId`
  and `LayoutId` begin at one; `BlockId`, `SlotId`, `ConstantId`, and
  `ObjectShapeId` begin at zero. IDs, counts, and byte lengths use `u32le`.
- Instructions and terminators use separate `u8` **Fixed-Shape Opcode
  Encodings** without per-instruction lengths. Unknown tags fail decoding.
- Each **Bytecode Tag Namespace** numbers known variants contiguously from
  `0x01`, reserves `0x00` and `0xFF`, and is frozen within one schema version.
  Any change to its accepted values requires a schema-version bump.
- V1 representation values are I32/I64/F64 = `0x01`/`0x02`/`0x03`; cleanup
  values are Trivial/OwnedRef/OwnedCallable/OwnedErased = `0x01` through
  `0x04`; result values are Unit/I32/I64/F64 = `0x01` through `0x04`.
- Function-entry values are BytecodeBody/RuntimeImport = `0x01`/`0x02`; Layout
  Recipe values follow Unit through Environment at `0x01..0x08`; Object Shape
  and LayoutOperand values are Data/Environment and Immediate/Witness,
  respectively, both `0x01`/`0x02`.
- The **Canonical V1 Opcode Table** assigns 66 instructions to `0x01..0x42`
  and seven terminators to independent `0x01..0x07`. Normal calls are
  instructions; CFG transfers, returns, tail calls, and unreachable are
  terminators excluded from `instruction_count`.
- V1 has no nop, opcode alias, generic operation-subtag instruction, embedded
  source location, profiling instruction, or debug instruction.
- Each **Canonical Bytecode Function Body** has a `u32le` payload byte length and
  must be consumed completely. Its payload order is slot table, function inputs,
  result descriptor, then block table.
- Block count is nonzero and block-table order implies `BlockId`; block zero is
  entry and has no parameters. Each block stores counted unique parameter slots,
  counted fixed-shape instructions, then one terminator without a block length.
- Slot-table order implies `SlotId`; each slot entry stores representation and
  cleanup tags, and only `OwnedErased` appends a companion SlotId. Bytecode
  records have no alignment padding, and `i64` and
  `f64` constants preserve raw little-endian bits.
- V1 **Slot Representation Tags** are `I32`, `I64`, and `F64`; Unit has no
  slot. Returning calls use zero destination OptionalSlot for Unit.
- **Slot Cleanup Categories** are `Trivial`, `OwnedRef`, `OwnedCallable`, and
  `OwnedErased`. They describe generated cleanup behavior, not source ownership
  or compiler-private borrow regions.
- `OwnedRef` pairs only with `I32`; `OwnedCallable` and `OwnedErased` pair only
  with `I64`. `OwnedErased` names an **Erased Ownership Companion** whose
  `I32 + Trivial` witness remains unchanged while the payload is live.
- Final bytecode has no `Borrowed` category. Block-local non-owning reference
  temporaries may use `Trivial`, but cannot cross a block, call, return, or
  heap-storage boundary.
- A bytecode body records **Bytecode Function Inputs** separately from block
  parameters. Environment uses zero or `SlotId + 1`; counted `I32 + Trivial`
  witnesses precede counted user-argument SlotIds, and all input IDs are distinct.
- The function result descriptor is one Unit/I32/I64/F64 tag and does not
  duplicate cleanup metadata. Unit has no result slot; actual return and
  destination slots provide cleanup categories.
- Every **Optional Slot Reference** is one `u32le` containing zero or
  `SlotId + 1`; environments, call destinations, return sources, and projection
  witness destinations use the same encoding.
- Every other SlotId operand is direct zero-based `u32le`. SlotId zero is valid;
  `make_closure` may name it even though the owned environment value must be nonzero.
- Slot arrays are one `u32le` count followed by exact SlotIds. `call_direct`
  stores target, environment OptionalSlot, witnesses, users, then destination;
  `call_value` stores callable, witnesses, users, then destination.
- Witness and Trivial user arguments are non-consuming reads. Owned user
  arguments transfer into the callee; direct calls consume their nonzero
  environment and value calls consume their callable.
- Bytecode has no call-shape table. Wasm lowering obtains a **Derived Indirect
  Call Shape** from call-site slot tags, while runtime-import adapter signatures
  come from the runtime registry. Matching remains trusted bytecode invariance.
- A **Return Terminator** stores one source OptionalSlot, consuming a non-Unit result
  owner into the caller. Normal return performs no implicit frame scan; explicit
  releases establish an **Ownership-Empty Exit** for every other owner.
- `tail_call_direct` stores target, environment OptionalSlot, counted witnesses,
  and counted user arguments. `tail_call_value` stores callable and both arrays.
  Both consume transferred operands and have no destination.
- Explicit releases remove untransferred owners before a tail terminator. Its
  target result representation matches the current function result descriptor;
  indirect-tail type derivation uses that descriptor rather than a destination.
- Wasm emits `return_call` or `return_call_indirect`. A tail-called runtime import
  uses the same transfer, and adapter failure occurs after the replaced frame is
  ownership-empty.
- A **Bytecode Edge Record** stores target BlockId, argument count, and exact
  SlotIds. `jump` stores one edge; `branch_bool` stores an `I32 + Trivial`
  condition followed by true and false edges.
- A **Tag Switch Terminator** is one node of the lowered decision tree, not a
  pattern-match instruction. It uses unsigned tag comparison, permits zero dense
  cases, always stores default, and has no block-table fallthrough.
- Only the selected edge transfers arguments, in parallel. Trivial sources may
  repeat and are read; owned sources are consumed and may not repeat without
  prior retain-copy. Edge ranges, arity, representation, cleanup, and ownership
  agreement remain trusted invariants.
- A **Trusted Unreachable Terminator** lowers directly to Wasm `unreachable` and
  does not use private fatal cleanup. Boolean branches lower through `if` or
  `br_if`; dense tag switches preferentially use `br_table` before CFG layout.
- Bytecode has no generic assignment. **Trivial Slot Copy** duplicates only
  `Trivial` slots; **Ownership Move** consumes a compatible source without ARC;
  **Retain Copy Instruction** establishes an owned destination and implements
  both owned duplication and borrow promotion.
- Every destination is logically dead before writing. `release(slot)` consumes
  one owner, and neither move nor release clears stale physical bits. Bytecode
  never implicitly releases an overwritten destination.
- Retain-copy and release dispatch by `OwnedRef`, `OwnedCallable`, or
  `OwnedErased`, with erased operations using the companion witness. ARC on a
  `Trivial` owner is invalid trusted bytecode rather than a specified no-op.
- Wasm lowering uses local get/set plus ARC helpers. Backend or Wasmoon
  optimization may remove redundant moves and balanced retain-copy/release
  pairs, but local assignment itself has no ownership semantics.
- `const_int`, `const_double`, and `const_bool` produce **Inline Scalar
  Constants** from `i64le`, raw binary64 bits, and byte `0` or `1`. Other Bool
  bytes are malformed, and Unit has no constant instruction.
- `const_function(dst, FunctionId)` creates a capture-free callable with
  environment zero. `const_string(dst, ConstantId)` creates an owned logical
  reference to an **Image String Constant**.
- `const_layout(dst, LayoutId)` writes a nonzero image layout identifier into an
  `I32 + Trivial` witness slot and does not use the String constant pool.
- The v1 **Bytecode Constant Pool** stores only reachable Strings after
  whole-program optimization. The linker deduplicates exact ASCII bytes, sorts
  unsigned raw bytes lexicographically, assigns zero-based IDs, and remaps
  `const_string`; empty String is ID zero when present.
- Active data segments materialize pooled immortal String objects. Wasm
  `const_string` lowering produces their static addresses without retaining.
- Integer primitives are signed `I64 + Trivial` add, subtract, multiply, negate,
  divide, remainder, bitwise operations, shifts, and comparisons. Overflow and
  invalid shift counts are **Integer Undefined Behavior**, permitting direct
  wrapping arithmetic and Wasm's low-six-bit shift behavior.
- Division by zero, `MIN_INT / -1`, and remainder by zero may cause a
  **Non-Unwinding Arithmetic Trap**. It bypasses private fatal cleanup, and the
  current Wasm instance is discarded rather than reused.
- Integer comparisons and Bool primitives produce **Canonical Boolean Scalars**.
  Bool v1 has not/equality only; short-circuit and/or lower to control flow.
- Double primitives use Wasm binary64 add, subtract, multiply, divide, negate,
  and comparisons. IEEE zero, infinity, and NaN comparison behavior applies;
  arithmetic does not promise NaN-payload preservation.
- Bytecode has no implicit conversion between Int and Double; only the defined
  **Explicit Numeric Conversion** opcodes cross those numeric types.
- **Explicit Numeric Conversion** uses signed `int_to_double` with IEEE nearest-
  ties-even rounding and `double_to_int` with truncation toward zero. Precision
  loss converting large Int values is permitted.
- NaN, infinity, or out-of-range Double-to-Int conversion may cause a
  **Non-Unwinding Conversion Trap**. V1 emits no saturating or non-trapping
  float-to-int form, and the failed instance is discarded.
- **Representation Erasure Bridges** zero-extend or wrap `I32`, preserve `I64`
  bits while changing cleanup interpretation, and reinterpret `F64`/`I64` bits.
  They consume sources and transfer ownership without ARC.
- Trusted slot and layout metadata governs bridge validity. Int and Callable use
  identity-bit I64 bridges rather than ordinary movement; these bridges never
  imply source-level numeric coercion.
- Every erased endpoint is `I64 + OwnedErased`, including no-op primitive
  layouts. Erase reads an initialized destination companion and unerase reads
  the source companion; neither carries a witness operand.
- One immutable companion may serve several live erased payloads and becomes
  reusable only after all are consumed. Calls perform no implicit erasure.
- Natural Unit has no slot, while generic Unit uses canonical `I64 0 +
  OwnedErased` with a nonzero no-op Unit LayoutId. `erase_unit` encodes only a
  destination and `unerase_unit` only a source.
- Zero-based `ObjectShapeId` identifies an **Object Shape** independently from
  runtime `LayoutId`. Data and Environment variants determine static field or
  capture offsets; layout metadata determines allocation and ARC behavior.
- `make_data` carries destination, direct zero-based Data shape, **Layout
  Operand**, counted witness slots, and counted field slots. The shape supplies
  constructor tag; Trivial inputs are read, owned fields are consumed, and a dead
  `I32 + OwnedRef` destination is published after complete initialization.
- `make_env` uses the symmetric destination, Environment shape, Layout Operand,
  counted witnesses, and counted captures form. It reads Trivial inputs, consumes
  owned captures, and fully initializes the tagless environment before publication.
- `borrow_capture` preserves its explicit environment source and produces a
  block-local borrowed result. `consume_captures` consumes one environment owner
  and returns selected captures as owners through equivalent unique/shared paths.
- Consuming capture indices are strictly increasing and may be empty.
- Capture-free functions use environment zero, have no Environment Object Shape,
  and execute no `make_env`.
- Object Shapes omit alignment and offsets. Data layout is header, tag, contiguous
  u32 witnesses, then aligned fields; Environment omits the tag. I32 uses four-
  byte size/alignment, I64/F64 eight, and total size rounds to eight.
- Member schemas encode representation, cleanup, and witness ordinal plus one.
  Exact shapes are deduplicated and sorted Data-first, then Environment.
- `load_tag` is a non-consuming read. `borrow_field` preserves object ownership
  and writes one **Field Projection Result**; reference payloads are `Trivial`,
  and generic fields also write their stored witness.
- `consume_fields` carries shape, object, count, and a possibly empty strictly
  increasing field/result sequence. It consumes the object, returns selected
  owned fields, releases unselected fields, and preserves unique/shared equivalence.
- Field indices are shape-local and valid only after constructor selection.
  Shape/layout compatibility is trusted bytecode state. No data opcode exposes
  raw heap offsets, loads, or stores.
- Slot allocation produces **Representation-Homogeneous Slots**. The interpreter
  still stores tagged VM values, while Wasm lowering maps each slot to a typed
  local according to its erased representation and ownership category.
- **Wasm CFG Structuring** uses temporary locals for parallel block-parameter
  transfer, structured Wasm control for reducible CFGs, and a `loop` plus
  `br_table` dispatcher fallback for irreducible CFGs. Multi-value block
  parameters remain an optional future optimization.
- Dynamic Wasm objects use the **Lane ARC Object Header**. Allocation returns a
  nonzero eight-byte-aligned header pointer with count one; payload begins at
  offset eight; fixed or variable size comes from layout-specific rules; and
  allocator metadata does not enter the Lane object ABI.
- Static image objects use the **Immortal Refcount Sentinel**. Retain and release
  are no-ops for the sentinel, while dynamic overflow into it is fatal. Releasing
  a dynamic object to zero runs its layout destructor before allocator free.
- **Bytecode Data Layout** assigns each constructor a type-local **Local
  Constructor Tag** and concrete **Typed Data Payload Layout**. Pattern matching
  loads the tag; `ObjectShapeId` selects static offsets, while `LayoutId` selects
  runtime allocation and destruction and is not constructor identity.
- Erased generic fields occupy `i64`, and data payloads store the hidden
  `LayoutId` witnesses required to destroy them. Construction consumes owned
  fields into the object. Eligible nullary constructors use immortal **Nullary
  Constructor Singletons** instead of dynamic allocation.
- Capturing functions use a **Typed Closure Environment Layout** with no
  constructor tag. Environment allocation followed by one-time initialization
  consumes capture ownership, stores generic witnesses needed by destruction,
  and then publishes an immutable object. Capture-free functions use zero and
  allocate no empty environment.
- Recursive closure groups share one environment without storing strong member
  callable references. Wasm may scalar-replace a non-escaping environment as an
  optimization while preserving the same ARC behavior.
- Wasm materializes the image layout table at immutable
  `layout_table_base:i32`; `LayoutId = 0` is invalid and each **Materialized
  Layout Descriptor** occupies 32 bytes. Fixed sizes and variable sizers return
  total allocation size including the common header.
- Retain and release helpers have `(i64) -> ()`, destroy helpers have `(i32) ->
  ()`, and sizers have `(i32) -> i32`. Destroy releases fields but does not free.
  **Layout Helper Entries** share the canonical function table but are not valid
  Lane `FunctionId` values.
- The Wasm module owns the **Canonical Lane Memory Export** and its allocator.
  Address zero is reserved, static image data comes first, and immutable
  `heap_base:i32` starts the aligned dynamic heap. Runtime imports access bytes
  through the exported memory rather than an imported host memory.
- Allocation uses a bump frontier plus reusable free lists and `memory.grow`.
  Reused blocks are not implicitly cleared; constructors initialize observable
  fields before publication. OOM and ARC overflow use a **Private Wasm Fatal
  Exception**, while free, destructors, and cleanup cannot throw.
- The **Lane Wasm Module ABI** exports `"lane.entry":() -> ()` for the selected
  executable entry and exports no other Lane function. Runtime imports reside in
  `"lane.runtime.v1"` and use natural primitive Wasm signatures; private fatal
  exceptions escape the entry boundary to Wasmoon.
- String inputs expand to `(i32, i32)` pointer-length pairs. String results are
  owned `i32` references created through
  `"lane.runtime.string.new":(i32) -> i32`; RuntimeContext validates and copies
  bytes through canonical memory during the approved nested service call.
- **Static Wasm Image Initialization** uses active data and element segments.
  The generated module has no start function; successful instantiation leaves
  static memory, immutable globals, allocator state, and the function table
  ready for `"lane.entry"` or a runtime service.
- The **Canonical Wasm Function Table** is private, has exact fixed minimum and
  maximum sizes, and is never grown. Index zero is invalid; indices `1..N` map
  Lane `FunctionId` values directly, including runtime-import adapters; layout
  helpers follow. Entry wrappers and runtime-service helpers remain outside it.
- Canonical memory declares no maximum. Its initial standard 64-KiB page count
  is the minimum that covers `heap_base`, and the allocator grows it on demand.
- LoisVM v1 uses the **Trusted Bytecode Contract**. `lane link` is responsible
  for emitting structurally and semantically valid bytecode; `loisvm/interp`
  and the Wasm backend do not run an independent LoisVM bytecode verifier. The
  emitted WebAssembly module must still satisfy WebAssembly validation.
- Binary artifact decoding remains strict about bytes, framing, schema tags,
  lengths, and complete section consumption. That decoding does not validate
  bytecode control-flow targets, slot data flow, call arities, or table
  references after the image has been decoded.
- Lane v1 `.lmo` module objects store canonical linkable Buslane/core and do
  not contain LoisVM bytecode or a per-module bytecode cache.
- `lane link` first links `.lmo` Buslane/core, runs whole-program core
  optimization, and only then runs the **Bytecode Lowering Pipeline** to produce
  the execution image for `.lbp`.
- A `.lbp` artifact is a **Linked Program Container**, not a raw LoisVM file.
  Its fixed-order payload contains `linked_program_schema_version:u32le = 4`
  followed by one LoisVM bytecode section occupying every remaining payload
  byte. There is no section directory or nested bytecode length.
- The outer `.lbp` payload does not repeat the selected entry or runtime-import
  table and carries no module paths, linked Buslane/core, external map, effect
  metadata, target profile, or backend identifier.
- `LinkedProgramArtifact` contains a decoded bytecode image. The artifact codec
  owns outer framing and delegates nested image encoding and decoding to
  `loisvm/bytecode`.
- `.lbp` uses the **Executable-Only Linked Artifact** policy. Linked
  Buslane/core snapshots are not embedded in ordinary linked program artifacts;
  semantic inspection belongs to module objects or a future explicit debug
  artifact mode rather than the default executable payload.
- `lane inspect` renders `.lbp` as **Canonical Linked Disassembly** rather than
  source reconstruction or raw bytes. Bytecode offsets remain section-relative;
  command diagnostics may additionally show derived absolute file offsets.
- **Core Occurrence Analysis** tracks value-level Buslane/core bindings and
  references; source type and effect symbol analysis belongs to checked-source
  diagnostics, not to core occurrence.
- **Core Occurrence Analysis** records structured occurrence facts for
  optimization, including use counts, call-position use, non-call escape,
  effectful-context use, and selected-entry reachability.
- **Core Occurrence Analysis** runs on linked Buslane/core rather than ANF; ANF
  may have separate lower-level liveness or occurrence analyses later.
- **Core Occurrence Analysis** belongs to `lanec` in its own package; it should
  not be mixed into Buslane language infrastructure or the compile/link command
  orchestration package.
- The package name for **Core Occurrence Analysis** is `occurrence`; the term
  still refers to linked Buslane/core occurrence, not source unused analysis.
- The `occurrence` package analyzes a link-pipeline internal linked core value
  and returns an occurrence summary; it does not read CLI arguments, `.lbp`
  files, or serialized artifacts directly.
- Link should first build an internal linked core with a selected exported
  entry, then validate executability, run occurrence and later optimization
  passes, and only then emit the linked executable artifact.
- An **Intentionally Ignored Local Binding** is still a normal resolved value
  binding when referenced; the leading `_` only suppresses unused-local-value
  warnings.
- `lanec` follows **GHC-Like Artifact Layering**: `.lmi` records interface
  semantics and optimization hints, `.lmo` records linkable Buslane/core, and
  `.lbp` may carry a final execution image after linking and optimization.
- `.lmi`, `.lmo`, and `.lbp` use **Binary Artifact Payloads** as their official
  serialized contract; text artifact parsing is not part of the production
  artifact load path.
- The link step selects the executable entry before **Core Occurrence
  Analysis**; `exec` executes the selected linked program rather than
  selecting an entry.
- A linked executable artifact stores a single selected entry; public entry
  catalogs belong to module objects and inspection, not to `exec` selection.
- A link-time executable entry is resolved from an exported module symbol, not
  from private lowered definitions or Buslane implementation names.
- Link validates the selected entry's executable type and supported runtime
  effects before writing a linked executable artifact; `exec` must not depend
  on source-level type metadata being present in `.lbp`.
- **Execution Image Lowering** is below Buslane/core and below any
  whole-program core optimization; ANF and bytecode are not the public semantic
  artifact boundary.
