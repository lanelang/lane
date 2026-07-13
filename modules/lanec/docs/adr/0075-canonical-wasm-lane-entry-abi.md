# Canonical Wasm Lane entry ABI

Every compiled Lane function target uses one canonical typed Wasm entry convention. Parameters are ordered as the hidden closure environment `env:i32`, followed by all required hidden representation layout witnesses `LayoutId:i32`, followed by user arguments in their erased Wasm representations. Capture-free functions receive zero for `env`; zero is not a valid allocated environment offset.

Monomorphic user values use natural Wasm types: `Int` is `i64`, `Double` is `f64`, `Bool` and wasm32 heap references are `i32`, and a packed callable is `i64`. Representation-polymorphic values use `i64` and are governed by the preceding layout witnesses. Layout witnesses are immediate non-owning image-table indices and do not participate in ARC.

Current Lane v1 functions return no Wasm result for `Unit` and one naturally represented or erased result for every other Lane value. The output profile includes Multi-value, so a future Lane value that genuinely requires several physical scalars may use several Wasm results, but no current v1 representation needs that facility.

Direct calls use `call`; packed callable calls unpack the table index and environment and use `call_indirect`. Tail forms use `return_call` and `return_call_indirect`. All four forms use the same erased signature for a target, so a function requires no separate closure adapter merely because it can be called both directly and as a first-class value. A representation-polymorphic Unit argument or result still occupies canonical `i64 0`; only statically natural Unit omits a Wasm value.

Runtime-import adapters expose the same Lane entry ABI. Their environment must be zero. The adapter uses the runtime symbol registry to convert typed or erased Lane operands to the physical host import signature under module namespace `"lane.runtime.v1"`. `Int`, `Double`, `Bool`, and `Unit` use natural Wasm scalar shapes; a String argument expands to `(bytes_ptr:i32, byte_length:i32)`, and a String result is one owned `string_ref:i32`. The adapter implements the private exception-based fatal cleanup contract when the import or a restricted runtime service fails.

The backend interns complete erased signatures in the Wasm type section. Bytecode does not serialize a separate `CallShapeId` table. For a returning callable-value call, the backend derives the exact signature from the ordered witness and user argument slot representations plus the optional destination representation. For a callable-value tail call, it uses the current function result descriptor because the terminator has no destination. It prepends canonical `env:i32` and interns the complete shape. Each indirect or indirect-tail call names the resulting exact type index. This preserves Wasm validation and dynamic indirect-call type checking without carrying full Lane source types.

Consequences:

- Every Lane entry has a hidden `env:i32` parameter, including capture-free functions.
- Layout witnesses precede user arguments and are non-owning `i32` values.
- Monomorphic values use native Wasm scalar representations.
- Generic values use `i64` erased representations.
- `Unit` returns no Wasm result; other current v1 values return one result.
- Multi-value is available but not required by current v1 value representations.
- Direct and packed-callable calls share the same target entry.
- Runtime imports use generated adapters with the canonical Lane entry ABI.
- Physical runtime imports use natural primitive Wasm signatures.
- String input expands to pointer-length and String output is an owned `i32` reference.
- Complete erased signatures are interned and used for typed indirect calls.
- Indirect call shapes are derived from call-site slot metadata, not a serialized shape table.
