# Numeric conversion and erasure bridges

LoisVM distinguishes source-authorized numeric conversion from compiler-internal representation erasure. Neither category creates implicit coercion between Lane `Int` and `Double`.

`int_to_double(destination, source)` converts signed `I64 + Trivial` Int to `F64 + Trivial`. Wasm lowering uses `f64.convert_i64_s`, with IEEE round-to-nearest-ties-even behavior. Large integers may lose precision; that loss is part of the explicit conversion.

`double_to_int(destination, source)` converts `F64 + Trivial` to signed `I64 + Trivial` by truncating toward zero. Wasm lowering uses trapping `i64.trunc_f64_s`. NaN, positive or negative infinity, and finite results outside the signed i64 range are undefined conversion inputs and may produce a non-unwinding conversion trap. Private ARC cleanup does not run, and the embedding discards the current instance. V1 provides no saturating or non-trapping float-to-int opcode.

Compiler-internal representation erasure uses eight bridge instructions:

- `erase_i32(destination, source)` zero-extends natural `I32` bits to erased `I64` with `i64.extend_i32_u`.
- `unerase_i32(destination, source)` selects the low 32 bits with `i32.wrap_i64`.
- `erase_i64(destination, source)` preserves `I64` bits while transferring into erased cleanup metadata.
- `unerase_i64(destination, source)` preserves `I64` bits while transferring into natural cleanup metadata.
- `erase_f64(destination, source)` reinterprets binary64 bits with `i64.reinterpret_f64`.
- `unerase_f64(destination, source)` restores binary64 bits with `f64.reinterpret_i64`.
- `erase_unit(destination)` produces canonical erased `i64 0` without a natural source slot.
- `unerase_unit(source)` consumes erased Unit without producing a natural destination slot.

An erasure bridge consumes its source logical value and transfers any ownership into the destination without retain or release. The destination cleanup category and companion witness describe the erased or natural ownership behavior. If later uses require the source owner, ARC insertion establishes another owner before the bridge. Trusted bytecode guarantees that `unerase_i32` selects the intended Bool or reference representation and that every companion witness matches the erased payload.

Every bridge destination is logically dead. Before an erase bridge establishes `I64 + OwnedErased`, its destination companion must already contain the applicable LayoutId. An unerase bridge consults the source companion. Bridge instructions carry no witness operand. The companion remains unchanged throughout the erased payload's live interval and may be shared by multiple live payloads.

The natural cleanup categories are constrained by width. I32 bridges transfer from or to `Trivial` Bool or `OwnedRef`; I64 bridges transfer from or to `Trivial` Int or `OwnedCallable`; F64 bridges transfer from or to `Trivial` Double. Natural Unit has no slot, so its bridge endpoint is absent. The erased side is always `I64 + OwnedErased`, including layouts whose cleanup is a no-op.

Lane Int and packed Callable already use `I64`, so their bridges do not change physical bits. Explicit `erase_i64` and `unerase_i64` still mark the logical erasure boundary, transfer ownership, and change which slot cleanup metadata governs the payload. Ordinary `move` remains a cleanup-compatible slot transfer and does not perform type erasure.

Call instructions never perform representation erasure implicitly. A natural value crosses into a generic argument slot through the applicable erase bridge before the call; a generic result crosses back through the applicable unerase bridge. Preserving a consumed trivial source requires a preceding `copy`, while preserving an owned source requires a preceding `retain_copy`.

The two numeric conversions and six width-bearing bridges encode destination `SlotId` then source `SlotId`. `erase_unit` encodes only destination and `unerase_unit` only source. Numeric conversions read trivial sources non-consumingly in the ownership sense; erasure bridges transfer or establish the erased ownership state explicitly.

Consequences:

- Int-to-Double is explicit and may lose precision.
- Double-to-Int truncates toward zero.
- Invalid Double-to-Int conversion may trap without cleanup.
- Saturating float-to-int conversion is absent from v1.
- I32 erasure uses unsigned zero extension and low-bit wrapping.
- I64 erasure preserves bits but explicitly transfers cleanup interpretation.
- F64 erasure preserves bits through reinterpretation.
- Unit erasure produces and consumes canonical zero without a natural slot.
- Erasure bridges consume and transfer ownership without ARC.
- Erase consults the destination companion; unerase consults the source companion.
- Companion witnesses are initialized first, immutable while payloads live, and shareable.
- Generic payloads uniformly use `OwnedErased`, including no-op layouts.
- Calls do not perform implicit erasure or unerasure.
- Ordinary move does not cross a representation-erasure boundary.
- Representation erasure does not imply source numeric coercion.
