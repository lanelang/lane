# Demand-driven runtime representation specialization

## Decision

LoisVM lowering builds one immutable representation-specialization plan after
ordinary reachable functions have been planned and before any function body is
lowered. The plan is the sole producer of representation-worker demand.
Lowering may query the plan but may not create workers or rediscover demand.

A demand key contains the original function identity, the canonical runtime
evidence ABI, the physical parameter ABI, and the result ABI. Unit and ordinary
values are keyed by their runtime value ABI. Callable type arguments additionally
carry their complete callable ABI, because `CallableValue` alone does not
distinguish parameter, witness, and result contracts. Source types with equal
runtime contracts therefore share one worker even when their source spelling
differs. Types with different callable, data-family, cleanup, or semantic value
contracts never share a worker.

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
witnesses. The original generic implementation always remains the fallback for
open calls, indirect calls, unsupported evidence kinds, and rejected recursive
families. It is planned and lowered before workers. Ordinary whole-image
reachability may remove it only when no reachable value can call or materialize
it; this is dead-function elimination, not specialization policy.

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
  recursion or code-growth limit. Expanding recursive demand remains generic.
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
