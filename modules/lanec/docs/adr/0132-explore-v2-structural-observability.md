# Explore v2 structural observability

## Decision

Explore Report schema version 2 publishes deterministic structural metrics and
an explicit function provenance graph. Entry discovery remains schema version
1 because its contract is unchanged.

Every completed stage contains an ordered metric array and an ordered array of
stage-local function scale observations. Metric identifiers define stable
structural meanings; a stage omits a metric that does not apply. Function scale
uses the identity owned by that IR. ANF identities and Wasm function indices
start at zero, while VM CFG and bytecode identities are their one-based
`FunctionId` values. Consumers must treat these as opaque within the named
stage, not as cross-stage arithmetic.

Tree-shaped Buslane and effect-lowering IRs do not assign function identities.
Those stages therefore publish aggregate function, node, and call metrics but
no per-function scale observations. A traversal ordinal is not an identity.
Publishing per-function scale for one of these stages requires its
transformation owner to produce an identity sidecar in the same operation that
constructs the observed IR.

The report-level function graph contains typed nodes and explicit directed
edges. ANF function identities are assigned when ANF functions are constructed.
LoisVM function-table canonicalization remaps body origins and merges every
origin of a deduplicated runtime import. VM CFG finalization preserves that
canonical identity sidecar, and both VM CFG and bytecode metrics consume it.
The Wasm compiler records imports and definitions at its sole function-emission
boundary and derives function scale from the same sidecar. A bytecode-backed
Wasm body, physical runtime
import, or runtime-import adapter carries its actual bytecode `FunctionId`;
compiler-generated functions carry closed runtime or helper roles.

Presentation consumes this graph directly. It must not infer lineage from
rendered IR, labels, spans, source names, array offsets, or coincident numeric
identities. Source names are optional display data attached to an existing
Buslane value anchor, not graph keys.

Metrics and provenance are observation sidecars. They are not fields of the
persisted linked artifact, LoisVM bytecode image, or Wasm module. The owners of
IR transformation and function emission produce the sidecars in the same
operation that determines identities and ordering. Ordinary compilation uses
the same implementations and discards only the observations.

## Consequences

- Equal Explore requests produce metrics, nodes, and edges in deterministic
  order without parsing human-readable IR.
- A function may have multiple origins after runtime-import deduplication and
  multiple outgoing Wasm edges when one bytecode import produces both a
  physical import and an adapter.
- Synthetic functions are roots unless a producer supplies a real earlier
  identity; fabricated source parents are forbidden.
- Protocol clients can correlate size changes across lowering boundaries while
  remaining independent of pretty-printer syntax and internal offset formulas.
- Changing metric meaning, graph shape, or role encoding requires another
  Explore schema revision. Adding persisted IR metadata remains a separate
  schema decision.
