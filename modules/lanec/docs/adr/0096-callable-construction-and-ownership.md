# Callable construction and ownership

LoisVM v1 has two callable constructors. `const_function(destination, FunctionId)` constructs a capture-free callable with environment zero. `make_closure(destination, FunctionId, environment)` constructs a capturing callable and consumes one nonzero environment owner. Both destinations are logically dead `I64 + OwnedCallable` slots before writing.

Trusted function-table metadata separates no-context and context-requiring targets. `const_function` may name only a no-context function, while `make_closure` may name only a context-requiring function. `make_closure` carries no LayoutId, ObjectShapeId, call-shape identifier, or explicit function type. Its fixed binary operands are destination SlotId, nonzero `u32le FunctionId`, and direct environment SlotId. Environment SlotId zero is valid because it identifies a slot rather than an optional operand; the owned reference stored in that slot must be nonzero.

Both execution tiers represent a capturing callable as one packed FunctionId and environment pair. A capture-free callable has environment zero. A capturing callable directly owns one strong environment reference and allocates no closure shell. The interpreter stores this pair in its tagged `I64` VM value; Wasm stores FunctionId in the low 32 bits and the consumed wasm32 environment address in the high 32 bits of one `i64`.

`copy` is invalid for `OwnedCallable`. `move` transfers an existing callable owner, `retain_copy` creates an additional callable owner, and `release` destroys one owner. Interpreter and Wasm operations retain or release the packed callable's nonzero environment component.

A recursive closure group constructs one shared environment and then one callable per member. ARC insertion first establishes the number of environment owners required by the published callables. Earlier member constructions consume retained copies; the final member construction may consume the original environment owner. The shared environment contains no strong references back to those callable values.

Representation-changing callable coercions use compiler-generated adapters built from the same `make_env` and `make_closure` instructions. The adapter environment consumes the source callable and stores required free LayoutId witnesses. Calling the adapter consumes its arguments according to the ordinary callee-owned ABI, recursively converts them into the captured callable's ABI, calls that value, and converts the result into the adapter's ABI. Borrowed source callables are promoted by ARC insertion when captured; owned source callables transfer ownership without an unnecessary retain.

An adapter may tail-call its captured callable only when argument conversion has completed and no result conversion remains. If result conversion is required, it uses an ordinary returning value call followed by conversion and return.

Consequences:

- Capture-free and capturing callables use distinct constructors.
- `make_closure` consumes one nonzero environment owner without implicit retain.
- Function context kind comes from trusted function-table metadata.
- Callable construction carries no layout, shape, or signature operand.
- Callable destinations are `I64 + OwnedCallable` and logically dead before writing.
- Interpreter and Wasm execution allocate no closure shell.
- Wasm packs the callable into `i64`; the interpreter uses the same logical pair in a tagged VM value.
- Callable copy, movement, retention, and release follow explicit ownership operations.
- Recursive groups establish one environment owner per published callable.
- Callable adapters are ordinary closures and introduce no new ownership category.
- Adapter construction consumes the source callable and captures free witnesses.
- Result conversion prevents tail-call lowering; otherwise the adapter may tail-call.
