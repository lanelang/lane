# Lane typechecking judgments

This context records the source-level judgments implemented by
`modules/lanec/typecheck`. It is a guide for reading and changing the checker;
it is not a separate specification from the implementation.

## Judgment notation

```text
Gamma |- e => T ! E
```

Expression `e` synthesizes type `T` and latent effect set `E` from the local
scope `Gamma`.

```text
Gamma |- e <= Expected ~~> checked_e ! E
```

Expression `e` checks against an adjacent expected type and produces checked
source expression `checked_e` plus latent effect set `E`.

```text
Gamma |- type : K
```

Type expression synthesis computes a kind. Lane has `Type`, `Effect`, and
function kinds for higher-kinded type parameters.

```text
Gamma |- effect => Eff
```

Effect expression checking produces a normalized effect term. Effect aliases are
transparent and must be fully expanded before comparison.

`Gamma` is a resolved symbol environment, not a textual name environment. It
contains value bindings, function bindings with parameter metadata, contextual
offers, and type-parameter kind bindings.

## Local inference boundary

Lane uses bidirectional local type inference. Expected type information flows
only to adjacent syntax positions: block results, `if` branches, call
arguments, function literals, operation payloads, and explicit pattern
checking. The checker must not create global Hindley-Milner unification
variables or delayed constraints.

Generic argument inference is also local. A generic call may infer type and
effect arguments from immediately adjacent argument expressions and from the
expected result type. Every inferred binding must be decided immediately:

```text
Gamma |- arg_i => Actual_i
collect(P_i, Actual_i) = Sub_i
collect(R, Expected) = Sub_R
all generic parameters are bound consistently
-------------------------------------------------
Gamma |- f(arg_1, ..., arg_n) => R[Sub]
```

If a generic parameter cannot be inferred from those local facts, the checker
reports a missing generic argument rather than keeping an unsolved variable.

## Expression checking

The expression dispatcher implements these two entry points:

```text
Gamma |- e <= Expected
Gamma |- e => T
```

Checking mode may delegate to synthesis and then require equality:

```text
Gamma |- e => Actual
Actual = Expected
-------------------
Gamma |- e <= Expected
```

Calls push parameter types down into arguments:

```text
Gamma |- callee => (P_1, ..., P_n) -> R ! F
Gamma |- arg_i <= P_i ~~> checked_arg_i ! E_i
------------------------------------------------
Gamma |- callee(arg_1, ..., arg_n) => R ! {F, E_i...}
```

Function literals check directly against adjacent function types:

```text
Gamma, x_i : P_i |- body <= R ~~> checked_body ! BodyEff
BodyEff <= ExpectedEff
--------------------------------------------------------
Gamma |- fn(x_1, ..., x_n) { body } <= (P_1, ..., P_n) -> R ! ExpectedEff
```

If a function literal has no expected function type, every parameter must carry
an annotation so synthesis can compute a function type locally.

## Effect expressions

Effect sets are normalized before equality. Singleton order does not matter and
duplicates collapse:

```text
Gamma |- Eff_i => E_i
-------------------------------
Gamma |- { Eff_1, ..., Eff_n } => normalize(E_1 union ... union E_n)
```

Effect aliases are transparent:

```text
type A[P...] : Effect = Body
Gamma |- args_i : kind(P_i)
Gamma |- Body[args/P] => E
---------------------------
Gamma |- A[args] => normalize(E)
```

Effect parameters have kind `Effect`. A type-kind parameter used in an effect
position is a kind mismatch.

## Generic effect-row matching

For generic inference over effects, a template effect set is split into concrete
singleton terms plus at most one tracked effect-row parameter:

```text
Template = { C_1, ..., C_n, E? }
Actual = { A_1, ..., A_m }
```

Each concrete template term must match one unique actual term. The residual
actual terms bind the row parameter when present:

```text
match(C_i, A_j) is unique for every C_i
Residual = Actual - matched(A_j)
--------------------------------------
collect(Template, Actual) binds E := Residual
```

Ambiguous matching is an inference failure, not a delayed constraint. This keeps
local inference terminating and prevents accidental effect subtyping.

## Effect operation calls

Operation calls have two independent generic layers:

- owner effect arguments, such as the `A` in `Effect[A]`;
- operation-level hidden witnesses, such as the `X` in `op[X](...)`.

At a perform site, owner arguments are known from the chosen singleton effect.
Operation-level witnesses are explicit or inferred locally from payload
arguments and expected result type:

```text
operation op[X...] : (P_1, ..., P_n) -> R in Owner[O...]
Sub_owner = [O/owner_params]
Sub_hidden inferred from P_i[Sub_owner] and R[Sub_owner]
Gamma |- arg_i <= P_i[Sub_owner][Sub_hidden]
-------------------------------------------------------
Gamma |- Owner[O...]::op[Sub_hidden](arg_i...) => R[Sub_owner][Sub_hidden]
```

The latent effect of a perform expression includes the owning singleton effect
plus any effects produced while evaluating payload expressions.

## Handler checking

Handlers first synthesize the handled body:

```text
Gamma |- body => BodyT ! BodyEff
```

Each `with` block handles exactly one singleton effect. Removing the handled
effects from `BodyEff` gives the initial residual effect. The final branch binds
the body value and synthesizes the handler result type:

```text
Gamma, value : BodyT |- final_body => ResultT ! FinalEff
ResidualSeed = (BodyEff - handled_effects) union FinalEff
```

Handler operation arms need the final result type and residual effect to type
their resume continuation:

```text
resume : (OperationResult) -> ResultT ! Residual
Gamma, opened_type_binders, payload_binders, resume |- arm_body <= ResultT
```

Because arm bodies may themselves produce effects, the checker first runs a
silent pass with `ResidualSeed`, then computes the final residual effect and
checks arms again with the final resume type. This is still a bounded local
process, not general constraint solving.

## Patterns

Pattern checking is expected-type driven:

```text
Gamma |- scrutinee => S
Gamma, binders(pattern_i : S) |- arm_i <= Expected
useful(pattern_i, previous_patterns)
exhaustive(S, patterns)
-------------------------------------------------
Gamma |- match scrutinee { pattern_i => arm_i } <= Expected
```

Variant and struct patterns are nominal. Their payload and field pattern types
come from the expected nominal type after substituting its generic arguments.

Pattern `let` accepts only irrefutable patterns. Refutability is checked
semantically after the initializer type is known.

## Checked source construction

The checked-source pass mirrors the same judgments but returns checked AST nodes
and latent effects. If an earlier error prevents constructing a checked node,
the checker keeps reporting diagnostics and marks the synthesis result as
missing rather than fabricating a valid checked expression.
