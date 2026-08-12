# Exact callable flow and deferred adaptation

## Decision

Lane performs callable devirtualization from one whole-image VM CFG callable
flow analysis. The analysis computes a finite fixed point over unreachable
values, closed callable alternatives, open alternatives with retained known
provenance, and recursively summarized aggregates. It propagates facts through
aliases, block parameters, immutable globals, aggregate projections, and known
function results. It uses no invocation-count threshold, growth budget, score,
or source-order heuristic.

An indirect call becomes direct only when its fact is closed and names exactly
one target. A locally known environment may be passed directly to the target.
The target's environment ABI is removed only when every observed construction
and invocation can use one exact environment shape and every environment
projection can become an explicit hidden witness or value parameter. Packing a
callable into an aggregate or global, passing it as a value argument, returning
it, or joining incompatible alternatives prevents that ABI rewrite. Such a
call may still be devirtualized while retaining its packed environment ABI.
Eligibility is decided before rewriting; there is no speculative rewrite and
fallback pass.

LoisVM lowering represents a required callable representation conversion as a
deferred structural value containing the source callable, source and target
types, exact parameter alignment, final substitution, and captured witnesses.
Calling that value fuses argument conversion, the source call, and result
conversion directly into the caller. Applying type arguments preserves the
same structural value. Only an operation that requires an ordinary first-class
callable slot materializes the canonical adapter plan, environment, and
closure.

Adapter alignment also proves whether the source and target callable contracts
are definitionally aligned after substitution and differ only by omitted Unit
positions. Such a conversion reuses the original callable bits; physical ABI
equality alone is insufficient because equal-width values may have different
source semantics. For adapters that must be materialized, function-table
canonicalization computes exact structural equivalence, including recursive
references to other adapters, and gives each equivalence class one physical
worker. Every materialization site retains its own environment and witnesses.

Callable-flow analysis is the sole producer of callable target and environment
facts. Callable adapter alignment is the sole producer of the deferred
adaptation contract. Consumers may preserve or materialize those facts but may
not reconstruct them from instruction adjacency, reference counts, runtime
layout equality, or source effect syntax.

## Consequences

- Callable propagation crosses CFG and immutable storage boundaries without
  relying on neighboring instruction shapes.
- Multiple uses of one known capture-free function remain directly callable;
  uniqueness of a reference is not an optimization precondition.
- Environment elimination changes both callers and the callee ABI only when
  the complete-image fact proves that change coherent.
- Non-escaping representation adapters add no adapter function, environment,
  closure, or callable-table entry.
- Definitionally aligned adapters whose runtime ABI already agrees add no
  wrapper, including target-only Unit parameters.
- Alpha-renamed or recursively equivalent materialized adapter contracts share
  one physical worker and preserve all contributing provenance.
- Escaping adapters retain the existing first-class callable semantics through
  the canonical materialization path.
- This decision does not specialize arbitrary generic function bodies by
  concrete runtime representation. Demand-driven erased-value specialization
  and cancellation of general `erase_*`/`unerase_*` pairs remain separate work.
- The transformation changes no persisted artifact or bytecode schema.
