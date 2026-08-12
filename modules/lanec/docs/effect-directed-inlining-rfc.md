# Effect-directed application reduction and inlining

Status: proposed

## Summary

Lane will replace its two substitution-only application reducers with one
effect-directed reduction module owned by `lanec/core_opt`.

The module will reduce both an immediately available function value and a
cloned known callable through the same operation. For each argument, it will
use the authoritative expression-effect fact to choose between direct
substitution and an ordered local binding:

- an `Empty` argument may be substituted, duplicated, delayed, reordered, or
  removed, subject only to profitability;
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

There are two application reducers:

1. `simplify_call` reduces an immediately present `Function` only when all
   arguments are `Ref` or `Literal`.
2. `PartialEvaluator::try_inline_known_call` clones a known top-level callable,
   also requires atomic arguments, requires the callee's latent effect to be
   `Empty`, substitutes the arguments, and then performs contextual
   simplification and profitability analysis.

The duplicate atom check is also a duplicate owner of application semantics.
Future argument or effect rules can drift between direct beta reduction and
interprocedural inlining.

`InlineCloneContext` correctly clones ordinary value binders and substitutes
the outer generic application. It deliberately rejects bodies containing
nested `TypeLambda` binders or match-alternative type binders because those
binders are not yet freshened. This makes cloning partial and leaves a second
eligibility predicate describing which legal Buslane bodies the cloner happens
to support.

## Design

### One application-reduction module

`lanec/core_opt` will own one private application-reduction module. Its
interface accepts:

- the already materialized parameter identities;
- the ordered argument expressions;
- the hygienically materialized body;
- inherited simplifier substitutions;
- the authoritative `ExpressionFactsQuery` and Core analysis.

It returns one reduced Buslane expression or a structured Core optimization
error. Callers do not classify arguments, build binding order, or perform
parameter substitution themselves.

The module owns these invariants:

1. parameter and argument arities are equal;
2. every `Empty` argument becomes a substitution candidate;
3. every nonempty argument is bound exactly once;
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

### Existing fact owners

The refactor will consume existing facts rather than introduce parallel
analyses:

- `ExpressionFactsQuery` owns whether an argument effect is `Empty`;
- `InterproceduralAnalysis` owns known-callable discovery and recursive-SCC
  classification;
- `InlineCloneContext` owns fresh metadata and hygienic body materialization;
- application reduction owns parameter evaluation semantics;
- `partial_evaluation_policy` owns profitability, work, and growth limits;
- occurrence analysis owns post-rewrite reachability and term retention.

Effect normalization failure must cross the existing Core optimization error
seam with its typed cause. It must not be converted to `false`, an empty row, or
a rendered string.

### Complete hygienic cloning

`InlineCloneContext` will be extended to clone every legal binder introduced by
a Buslane callable body:

- function parameters;
- local `Let` and `LetRec` binders;
- match binders and value binders;
- nested `TypeLambda` binders;
- match-alternative type binders;
- handler result, payload, resume, and type binders.

Fresh type binders will retain their kind and receive a local substitution used
by all nested types, effects, generic arguments, and metadata. Once every
Buslane expression constructor is supported, `callable_body_can_be_cloned`
will be deleted. Legal nonrecursive bodies will no longer be rejected because
of an implementation gap in the cloner.

This RFC does not make recursive callables eligible. Recursive-SCC exclusion is
an explicit optimization policy that prevents unbounded expansion, not a clone
implementation fallback.

### Direct and interprocedural callers

The immediate-function path will materialize its existing parameters and body,
then call the shared reducer.

The interprocedural path will:

1. resolve the known callable and complete generic application;
2. reject recursive SCCs;
3. hygienically clone and instantiate the callable;
4. call the shared reducer for all value arguments;
5. recursively optimize the reduced candidate;
6. compare the complete original and candidate plans;
7. commit the candidate and rerun affected analysis when profitable.

