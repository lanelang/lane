# Demand-driven runtime representation specialization

Status: accepted for generic fallback and finite demand; per-value assignment
and complete function/data contracts are revised by ADR-0136.

## Decision

After semantic callable instances have been analyzed, the Representation
Constraint Graph solver produces physical function variants and representation
bridges before any VM CFG body is emitted. Its solution is carried by verified
Physical ANF. VM CFG emission may not create workers, rediscover demand, or
choose a representation from source types.

A function-variant key contains one semantic callable instance, its Callable
Invocation Contract, exact capture shapes, and the body-shape assignment that
affects emission. Unit and ordinary values are keyed by Physical Value Shape;
callable and data values therefore name their exact callable contract or data
family rather than an outer machine representation. Source types with equal
complete physical contracts may share a worker when they belong to the same
semantic callable instance. Different callable, data-family, environment,
cleanup, or semantic value contracts never share a worker.

The first implementation specializes functions whose runtime evidence consists
only of registry-declared first-order `Type` parameters. Higher-kinded layout
constructors and compiler-generated effect companions retain the generic path:
their behavior is not represented by a first-order value ABI, so treating their
slots as sufficient keys would be unsound. This is a semantic eligibility
boundary, not a size or profitability heuristic.

Every accepted key owns exactly one worker. A worker receives concrete physical
parameters and returns a concrete result without layout-witness parameters or
erased-value bridges. Its active type substitution is carried through nested
function lifting, while specialized parameters are never recaptured as runtime
witnesses. Distinct open and closed components may require the generic
implementation and one or more specialized workers simultaneously. This is
ordinary finite representation specialization: each complete canonical
physical key owns at most one worker, independent of source spelling, call
frequency, function size, or a profitability score.

The original generic implementation remains the correctness baseline for open
calls, indirect calls, unsupported evidence kinds, and rejected recursive
families. It is always plan-capable. Ordinary whole-image reachability removes
it when no reachable value can call or materialize it; this is dead-function
elimination, not a second specialization policy.

Callable erasure is position-directed. When an erased position explicitly
names a callable ABI, including a lowering-owned canonical callable placeholder,
that formal shape owns the payload ABI on both erasure and unerasure. An opaque
source parameter such as `T` does not acquire a callable ABI merely because its
concrete substitution happens to be callable; it uses the concrete callable's
canonical ABI. This distinction keeps nested generic result slots erased while
preserving ordinary `T` container round trips. Erasure and unerasure consume the
same formal ABI fact rather than independently inferring a payload contract.

The planner constructs the direct generic-call graph and computes its strongly
connected components. A recursive component is specialized only when every
intra-component demand produced by every seeded worker is already a member of
that component's finite seed set. A transformation such as `T -> Box[T]`
therefore keeps the whole component generic; `T -> T` may specialize. This is an
exact closure proof. It has no call-count threshold, function-size limit,
expansion budget, score, speculative rewrite, or fallback pass.

First-class callable contracts add a separate structural boundary. A
`CanonicalCallableAbi` recursively contains the shapes of its parameters and
result; it does not contain a nominal reference to another callable contract.
The planner therefore computes the exact SCC of representation demands linked
through first-class callable ports and results. It emits no worker for a
recursive component, and every edge targeting that component retains the
callable's generic invocation ABI instead of trying to embed a worker contract
in itself. Acyclic first-class edges may use a concrete worker only when its ABI
preserves one physical slot per logical callable parameter. A worker that
expands a closed aggregate into several physical parameters is a direct-call
contract, not a first-class callable contract. These rules are structural, not
recursion-depth or profitability heuristics.

Callable allocation is the sole owner of materialization. Its frozen plan binds
one semantic callable target to one implementation, one invocation ABI, and one
capture contract. Type/evidence application carries the callable's actual
physical ABI forward; it cannot reconstruct an ABI from type syntax. VM CFG
emission consumes the frozen allocation contract and never independently
reselects generic versus worker code.

After every body has been lowered, function-table canonicalization computes the
exact transitive function closure from the entry and initializer. It follows
direct calls, tail calls, function constants, and closure construction. This
single reachability owner removes dead generic fallbacks and other dead
synthetic functions before VM CFG observation and bytecode finalization.

## Consequences

- Representation workers are demand-driven and deduplicated by runtime ABI,
  not by source type spelling or observed invocation frequency.
- Planner output fixes worker identity before lowering begins. Direct generic
  calls either select that worker or use the generic fallback. Exact final
  reachability removes a fallback only when the complete image has no such use.
- Stable recursive generic code may specialize without imposing an arbitrary
  recursion or code-growth limit. Expanding recursive demand remains generic,
  a recursive first-class callable boundary retains its generic callable ABI,
  and scalar-expanded workers remain available only to direct calls.
- Explore gates both sides of the tradeoff: function count records retained
  fallbacks and workers, while `eraseCount` and `uneraseCount` prove that
  concrete call paths removed representation bridges.
- Higher-kinded evidence can be added only after it gains a canonical behavioral
  runtime key and complete worker-instantiation support. A layout-constructor
  slot ABI by itself is insufficient.
- An erased callable's layout witness identifies callable representation, not
  its full invocation contract. The formal erased position is therefore the
  sole owner of the callable payload ABI.
- The optimization changes neither persisted bytecode nor linked-artifact
  schemas.
