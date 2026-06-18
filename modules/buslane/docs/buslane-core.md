# Buslane Core Language

This document consolidates the current Buslane design into an implementation
oriented shape. ADR-0053 records the architectural decision; this document
records the data model and verifier contract that should guide the Buslane
package implementation.

Buslane is a typed expression-tree core language. It is produced after Checked
Source and before ANF. Buslane preserves semantic constructs such as functions,
type lambdas, nominal data construction, and one-level matches. It does not
introduce ANF atoms, RHS categories, administrative temporaries, source spans,
source names, or source-origin annotations.

## Pipeline Position

```text
Source -> Resolved -> Desugared -> Checked Source -> Buslane -> ANF -> Interpreter/VM
```

Buslane is the semantic core boundary. ANF is the later normalization boundary.
The Buslane package should be independent enough to move into a separate module
later.

Buslane must not depend on parser, resolver, typechecker, checked-source AST,
compiler symbol tables, compiler type objects, or source diagnostic machinery.
The Lane front end translates its checked world into Buslane at the semantic
lowering boundary.

## Program Root

The root artifact is a complete program:

```text
Program {
  metadata : MetadataRegistry
  terms : Array[TopTerm]
}
```

The metadata registry stores semantic information for Buslane identities. The
term sequence stores top-level value bodies and preserves top-level value
initialization order.

Buslane does not store a separate dependency order. Recursive visibility is
represented by metadata and explicit `TopTerm::LetRec` groups. Any dependency
ordering beyond the term sequence belongs to Lane lowering, later scheduling, or
execution-oriented passes.

The metadata registry is not required to be dead-code-free. It may contain
well-formed entries that are not referenced by the term sequence.

## Identities

Buslane uses globally unique identities separated by namespace:

```text
TypeId
TypeParameterId
ValueId
DataConId
```

There is no `FieldId` or source variant id in Buslane. Source structs and enum
variants lower to nominal data constructors. Source fields lower to ordinary
selector functions before Buslane.

`TypeParameterId` is also globally unique. Source-level generic parameter
shadowing is resolved before Buslane. Forall equality still uses
alpha-equivalence; globally unique identities are a representation and scoping
device, not raw binder identity equality.

## Metadata

The metadata registry owns the semantic information for identities. A concrete
implementation may split the registry into maps, arrays, and deterministic order
tables, but the conceptual content is:

```text
MetadataRegistry {
  types : TypeMetadata
  type_parameters : TypeParameterMetadata
  values : ValueMetadata
  data_constructors : DataConMetadata
  order : MetadataOrder
}
```

Value metadata records kind and type:

```text
ValueInfo {
  kind : ValueKind
  type : Type
}

ValueKind =
  Function
  Value
  External
  Parameter
  Local
  MatchBinder
```

`ValueKind` is a Buslane binding category. It is not source syntax, visibility,
or source/generated status.

Type parameter metadata records kind:

```text
TypeParameterInfo {
  kind : Kind
}
```

Buslane supports value types and n-ary type-level functions:

```text
Kind =
  Type
  Function(Array[Kind], Kind)
```

Nominal type and data-constructor metadata describe the complete nominal data
shape:

```text
TypeInfo {
  parameters : Array[TypeParameterId]
  constructors : Array[DataConId]
}

DataConInfo {
  owner : TypeId
  hidden_type_parameters : Array[TypeParameterId]
  payload_types : Array[Type]
}
```

`hidden_type_parameters` model existential members introduced by the data
constructor. Universal type parameters belong to the owner type. The
implementation may store derived arity or layout data, but source struct/enum
distinctions and source field names do not belong to Buslane metadata.

## Types

Buslane owns its type objects and type logic:

```text
Type =
  Primitive(PrimitiveType)
  Parameter(TypeParameterId)
  Constructor(TypeId)
  Apply(Type, Array[Type])
  TypeLambda(Array[TypeParameterId], Type)
  Function(Array[Type], Type)
  Forall(Array[TypeParameterId], Type)

PrimitiveType =
  Unit
  Bool
  Int
  String
```

Function types use n-ary parameter lists. Buslane does not curry function types,
does not tuple arguments implicitly, and does not support implicit partial
application.

