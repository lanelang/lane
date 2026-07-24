# Lane Compiler Pipeline

This context names compiler identity, IR, and lowering concepts from parsing to
Buslane and ANF.

## Language

**Syntax AST**:
The source-shaped tree produced from Lane concrete syntax.
_Avoid_: typed tree, core IR

**Resolved AST**:
A source-shaped tree whose names, variants, and operator aliases have been resolved.
_Avoid_: parsed AST, Buslane Core Language

**Checked Source AST**:
The typed, symbol-resolved source tree produced by Source Elaboration before lowering to Buslane Core Language.
_Avoid_: ANF IR, resolved surface AST, environment-only check result

**Source-Level Structure**:
The expression structure of the source language, such as blocks, conditionals, matches, calls, literals, and function literals, preserved before ANF lowering.
_Avoid_: atomized core shape, source-only syntax, basic blocks

**Surface Sugar Expansion**:
A recursive pre-resolution transformation that replaces source-only type,
expression, and pattern sugar with ordinary qualified source syntax while the
parsed Syntax AST remains available to formatting and source tooling. For
expression sugar, expansion preserves the lexical left-to-right evaluation of
authored child expressions and never duplicates or discards their evaluation.
_Avoid_: resolver special case, typechecker sugar rule, formatter reconstruction

**Surface Source Provenance**:
The mapping from nodes introduced by Surface Sugar Expansion to the real source
span of the authored sugar node that produced them. Generated qualified names
do not invent identifier-token spans.
_Avoid_: synthetic token location, generated-name source text, Buslane span field

**Expected Syntax Slot**:
A zero-width tolerant-parser/CST node recording the grammar category expected
at an incomplete source position, such as a type, expression, or pattern.
Completion consumes this role directly instead of inferring it by scanning
nearby punctuation.
_Avoid_: token backscan, delimiter heuristic, tuple-specific completion rule

**Source Elaboration**:
The source-level checking phase that turns resolved surface syntax into checked source syntax by removing source-only forms and selecting concrete symbols.
_Avoid_: pure desugaring, Buslane lowering

**Semantic Lowering**:
The transformation from Checked Source AST into Buslane Core Language.
_Avoid_: source elaboration, parsing, bytecode generation

**Compiler Facade**:
The stable compiler-library entry package consumed by tools instead of importing internal pipeline packages directly.
_Avoid_: CLI command, compiler process boundary, Buslane package

**Buslane Core Language**:
The typed expression-tree core language produced from Checked Source AST before ANF normalization.
_Avoid_: source AST, checked source AST, ANF IR, bytecode, VM instruction format

**Buslane Program**:
The self-contained Buslane root containing a metadata registry and a term declaration sequence.
_Avoid_: bare declaration list, metadata-only program

**Buslane Verifier**:
The Buslane-owned program-level checker for core well-formedness invariants.
_Avoid_: Lane source checker, lowering quality checker, expression-only public verifier

**Buslane Verifier Diagnostic**:
A core diagnostic that reports Buslane identities, node paths, and structural verifier errors without source spans.
_Avoid_: source-facing diagnostic, source span, source name display

**Buslane Boundary**:
The ownership boundary where Buslane defines its own core types, symbols, nodes, and metadata without depending on compiler-front-end packages.
_Avoid_: checked-source facade, compiler-internal type alias

**Buslane Identity**:
A Buslane-owned separated symbol identity for core type, type-parameter, value, or data-constructor references.
_Avoid_: compiler symbol id, de Bruijn-only identity, source name string

**Buslane Type Parameter Identity**:
A globally unique Buslane identity for a type parameter introduced by a forall or type lambda binder.
_Avoid_: source generic parameter name, de Bruijn index, compiler-front-end type variable

**Buslane Metadata Registry**:
The program-owned metadata environment that maps Buslane identities to declaration, owner, and type information.
_Avoid_: compiler symbol registry, duplicated node metadata, external lookup table, dead-code-free bundle

