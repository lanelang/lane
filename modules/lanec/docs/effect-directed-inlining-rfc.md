# Effect-directed application reduction and inlining

Status: implemented (2026-08-12)

## Summary

Lane replaces its two substitution-only application reducers with one
effect-directed reduction module owned by `lanec/core_opt`.

The module reduces both an immediately available function value and a
cloned known callable through the same operation. For each argument, it
uses the authoritative expression-effect fact to choose between direct
substitution and an ordered local binding:

- an `Empty` argument whose type is definitionally equal to its parameter type
  may be substituted, duplicated, delayed, reordered, or removed, subject only
  to profitability;
- an argument whose parameter boundary performs type or callable adaptation is
  retained in a local binding even when evaluating the argument is `Empty`;
- an argument with any nonempty effect is evaluated exactly once through a
  `Let`, and nonempty-effect arguments retain their source relative order;
- a failed effect query is a structured Core optimization failure, not an
  assertion of purity.

No effect name is special. A user-defined empty declaration such as
`effect Diverge {}` still forms a nonempty effect row when it appears in a
function type. The compiler needs to distinguish only `Empty` from nonempty.

The refactor also removes the blanket requirement that an inlined callee have
an empty latent effect. Inlining inserts one cloned body for one original call;
the body's effects remain visible to the existing effect-aware simplifier.
Recursion remains excluded from this RFC.

## Motivation

The current Core optimizer performs real interprocedural inlining, but only
when every value argument is a `Ref` or `Literal`. This excludes ordinary Lane
program shapes such as:

```lane
consume(produce(value))
apply(Dictionary::{ operation: implementation })
convert(load(value))
```

The restriction is an implementation artifact. The current reducer represents
parameter application only as expression substitution. Substituting an
arbitrary effectful expression would be unsound because an unused parameter
could delete it and a multiply used parameter could duplicate it. Restricting
all arguments to atoms avoids that bug, but also rejects pure, total
computations that Lane explicitly permits the optimizer to move or eliminate.

Lane's effect contract already carries the required semantic fact. `Empty`
means the expression has no observable effect. If a computation may diverge or
otherwise must remain observable, the source program gives it a nonempty
effect. The effect may be compiler-owned, library-defined, or user-defined;
the optimizer does not inspect its identity or operations.

The refactor therefore needs no local copy of ANF, no `Diverge` builtin, no
termination checker, and no effect-name policy. It needs one application
reduction operation that consumes the effect fact already owned by Buslane.

## Semantic contract

### Empty computations

An expression whose inferred Buslane effect is `Empty` is observationally
pure for optimization. The optimizer may:

- evaluate it earlier or later;
- evaluate it zero, one, or multiple times;
- propagate it into branches;
- remove it when its value is unused;
- duplicate it when the complete optimized candidate remains profitable.

These permissions do not require a particular effect declaration for
termination. A source author who needs potential divergence to remain
observable places a nonempty effect in the function contract. The optimizer
uses the resulting row exactly as it uses every other nonempty row.

These permissions govern evaluation, not representation conversion. If the
argument is only consumable as the parameter type rather than definitionally
equal to it, application reduction retains the parameter binding that owns the
conversion.

The compiler does not recognize the declaration name or prove termination. It
trusts the checked effect contract. Omitting a required divergence effect gives
the optimizer the same purity permission as any other incorrect empty-effect
assertion; it does not force every optimizer to rediscover nontermination.

Allocation, closure construction, and immutable nominal construction do not
make an expression observable by themselves. Lane exposes no identity test for
these values. Runtime resource exhaustion is not a source-level observation
that constrains pure optimization.

### Nonempty computations

An expression with any nonempty effect must not be deleted or duplicated by
application reduction. When several nonempty arguments occur in one call, they
must retain their source left-to-right relative order and all must execute
before the inlined function body.

Pure arguments may move across these bindings because they have no source-level
observation. For example, reducing:

```text
f(pure_a(), io_b(), pure_c(), panic_d())
```

may produce the equivalent shape:

```text
let b = io_b() in
let d = panic_d() in
body[a := pure_a(), c := pure_c()]
```