Nominal constructors are type-level values. A nullary nominal type is a
`Constructor`; generic nominal instances use uniform `Apply(Constructor(id),
arguments)`. Buslane stores alias-free type terms; transparent source aliases
are expanded before lowering.

Buslane has no standalone `Exists` type constructor. Existential information is
nominal: hidden type members live in data-constructor metadata, construction
supplies witnesses, and match alternatives bind fresh abstract type parameters
when opening hidden members.

Buslane v1 has no core coercion node. Type conversion requires ordinary Buslane
type equality.

## Literals

Primitive values are not nominal data constructors:

```text
Literal =
  Unit
  Bool(Bool)
  Int(Int64)
  String(AsciiBytes)
```

Literals store normalized primitive values rather than source spelling. Strings
are semantically ASCII byte sequences. An implementation may initially use a
host string representation if construction or verification preserves the ASCII
invariant.

## Top-Level Terms

Top-level terms contain value bodies only:

```text
TopTerm =
  Let(ValueId, Expr)
  LetRec(Array[RecursiveBinding])
  External(ValueId)

RecursiveBinding {
  id : ValueId
  rhs : Expr
}
```

Type declarations and data constructors live in metadata, not in the term
sequence. Top-level pattern declarations do not enter Buslane.

`TopTerm::Let` represents top-level values and non-recursive functions.
`TopTerm::LetRec` represents recursive function groups. The Lane front end
should lower strongly connected recursive functions to the smallest
corresponding let-rec groups, but Buslane well-formedness does not reject an
oversized let-rec group merely because it is not a minimal SCC.

`TopTerm::External` declares a value supplied outside the Buslane program.
Runtime intrinsic names or plugin handles live in an external side table, not in
Buslane metadata or expressions.

## Expressions

Buslane has one expression category:

```text
Expr =
  Ref(ValueId)
  Literal(Literal)
  Function(FunctionExpr)
  Call(Expr, Array[Expr])
  TypeLambda(Array[TypeParameterId], Expr)
  TypeApply(Expr, Array[Type])
  Construct(ConstructExpr)
  Let(ValueId, Expr, Expr)
  LetRec(Array[RecursiveBinding], Expr)
  Match(MatchExpr)
```

`Ref(ValueId)` is uniform. Buslane does not split references into local, global,
parameter, function, external, or match-binder reference variants. The referenced
value's role is read from metadata and checked by verifier scope rules.

Function expressions store parameter identities, an explicit result type, and an
arbitrary Buslane expression body:

```text
FunctionExpr {
  parameters : Array[ValueId]
  result_type : Type
  body : Expr
}
```

Parameter types come from value metadata. The function expression does not store
a duplicated full function type.

Calls are expression-tree calls. The callee and arguments are arbitrary
expressions. Callee and argument atomization belongs to ANF lowering:

```text
Call(callee, arguments)
```

Call expressions do not store result types. The verifier synthesizes the result
from the callee function type.

Type lambdas and type applications preserve forall introduction and
elimination:

```text
TypeLambda(type_parameters, body)
TypeApply(callee, type_arguments)
```

`TypeLambda` and `Forall` use the same `TypeParameterId` model. `TypeLambda`
does not store a duplicated forall result type. `TypeApply` does not store a
result type; the verifier synthesizes it by instantiating the callee forall
type.

Nominal data construction is dedicated syntax, not a data-constructor function
call:

```text
ConstructExpr {
  constructor : DataConId
  type_arguments : Array[Type]
  hidden_witnesses : Array[Type]
  payloads : Array[Expr]
}
```

`type_arguments` instantiate the owner nominal type. `hidden_witnesses` supply
existential members introduced by the constructor. An implementation may store a
single type-argument array if metadata separates universal arguments from hidden
witnesses, but the verifier contract must keep both roles distinct.

`Construct` does not store a result type. The verifier synthesizes it from the
constructor owner and explicit type arguments.

Local sequencing is represented with nested let expressions:

```text
Let(id, initializer, body)
LetRec(bindings, body)
```

`Let` binds one value identity. It may bind an already-polymorphic value such as
a `TypeLambda`, but Buslane does not perform implicit let-generalization.

`LetRec` binds recursive function groups. Each right-hand side must be a
function value or a type-lambda-wrapped function value. Buslane does not support
general recursive values.

`Let` and `LetRec` do not store result types; their type is the body type.