**Buslane Metadata Order**:
A deterministic registry traversal order used for serialization, pretty printing, and tests.
_Avoid_: source declaration order, module visibility order, semantic dependency order

**Buslane Value Kind**:
The core binding category of a Buslane value identity, such as function, value, external, parameter, local, or match binder.
_Avoid_: source origin, visibility flag, generated flag

**Buslane Value Reference**:
The uniform expression reference to a Buslane value identity, regardless of whether the identity denotes a parameter, local binding, top-level value, function, match binder, or external value.
_Avoid_: separate local/global/parameter reference nodes, source name lookup

**Buslane Value Scope**:
The verifier relation that determines whether a Buslane value identity is available at a reference site.
_Avoid_: source-level shadowing, source-name lookup, textual shadowing rule

**Buslane Declaration Order**:
The top-level Buslane term declaration sequence that preserves program order for value initialization.
_Avoid_: unordered top-level map, metadata-only program, semantic dependency order

**Buslane Declaration**:
A top-level core term for a value binding, recursive binding group, or external value.
_Avoid_: source declaration, type declaration, data-constructor declaration, top-level pattern declaration

**Buslane Node**:
A Buslane expression or declaration in a typed core program.
_Avoid_: ANF node, source syntax node

**Extrinsic Buslane Typing**:
The rule that Buslane expression occurrences are typed by metadata and verifier judgments rather than duplicated type fields on every expression.
_Avoid_: untyped core, every-node type annotation

**Typed Buslane Binder**:
A Buslane value binder whose type is recorded in the Buslane metadata registry.
_Avoid_: untyped binder, duplicated occurrence annotation

**Buslane Parameter List**:
The n-ary function and call shape used by Buslane instead of curried unary chains.
_Avoid_: curried core function, tupled argument value, partial application

**Buslane Function Result Type**:
The explicit return type carried by a Buslane function expression.
_Avoid_: duplicated full function type, body-inferred return type

**Buslane Function Body**:
The arbitrary Buslane expression checked against a function expression's result type.
_Avoid_: ANF body, restricted RHS form, implicit block node

**Buslane Type Lambda**:
A Buslane expression that introduces explicit type parameters for a polymorphic value.
_Avoid_: erased generic binder, type-level lambda

**Buslane Type Application**:
A Buslane expression that instantiates a polymorphic value with explicit type arguments.
_Avoid_: erased type argument, runtime typecase

**Buslane Coercion Node**:
A type-equality proof or cast expression in the core language.
_Avoid_: v1 type equality, ordinary type application

**Buslane Tick Node**:
A debug, profiling, or source-note annotation expression in the core language.
_Avoid_: Buslane core expression, source origin side table

**Buslane Existential Witness**:
A construction or pattern witness that packs or opens a nominal hidden type member without introducing a structural existential type.
_Avoid_: `Exists` type constructor, structural package type

**Buslane Value Binding**:
A core let binding that binds one value identity to one initializer expression.
_Avoid_: pattern let, destructuring binding, implicit let-generalization

**Buslane LetRec**:
A core recursive binding group whose right-hand sides are function values or type-lambda-wrapped function values.
_Avoid_: general recursive value binding, implicit top-level recursion marker

**Minimal Recursive Group Lowering**:
The Lane front-end rule that lowers non-recursive functions to let bindings and strongly connected recursive function groups to let-rec groups.
_Avoid_: all-functions-are-recursive lowering, oversized recursive group

**Buslane Expression Tree**:
The single expression category used by Buslane for value introductions, eliminations, and control flow.
_Avoid_: source expression tree, ANF atom/RHS split, separate value AST

**Buslane External Value**:
A Buslane value identity whose implementation is supplied outside the Buslane program.
_Avoid_: unsafe builtin expression, source builtin syntax

**Buslane External Map**:
A compiler or linker side table that maps Buslane external value identities to runtime-provided names or implementations.
_Avoid_: builtin string in Buslane metadata, source intrinsic expression

