# Lane Compiler Roadmap Checklist

This checklist tracks the main compiler pipeline phases. It is intentionally
high-level; detailed module tasks should live in issues or implementation
notes.

Cross-cutting language features are tracked inside the pipeline phases they
affect. Items prefixed with `Existential:` refer to the design note in
`docs/existential-types.md`.

## 0. Source Surface And Specification

- [x] Workspace layout for `spec`, `lanec`, `lane tools`, and `basic`.
- [x] Lexer and parser.
- [x] Syntax AST and syntax pretty printer.
- [x] Parser tests based on pretty-printed output.
- [x] Existential: promote the design into the language specification,
  including formation, introduction, elimination, scope, and escape rules.
- [x] Existential: extend syntax, parser, and pretty printers for enum variant
  type binders such as `hide[T](T)`.
- [x] Existential: extend syntax, parser, and pretty printers for struct type
  members such as `type T : Type`, struct literal type witnesses such as
  `T = Int`, and struct patterns such as `Hide::{ T, val }`.
- [x] Existential: decide and implement the wildcard spelling for ignored
  hidden type binders in struct patterns.
- [ ] F-Omega: promote higher-kinded types, type-level lambdas, top-level type
  aliases, and definitional type equality into the language specification.
- [ ] F-Omega: extend syntax, parser, and pretty printers for kind parameter
  lists, kind-annotated type binders, type-level lambdas, and top-level type
  alias parameter headers.

## 1. Compiler Identity And Types

- [x] Introduce stable compiler identities for types, values, fields, variants,
  and type parameters.
- [x] Introduce checked type objects shared by semantic analysis, Buslane Core
  Language, builtin dispatch, and the interpreter.
- [x] Support primitive type constants, nominal type applications, function
  types, forall types, kind metadata, substitution, and alpha-equivalence.
- [x] Provide pretty printers and tests for symbols and checked types.
- [x] Keep compiler identity and substitution internals behind public APIs
  instead of exposing raw indices or backing arrays.
- [x] Existential: extend type objects and kind checking so existential
  packages can carry explicit hidden type members while preserving nominal
  struct and enum identity.
- [ ] F-Omega: replace nominal type applications with separate nominal
  constructor objects and uniform type application.
- [ ] F-Omega: implement structural kind checking for parameter-list kinds,
  higher-kinded type parameters, arbitrary-kind aliases, and higher-kinded
  existential witnesses.
- [ ] F-Omega: implement alias expansion, capture-avoiding beta normalization,
  definitional equality, occurs checks, and internal-bug reporting for
  exhausted normalization fuel.

## 2. Name Resolution

- [x] Collect top-level declarations, nominal members, parameters, and type
  parameters into separated symbol identities while preserving display names
  and origin spans.
- [x] Provide an initial resolved IR pretty printer and tests based on resolved
  declaration output.
- [x] Resolve source type references, value references, qualified variants,
  patterns, function bodies, and expression-local binders into resolved IR.
- [x] Resolve unqualified variant calls when exactly one visible variant
  matches.
- [x] Remove `open` and `let open` from syntax, resolution, desugaring,
  typechecking, and tests.
- [x] Resolve offered value definitions into a contextual offer environment.
- [x] Resolve field access into field symbol identities after enough type
  information is available.
- [x] Resolve contextual forwarding fields declared with `offer field : Type`
  after checked field types are available.
- [ ] Resolve operator aliases through ordinary operation names while
  preserving call origin metadata for diagnostics.
- [x] Report diagnostics for unresolved types, unresolved values, unresolved
  qualified variants, and ambiguous unqualified variants.
- [ ] Report diagnostics and warnings for invalid offers, duplicate offers,
  missing contextual offers, ambiguous contextual offers, and invalid explicit
  contextual arguments.
- [x] Extend resolved IR pretty tests to cover expression and pattern
  resolution once those nodes carry symbols.
- [x] Existential: add symbol and resolved IR support for existential type
  binders, struct type members, type witness fields, and pattern-opened hidden
  type binders.

## 3. Type Checking

Local type inference is implemented as two source-level judgments: synthesis
computes a type from an expression, and checking verifies an expression against
an expected type. It must not introduce Hindley-Milner-style global unification
state. Contextual Resolution supplies omitted contextual arguments only after
ordinary local typing has determined their target types.

- [x] Move the type-checking engine into the dedicated `lanec/typecheck`
  package, with no compatibility wrapper under `lanec/check`.
- [x] Build the checked declaration environment for custom types, including
  struct field types and enum variant payload types.
- [x] Introduce the first source-level type checker slice for annotated
  values, direct calls, blocks, struct literals, and field access.
- [x] Replace open candidate selection with Contextual Resolution for omitted
  `auto` parameters.