Buslane has no `if` expression node. Source conditionals lower to matches over
`Bool` literals.

Buslane has no field-access expression node. Source field access lowers to a
call of an ordinary selector function before entering Buslane.

Buslane has no unsafe-builtin expression. Source `builtin` syntax lowers to a
Buslane external value.

Buslane has no cast, coercion, tick, source-note, profiling, or debug annotation
expression node in v1.

## Matches

Buslane matches inspect one scrutinee at one level:

```text
MatchExpr {
  scrutinee : Expr
  binder : ValueId
  result_type : Type
  alternatives : Array[Alternative]
}

Alternative {
  constructor : AltCon
  type_binders : Array[TypeParameterId]
  value_binders : Array[ValueId]
  body : Expr
}

AltCon =
  Default
  Literal(Literal)
  DataCon(DataConId)
```

The match binder names the evaluated scrutinee and is visible in alternatives.
The binder type comes from value metadata. A match stores a result type, but not
a separate scrutinee type. Alternative bodies do not store separate result
types; each body is checked against the enclosing match result type.

Data-constructor alternatives bind payloads positionally. They do not retain
source field names or source payload labels. Hidden type members are opened by
`type_binders` according to data-constructor metadata order.

Every Buslane match must be exhaustive. A default alternative is optional,
appears at most once, and must be last when present. Duplicate literal or
data-constructor alternatives are invalid.

Nested source patterns are compiled into nested one-level Buslane matches before
entering Buslane. Full decision-tree IR belongs to a later execution-oriented
lowering, not to Buslane.

## Verifier Contract

The public verifier entry is whole-program verification:

```text
verify_program(program : Program) -> Result[Unit, Array[Diagnostic]]
```

Expression and type verification may exist as internal components, but the
semantic boundary is a complete `Program`.

The verifier checks these invariants:

- every referenced identity exists in program metadata;
- metadata entries are well-formed;
- type expressions are well-formed and kind-correct;
- nominal type applications use the correct arity;
- value references are available in Buslane value scope;
- top-level term declarations agree with value metadata;
- external top-level terms refer to external values;
- function parameter ids have value metadata and are in scope for the body;
- function bodies check against their explicit result type;
- call callees synthesize n-ary function types and arguments check against the
  corresponding parameter types;
- type lambdas synthesize forall types from globally unique type parameter ids;
- type applications instantiate forall types;
- constructor payloads check against instantiated payload types;
- let initializers check against binder metadata types;
- let-rec right-hand sides are function values or type-lambda-wrapped function
  values;
- let-rec groups introduce all binders recursively within the group;
- match binders agree with synthesized scrutinee types;
- match alternatives check against the enclosing match result type;
- match alternatives are exhaustive;
- default alternatives appear at most once and last;
- duplicate literal or data-constructor alternatives are rejected;
- data-constructor alternatives provide the required hidden type binders and
  payload binders.

The verifier does not check:

- Lane source syntax rules;
- source-level shadowing;
- source declaration names;
- source spans;
- source visibility;
- whether a Buslane program is dead-code-free;
- whether let-rec groups are minimal SCCs;
- runtime availability of external implementations;
- later ANF atomization quality.

Verifier diagnostics report Buslane identities, node paths, and structural
errors. They do not contain source spans. User-facing diagnostics recover source
locations through an origin side table outside Buslane.

## Side Tables

The following are intentionally outside Buslane:

- `OriginMap`: maps Buslane identities or node ids to source locations.
- `ExternalMap`: maps external value ids to runtime-provided names or
  implementations.
- future name/debug maps for source-facing diagnostics.
- future module/import/export/linking wrappers.

The Buslane pretty printer should be pure: it renders stable identity numbers
and does not accept a source name map. V1 pretty output is for debugging and
tests, not a parseable or stable serialization format.

## Non-Goals

Buslane v1 does not include:

- source syntax nodes;
- source spans or display names;
- module namespaces;
- source struct/enum distinctions;
- field-access nodes;
- data constructors as first-class values;
- pattern let or top-level pattern declarations;
- `if` nodes;
- unsafe-builtin expressions;
- casts or coercions;
- tick/debug/profiling annotation nodes;
- every-node type annotations;
- a standalone `Exists` type constructor;
- ANF atom/RHS/body categories;
- full decision trees.