**Buslane Unit**:
A future wrapper around a Buslane program that can carry module, import, export, linking, name, origin, and external maps.
_Avoid_: module namespace inside Buslane core, source module system

**Synthetic Bool Match**:
A Buslane match produced from a source conditional expression using `true` and `false` literal patterns.
_Avoid_: Buslane if node, enum-like Bool constructor lowering

**One-Level Buslane Match**:
A Buslane match that inspects only the immediate constructor or literal shape of one scrutinee.
_Avoid_: nested source pattern, full decision tree, source match arm list

**Exhaustive Buslane Match**:
A Buslane match whose alternatives cover every possible scrutinee value.
_Avoid_: runtime match failure, partial core case

**Buslane Match Binder**:
The value identity bound to the evaluated scrutinee of a Buslane match and visible in its alternatives.
_Avoid_: repeated scrutinee expression, source pattern binder

**Buslane Match Result Type**:
The explicit result type carried by a Buslane match for checking all alternatives against one expected type.
_Avoid_: scrutinee type annotation, branch-inferred result

**Buslane Alternative Body**:
The expression evaluated by a Buslane match alternative and checked against the enclosing match result type.
_Avoid_: per-alternative result type field, branch-local result annotation

**Buslane Alternative Constructor**:
The one-level branch key of a Buslane match: default, primitive literal, or data constructor.
_Avoid_: nested pattern, decision-tree test

**Positional DataCon Binder**:
A Buslane match alternative binder introduced by data-constructor payload position rather than by source field or payload name.
_Avoid_: field-name binder, labeled payload binder

**Buslane Primitive Literal**:
A core literal value for `Unit`, `Bool`, `Int`, or `String` that is not represented as a data constructor.
_Avoid_: primitive data constructor, nominal primitive wrapper

**Normalized Buslane Literal**:
A Buslane literal that stores the primitive value rather than the source spelling.
_Avoid_: source token text, escaped string spelling

**ANF Lowering**:
The transformation from Buslane Core Language into ANF IR.
_Avoid_: semantic lowering, source elaboration, bytecode generation

**ANF IR**:
The typed Structured ANF representation produced from Buslane Core Language while preserving Lane/Core semantics.
_Avoid_: source AST, checked source AST, bytecode, VM instruction format

**ANF Node**:
A typed ANF expression, binding, atom, or right-hand side whose type is explicitly available after type checking.
_Avoid_: Buslane node, re-inferred node, untyped expression

**Administrative Normal Form**:
An intermediate representation shape where non-trivial computations are named so that evaluation order is explicit.
_Avoid_: CPS, bytecode

**Structured ANF**:
An Administrative Normal Form that keeps structured conditionals and matches while requiring their inputs and calls to use atomic values.
_Avoid_: CFG, basic blocks, jump IR

**ANF Atom**:
A typed ANF value form that can be referenced without introducing additional evaluation order.
_Avoid_: arbitrary expression, computed RHS

**Nominal Core Data**:
Buslane or ANF data that retains its nominal type and data-constructor identity.
_Avoid_: anonymous tuple, raw tag

**Data Constructor**:
A Buslane constructor identity for creating a nominal data value.
_Avoid_: constructor function, curried constructor

**Dedicated Construction Form**:
The Buslane expression form that creates nominal data from a data constructor without treating the constructor as a function value.
_Avoid_: constructor worker function call, first-class constructor

**Lane-To-Buslane Data Lowering**:
The front-end lowering rule that maps Lane structs and enums into Buslane nominal types and data constructors.
_Avoid_: Buslane struct node, Buslane enum-origin metadata

**Resolved Variant Construction**:
A checked source enum construction that lowers to Buslane data construction.
_Avoid_: string variant lookup, raw tag only

**Resolved Field Access**:
A checked source field access that lowers to a selector function call in Buslane.
_Avoid_: Buslane field node, string field lookup

**First-Class Call**:
A Buslane call whose callee is any function-valued expression rather than only a known function symbol.
_Avoid_: direct-call-only core, method dispatch

