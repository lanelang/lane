# Callable construction and ownership

LoisVM v1 has two callable constructors. `const_function(destination, FunctionId)` constructs a capture-free callable with environment zero. `make_closure(destination, FunctionId, environment)` constructs a capturing callable and consumes one nonzero environment owner. Both destinations are logically dead `I64 + OwnedCallable` slots before writing.

Trusted function-table metadata separates no-context and context-requiring targets. `const_function` may name only a no-context function, while `make_closure` may name only a context-requiring function. `make_closure` carries no LayoutId, ObjectShapeId, call-shape identifier, or explicit function type. Its fixed binary operands are destination SlotId, nonzero `u32le FunctionId`, and direct environment SlotId. Environment SlotId zero is valid because it identifies a slot rather than an optional operand; the owned reference stored in that slot must be nonzero.

The LoisVM interpreter represents a capturing callable as a new reference-counted closure shell with count one and payload containing FunctionId plus one owned environment reference. The shell's allocation and destruction layout is interpreter-internal rather than a bytecode operand. A capture-free callable remains an immediate FunctionId and allocates no shell.

The Wasm backend does not allocate the interpreter closure shell. It packs FunctionId into the low 32 bits and the consumed wasm32 environment address into the high 32 bits of one `i64`. This is ownership-equivalent because every owned packed callable with a nonzero environment directly owns one strong environment reference.

`copy` is invalid for `OwnedCallable`. `move` transfers an existing callable owner, `retain_copy` creates an additional callable owner, and `release` destroys one owner. Interpreter operations retain or release the closure shell; Wasm operations retain or release the packed callable's nonzero environment component.

A recursive closure group constructs one shared environment and then one callable per member. ARC insertion first establishes the number of environment owners required by the published callables. Earlier member constructions consume retained copies; the final member construction may consume the original environment owner. The shared environment contains no strong references back to those callable values.

Consequences:

- Capture-free and capturing callables use distinct constructors.
- `make_closure` consumes one nonzero environment owner without implicit retain.
- Function context kind comes from trusted function-table metadata.
- Callable construction carries no layout, shape, or signature operand.
- Callable destinations are `I64 + OwnedCallable` and logically dead before writing.
- The interpreter allocates a closure shell with reference count one.
- Wasm packs the callable into `i64` without closure-shell allocation.
- Callable copy, movement, retention, and release follow explicit ownership operations.
- Recursive groups establish one environment owner per published callable.
