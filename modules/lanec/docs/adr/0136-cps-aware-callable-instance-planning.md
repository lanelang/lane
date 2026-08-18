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

The same allocation graph may select a concrete data-storage family only for
one closed allocation site whose reachable matches all retain that exact
allocation identity. Closed interned runtime type expressions key the family.
Values crossing erased or existential payloads, open uses, or owners with
multiple allocation sites retain the uniform generic family. This is necessary
because `Reference` evidence alone cannot recover a specialized nominal data
shape after existential opening.

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
- Closed handler dictionaries can avoid an erase/unerase adapter round trip,
  while existential and multi-allocation data preserve their uniform ABI.
- No source-language, linked-artifact, or LoisVM bytecode schema changes are
  required by this decision.

## Implementation status

The typed Runtime ANF callable catalog, immutable callable-instance fixed point,
canonical partial workers, finite recursive-demand proof, and allocation-proven
data-storage families are implemented. Effect-aware CPS Core optimization and
interprocedural VM CFG callable flow remain separate prerequisite and consumer
boundaries. Runtime effect projection occurs only at the ANF seam.