**Selector Function**:
A Buslane function declaration produced by Lane lowering to implement source field access.
_Avoid_: source-visible field function, Buslane field primitive

**Symbol Identity**:
A stable compiler identity for a resolved type, value, constructor, or local binding.
_Avoid_: source spelling, de Bruijn-only identity

**Separated Symbol Identity**:
Distinct compiler identity types for different namespaces such as type, value, field, and variant symbols.
_Avoid_: kind-tagged universal symbol id, string namespace

**Nominal Type Symbol**:
A type-namespace symbol identity for a declared struct or enum type constructor.
_Avoid_: type parameter, source type name

**Type Parameter Identity**:
A compiler identity for a type parameter introduced by a generic binder.
_Avoid_: nominal type symbol, erased runtime type

**Value Symbol**:
A value-namespace symbol identity for top-level values, functions, parameters, local bindings, local functions, and pattern binders.
_Avoid_: function-only id, parameter-only id

**Owned Symbol Metadata**:
Compiler metadata that records the nominal owner of a globally unique field or variant symbol.
_Avoid_: locally indexed field only, ownerless constructor

**Separated Namespaces**:
The rule that type names and value names are resolved in distinct namespaces and may use the same spelling without conflict.
_Avoid_: single namespace, unrestricted shadowing

**Buslane Origin Map**:
A compiler-front-end side table that links Buslane identities or nodes back to source text without being part of Buslane.
_Avoid_: Buslane source span field, semantic location, runtime value

**IR Pretty Printer**:
A stable human-readable printer for an intermediate representation used in diagnostics and tests.
_Avoid_: debug dump, unstable snapshot

**Pure Buslane Pretty Printer**:
A Buslane pretty printer that renders stable identity numbers without consulting source names.
_Avoid_: name-map pretty printer, source-facing diagnostic output

**Buslane Serialization Format**:
A future explicit interchange format for Buslane programs.
_Avoid_: current pretty output, implicit stable ABI

**Canonical Core Artifact**:
The authoritative semantic payload of compiler and linker artifacts, expressed as Buslane/core plus the side metadata needed for linking, inspection, verification, and lowering.
_Avoid_: ANF cache, bytecode image, runtime execution layout

**Execution Image Lowering**:
The transformation from a linked and optimized canonical core program into a target-specific execution image.
_Avoid_: semantic lowering, source elaboration, interface generation

**Bytecode Image**:
A portable execution image for the future bytecode VM, produced after core linking and optimization.
_Avoid_: Buslane program, ANF IR, module interface

**Per-Module Bytecode Cache**:
An optional cached bytecode section in a module object, guarded by compiler version, target, options, and core fingerprint.
_Avoid_: canonical artifact payload, interface fingerprint source, cross-module semantic record

**Closure Conversion**:
A lowering step that makes captured lexical variables explicit in function values.
_Avoid_: type checking, name resolution

**Typechecking Judgment**:
A local source-level typing rule used by the checker, such as synthesis, checking, type kinding, effect checking, pattern checking, or handler checking.
_Avoid_: global unification equation, Buslane verifier rule, optimizer rewrite

## Relationships

- A parsed **Syntax AST** undergoes **Surface Sugar Expansion** before it is
  resolved into a **Resolved AST**.
- List and tuple syntax are absent after **Surface Sugar Expansion**; resolution
  and typechecking observe only ordinary qualified nominal syntax.
- Nodes introduced by **Surface Sugar Expansion** carry **Surface Source
  Provenance**, so diagnostics and source tooling point to authored sugar rather
  than synthetic qualified names.
- Incomplete surface lists expose **Expected Syntax Slots** through the tolerant
  parser/CST; completion uses their type, expression, or pattern roles without
  recognizing tuple syntax or scanning punctuation.
- Expression **Surface Sugar Expansion** preserves authored child-expression
  evaluation order even when the expanded nominal representation is
  right-nested.
