# Packed Wasm callables

The wasm32 backend currently represents every first-class Lane callable as one `i64`. The low 32 bits contain the image `FunctionId`, which is also the function's Wasm table index, and the high 32 bits contain the wasm32 linear-memory offset of the closure environment. `FunctionId = 0` is invalid, making packed value zero an invalid callable. Environment offset zero denotes a capture-free function, so linear-memory address zero is reserved and never used for an allocated environment.

Memory64 is excluded from this profile. Supporting 64-bit environment offsets would require a different callable representation and is not a transparent extension of the packed v1 ABI.

Multiple Tables is also excluded. The packed callable carries one `FunctionId` but no table identifier, so every callable target belongs to one canonical Wasm `funcref` table. The table is private, is initialized by an active element segment, has exact equal minimum and maximum sizes, and cannot grow.

Table index zero remains invalid. Contiguous indices `1..N` are valid Lane `FunctionId` values and include both compiled Lane bodies and generated runtime-import adapters. Internal layout retain, release, destroy, and size helpers follow that range. Such helper indices are not valid `FunctionId` values. The exported entry wrapper and runtime-service helpers are not table entries. A packed callable may contain only an index from the declared Lane `FunctionId` range.

Callable targets use a typed Wasm function signature whose hidden first argument is the unpacked environment `i32`. A capture-free call passes zero. `call_direct` uses a direct Wasm `call` with the statically known environment argument, while `call_value` unpacks the `i64` and invokes the indexed target through `call_indirect` with the statically known erased representation signature. Runtime-import entries use table adapters when necessary.

After the hidden environment, the target receives required `LayoutId` witnesses and then user arguments in their erased Wasm representations. The complete signature is interned in the Wasm type section and selected as the exact type index for `call_indirect` or `return_call_indirect`.

The Lane Wasm feature profile permits Typed Function References, but they do not replace this canonical representation. A `funcref` cannot be stored directly in Lane's linear-memory heap or in the generic `i64` erased payload. Canonical value calls therefore use `call_indirect`, and canonical tail value calls use `return_call_indirect`. `call_ref` and `return_call_ref` may be used for backend-local optimizations only when the packed storage, ownership, and generic-erasure contracts remain unchanged.

The Wasm representation does not allocate a closure shell. Each owned packed callable whose environment is nonzero directly owns one strong reference to that environment. Retaining the callable retains the environment; releasing it releases the environment; consuming invocation transfers that environment owner into the callee. Multiple callable owners are established by compiler-inserted retains, so consuming a packed callable requires no dynamic unique-versus-shared shell-count branch.

`make_closure(destination, FunctionId, environment)` consumes one nonzero environment owner and packs it with a context-requiring function identifier. It performs no Wasm allocation. `const_function` constructs only a no-context callable with environment zero. Neither instruction carries a LayoutId, ObjectShapeId, call-shape identifier, or function type operand; trusted function-table metadata establishes the required context kind and call signature.

This differs physically from the LoisVM interpreter, where a callable may be an immediate `FunctionId` or a reference-counted closure shell that owns an environment. The representations are ownership-equivalent: interpreter shell ownership and Wasm direct environment ownership preserve the same observable callable behavior, and Lane exposes no closure-shell identity.

The packed callable is also a valid representation-polymorphic `i64` payload. Its `LayoutId` descriptor knows that the high 32-bit environment component is reference-bearing and applies retain or release only when that component is nonzero.

Consequences:

- Callable parameters and results occupy one Wasm `i64`.
- `FunctionId` is also the corresponding Wasm function-table index.
- `FunctionId = 0` and packed callable zero are invalid.
- All callable targets belong to one canonical function table.
- The table is private, fixed-size, and initialized by an active element segment.
- Runtime-import adapters occupy ordinary `FunctionId` entries.
- Entry and runtime-service wrappers are outside the callable table.
- The hidden callable environment is a wasm32 `i32` offset.
- Linear-memory address zero is reserved as the no-environment sentinel.
- Capture-free functions pack a zero environment and require no ARC operation.
- Capturing callables directly own environment references and allocate no closure shell in Wasm.
- `make_closure` consumes one environment owner; `const_function` constructs only the zero-environment case.
- `call_value` lowers to unpacking plus typed `call_indirect`.
- Typed Function References are available but do not define the canonical callable ABI.
- Wasm consuming call has no closure-shell uniqueness branch.