It will delete both `arguments.all(is_substitutable_atom)` and
`callable_effect_is_empty` from semantic eligibility. The helper
`is_substitutable_atom` will disappear if it has no independent consumer.

### Profitability remains separate

Semantic eligibility answers whether a rewrite is observationally valid.
Profitability answers whether the compiler should commit that valid rewrite.
The two decisions must remain separate.

Direct substitution may duplicate a large pure expression. The existing
candidate-cost comparison and whole-program growth budget must see the fully
reduced candidate, including every duplicated node and every callee definition
that becomes unreachable. No pre-reduction size rule may reject a candidate
whose branches, constructors, or adapters disappear after contextual
simplification.

The current `8/16/2` call, branch, and allocation weights and the current work
and growth constants are not made semantic by this RFC. Replacing them with
lowering-relevant cost is tracked by the optimization plan. This refactor will
preserve the policy seam so that work can proceed independently.

## Pipeline placement

Application reduction remains in effect-aware Buslane Core optimization after
linking, executable entry selection, effect specialization, handler
elaboration, selective CPS, open-context resolution, and monadic continuation
lifting. It remains before residual-effect erasure and ANF lowering.

This placement provides:

- a whole-program known-call graph;
- explicit, normalized residual effects for observability decisions;
- concrete effect-specialized callables where available;
- high-level constructors and matches for contextual reduction;
- no need to reconstruct source semantics from ANF or VM CFG.

ANF continues to make the surviving execution order mechanically explicit for
lowering. It is not duplicated inside Core optimization.

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
query. Substitute all `Empty` arguments. Bind all nonempty arguments once in
their original relative order. Remove the atom-only guard and prove the mixed
argument cases through complete optimized-program observations.

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
- candidates rejected by profitability or resource budget;
- net Core calls and top terms removed.

Explore presentation may consume these facts but must not reconstruct them from
rendered Core text. Remove the old atom predicate, empty-callee eligibility
helper, duplicate beta-reduction loop, and tests that inspect superseded private
mechanics.

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
| Failure | normalization failure, metadata allocation exhaustion, growth-budget rejection |

At least one executable conformance test must compare interpreter and Wasm
traces for mixed nonempty arguments. The trace, not an internal ID or opcode
sequence, owns the ordering assertion.

## Measurement baseline and gates

On 2026-08-11, the current compiler was measured against clean Basic revision
`8a7be0e619a611ae3c2189278ae548d5353db5cc`, entry
`test/entry.lane:test_entry`. An isolated compiler build with
`partially_evaluate_program` disabled produced the following comparison:

| Metric | Partial evaluation disabled | Current compiler |
| --- | ---: | ---: |
| Core top terms | 199 | 164 |
| Core functions | 352 | 311 |
| Core call nodes | 824 | 687 |
| Bytecode functions | 798 | 731 |
| Bytecode instructions | 6,674 | 5,933 |
| Bytecode indirect calls | 505 | 408 |
| Bytecode closures/environments | 508 | 456 |
| Wasm functions | 942 | 877 |
| Wasm instructions | 141,839 | 125,486 |
| Wasm locals | 11,905 | 10,626 |

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
- bytecode and Wasm size remain visible alongside any compile-time change;
- no source symbol spelling, effect identity, call frequency, or function ID
  participates in semantic eligibility.

## Persistence and interfaces

The refactor changes compiler-private Core optimization only. It does not
change Lane syntax, source typing, Buslane syntax, module interfaces, module
objects, linked-program artifacts, LoisVM bytecode, or Wasm ABI. No persisted
schema version changes.

Adding typed Explore observations changes the compiler observation interface.
Its protocol version must be reviewed according to the existing Explore schema
policy; this RFC does not silently add fields to a closed persisted format.

## Non-goals

- recognizing a builtin or specially named `Diverge` effect;
- proving termination;
- recursive-function inlining or recursive unrolling;
- profile-guided optimization or hotness annotations;
- moving general Core optimization after ANF;
- reconstructing effects from syntax, source names, or runtime ABI;
- changing the current representation-specialization plan;
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