- [x] Propagate expected types through function bodies, block results, `if`
  branches, and known call parameters to drive local checking.
- [x] Check desugared operator alias calls as ordinary calls to resolved `op_*`
  named functions.
- [x] Reframe the checker around explicit synthesis (`synthesize(expr) -> T`)
  and checking (`check(expr, expected)`) judgments.
- [x] Document the main typechecking judgments, including expression,
  generic-argument, effect-row, operation-call, handler, and pattern rules.
- [x] Implement non-generic bidirectional local checking for function literals,
  calls, blocks, `if` branches, struct literals, field access, and non-thunked
  operator aliases.
- [x] Check direct named calls with trailing `auto` parameters, explicit
  contextual arguments, and contextually resolved omitted arguments.
- [x] Implement local type argument synthesis for generic applications,
  including constraints from argument types and expected result types in
  checking mode.
- [ ] Support higher-kinded generic instantiation by structural matching
  without higher-order unification.
- [x] Ensure checked source contains no omitted contextual arguments and no
  contextual offer ambiguity states.
- [x] Check top-level recursive groups, ordered top-level values, local
  sequential bindings, and local generic functions.
- [x] Check forall introduction/elimination, generic candidate instantiation,
  primitive operations, nominal construction, and field access.
- [x] Check enum variant construction and unqualified variant calls after type
  information is available.
- [x] Existential: type check enum construction by choosing witness types and
  checking payloads under the instantiated variant payload type.
- [x] Existential: type check struct construction by checking type-member
  witnesses and value fields against the declared member types.
- [x] Existential: reject hidden type escape from opened scopes unless the
  value is repacked into another existential before leaving the scope.
- Pattern analysis:
  - [x] Use a pattern matrix model for exhaustiveness and usefulness checking.
  - [x] Check primitive literal patterns, enum patterns, struct patterns,
    binder uniqueness, binder scope, and unreachable arms.
  - [x] Produce checked patterns with resolved variants, resolved struct
    fields, declaration-order struct fields, and typed binders.
  - [x] Keep checked patterns available as input to Buslane lowering.
  - [x] Defer decision tree generation to later lowered IR or VM work.
  - [x] Existential: type check enum and struct pattern elimination by
    introducing fresh abstract type binders into the arm or remaining local
    scope.
- [x] Produce stable diagnostics with origin spans.

## 4. Source Elaboration

Source elaboration consumes the type checker and produces the Checked Source
AST. It preserves source-level structure while eliminating source-only syntax
and unresolved or ambiguous states before Buslane lowering.

- [x] Create the `lanec/checked` package as the owner of the Checked Source
  AST.
- [x] Create the `lanec/desugar` package as the owner of the resolved-to-
  desugared AST pass.
- [x] Define checked expressions, checked local items, checked top-level bodies,
  checked match arms, and checked patterns with attached types and origin spans.
- [x] Provide a Checked Source pretty printer and snapshot tests for the initial
  checked expression and pattern shapes.
- [x] Implement `lanec/elaborate` as the source-to-checked pipeline over
  resolved source and type-checking judgments.
- [x] Desugar pipeline expressions into ordinary calls before type checking.
- [x] Desugar ordinary operator aliases into resolved `op_*` calls before type
  checking.
- [x] Desugar `&&` and `||` into thunked calls to `op_and` and
  `op_or`.
- [ ] Preserve call origin metadata when desugaring operators into `op_*`
  direct named calls.
- [x] Desugar struct field punning into explicit field values.
- [x] Desugar qualified and unqualified enum variant expressions into one
  variant-call expression shape.
- [x] Elaborate builtin expressions into checked builtin requests without
  interpreting intrinsic names.
- [x] Integrate checked-source lowering with the resolved-to-checked source
  elaboration pipeline.
- [ ] Produce a typed source-level result that contains no unresolved names,
  omitted contextual arguments, or source-only ambiguity states.
- [x] Existential: preserve witness and opened-type information in Checked
  Source so later Buslane lowering does not need source syntax.

## 5. Buslane Core Language

- [x] Consolidate the Buslane Core Language design in
  `docs/buslane-core.md`.
- [x] Replace the current `lanec/buslane` package with an independent Buslane
  model that owns its own identities, types, metadata, expressions, literals,
  and diagnostics.
- [x] Represent Buslane programs as a metadata registry plus a top-level term
  declaration sequence.
- [x] Remove source spans, display names, checked-source nodes, compiler symbol
  ids, compiler type objects, field nodes, `if` nodes, and unsafe-builtin nodes
  from Buslane.
- [x] Lower Checked Source into Buslane expression-tree core: nominal data
  construction, first-class calls, functions, type lambdas, type applications,
  local `let`, `let-rec`, one-level matches, external values, and existential
  witnesses.