- A **Resolved AST** attaches **Symbol Identity** to resolved names while preserving source names for diagnostics.
- Lane compiler IR uses **Separated Symbol Identity** and **Separated Namespaces**.
- **Source Elaboration** consumes type checking information and produces a **Checked Source AST**.
- **Typechecking Judgments** are bidirectional and local: synthesis computes
  types from syntax, while checking pushes only adjacent expected types into
  expressions.
- A **Checked Source AST** preserves **Source-Level Structure** while removing source-only syntax and unresolved or ambiguous references.
- A **Compiler Facade** exposes stable parse, check, and compile entrypoints for the **Tools Project**.
- **Semantic Lowering** transforms a **Checked Source AST** into **Buslane Core Language**.
- A **Buslane Program** is the root value consumed by Buslane pretty printing, ANF lowering, and execution-oriented passes.
- A **Buslane Verifier** verifies a whole **Buslane Program** and checks Buslane core invariants without checking Lane-front-end lowering quality.
- **Buslane Boundary** excludes dependencies on checked-source, resolver, typechecker, compiler-symbol, or compiler-type packages.
- **Buslane Identity** is globally unique within a Buslane program and separated by namespace.
- A **Buslane Metadata Registry** belongs to each Buslane program and makes Buslane self-contained.
- A **Buslane Metadata Registry** may contain metadata not referenced by the term declaration sequence.
- A **Buslane Metadata Order** is deterministic but has no source or module semantics.
- Value metadata records a **Buslane Value Kind** and type, not a source origin.
- A **Buslane Value Reference** is uniform; reference category is read from metadata rather than encoded as separate expression variants.
- **Buslane Value Scope** is checked over globally unique identities; source-level shadowing is resolved before Buslane.
- **Buslane Nodes** store ids and local operands rather than duplicating full declaration metadata.
- Buslane uses **Extrinsic Buslane Typing** rather than type fields on every expression occurrence.
- Every value binder is a **Typed Buslane Binder**.
- **Buslane Declaration Order** preserves ordered top-level value initialization while metadata records recursively visible type and function shape.
- Buslane does not store a separate dependency order; dependency ordering beyond the term declaration sequence belongs to lowering, scheduling, or later passes.
- **Buslane Declarations** do not include top-level pattern, type, or data-constructor declarations.
- Types and data constructors live only in the **Buslane Metadata Registry**.
- Buslane function and value bodies live in the term declaration sequence, not in the **Buslane Metadata Registry**.
- Buslane does not store source spans or source origins; a **Buslane Origin Map** belongs to the compiler front end.
- **Buslane Verifier Diagnostics** do not carry source spans; user-facing diagnostics recover source locations through a **Buslane Origin Map** outside Buslane.
- Buslane does not store display names.
- A **Pure Buslane Pretty Printer** does not accept a name map.
- Buslane v1 pretty output is not a **Buslane Serialization Format**.
- **Buslane Core Language** preserves expression-tree structure and does not introduce ANF temporaries.
- **First-Class Calls** keep both the callee and arguments as Buslane expressions.
- **First-Class Calls** do not store result types; the **Buslane Verifier** synthesizes them from callee function types.
- **Dedicated Construction Forms** keep constructor payloads as Buslane expressions.
- **Dedicated Construction Forms** do not store result types; the **Buslane Verifier** synthesizes them from data-constructor metadata.
- **Buslane Parameter Lists** preserve Lane's uncurried function semantics.
- A Buslane function stores parameters and a **Buslane Function Result Type**, not a duplicated full function type.
- A **Buslane Function Body** is an arbitrary **Buslane Expression Tree**, not an ANF-specific body form.
- **Buslane Type Lambdas** and **Buslane Type Applications** preserve forall introduction and elimination before runtime erasure.
- A **Buslane Type Lambda** stores **Buslane Type Parameter Identities** and body, not a duplicated forall result type.
- Buslane forall types use the same **Buslane Type Parameter Identities** as **Buslane Type Lambdas**.
- A **Buslane Type Application** does not store a result type; the **Buslane Verifier** synthesizes it by forall instantiation.
- Buslane v1 has no **Buslane Coercion Node**.
- Buslane v1 has no **Buslane Tick Node**.
- **Buslane Existential Witnesses** express existential packaging and opening through nominal declarations.
- Buslane has no source block node; local sequencing is represented with nested `let`.
- Buslane `let` binds only **Buslane Value Bindings**.
- Buslane `let` does not store a result type; its type is the body type.
- Buslane `let` may bind an already-polymorphic value; Buslane does not perform implicit let-generalization.
- A recursive function group lowers to **Buslane LetRec**, not to an implicit top-level function marker.
- **Buslane LetRec** does not store a result type; its type is the body type.
- **Buslane LetRec** does not permit general recursive values.
- Buslane does not require every function to use **Buslane LetRec**; Lane lowering uses **Minimal Recursive Group Lowering**.
- Buslane well-formedness does not require checking that let-rec groups are minimal SCCs.
- **Buslane Expression Tree** has no separate value AST; ANF lowering decides which expressions become atoms.
- Buslane has no unsafe-builtin expression; source builtins lower to **Buslane External Values**.
- Buslane external value metadata does not store runtime names; a **Buslane External Map** belongs to the compiler, linker, or runtime.
- The **Compiler Facade** may return a **Buslane External Map** alongside a **Buslane Program**.
- Buslane v1 has no module namespace; a future **Buslane Unit** may wrap a program with linking metadata.
- A **Canonical Core Artifact** is the semantic source of truth for `.lmo` and
  linked `.lbp` artifacts.
