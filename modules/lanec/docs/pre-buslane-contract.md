# Pre-Buslane Contract

This document defines the long-term boundary between Lane source elaboration and
Buslane core lowering. It is a semantic boundary, not an optimization boundary.

The pipeline is:

```text
Source -> Resolved -> Desugared -> Checked Source -> Buslane -> ANF/Execution
```

`Checked Source` is the last compiler-front-end representation that may carry
source presentation data. `Buslane` is the first source-independent semantic
core representation.

## Checked Source Success

A successful checked source result must satisfy these invariants:

- Every type, value, field, variant, effect, operation, and type parameter
  reference has a resolved compiler identity.
- All expression nodes carry their checked value type.
- All function types carry their latent effect.
- All explicit generic arguments are kind checked and represented as
  `GenericArgument` values, preserving Type-kind and Effect-kind arguments.
- Contextual `auto` parameters are either filled with ordinary checked call
  arguments or rejected before checked source success.
- Contextual offer ambiguity is rejected before checked source success.
- Transparent type and effect aliases are expanded in semantic type/effect
  objects; user-written aliases survive only as diagnostic presentation data.
- Source field punning, operator syntax, pipeline syntax, and unqualified
  variant syntax are desugared before or during checked source construction.

The checked source tree may still preserve source-level expression structure
when that structure has semantic meaning for diagnostics or lowering. Examples
include `If`, `Field`, `UnsafeBuiltin`, `Handler`, and checked source patterns.
Every such shape must have an explicit Buslane lowering rule.

## Canonical Type And Effect Terms

The type layer owns canonicalization before Buslane lowering:

- Transparent type aliases synthesize to their expanded body.
- Transparent effect aliases synthesize to normalized effect terms.
- Type-level lambda application beta-reduces during type normalization.
- Effect unions flatten, deduplicate, and preserve row variables.
- Definitional type equality compares normalized terms.

Buslane lowering consumes these semantic type and effect objects and translates
them into Buslane-owned type/effect terms. Buslane must not depend on the Lane
typechecker package or on source type syntax.

## Lowering Obligations

Buslane lowering must eliminate the following front-end-only shapes:

- `If` lowers to a match over `Bool`.
- `Field` lowers to a call of a generated selector function.
- `UnsafeBuiltin` lowers to an external Buslane value.
- Source and checked patterns lower to one-level Buslane matches.
- Handler operation payload patterns lower to positional payload binders.
- Operation calls lower to `perform`, including owner effect arguments and
  operation-level hidden witnesses.
- Generic expression applications lower to Buslane type applications with
  kind-aware generic arguments.
- Struct and enum construction lower to nominal data construction with all
  required universal arguments and existential witnesses.

The lowered Buslane program must not contain parser nodes, resolver nodes,
checked-source nodes, compiler symbol ids, source spans, source names,
field-access nodes, `if` nodes, unsafe-builtin nodes, source patterns, or source
diagnostic machinery.

## Origin And Presentation Data

Source diagnostics and LSP features may need source spans, display names, and
user-written type presentations after type checking. That data belongs outside
Buslane:

- source spans stay in checked source and analysis side data;
- display names stay in compiler symbol metadata and diagnostics;
- alias names and source type presentation stay in diagnostic display contexts;
- Buslane verifier diagnostics use Buslane identities and may be mapped back by
  an explicit origin side table when the compiler owns one.

This keeps Buslane movable as an independent module while preserving high-grade
source diagnostics in `lanec`.

## Non-Goals

This contract does not define performance optimization. Dead code elimination,
inlining, specialization, closure conversion, decision-tree optimization,
layout lowering, bytecode lowering, and target-specific execution-image work all
belong after Buslane or after linked canonical core.
