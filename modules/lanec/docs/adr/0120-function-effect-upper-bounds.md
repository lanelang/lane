# ADR 0120: Function effects are upper bounds

Lane function effects describe the effects a call is permitted to perform. A
function whose actual effect row is a subset of that bound may inhabit the
function type:

```text
ActualEffect subset ExpectedEffect
------------------------------------------------
(P...) -> R ! ActualEffect <= (P...) -> R ! ExpectedEffect
```

Parameter and result types remain invariant. This is not general function
subtyping, and effect arguments inside nominal types remain invariant.

Effect equality and effect containment are separate operations. The empty row
is accepted by every upper bound because it contains no terms; it has no
dedicated compatibility rule.

Generic effect parameters in function-effect position accumulate lower-bound
constraints. Local inference chooses their canonical union, so argument order
does not affect the inferred row. Effect parameters in invariant generic
argument positions continue to require exact row matching.

When an already-typed function value is widened, Checked AST records
`FunctionEffectWiden`. Buslane lowering evaluates the original value once and
constructs an adapter with the target function type. Selective CPS lowering
therefore chooses the target ABI for the adapter while calls inside it retain
the original function ABI. Function declarations and function literals lower
through Buslane function bindings whose metadata carries the declared or
expected type, so selective CPS receives their target latent effect directly.
Buslane permits this containment relation only while verifying the direct
`Function` or `TypeLambda` implementation of such a binding. Ordinary
references, calls, and value bindings continue to require exact types; a
widened first-class value must use the explicit adapter.
