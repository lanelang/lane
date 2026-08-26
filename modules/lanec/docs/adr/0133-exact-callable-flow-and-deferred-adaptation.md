# Exact callable flow and deferred adaptation

## Decision

Lane performs callable devirtualization from one whole-image VM CFG callable
flow analysis. The analysis computes a finite fixed point over unreachable,
closed, and open callable alternatives and recursively summarized aggregates.
It propagates facts through aliases, block parameters, immutable globals,
aggregate projections, known function inputs, and known function results.

An indirect call becomes direct only when its fact is closed and names exactly
one target. A known environment may be passed directly to that target. The
environment ABI is removed only when every construction and invocation can use
one exact environment shape and every projection can become an explicit hidden
parameter. Packing, returning, joining, or otherwise escaping a callable may
retain its environment ABI even when the target can be devirtualized.

Representation elaboration expresses a callable conversion as one structural
adaptation from a complete source callable contract to a complete target
callable contract. Calling that value may fuse parameter conversion, the source
call, and result conversion into the caller. Only a first-class escape
materializes a worker, environment, and closure.

Adapter alignment proves semantic parameter and result compatibility after
substitution. Equal physical slots alone do not establish compatibility:
equal-width values may differ in ownership, object shape, callable ABI, or
required semantic conversion.

Equal structural source/target contracts share one materialized worker. Every
materialization site supplies its own captures. Recursive callable ABI
identities belong to the physical ABI owner; they are not a second adapter
equivalence analysis. Function-table processing owns reachability, Runtime
Import deduplication, stable remapping, and provenance remapping, but never
reconstructs adapter identity from VM CFG bodies.

Callable-flow analysis is the sole producer of callable target and environment
facts. Structural callable adaptation is the sole producer of the conversion.
Consumers may preserve, fuse, or materialize it but may not reconstruct it from
instruction adjacency, reference counts, runtime-layout equality, source type
spelling, or source effect syntax.

## Consequences

- Callable propagation crosses CFG and immutable storage boundaries without
  relying on neighboring instruction shapes.
- Multiple uses of one known capture-free function remain directly callable;
  uniqueness of a reference is not an optimization precondition.
- Environment elimination changes callers and the callee ABI only when the
  complete-image fact proves the rewrite coherent.
- Non-escaping adaptations add no adapter function, environment, closure, or
  callable-table entry.
- Definitionally aligned adaptations whose complete physical contract agrees
  add no wrapper, including target-only `Unit` parameters.
- Alpha-renamed materialized adaptations with the same physical contracts
  share one worker before VM CFG construction.
- Escaping adaptations retain first-class callable semantics.
- Arbitrary generic-body specialization remains the optional program rewrite
  defined by ADR-0138. It is not a prerequisite for callable adaptation or VM
  CFG construction.
- The transformation changes no persisted artifact or bytecode schema.