The bindings preserve the relative order of `io_b()` and `panic_d()`. The
substituted pure computations may be reduced, delayed, duplicated, or removed
inside `body`.

### Callee effects

A known callee's latent effect is not an inlining prohibition. Replacing one
direct call with one hygienic copy of its body preserves the body's effects.
Argument reduction establishes the call-by-value obligations before the body,
and the effect-aware simplifier continues to reject deletion or duplication of
nonempty computations inside that body.

The known-callee expression remains restricted to effect-free identity forms
such as `Ref` and complete `TypeApply` chains. If callable-flow later exposes a
computed callee expression, that expression must participate in the same
ordered evaluation protocol before this interface accepts it.

## Current implementation

Core optimization currently runs:

```text
simplify
reachable-definition pruning
interprocedural partial evaluation
simplify
reachable-definition pruning
```

`application_reduction.mbt` is the single owner of parameter application
semantics. Both immediate `Function` reduction and interprocedural known-call
inlining submit their materialized parameters, ordered arguments, and body to
that operation. The reducer consumes `ExpressionFactsQuery`, substitutes
`Empty` arguments whose type is definitionally equal to the parameter type,
and materializes every nonempty or representation-adapting argument once in
source order. Parameter binding remains the owner of callable and runtime
representation adaptation; effect-directed reduction does not bypass it.

`InlineCloneContext` freshens every value and type binder in a legal Buslane
callable body. Recursive callable headers are alpha-renamed before their value
metadata is allocated, so the expression, metadata type, and runtime layout
witness scope share the same binder identities. Capture-rejecting Buslane
substitution remains separate and is used only after this clone-owned
alpha-renaming step.

`optimize_observed` exposes typed considered, accepted, rejected, argument, and
net program-change observations. The original `optimize` interface remains the
non-observing convenience entry.

## Design

### One application-reduction module

`lanec/core_opt` owns one private application-reduction module. Its
interface accepts:

- the already materialized parameter identities;
- the ordered argument expressions;
- the hygienically materialized body;
- inherited simplifier substitutions;
- the authoritative `ExpressionFactsQuery` and Core analysis.

It returns one reduced Buslane expression or a structured Core optimization
error. Callers do not classify arguments, build binding order, perform
parameter substitution, or decide whether a parameter adaptation boundary can
be removed.

The module owns these invariants:

1. parameter and argument arities are equal;
2. every `Empty` argument with a definitionally equal parameter type becomes a
   substitution candidate;
3. every nonempty or adaptation-requiring argument is bound exactly once;
4. nonempty bindings preserve their original relative order;
5. every binding encloses the function body;
6. contextual simplification runs only after this application shape exists;
7. no expression is classified from syntax as a substitute for effect facts.

The implementation constructs nonempty bindings in reverse AST-building order
so their execution order remains left to right:

```text
body
=> let last_effectful_parameter = last_effectful_argument in body
=> ...
=> let first_effectful_parameter = first_effectful_argument in ...
```

Pure parameter substitutions are installed before simplifying the resulting
body and bindings.

Parameter bindings also own type adaptation. Removing such a binding is valid
only when the synthesized argument type and parameter metadata type are
definitionally equal. Consumability alone is insufficient: a narrower callable
effect can be consumed as a wider callable effect while still requiring a
runtime adapter. The reducer therefore materializes non-equal argument types
and lets the ordinary lowering boundary produce that adapter.

### Existing fact owners

The implementation consumes existing facts rather than introducing parallel
analyses:

- `ExpressionFactsQuery` owns whether an argument effect is `Empty`;
- `InterproceduralAnalysis` owns known-callable discovery and the immutable call
  graph;
- `InlinePlan` owns deterministic SCC classification, stable call-site keys,
  legality, and profitability;
- `InlineExecutor` owns hygienic materialization of accepted plan entries;
- `InlineCloneContext` owns fresh metadata and hygienic body materialization;
- application reduction owns parameter evaluation semantics;
- `CoreSimplifier` owns local effect-aware reduction and never clones a
  top-level callable;
- `CoreCleanup` owns local propagation, dead-code elimination, and reachability
  cleanup between plans;
