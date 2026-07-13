# Typed closure environment layouts

A capturing Lane function uses an immutable ARC closure environment in canonical wasm32 linear memory. The environment reference points to the common 8-byte object header. A zero-based `ObjectShapeId` selecting an Environment shape provides the static capture schema, while runtime `LayoutId` selects allocation size and ARC behavior. Environment payloads have no constructor tag.

Capture fields are placed according to canonical erased Wasm representation sizes and alignments. Monomorphic references use wasm32 offsets, immediate values use their natural scalar storage, callables use packed `i64`, and representation-polymorphic captures use `i64` plus stored `LayoutId` witnesses. The Environment Object Shape records representation, cleanup, and optional witness ordinal for each capture but stores no alignment or computed raw offset. The interpreter and Wasm backend compute offsets deterministically from the shape.

`make_env(destination, shape, layout, witnesses, captures)` allocates and completely initializes one environment. Its shape must be an Environment variant. Witness and capture arrays follow shape order and match its declared counts. The instruction copies trivial stored witnesses, consumes owned captures without implicit retains, and publishes the destination only after initialization completes. Capture projection carries the same `ObjectShapeId`, an explicit environment source slot, and a shape-local capture index. The environment is immutable after publication.

`borrow_capture` preserves environment ownership and returns one capture through the common projection-result schema. Reference-bearing results are block-local borrows in `Trivial` destinations, and erased captures also return their stored witness. `consume_captures` consumes one environment owner and returns selected captures as owned values. A unique environment moves selected captures, releases unselected owned captures, and frees the shell. A shared environment retain-copies selected captures and releases only the consumed environment owner. Both paths are semantically equivalent.

Free representation parameters of a lifted function are environment state, not additional explicit callable witness parameters. Closure construction stores those LayoutIds before captures, and the lifted entry loads them from the environment before projecting generic captures or creating erased locals. Explicit `forall` parameters remain ordinary hidden witness inputs and are kept separate from these captured witnesses.

Capture-free functions use environment offset zero and allocate no empty environment. Capturing packed callables directly own one reference to their environment. Multiple callables sharing one environment require compiler-inserted retains to establish distinct environment owners.

A recursive closure group shares one environment for outer captures. The environment does not store strong references back to the member callable values. Known member calls use function identifiers with the shared environment, while first-class member values pack the member identifier with another owned reference to that environment. This prevents an environment-to-callable ownership cycle.

The Wasm backend may scalar-replace or stack-promote a non-escaping environment when its analysis proves that no reference escapes. This is an optimization over the same allocation, initialization, ownership, and destruction semantics and is not required for correctness.

Consequences:

- Environment Object Shapes provide static capture schemas separately from runtime LayoutIds.
- Environment payloads have typed capture layouts and no constructor tag.
- Environment shapes store no raw byte offsets.
- Generic captures store the layout witnesses required by destruction.
- Lifted entries load free layout witnesses from their environments.
- Captured witnesses do not change the callable's explicit witness arity.
- `make_env` completely initializes the environment and consumes capture ownership.
- Capture projection names an explicit environment source and shape-local capture indices.
- Borrowing capture projection preserves the environment and produces block-local borrows.
- Consuming capture projection preserves unique/shared ownership equivalence.
- Capture-free callables allocate no environment.
- Recursive groups share an environment without strong member-callable backreferences.
- Multiple callable owners require multiple environment owners.
- Non-escaping environment scalar replacement is optional.
