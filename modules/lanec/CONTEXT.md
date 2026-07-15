# Lane Compiler

This context defines compiler-front-end, analysis, and LoisVM-lowering vocabulary. Portable bytecode, VM runtime, host ABI, and Wasm execution terms are defined only in `modules/loisvm/CONTEXT.md`.

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

**Execution Image Lowering**:
The lowering from linked and optimized Buslane/core into a target execution image such as portable bytecode.
_Avoid_: semantic lowering, source elaboration, module interface generation

**Module Link Package**:
The target-independent `lanec/module/link` package that owns module-linking algorithms and the Linked Program model consumed by Whole-Program Elaboration.
_Avoid_: compilation orchestrator, artifact codec, execution-image target

**Whole-Program Elaboration**:
The post-link compiler phase that validates one program's selected entry and makes ordered top-level initialization, effect-lowering companions, and execution roots explicit before execution-image lowering.
_Avoid_: source elaboration, linking, LoisVM bytecode emission

**Executable Program**:
The compiler-owned result of Whole-Program Elaboration, containing one selected entry, explicit execution roots, ordered initializers, lowered core, externals, and effect companions needed for execution-image lowering without consulting the original link product.
_Avoid_: shallow linked-program wrapper, LoisVM bytecode image, loaded execution instance

**Executable Program Package**:
The target-independent `lanec/executable` package that owns Whole-Program Elaboration and the Executable Program model consumed by execution-image targets.
_Avoid_: LoisVM lowering subpackage, link implementation, command orchestration

**Execution Root Set**:
The selected entry and every ordered top-level initializer computation that Execution Image Reachability Collection must preserve and traverse.
_Avoid_: exported symbol set, already-computed dependency closure, bytecode function table

### LoisVM Lowering

**Register Bytecode Lowering**:
The execution-image lowering strategy that maps ANF values and temporaries to bytecode frame local slots instead of rebuilding an operand-stack program.
_Avoid_: stack bytecode lowering, source lowering, Buslane verification

**Execution Image Reachability Collection**:
The execution-image-lowering analysis that starts from an Executable Program's Execution Root Set and retains only transitively required functions, externals, and runtime imports for code generation.
_Avoid_: Whole-Program Elaboration, source unused-declaration analysis, linker export selection

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

**Mid-Level Bytecode Instruction**:
A bytecode instruction that makes primitive operations explicit while keeping functions, data constructors, closures, and ordinary calls as VM-level semantic operations after effect erasure.
_Avoid_: source operator call, builtin dispatch call, machine-layout instruction

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

**Cycle-Free Recursive Closure Lowering**:
The closure-conversion rule that represents recursive group member references through known function identifiers plus the shared environment rather than storing strong group-closure references inside that environment.
_Avoid_: EnvRef-to-closure ownership cycle, runtime cycle collector, weak-reference source semantics

**Effect-Erasure Pipeline**:
The pre-ANF handler elaboration, `mon-trans`, `open-resolve`, `monadic-lift`, and residual-effect-erasure sequence that converts source effects through explicit compiler-private dictionaries and selective answer-type CPS, preserves non-monadic residual effects through effect-sensitive optimization, and finally removes all effect-specific forms before compiler-private VM CFG lowering.
_Avoid_: LoisVM effect instruction, bytecode handler lowering, runtime stack capture

**Handler Dictionary**:
The compiler-private immutable product of ordinary operation-clause callables supplied for one concrete effect during effect erasure; its fields are selected statically and lose handler identity before VM CFG lowering.
_Avoid_: runtime operation table, dynamic effect map, LoisVM handler object

**Effect Context Argument**:
An ordered compiler-private ordinary value argument carrying either one concrete Handler Dictionary or one opaque companion context for an abstract effect parameter during selective CPS lowering.
_Avoid_: global evidence vector, LoisVM hidden ABI field, runtime handler lookup

**Effect Context Companion**:
The compiler-generated kind-Type parameter and value parameter paired with one kind-Effect parameter so polymorphic code can forward an opaque effect context without runtime operation tags or heterogeneous lookup.
_Avoid_: source type parameter, layout witness, universal operation table