- [x] Lower checked literals, values, functions, calls, blocks, conditionals,
  enum construction, struct construction, pattern lets, source matches,
  external values, and generic applications into Buslane expression-tree core.
- [x] Generate real Buslane selector functions for checked source field access
  instead of the temporary external-call placeholder.
- [x] Provide a program-level Buslane verifier for metadata, type
  well-formedness, scope, typing, constructor arity, match exhaustiveness, and
  let-rec RHS shape.
- [x] Provide a pure Buslane pretty printer and tests based on stable Buslane
  identity output.
- [ ] Upgrade Buslane type terms and verifier rules with F-omega constructs:
  higher kinds, type-level lambdas, and type-level application.
- [ ] Lower source aliases into alias-free Buslane type terms while preserving
  source type presentation for diagnostics outside Buslane.

## 6. ANF IR

- [x] Rename the previous structured ANF package from `core` to `anf`.
- [x] Lower checked source semantics into structured ANF with typed nodes and
  origin spans.
- [x] Preserve nominal data, first-class functions, type lambdas, type
  applications, existential packages, checked patterns, and typed unsafe
  builtins.
- [x] Provide an ANF pretty printer and tests based on ANF output.
- [x] Lower Buslane Core Language into ANF IR instead of lowering ANF directly
  from Checked Source.

## 7. Reference Interpreter

- [x] Define uniform interpreter values, global environments, call frames,
  closure environments, and runtime programs.
- [x] Evaluate whole ANF programs without hard-coding `main`.
- [x] Use the interpreter runtime model while evaluating ANF programs.
- [x] Evaluate first-class calls, type lambdas/applications with runtime type
  erasure, existential packages, nominal data, checked patterns, conditionals,
  and matches.
- [x] Existential: evaluate packages and unpacking with runtime type erasure
  while preserving the checked scope discipline.
- [x] Define the builtin runtime plugin contract and runtime error reports.
- [x] Provide a Buslane reference interpreter with erased type applications,
  nominal data, one-level matches, closures, let-rec groups, and external value
  resolution.
- [x] Treat Buslane external declarations as values resolved by a runtime
  resolver, with callable externals represented as native function runtime
  values rather than direct `invoke(id, args)` operations.
- [ ] Add ABI signatures for native function runtime values and standard
  intrinsic declarations, and check ABI compatibility against the declared
  Buslane type during external resolution or linking.
- [x] Use the Buslane interpreter as the semantic oracle for the first native
  `lane run` implementation.

## 8. Basic Library And Conformance

- [x] Encode and check the v1 Basic library modules as Lane source.
- [x] Populate contextual offers from explicitly imported Basic library
  offered value definitions.
- [x] Provide required standard intrinsic implementations through `lanec`
  intrinsic runtime plugins.
- [x] Provide a native-only `lane` command for single-file `check` and
  `run FILE:ENTRY` workflows.
- [x] Expand valid and invalid conformance fixtures under `examples`.
- [x] Existential: add valid and invalid parser, resolver, type checker,
  elaborator, Buslane Core Language, ANF, and interpreter fixture coverage for
  existential enums, structs, higher-kind-ready type members, and escape
  diagnostics.
- [ ] F-Omega: add conformance fixtures for higher-kinded polymorphism,
  type-level lambdas, type aliases, contextual offers, and existential
  witnesses.
- [ ] Run parser, type checker, elaborator, and interpreter tests over shared
  fixtures where practical.

## 9. IDE Tooling And LSP

- [x] LSP: preserve source identity in analysis inputs so compiler spans can
  become editor locations. (ISS-005)
- [x] LSP: build a semantic index for definitions, references, and hover
  payloads from resolved and checked source data. (ISS-006)
- [x] LSP: implement `textDocument/definition` through the semantic index
  rather than source-text matching. (ISS-007)
- [x] LSP: implement `textDocument/hover` using checked types, kinds, and
  declaration summaries. (ISS-008)
- [x] LSP: support partial semantic analysis so navigation and hover remain
  useful when unrelated diagnostics exist. (ISS-009)

## Later Execution Work

- [ ] Lowered IR for closure conversion, decision trees, and execution layout
  derived from Buslane/core rather than used as the artifact boundary.
- [ ] Portable bytecode VM whose bytecode image is produced after linked-core
  optimization.
- [ ] Optional per-module bytecode caches guarded by compiler version, target,
  lowering options, and core fingerprints.
- [ ] Linker entrypoint selection.
- [ ] Algebraic effects and handlers.
- [ ] Direct native, WebAssembly, or JavaScript execution targets.
- [ ] Optional monomorphization and specialized runtime layouts.