- ANF is a derived representation below Buslane and must not become the
  artifact boundary.
- **Execution Image Lowering** happens after linking and any whole-program
  optimization over canonical core.
- A **Bytecode Image** may become the primary runtime payload for `runobj`, but
  it is still lowered code rather than the compiler interface contract.
- A **Per-Module Bytecode Cache** is an invalidatable build cache, not a
  substitute for linkable Buslane/core.
- Buslane has no `if` node; source conditionals lower to **Synthetic Bool Matches**.
- Buslane uses **One-Level Buslane Matches**; nested source patterns are compiled into nested one-level matches before entering Buslane.
- Every **One-Level Buslane Match** must be an **Exhaustive Buslane Match**.
- Each **One-Level Buslane Match** has a **Buslane Match Binder** for the evaluated scrutinee.
- A Buslane match carries a **Buslane Match Result Type**, but not a separate scrutinee type field.
- A **Buslane Alternative Body** does not store its own result type; it is checked against the enclosing **Buslane Match Result Type**.
- A **Buslane Alternative Constructor** is only default, primitive literal, or data constructor.
- Data-constructor alternatives introduce **Positional DataCon Binders**.
- A default alternative is optional, appears at most once, and must be last.
- Duplicate literal or data-constructor alternatives are invalid in Buslane.
- **Buslane Primitive Literals** are separate from nominal **Data Constructors**.
- **Normalized Buslane Literals** do not retain source spelling.
- Source field access lowers to a **Selector Function** call; Buslane has no field-access expression node.
- **ANF Lowering** transforms **Buslane Core Language** into **ANF IR**.
- **ANF IR** uses **Administrative Normal Form** and **Structured ANF**, not basic blocks.
- **Buslane Core Language** and **ANF IR** represent source structs and enums as **Nominal Core Data**.
- **Nominal Core Data** is introduced through **Data Constructors**.
- A **Data Constructor** is not a first-class value; Buslane uses a **Dedicated Construction Form**.
- **Lane-To-Buslane Data Lowering** removes source-specific struct and enum distinctions before Buslane.
- A **Selector Function** is an ordinary Buslane function declaration, not a metadata-only primitive.
- Every compiler IR layer has an **IR Pretty Printer**.
- **Closure Conversion** happens after **Buslane Core Language**, usually after ANF lowering.

## Example dialogue

> **Dev:** "Can Buslane introduce temporaries for every call?"
> **Domain expert:** "No. That is **ANF Lowering**. **Buslane Core Language** keeps expression-tree structure."