- occurrence analysis owns post-rewrite reachability and term retention.

Effect normalization failure must cross the existing Core optimization error
seam with its typed cause. It must not be converted to `false`, an empty row, or
a rendered string.

### Complete hygienic cloning

`InlineCloneContext` clones every legal binder introduced by
a Buslane callable body:

- function parameters;
- local `Let` and `LetRec` binders;
- match binders and value binders;
- nested `TypeLambda` binders;
- match-alternative type binders;
- handler result, payload, resume, and type binders.

Fresh type binders retain their kind and receive a local substitution used
by all nested types, effects, generic arguments, and metadata. Once every
Buslane expression constructor was supported, `callable_body_can_be_cloned`
was deleted. Legal nonrecursive bodies are not rejected because of an
implementation gap in the cloner.

This RFC does not make recursive callables eligible. Recursive-SCC exclusion is
an explicit optimization policy that prevents unbounded expansion, not a clone
implementation fallback.

### Direct and interprocedural callers

The immediate-function path materializes its existing parameters and body,
then calls the shared reducer.

The interprocedural path is split into an immutable plan and an executor:

1. assigns each call in a caller a deterministic `CallSiteKey`;
2. resolves known callables and computes call-graph SCCs;
3. rejects recursive SCCs and decides profitability after contextual local
   reduction;
4. freezes those decisions in `InlinePlan`;
5. executes every accepted plan entry at most once;
6. runs `CoreCleanup`;
7. plans newly exposed calls from the resulting program.

The executor never recursively visits a cloned body. A call exposed by an
accepted rewrite belongs to a later immutable plan, so one source call site
cannot trigger an unbounded tree of speculative intermediate programs.

Both `arguments.all(is_substitutable_atom)` and `callable_effect_is_empty` have
been deleted from semantic eligibility. `is_substitutable_atom` had no
independent consumer and was removed.

### Profitability remains separate

Semantic eligibility answers whether a rewrite is observationally valid.
Profitability answers whether the compiler should commit that valid rewrite.
The two decisions must remain separate.

Direct substitution may duplicate a large pure expression. Profitability sees
the fully contextually reduced candidate, including every branch or adapter
that disappears. It uses structural program size, plus the exact removal of a
single-use non-root definition. Straight-line values are accepted because they
remove a call boundary without duplicating dynamic calls, branches, operations,
or handler dispatch.

There is no expansion quota, per-callee quota, arbitrary work budget, or
weighted source-node score. Termination follows from rejecting recursive SCCs,
executing each immutable plan entry once, and placing newly exposed call sites
in a later plan.

## Pipeline placement

Application reduction runs in effect-aware Buslane Core optimization after
linking, executable entry selection, and effect specialization. It runs before
handler elaboration, monadic transformation, selective CPS, open-context
resolution, continuation lifting, and runtime ANF lowering. The same optimizer
runs again after continuation lifting and before runtime projection.

This placement provides:

- a whole-program known-call graph;
- authoritative source-level effects for observability decisions;
- concrete effect-specialized callables where available;
- high-level constructors and matches for contextual reduction;
- no need to reconstruct source semantics from ANF or VM CFG.

This optimization runs both before effect lowering and after monadic
continuations have been lifted. Selective CPS changes which effects remain in
the row, but not what `Empty` means: the target computation is observationally
pure. A generated context or continuation call that can perform `Io`, `Panic`,
or another residual effect must carry that effect in its CPS ABI. Losing it is
an effect-lowering defect, not a reason to weaken the optimizer's purity rule.

ANF continues to make the surviving execution order mechanically explicit for
lowering. It is not duplicated inside Core optimization.

Residual effect projection occurs only while constructing runtime ANF. The
runtime IR is not accepted by this optimizer, so “effect
information is unavailable” is never represented as semantic `Empty` at an
optimization seam.

## Implementation plan

### Phase 1: lock the semantic contract

Add public compiler regressions before changing the reducer:

- a complex `Empty` argument used once is inlined;
- an unused complex `Empty` argument disappears;
- a multiply used complex `Empty` argument may be duplicated when the complete
  candidate is cheaper;
