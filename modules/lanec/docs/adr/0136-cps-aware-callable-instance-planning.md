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

Allocation identities in this graph propagate callable and data-flow facts;
they never become storage identities themselves. When the complete use graph
of one closed generic data instance is proved, the plan may instead select a
canonical specialized data representation family. The key contains the nominal
owner and complete canonical runtime arguments, including higher-kinded type
expressions and evidence. The family is created before VM CFG emission and owns
the complete constructor-tag and object-shape contract for that instance.

Declaration and specialized families are different identities. Construction,
matching, nested field layout, callable parameter and result ABIs, capture
layout, and bytecode object-shape verification consume the selected identity;
none may infer it from the outer `Reference` layout or from an allocation site.
An open, existential, recursively expanding, or incompatible use rejects the
whole connected component and retains the declaration family. A nested data
type whose storage depends on evidence bound by a local `forall` is open at the
family-planning boundary; a truly phantom argument does not prevent an outer
closed family.

Callable-valued storage currently retains the declaration family. Its physical
ABI can mention nominal families again in parameters, results, captures, and
nested callables, so the outer family alone is not a complete proof. ISS-385
owns the family-aware callable ABI required to admit that higher-order case.
Control-flow joins likewise retain nominal declaration storage unless every
incoming family is represented by an explicit joined-family proof.

When a generated aggregate is closed and non-escaping, callable-instance
planning may additionally produce an immutable scalar-replacement proof. This
proof is separate from `CallableInstanceKey`: semantic callable identity stays
function plus type/evidence arguments. The proof follows one exact
allocation-to-match carrier path through aliases and representation-worker
parameters. Representation specialization then owns the physical flattened
parameter contract. Lowering only consumes these two plans.

The scalar-replacement proof rejects the complete component when flow is open,
has multiple uses, contains hidden evidence or erased payloads, crosses a
generic fallback or a captured callable whose physical invocation is not
explicit, or produces an aggregate through a control-flow join. Rejection
retains an ordinary nominal allocation; there is no emission-time reboxing
fallback. Retained allocations are independently eligible for the stricter
specialized-family proof above. Failure of that proof always selects the
declaration family.

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
- Constructor fields and matches either preserve their declaration-owned
  uniform ABI or consume one explicitly planned specialized family. A family
  change cannot be introduced while emitting a body.
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
proof, physical scalar worker projection, and explicit specialized data-family
plan are implemented. The focused concrete-answer CPS path has no callable
adapter or erase/unerase bridge. Closed retained data may use a complete
specialized family; every unproved use continues to use the declaration-owned
ABI. Effect-aware CPS Core optimization and interprocedural VM CFG callable
flow remain separate prerequisite and consumer boundaries. Runtime effect
projection occurs only at the ANF seam.
