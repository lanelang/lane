# Preserve nominal tuple semantics and optimize after linking

The grammar recognizes tuple syntax independently of imports. A uniform
pre-resolution surface pass rewrites tuple types, expressions, and patterns
into ordinary qualified nominal syntax. The same pass now owns list literal
expansion, so resolver and typechecker contain no List- or Tuple-specific
lookup path.

Expansion targets the fixed language ABI `Basic.Data.Tuple.Tuple`,
`Basic.Data.Tuple.Tuple::tuple`, `Basic.Data.List.List`,
`Basic.Data.List.List::empty`, and `Basic.Data.List.List::cons`. Providers are
not configurable, and the compiler does not search for declarations with a
compatible shape. The sugar adds no hidden dependency: missing imports,
declarations, or compatible signatures use ordinary resolution and
typechecking diagnostics. Qualified, open, and selective imports all establish
the ordinary module binding needed by the generated qualified references.

Checked source and Buslane retain the right-nested nominal representation.
Linked whole-program optimization may scalarize tuple chains or avoid
intermediate allocations, but Lane promises no flat tuple ABI and must
materialize nested nominal values when they escape.

## Consequences

- `(A, B, C)` expands as
  `Basic.Data.Tuple.Tuple[A, Basic.Data.Tuple.Tuple[B, C]]`; expressions and
  patterns follow the same right-nested structure.
- Tuple elements are accessed through tuple patterns and ordinary Basic
  functions. Lane does not introduce numeric projections.
- Tuple patterns are valid in every existing Pattern position. Function
  parameters remain named declarations and do not gain destructuring syntax.
- `()` remains Unit, `(x)` remains grouping, tuple syntax begins at two items,
  and trailing commas are invalid.
- `(A, B) -> C` has two parameters, while `((A, B)) -> C` has one tuple
  parameter. Bare `A -> B` is invalid; every function type has a parenthesized
  parameter list.
- `f(a, b)` passes two arguments, while `f((a, b))` passes one tuple value.
- Formatting flattens right-nested tuple-syntax chains but preserves left
  nesting whose removal would change nominal structure.
- Surface expansion visits children left to right and preserves their authored
  spans. It never reorders, duplicates, or discards child-expression
  evaluation.
- Incomplete tuple syntax exposes zero-width expected type, expression, or
  pattern slots through the tolerant parser. Completion consumes those roles
  without punctuation scans or tuple-specific inference.
- Value hover, completion, and exported value signature display consume the
  surface-presentation sidecar. The sidecar has a separate presentation
  fingerprint, preserves the difference between authored tuple syntax and
  explicit nominal syntax, and does not affect semantic equality.
- Internal IR printers and the semantic portion of artifact encoding expose
  the true nominal expansion.