- a nonempty unused argument still executes once;
- a nonempty multiply used argument still executes once;
- two nonempty arguments retain left-to-right order;
- mixed empty and nonempty arguments preserve only the observable order;
- a nonempty callee body is inlined without losing or duplicating its effect;
- a user-defined operationless effect is treated like every other nonempty
  effect row.

Prefer source-level or compile-facade black-box tests. Use a white-box test only
for clone hygiene or a private decision that cannot be observed through a
complete optimized program.

### Phase 2: extract the shared reducer

Move immediate-function beta reduction behind the new application-reduction
interface without broadening eligibility. Move the interprocedural path to the
same interface. Delete the duplicate argument-to-parameter loops. Existing
tests must remain unchanged at this intermediate point.

### Phase 3: make reduction effect-directed

Replace syntactic atom classification with the authoritative expression-effect
query. Substitute `Empty` arguments only when their type is definitionally
equal to the parameter type. Bind all nonempty and representation-adapting
arguments once in their original relative order. Remove the atom-only guard and
prove the mixed argument cases through complete optimized-program observations.

### Phase 4: admit nonempty callees

Remove the empty-callee guard. Verify direct residual `Io`, `Panic`, External,
and user-defined effect examples. Each original call must produce one body
execution, and subsequent simplification must preserve every nonempty
operation.

### Phase 5: complete hygienic cloning

Freshen nested value and type binders, remove
`callable_body_can_be_cloned`, and add generic, existential, handler, and nested
lambda regressions. Metadata allocation failure must preserve its typed Core
optimization cause and return no partially rewritten program.

### Phase 6: add observability and delete obsolete code

Expose typed optimization observations for:

- applications considered;
- applications accepted;
- empty arguments substituted;
- nonempty arguments bound;
- candidates rejected for recursion;
- candidates rejected by profitability;
- net Core calls and top terms removed.

Explore presentation may consume these facts but must not reconstruct them from
rendered Core text. Remove the old atom predicate, empty-callee eligibility
helper, duplicate beta-reduction loop, and tests that inspect superseded private
mechanics.

## Implementation status

All six phases are complete:

- direct and interprocedural applications consume the shared reducer;
- semantic eligibility uses the authoritative `Empty`/nonempty effect
  distinction together with definitional type equality at the parameter
  adaptation boundary;
- nonempty callee bodies may be inlined;
- nested type lambdas, existential alternatives, handler operations, and
  recursive callable metadata are freshened hygienically;
- atom-only, empty-callee, and cloneability guards have been deleted;
- typed observations report application decisions and net program changes.

Public Core optimizer regressions cover zero, one, and multiple parameter uses,
complex pure arguments, pure callable adaptation, `Io`, operationless user
effects, effectful callees, clone hygiene, and structured failure propagation.
Backend conformance checks observable ordering and callable adaptation on the
direct interpreter, Wasm interpreter, and Wasm JIT.

## Test matrix

The final suite must cover these independent dimensions:

| Dimension | Required cases |
| --- | --- |
| Argument effect | `Empty`, `Io`, `Panic`, External, user-defined empty declaration |
| Argument shape | literal, reference, call, construct, match, local binding, lambda |
| Parameter use | zero, one, multiple, different branches |
| Callee effect | `Empty`, one nonempty effect, effect union |
| Generic shape | monomorphic, ordinary generic, effect generic after specialization, nested type lambda |
| Callability | direct reference, complete type application, alias resolved by Core analysis, first-class escape retained |
| Recursion | direct recursion, mutual recursion, nonrecursive dependency chain |
| Failure | normalization failure, metadata allocation exhaustion, profitability rejection |

At least one executable conformance test must compare interpreter and Wasm
traces for mixed nonempty arguments. The trace, not an internal ID or opcode
sequence, owns the ordering assertion.

## Measurement baseline and gates

On 2026-08-11, the compiler was measured against clean Basic revision
`8a7be0e619a611ae3c2189278ae548d5353db5cc`, entry
`test/entry.lane:test_entry`. An isolated compiler build with the former
interprocedural evaluator disabled produced the following comparison:

