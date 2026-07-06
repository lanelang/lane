# Buslane Core Language before ANF

Lane2 separates its semantic core language from administrative normal form.
Buslane is the typed expression-tree Core Language produced after Checked Source
elaboration. ANF is a later normalized IR that introduces atom/RHS/binding
structure and explicit administrative temporaries.

Buslane is also a module boundary. It owns its own core type objects, symbol
identities, declarations, patterns, and literals. It must not
depend on compiler front-end packages such as syntax, resolution, type checking,
checked-source AST, compiler symbol tables, or compiler type objects. The
compiler front end translates its checked world into Buslane at the semantic
lowering boundary.

The root Buslane artifact is a Buslane program containing the metadata registry
and the term declaration sequence. Downstream Buslane pretty printing, ANF
lowering, and execution-oriented passes consume this root value.

Buslane identities are separated by namespace and globally unique within a
Buslane program: type constructors, type parameters, values, and data
constructors use distinct identity types. Buslane does not use source strings,
de-Bruijn-only references, or compiler-front-end symbol ids as its core identity
model.
Type parameter identities are also globally unique Buslane identities.
Source-level generic parameter shadowing is resolved before Buslane lowering.

Each Buslane program carries its own metadata registry. The registry maps
Buslane identities to declaration shape, owner information, and types. Buslane
nodes store ids and local operands rather than duplicating full symbol metadata
on every occurrence.
The registry is not required to be dead-code-free. It may contain well-formed
metadata entries that are not referenced by the term declaration sequence.
The registry also carries deterministic traversal order for serialization,
pretty printing, and tests; this order has no source or module semantics.
Value metadata records a Buslane binding category, such as function, value,
external, parameter, local, or match binder, and the value type. This category is
not a Lane source-origin or visibility flag.
Buslane uses one uniform value-reference expression for every referenced value
identity. Parameters, local bindings, top-level values, functions, match
binders, and external values are distinguished by metadata and verifier rules,
not by separate expression variants.

The Buslane program also preserves a top-level term declaration sequence.
Metadata records the recursively visible shape of types and functions, while
declaration order records function bodies, value bodies, and ordered top-level
value initialization.
Buslane does not store a separate dependency order. Dependency ordering beyond
the term declaration sequence is a responsibility of Lane lowering, later
scheduling, or execution-oriented passes.
Buslane top-level declarations are core terms for value bindings, recursive
binding groups, or external values. They do not include top-level pattern
declarations, type declarations, or data-constructor declarations. Types and
data constructors do not appear in the declaration sequence because they have no body or
initialization order; they live in the Buslane metadata registry.

Buslane does not contain source spans or source-origin annotations. The compiler
front end may produce a side table that maps Buslane identities or node ids back
to Lane source locations for diagnostics, but that table is not part of the
Buslane core language.
Buslane verifier diagnostics therefore report Buslane identities, node paths,
and structural verifier errors without embedding source spans. User-facing
source locations are recovered through an origin map outside Buslane.

Buslane also does not contain display names. The Buslane pretty printer renders
stable identity numbers directly and does not consult a name map. Source-facing
diagnostic display belongs to the Lane front end, not to Buslane.
The v1 pretty output is for debugging and tests. It is not a parseable Buslane
text format or a stable serialization ABI.

Buslane keeps Lane2's uncurried function model. Function types, function
values, and calls use n-ary parameter lists, not curried unary chains, tupled
argument values, or implicit partial application.
A Buslane function expression stores parameter value identities and an explicit
result type. Parameter types come from value metadata, so the full function type
is synthesized by the verifier rather than duplicated on the function node.
The function body is an arbitrary Buslane expression checked against the
function result type; it is not restricted to an ANF body or RHS shape.

