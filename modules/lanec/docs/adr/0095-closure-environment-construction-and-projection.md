# Closure environment construction and projection

LoisVM v1 exposes three closure-environment operations: `make_env`, `borrow_capture`, and `consume_captures`. They are distinct from nominal-data operations even though both use Object Shapes and share projection-result and ownership conventions. Keeping separate opcodes preserves the semantic distinction between Data and Environment shape variants without exposing raw memory access.

`make_env(destination, shape, layout, witnesses, captures)` encodes destination SlotId, direct zero-based Environment ObjectShapeId, LayoutOperand, counted witness array, then counted capture array. Arrays follow the shape's declared order and match its counts under the trusted contract. The instruction reads Trivial witnesses and captures, consumes owned captures, writes every observable payload word, and publishes a logically dead `I32 + OwnedRef` destination only after complete initialization. LoisVM has no separate uninitialized environment allocation, per-field initialization, seal, or mutation instruction.

`borrow_capture(shape, environment, capture_index, result)` carries an explicit environment source `SlotId`. The index is a shape-local `u32`. The instruction preserves environment ownership, copies immediate captures, and produces block-local borrowed reference payloads in `Trivial` destinations. An erased capture also copies its stored LayoutId into the result's witness destination.

`consume_captures(shape, environment, selected_results)` consumes one environment owner. Selected results are encoded as a possibly empty strictly increasing sequence of capture-index and ProjectionResult pairs. For a unique environment, execution moves selected owned captures, releases unselected owned captures, and frees the environment shell. For a shared environment, execution retain-copies selected owned captures and releases only the consumed environment owner. Both paths produce the same owned results and copy required trivial witnesses.

Capture-free functions use environment zero. They have no Environment Object Shape entry and execute no `make_env`. A recursive closure group constructs one shared environment for outer captures, establishes one environment owner for each published callable, and stores no strong member-callable backreferences.

The Wasm backend may scalar-replace a non-escaping environment, keep captures in locals, or remove redundant retain/release pairs. These optimizations implement the same construction, projection, and ownership-transfer semantics and are not visible in LoisVM bytecode.

Consequences:

- Environment construction is one complete consuming operation.
- Environment projection always carries an explicit source slot.
- Capture indices are local to an Environment Object Shape.
- Borrowing projection preserves environment ownership and returns block-local borrows.
- Consuming projection consumes one environment owner and returns owned captures.
- Unique and shared consuming paths are semantically equivalent.
- Selected consuming indices are strictly increasing and may be empty.
- Capture-free functions allocate no environment and need no Environment Object Shape.
- Recursive groups share environments without strong environment-to-callable cycles.
- Backend scalar replacement does not change bytecode semantics.