| Metric | Partial evaluation disabled | Pre-refactor compiler | Implemented reducer |
| --- | ---: | ---: | ---: |
| Core top terms | 199 | 164 | 161 |
| Core functions | 352 | 311 | 191 |
| Core call nodes | 824 | 687 | 663 |
| Physical Program functions | 798 | 731 | 700 |
| Physical Program instructions | 6,674 | 5,933 | 5,909 |
| Physical Program indirect calls | 505 | 408 | 363 |
| Physical Program closures | 508 | 456 | 420 |
| Physical Program environments | - | 456 | 434 |
| Physical Program erase operations | - | 440 | 425 |
| Physical Program unerase operations | - | 325 | 334 |
| Wasm functions | 942 | 877 | 849 |
| Wasm instructions | 141,839 | 125,486 | 124,761 |
| Wasm locals | 11,905 | 10,626 | 10,661 |

The implemented Core stage now occurs before effect lowering, whereas the two
older Core columns were observed after monadic continuation lifting. Their Core
counts therefore describe different semantic boundaries; Physical Program and Wasm
remain directly comparable. Moving to the sound source-effect boundary removes
31 physical functions, 45 indirect calls, 36 closures, 22 environments, and
725 Wasm instructions relative to the pre-refactor compiler. Unerase operations
increase by 9 and Wasm locals by 35, while total erase/unerase operations,
physical instructions, and Wasm instructions all decrease. These measured
changes are the explicit representation tradeoff for no longer running
source-purity rewrites over generated CPS calls.

These are net partial-evaluation results, not an accepted-inline count. The new
typed observations will make future attribution exact.

The refactor is accepted only if:

- all semantic and clone-hygiene tests pass;
- every valid example and the repository integration gate pass;
- Basic interpreter and JIT behavior remain identical;
- the accepted-inline count increases on at least one complex-argument public
  regression;
- Core call count and representation operations do not regress on the pinned
  Basic entry without an explicitly reviewed tradeoff;
- Physical Program and Wasm size remain visible alongside any compile-time change;
- no source symbol spelling, effect identity, call frequency, or function ID
  participates in semantic eligibility.

## Persistence and interfaces

The refactor changes Core optimization and its typed compiler-observation
interface. It does not change Lane syntax, source typing, Buslane syntax,
module interfaces, module objects, and linked WebAssembly artifacts,
or Wasm ABI. No persisted artifact schema version changes.

Moving the observed Core stage before effect lowering changes the ordered
Explore contract, so Explore Report Protocol version 3 owns the new stage
order. The protocol does not infer application decisions from rendered IR;
future presentation of typed optimization observations requires another
explicit protocol review. Protocol version 4 retains this order while tightening
the function-identity ownership contract.

## Non-goals

- recognizing a builtin or specially named `Diverge` effect;
- proving termination;
- recursive-function inlining or recursive unrolling;
- profile-guided optimization or hotness annotations;
- moving general Core optimization after ANF;
- reconstructing effects from syntax, source names, or runtime ABI;
- changing the Canonical Generic ABI or optional representation-specialization
  rewrite from ADR-0138;
- treating devirtualization, adapter fusion, or worker specialization as
  accepted source-level inlining;
- defining final lowering-relevant profitability weights in this refactor.

## Rejected alternatives

### Keep the atom-only rule

This is safe but discards the effect information Lane already computes and
misses common nested calls, constructors, dictionaries, and adapters.

### Bind every complex argument

This preserves strict evaluation but unnecessarily prevents contextual
reduction of `Empty` computations. It treats a representation convenience as a
language-semantic constraint.

### Run the inliner only after ANF

ANF makes every argument atomic, but it has already hidden the high-level
constructor, match, effect-specialization, and generic context that makes
profitable reduction visible. Moving the pass would also duplicate or move
effect-aware Core policy into a lower representation.

### Special-case known effect names

The optimizer needs only the empty/nonempty distinction. Recognizing `Diverge`,
`Io`, `Panic`, or a library-qualified effect name would create a second effect
semantics and reject equivalent user-defined contracts.

### Substitute every argument

This duplicates or removes nonempty computations and is unsound even if the
callee itself is pure.
