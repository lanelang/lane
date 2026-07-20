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

The checker also maintains a checked declaration environment `Delta`. `Delta`
contains nominal type metadata, field and variant declarations, effect
operations, imported module interfaces, and transparent type aliases. Expression
judgments read from `Delta`; declaration checking builds it before source value
bodies are checked.

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

Function literals are excluded from the `arg_i => Actual_i` premises above.
They do not contribute parameter or result type evidence to generic argument
inference. After all ordinary argument and expected-result constraints have
been collected, a monomorphic function literal may contribute only its latent
effect when its expected parameter and result types are already ground for this
call:

```text
Sub_0 = collect(non-literal arguments, Expected)
P'_1, ..., P'_n = (P_1, ..., P_n)[Sub_0]
R' = R[Sub_0]
ground_call(P'_1, ..., P'_n, R')
Gamma |- lambda <=shape (P'_1, ..., P'_n) -> R' ~~> BodyEff
collect(F[Sub_0], BodyEff) = Sub_E
------------------------------------------------------------
lambda contributes only Sub_E to this generic application
```

`ground_call` requires the callback parameter and result types to contain
neither errors nor parameters quantified by the current generic application;
rigid parameters from an enclosing scope remain admissible. The `<=shape`
judgment checks the literal against those already-ground parameter and result
types and measures its latent effect without supplying an expected effect.

If the callback shape is not ground, or if the literal has its own type
parameters, the literal contributes no inference evidence. In particular, this
rule does not infer callback parameter or result types from annotations or the
body, decompose `Forall` arguments, backtrack effect rows, or enable polymorphic
recursion.

If a generic parameter cannot be inferred from those local facts, the checker
reports a missing generic argument rather than keeping an unsolved variable.

Higher-kinded generic parameters use the same local inference boundary. The
checker may decompose matching type-application spines and bind an unsolved
callee parameter to the actual callee when the kinds match:

```text
F : [K] -> Type
Gamma |- ActualF : [K] -> Type
collect(A, B) = Sub
--------------------------------
collect(F[A], ActualF[B]) binds F := ActualF and merges Sub
```

This is structural matching, not higher-order unification. The checker never
synthesizes a new type lambda such as `[X] => Pair[X, Bool]` to satisfy
`F[Int] ~ Pair[Int, Bool]`; users must pass that type-level lambda explicitly
when they need partial application. Every inferred higher-kinded binding is
kind-checked immediately and rejected if it would recursively mention the
parameter being solved.

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

## Declaration and type-level checking

Declaration checking builds `Delta` from imported interfaces plus local nominal
and effect declarations. It validates type-level syntax before value bodies use
the declarations:

```text
Gamma_type |- P_i : K_i
Gamma_type, P_i : K_i |- member_j : Type
------------------------------------------------
Delta |- struct S[P_i...] { member_j... } ok
```

Enum payloads, struct fields, operation payloads, operation results, value
annotations, and contextual offer annotations all require value-level types:

```text
Gamma_type |- T : K
K = Type
---------------------------
Gamma_type |- T value-type
```

General type application is kind-directed. The callee can be any type-level
expression with function kind, including a nominal constructor, type parameter,
alias expansion, or type-level lambda:

```text
Gamma_type |- F : [K_1, ..., K_n] -> K
Gamma_type |- A_i : K_i
---------------------------------------
Gamma_type |- F[A_1, ..., A_n] : K
```

Type aliases are transparent. Expanding an alias is part of type synthesis, and
recursive alias expansion is rejected immediately instead of being delayed.
Alias bodies may have kind `Type`, `Effect`, or a higher kind; positions that
need a runtime value type still require the synthesized kind to be exactly
`Type`.

Forall function types bind kinded type parameters and then check parameter and
result types at kind `Type` plus the latent effect at kind `Effect`:

```text
Gamma_type, A_i : K_i |- P_j : Type
Gamma_type, A_i : K_i |- R : Type
Gamma_type, A_i : K_i |- E : Effect
------------------------------------------------
Gamma_type |- [A_i : K_i] (P_j...) -> R ! E : Type
```

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

## Contextual argument resolution

Contextual argument insertion is a type-directed rewrite that happens only for
direct calls to known function symbols. Auto parameters must form a trailing
suffix. Explicit direct arguments determine the non-auto prefix, explicit named
contextual arguments fill named auto parameters, and every remaining auto
parameter is supplied from visible offers:

