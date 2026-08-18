# CPS-aware callable-instance planning

Status: accepted and implemented; tracked by ISS-363.

## Decision

LoisVM lowering plans semantic callable instances before emitting VM CFG.
One typed ANF fixed point propagates callable identity, generic application,
closure allocation, aggregate members, parameters, results, recursion, and
immutable globals. Its immutable result is the sole producer of
runtime-representation specialization demand. Lowering consumes that plan and
does not rediscover workers from expression syntax.

The analysis is CPS-aware through ordinary typed structure. It composes every
`TypeApply`, including generated CPS answer and residual applications, but
does not inspect generated names or reconstruct source effects. The selective
CPS callable shape remains owned by effect lowering. The representation plan
consumes the fully elaborated callable type and explicit effect-companion
metadata.

A representation worker may specialize a closed first-order `Type` binder
while retaining symbolic binders. In particular, a concrete CPS answer ABI may
be selected while a higher-kinded effect companion remains an explicit worker
witness. The companion is neither guessed nor treated as a first-order layout;
its application continues to use the representation elaborator. Purely static
effect binders do not enter runtime keys.

Worker keys contain the original logical function and the complete canonical
runtime ABI of specialized evidence, physical parameters, and result. Retained
generic binders are part of the worker contract rather than part of the
specialized evidence key. One key owns at most one worker. Open uses retain the
generic implementation, and ordinary exact function reachability is the only
mechanism that may later remove it.

Recursive callable-instance demand is accepted only when the planner proves
the instance set finite over the generic call SCC. There is no call-count,
function-size, worker-count, score, growth budget, speculative rewrite, or
fallback pass.

Allocation identities in this graph propagate callable-flow facts only. They do
not select a data-storage ABI. Every nominal type continues to use the uniform
family owned by its declaration, because allocation-site identity and a
canonical runtime ABI do not create a distinct nominal representation identity.

When a generated aggregate is closed and non-escaping, callable-instance
planning may additionally produce an immutable scalar-replacement proof. This
proof is separate from `CallableInstanceKey`: semantic callable identity stays
function plus type/evidence arguments. The proof follows one exact
allocation-to-match carrier path through aliases and representation-worker
parameters. Representation specialization then owns the physical flattened
parameter contract. Lowering only consumes these two plans.

The proof rejects the complete component when flow is open, has multiple uses,
contains hidden evidence or erased payloads, crosses a generic fallback or a
captured callable whose physical invocation is not explicit, or produces an
aggregate through a control-flow join. Rejection retains the ordinary nominal
allocation; there is no emission-time reboxing fallback. If an allocation
remains, it uses the declaration-owned family without exception. ISS-384
separately tracks the representation-family boundary that would be required for
retained generic data to have specialized storage; it is not a prerequisite for
this decision.

VM CFG callable-flow has a separate, physical responsibility. It propagates
the emitted environment, witness, argument, aggregate, global, and result
facts and decides whether a final `CallValue` can become `CallDirect` or lose
its environment ABI. It does not create specialization demand or infer source
generic applications from layout instructions.

## Consequences

- CPS answer specialization is an instance of general runtime-ABI
  specialization, not an effect-specific lowering path.
- Higher-kinded companions can remain symbolic while concrete answer
  erase/unerase bridges disappear.
- Callable values with open or incompatible ABI uses remain generic and
  indirect; correctness does not depend on optimistic rewriting.
- Function planning must be complete before specialization demand closes, and
  VM CFG emission consumes a frozen plan.
- Constructor fields and matches preserve their declaration-owned uniform data
  ABI; callable specialization cannot silently introduce another family.
- Closed generated dictionaries may lose their allocation and representation
  bridges through scalar replacement, without creating another data family.
- Scalar-replacement eligibility and physical worker projection are explicit
  plan facts. `LocalValue` may carry a proved closed aggregate only while
  lowering the planned path; it cannot enter VM CFG or bytecode.
- Captured workers and aggregate-valued control-flow joins retain the nominal
  representation until their own physical callable/result contracts exist.
- No source-language, linked-artifact, or LoisVM bytecode schema changes are
  required by this decision.

## Implementation status

The typed Runtime ANF callable catalog, immutable callable-instance fixed point,
canonical partial workers, finite recursive-demand proof, closed-aggregate use
proof, and physical scalar worker projection are implemented. The focused
concrete-answer CPS path has no callable adapter or erase/unerase bridge while
nominal families retain one declaration-owned ABI. Effect-aware CPS Core
optimization and interprocedural VM CFG callable flow remain separate
prerequisite and consumer boundaries. Runtime effect projection occurs only at
the ANF seam.
