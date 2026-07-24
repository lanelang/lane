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
the original function ABI. Function declarations and context-checked function
literals can select their declared or expected ABI directly and need no value
adapter.
