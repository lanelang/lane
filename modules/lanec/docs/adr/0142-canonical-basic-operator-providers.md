---
status: accepted
---

# Canonical Basic operator providers

Lane operator tokens resolve to public values in `Basic.Ops`. The fixed
token-to-provider-name mapping belongs to the Canonical Basic ABI. Source
modules must make `Basic.Ops` reachable through an authored import or re-export;
operator syntax creates no hidden module dependency and exposes no `Basic.Ops`
value in lexical scope.

Consequently, `a + b` always targets the certified `Basic.Ops.op_add` identity.
A local or imported value also named `op_add` cannot capture `+`. An explicit
`op_add(a, b)` remains an ordinary lexical call and can name user code. The
shipped Basic wrappers use trailing contextual parameters for customization,
but Basic may revise that design. The compiler does not
prescribe the provider's generic parameters, ordinary parameters, contextual
parameters, effects, or result type. Ordinary call typechecking consumes the
actual declaration exported by Basic and reports any incompatibility at use
sites.

Resolution records the canonical provider and resolved value identity in the
resolved tree. Desugaring then produces an ordinary direct call while retaining
operator argument provenance; later semantic and presentation stages consume
that provenance rather than reconstructing operator syntax from spans or names.
`&&` and `||` retain their language-owned lazy-right-operand transformation.

This decision removes two former semantic producers: lexical lookup no longer
decides operator identity, and the compiler no longer owns a duplicate of the
Basic provider's type. It supersedes the operator-target portions of ADR 0044
and ADR 0052; their typed-call and contextual-resolution decisions remain in
force.