Buslane removes source block structure. Local sequencing is represented as
nested let expressions. Buslane let expressions bind only one value identity;
pattern bindings do not enter Buslane. Ordinary local value bindings are
non-recursive. Recursive function groups are represented by explicit let-rec
groups. A let-rec group may contain multiple bindings, but each right-hand side
must be a function value or a type-lambda-wrapped function value; this does not
introduce general recursive values.
Let expressions do not store result types; a let expression has the type of its
body.
Buslane let may bind an already-polymorphic value, such as a type lambda whose
metadata type is a forall type. Buslane does not perform implicit
let-generalization from an initializer.
Let-rec expressions do not store result types; a let-rec expression has the type
of its body.
Buslane itself does not require every function to be represented with let-rec.
The Lane front end should lower non-recursive functions to ordinary let bindings
and strongly connected recursive function groups to the smallest corresponding
let-rec groups.
Buslane well-formedness does not check SCC minimality; oversized let-rec groups
are a Lane lowering quality issue rather than a Buslane language error.

Buslane has one expression category. Function values, type lambdas, literals,
references, construction, elimination forms, and control-flow forms are all
expressions. Buslane does not split expressions into value/atom and RHS
categories; that split belongs to ANF lowering.

Buslane calls are expression-tree calls: both the callee and arguments are
Buslane expressions. Callee and argument atomization belongs to ANF lowering,
not Buslane.
Call expressions do not store result types. The verifier requires the callee to
synthesize to a function type and uses that function result type as the call
type.

Buslane has no `if` expression node. Source conditionals lower to synthetic
matches over `Bool` literal patterns for `true` and `false`.

Buslane matches inspect only one level of one scrutinee, following the same
high-level discipline as GHC Core case alternatives. Nested source patterns are
compiled into nested one-level Buslane matches before entering Buslane. This
preserves a structured expression-tree core while avoiding both source-shaped
nested patterns and fully lowered decision-tree IR.

Each Buslane match has a scrutinee binder. The binder names the evaluated
scrutinee value and is available to alternatives, so pattern compilation and
later ANF lowering can refer to the scrutinee without duplicating its
expression.
Buslane matches carry an explicit result type, but not a separate scrutinee type
field. The verifier synthesizes the scrutinee type and checks it against the
match binder metadata.
Match alternatives do not store separate result types. The verifier checks each
alternative body against the enclosing match result type.
Every Buslane match must be exhaustive. A default alternative is optional,
appears at most once, and must be last when present. Duplicate literal or
data-constructor alternatives are invalid.

Buslane match alternatives branch on default, primitive literals, and data
constructors. Lane lowering maps source structs and source enum variants into
Buslane nominal types and data constructors before they enter Buslane; Buslane
does not record which source construct produced a data constructor.
Data-constructor alternatives bind payloads positionally. They do not retain
source field names or source payload labels.

Data constructors are not first-class function values in Buslane. Nominal data
creation uses a dedicated construction expression, and matches refer to data
constructors as alternative constructors. Selector functions are ordinary
Buslane values, but data constructors are not.
Construction payloads are Buslane expressions; payload atomization belongs to
ANF lowering.
Construction expressions do not store result types; the verifier synthesizes
their result types from data-constructor metadata and explicit type arguments or
witnesses.

Primitive values are not represented as nominal data constructors. Buslane has
primitive type forms and primitive literal forms for `Unit`, `Bool`, `Int`, and
`String`. Match alternatives can branch on primitive literals separately from
data constructors.
Buslane literals store normalized primitive values rather than source token
spelling.
Integer literals are stored as signed 64-bit values.
String literals are stored semantically as ASCII byte sequences. An
implementation may initially use a host string representation, but Buslane
literal construction or verification must preserve the ASCII-only invariant.