**Monadic Effect Predicate**:
The conservative classification used by `mon-trans` that holds when an effect row has an open tail or contains any handled operation. Every handled operation is potentially multi-shot, so the predicate does not analyze or infer resume counts. It determines whether monadic translation is required, independently of whether the computation is pure or otherwise observable.
_Avoid_: nonempty-effect test, `Io` special case, optimizer purity test, resume-count analysis

**Non-Monadic Residual Effect**:
The portion of an effect row that does not require monadic translation and therefore remains on direct and CPS-transformed function types until residual effect erasure. `Io` is the initial built-in non-monadic effect.
_Avoid_: pure effect, discarded CPS effect, handler context

**Residual Effect Erasure**:
The final effect-lowering pass that removes non-monadic residual effects after all effect-sensitive optimization while preserving their ordinary extern calls and other observable operations.
_Avoid_: monadic translation, extern-call deletion, early purity rewrite

**Built-in Effect Atom**:
The compiler-IR effect term for an intrinsically identified built-in effect such as `Io`; it is not represented by an EffectId and has no effect or operation metadata to remap across modules.
_Avoid_: reserved EffectId, synthetic effect declaration, module-qualified nominal effect

**Answer-Type CPS**:
The selective transformation of a function whose latent effect satisfies the **Monadic Effect Predicate** from `(args) -> A ! E` to the conceptual shape `[Answer](context, args, (A) -> Answer ! R) -> Answer ! R`, where `R` is the **Non-Monadic Residual Effect**; functions whose effects do not satisfy the predicate remain direct style even when they are non-pure.
_Avoid_: whole-program CPS, VM stack capture, yielding side channel

**Effect Lowering Core Package**:
The `lanec/effect_lowering/core` package that owns the shared effect-lowering IR, synthesis and error semantics, and the complete non-CPS effect-erasure pipeline; the parent `lanec/effect_lowering` package is a compatibility facade, while sibling lowering packages depend on `core` directly.
_Avoid_: duplicated semantic helpers, implementation state in the compatibility facade, sibling-to-parent dependency cycles

**Selective CPS Package**:
The `lanec/effect_lowering/cps` package that owns dictionary schema generation, selective CPS ABI rewriting, context selection, relay dictionaries, and CPS-specific integration tests behind the `rewrite_selective_cps_abis` entrypoint.
_Avoid_: `cps_*.mbt` files in the parent effect-lowering package, LoisVM callable ABI, runtime continuation machinery

**Open Context Plan**:
The compiler-private effect-subsumption proof marker recording source contexts consumed by a generated call and ambient target contexts claimed to supply them; selective CPS materializes the arguments, and `open-resolve` validates the claim before erasing the marker.
_Avoid_: lexical operation dispatch, dynamic evidence search, bytecode metadata

**Resume Closure**:
The ordinary reusable continuation closure produced by effect erasure whose captured inner context reinstalls a deep handler when called and whose repeated uses are managed by ordinary ARC insertion.
_Avoid_: captured VM stack, dedicated continuation object, one-shot assumption

**One-Shot Continuation Analysis**:
A conservative analysis that may classify a resume continuation as linearly used only when repeated or escaping resume is impossible.
_Avoid_: heuristic one-shot guess, effect typing, dead-code analysis

**Closure Lifting**:
The pre-bytecode lowering pass that turns nested functions and continuation closures into lifted bytecode functions plus explicit captured context.
_Avoid_: runtime code generation, nested bytecode function, source lambda lifting

**Bytecode Lowering Pipeline**:
The ordered compiler path from linked Buslane/core through the effect-erasure pipeline, ordinary ANF, closure lifting, compiler-private VM CFG lowering, runtime ownership analysis, ARC insertion, slot allocation, and bytecode emission.
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

## Relationships

- `lanec` implements the language contract from `spec`.
- `lanec` consumes `buslane` as the semantic core target.
- The **Pre-Buslane Contract** is documented in
  `modules/lanec/docs/pre-buslane-contract.md`; it separates source
  elaboration and canonicalization from Buslane, ANF, and execution
  optimization.
- `lane` and future tools should call compiler APIs instead of importing
  internal packages when possible.
- The **Executable Program Package** owns Lane execution semantics between
  linking and target-specific execution-image lowering; target lowerers depend
  on it, never the reverse.
- The **Module Link Package** owns Linked Program construction independently of
  compilation orchestration and execution-image targets; the executable package
  depends on this link model.
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