```text
Gamma |- f : (P_1, ..., P_m, C_1, ..., C_n) -> R
auto suffix = C_1, ..., C_n
Gamma.offers contains exactly one offer o_i with type C_i
---------------------------------------------------------
Gamma |- f(args...) rewrites to f(args..., o_i...)
```

If there is no matching offer, the checker reports a missing contextual offer.
If more than one offer has the required type, it reports ambiguity. Contextual
resolution never searches for offers to infer generic arguments. For generic
direct calls, generic arguments are inferred first from supplied direct
arguments and the adjacent expected result type; only then are omitted
contextual arguments matched by type equality.

Offer fields are already resolved before typechecking reaches this rewrite.
The typechecker consumes a flat offer environment; it must not re-open values or
perform field search during contextual insertion.

## Generic effect-row matching

For generic inference over effects, a template effect set is split into concrete
singleton terms plus at most one tracked effect-row parameter:

```text
Template = { C_1, ..., C_n, E? }
Actual = { A_1, ..., A_m }
```

The checker first collects ordinary type constraints from all adjacent call
arguments and the adjacent expected result, then applies that partial
substitution to the template effect. It matches each resulting effect row once;
row constraints are never retained beyond the current call or retried through
backtracking.

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

## Nominal construction and projection

Enum variant construction synthesizes the owner nominal type. Owner generic
arguments may be explicit, copied from the adjacent expected result type, or
inferred locally from payload expressions. Variant-level hidden witnesses are a
separate generic layer and are inferred only from the variant payloads:

```text
variant v[X...] : (P_1, ..., P_n) in enum E[A...]
Sub_owner inferred from payloads and Expected?
Sub_hidden inferred from P_i[Sub_owner] and payloads
Gamma |- arg_i <= P_i[Sub_owner][Sub_hidden]
----------------------------------------------------
Gamma |- E[Sub_owner]::v[Sub_hidden](arg_i...) => E[Sub_owner]
```

Struct literals synthesize a nominal type and require every declared value field
and hidden type member to be supplied exactly once. Field values are checked
after substituting both owner type arguments and existential witnesses:

```text
Gamma |- witness_j : kind(member_j)
Gamma |- field_i <= FieldType_i[owner_sub][witness_sub]
-------------------------------------------------------
Gamma |- S[owner_args]::{ type member_j = witness_j, field_i: expr_i } => S[owner_args]
```

Field access first synthesizes the base expression. The base must be a nominal
struct type, and the selected field type is read through the resolved field
symbol, not through textual field lookup:

```text
Gamma |- base => S[args]
field(S, name) = FieldSymbol : T
---------------------------------
Gamma |- base.name => T[args]
```

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
silent measurement pass with a provisional residual parameter. That parameter
does not count as concrete generic evidence and is removed from measured arm
effects. The checker then unions those effects with `ResidualSeed` and checks
the arms again with the final resume type. This is still a bounded local process,
not general constraint solving.

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

Pattern opening of existential hidden type members is scoped. A hidden type
opened by a pattern may be used while checking the arm body, but it must not
escape into the synthesized result type of the surrounding expression.

## Public interface and escape checks

Module interfaces are constructed from checked declarations, then validated as
the public boundary. Public declarations may mention public imported names and
their own public declarations, but cannot expose private local nominal types or
private local effects:

```text
Delta |- public decl : T
private_names(T) = empty
--------------------------------
Delta |- decl exportable
```

The same check is run over resolved public annotations before and over checked
types after alias expansion. The resolved pass gives diagnostics at source
spans near the public signature; the checked fallback catches private names
that appear only after expansion or synthesis.

Existential escape is separate from public/private escape. When a pattern opens
hidden members, any result type mentioning those hidden type parameters is
rejected even if all nominal owners are public:

```text
opened(pattern) = X_i
mentions(ResultT, X_i)
----------------------
hidden type escape
```

## Checked source construction

The checked-source pass mirrors the same judgments but returns checked AST nodes
and latent effects. If an earlier error prevents constructing a checked node,
the checker keeps reporting diagnostics and marks the synthesis result as
missing rather than fabricating a valid checked expression.

Silent analysis uses the same typing rules with a copied checker and an empty
diagnostic sink. It is allowed only where the checker needs a bounded local
measurement, such as computing handler residual effects. A silent pass must not
commit values, offers, inferred generic arguments, or diagnostics back into the
real checker.