Buslane v1 supports only the `Type` kind, but type parameter metadata records a
kind so the representation remains ready for future higher kinds. Buslane does
not include type-level lambda in v1. Rank-n polymorphism is represented by
allowing forall types in ordinary type positions.
Buslane owns its type well-formedness, kind checking, type equality, and
forall alpha-equivalence logic. It does not depend on compiler-front-end type
objects or equality routines. Globally unique type parameter identities are a
representation and scoping device; forall type equality still uses
alpha-equivalence rather than raw binder identity equality.
Buslane v1 has no cast or coercion node. Type conversion is only valid when the
types are equal by Buslane type equality. Coercion machinery can be introduced
later if language features such as newtypes, type aliases, or representation
coercions require it.
Buslane v1 also has no tick, source-note, profiling, or debug annotation node.
Such metadata belongs in side tables or later instrumentation layers, not in the
Buslane core language.

Buslane preserves explicit value-level type lambdas and type applications.
These nodes express forall introduction and elimination for polymorphic values.
Runtime type erasure is a later lowering or execution concern, not part of
Buslane construction.
A Buslane type lambda stores type parameter identities and a body expression;
those identities are globally unique and their kinds come from metadata. The
verifier synthesizes the resulting forall type. Forall types use the same type
parameter identity model as type lambdas; Buslane does not introduce a separate
type-object binder identity.
Type application expressions do not store result types; the verifier
synthesizes them by instantiating the callee forall type.

Buslane has no unsafe-builtin expression. Lane builtin syntax lowers to a
Buslane external value whose implementation is supplied by a linker, runtime
plugin, or execution environment. Undefined behavior from builtin misuse is
therefore an external value contract, not a Buslane expression form.
Buslane external value metadata records only that a value is external and what
type it has; runtime names such as intrinsic strings live in compiler, linker,
or runtime side tables.

Buslane v1 has no module namespace. Identities are unique within one Buslane
program. Future module, import, export, linking, name, origin, and external maps
belong in a wrapper such as a Buslane unit, not inside the Buslane core language
itself.

The Buslane module should provide a program-level verifier for Buslane
well-formedness. The public semantic boundary is whole-program verification;
expression and type verification may exist as internal components. The verifier
checks core invariants such as id existence, type and kind
well-formedness, arity, call typing, constructor payload typing, let-rec RHS
shape, match exhaustiveness, default ordering, duplicate alternatives, and
scope. It does not check Lane source rules or lowering quality constraints such
as minimal SCC grouping, and it does not reject unused metadata entries merely
because they are unreachable from term declarations.
Buslane scope is defined over globally unique value identities. Source-level
shadowing has already been resolved before Buslane lowering, so the verifier
checks identity availability rather than source-name shadowing.
Buslane is typed, but expression occurrences do not all carry duplicated type
annotations. Value binders carry types through the Buslane metadata registry,
and the verifier synthesizes or checks expression types from metadata and local
typing rules. Boundary nodes such as functions and matches may carry the
expected result types needed to make checking local.

Buslane has no field-access expression node. Source field access lowers to a
call of a selector function before entering Buslane. Selector functions are
ordinary Buslane function declarations. Source visibility and source field
names are Lane-front-end concepts, not Buslane concepts.

Selector functions appear as top-level Buslane function declarations. Downstream
Buslane consumers execute or lower them like any other Buslane function.

Existential information in Buslane is nominal. Hidden type members are recorded
in nominal data declaration metadata. Construction nodes carry type witnesses
when they pack a value, and match alternatives introduce fresh abstract type
binders when they open a hidden member. Buslane does not add a standalone
structural `Exists` type constructor.

The previous design used structured ANF as the first typed core representation.
That conflated two different responsibilities: preserving the language's
semantic constructs and making evaluation order mechanically explicit for later
execution. Buslane now owns the semantic core boundary; ANF owns the
normalization boundary after Buslane.

The current reference execution path evaluates Buslane programs directly while
ANF remains a later normalization and execution-layout boundary. The intended
semantic pipeline is:

```text
Source -> Resolved -> Desugared -> Checked Source -> Buslane -> ANF/Execution Image
```

ADR-0004 is superseded by this decision. Other older ADRs that mention "typed
core" should be read as applying to Buslane when they describe semantic
constructs, and to ANF only when they describe administrative atom/RHS/binding
shape.
