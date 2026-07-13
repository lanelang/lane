# Representation erasure for Wasm

Lane uses representation erasure rather than whole-program monomorphization for its wasm32 linear-memory backend. Source types, source-level type applications, and full generic witnesses are removed before LoisVM execution, but the bytecode image retains the minimal representation signatures and hidden layout witnesses required to lower the same image into typed WebAssembly and to manage erased generic values correctly.

Monomorphic values use natural Wasm representations. `Int` lowers to `i64`, `Double` to `f64`, `Bool` and wasm32 linear-memory references to `i32`, and `Unit` to no value where the surrounding Wasm construct permits it. Monomorphic function parameters and results use those representations directly rather than passing LoisVM tags or tag-payload pairs.

The canonical Wasm Lane entry ABI orders hidden and user parameters consistently: `env:i32` first, required `LayoutId:i32` witnesses next, and user arguments after them. Generic user values use `i64`; monomorphic user values use their natural representation. Current v1 functions return zero results for `Unit` and one result otherwise. Multi-value remains available for a future value representation requiring several physical scalars.

A representation-polymorphic value uses one `i64` erased payload. `erase_i64` and `unerase_i64` preserve full `i64` bits while explicitly crossing the cleanup-metadata boundary. `erase_f64` and `unerase_f64` cross the erased boundary through `i64.reinterpret_f64` and `f64.reinterpret_i64`. `erase_i32` zero-extends an `i32` value or wasm32 offset through `i64.extend_i32_u`, while `unerase_i32` selects the low bits through `i32.wrap_i64`. A runtime value that cannot fit this payload must be represented indirectly rather than expanding every generic ABI value into a tag-payload pair.

Natural Unit has no slot, but representation-polymorphic Unit uses canonical erased payload `i64 0` so generic signatures remain fixed. `erase_unit` produces that payload without a source slot, and `unerase_unit` consumes it without a destination slot. A nonzero static Unit LayoutId supplies no-op cleanup and does not describe a heap object.

These erasure bridges are consuming representation moves. They transfer any source ownership into the destination without retain or release. If the source owner must remain live, ownership lowering first creates the required additional owner. They are compiler-internal representation operations rather than source numeric conversions.

A callable also fits the erased payload directly. Its low 32 bits hold the `FunctionId` or Wasm table index and its high 32 bits hold the wasm32 closure-environment offset. The callable's layout witness retains or releases the nonzero environment component.

The packed bits alone are insufficient when a callable crosses a representation-polymorphic boundary and substitution changes an argument or result representation. Monomorphic callables retain their natural Wasm signatures. The compiler therefore synthesizes ordinary adapter closures at such boundaries. A direct erased callable value uses a canonical callable ABI in which each represented immediate argument or result crossing the erased type boundary uses `i64`; Unit remains absent. The adapter recursively erases contravariant arguments before calling the captured source callable and unerases covariant results afterward.

An adapter environment captures the source callable and every free LayoutId witness required by those conversions. Explicit `forall` witnesses remain explicit callable inputs and are forwarded in declaration order; they are not duplicated as captured source types. Nested callable values are adapted recursively through the same rule. Nominal objects are not deep-copied merely because a field contains a callable: their own generic field construction and projection boundaries perform the required adaptation.

Each erased type parameter that affects runtime representation is accompanied by a hidden representation layout witness identified by `LayoutId`. The descriptor contains only the layout and ownership behavior required by generic code, including retain, release, destruction, and generic field handling. It is not a full Lane type, does not support source-level reflection or dynamic typechecking, and is not visible as a Lane function parameter.

Nominal data values share the witness-only Reference recipe when they cross an erased boundary. Its retain and release helpers operate on the wasm32 reference and obtain the concrete destruction LayoutId from that object's header if the count reaches zero. Reference is never written into an allocated object's header, does not select a representative constructor shape, and carries no source nominal identity.

`LayoutId` is an immediate `u32` index into an image-owned static layout table. Layout entries remain valid for the loaded image's lifetime and are neither dynamically allocated nor reference-counted. An entry records the erased representation kind, size, alignment, and ownership behavior required by generic code.

Static monomorphic ARC lowers directly from known representation facts. ARC over an erased generic value uses the associated layout witness. Generic data that owns erased fields retains enough descriptor information for its destructor to release those fields correctly after the constructing call has returned.

LoisVM interpretation may continue to use tagged VM values, but the Wasm backend does not reproduce that representation for monomorphic code. The retained representation metadata exists so an independent backend can lower decoded `.lbp` bytecode without consulting Buslane/core or compiler-private VM CFG data.

Consequences:

- Lane does not require whole-program monomorphization before bytecode emission.
- Monomorphic Wasm calls use one natural Wasm value per Lane argument and result.
- Generic Wasm boundaries use `LayoutId` witnesses and `i64` erased payloads.
- Erased Unit uses canonical zero payload and a no-op Unit LayoutId.
- I32 width changes, I64 identity transfers, and F64 bit reinterpretation use explicit erasure bridges.
- Erasure bridges consume and transfer ownership without ARC.
- Callable ABI changes use compiler-generated ordinary adapter closures.
- Adapter environments own the source callable and capture only required free layout witnesses.
- Explicit `forall` witnesses remain explicit and are forwarded by adapters.
- Nested callable coercions recurse through argument and result boundaries.
- Full source types and source-level type arguments remain absent from bytecode.
- Layout witnesses are runtime representation metadata, not a bytecode type system or verifier.
- Nominal erased values share the witness-only Reference recipe.
- Layout witnesses index static image-owned entries and have no ARC behavior.
- Generic ARC is descriptor-directed; monomorphic ARC remains direct.
- Generic objects that outlive a call retain the descriptor information needed by destruction.
- Bytecode remains sufficient input for independent Wasm lowering.
