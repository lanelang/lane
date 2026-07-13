# Erased payload and layout witness contract

Every representation-polymorphic runtime value uses one `I64 + OwnedErased` payload slot and one associated `I32 + Trivial` LayoutId witness slot. The cleanup category remains `OwnedErased` even when the selected layout has no ownership work, such as Unit, Int, Bool, or Double. This gives generic code one static slot discipline independent of the runtime witness.

`const_layout(destination, LayoutId)` materializes a known nonzero image LayoutId in a logically dead witness slot. Its binary encoding is destination `SlotId` followed by `u32le LayoutId`; it is an inline compiler-internal constant and does not occupy the String constant pool. Hidden function witnesses and copied witness slots provide the other LayoutId sources.

An erase bridge consults the destination erased slot's companion. That companion must contain the applicable LayoutId before the payload owner is established. An unerase bridge consults the source erased slot's companion. The six bridge opcodes encode only destination and source SlotIds and carry no witness operand.

The companion witness remains unchanged for the complete live interval of every erased payload that names it. One witness slot may serve multiple simultaneously live erased payloads when they use the same LayoutId. It may be reused only after all dependent payloads have been consumed.

Opening an existential constructor may establish a branch-local witness independently of payload projection. The witness is loaded from the selected object's stored witness array and can serve generic calls, generic construction, or ARC for the opened binder even when the constructor has no payload field of that type. This does not reify the erased type or permit dynamic type comparison.

Natural bridge endpoints follow representation and cleanup categories. I32 bridges accept or produce `Trivial` Bool and `OwnedRef` references. I64 bridges accept or produce `Trivial` Int and `OwnedCallable` callables. F64 bridges accept or produce `Trivial` Double. Every erased endpoint is `I64 + OwnedErased`.

Natural Unit has no slot. `erase_unit(destination)` establishes canonical zero in an erased destination whose companion already contains the nonzero Unit LayoutId. `unerase_unit(source)` consumes that erased payload and produces no destination. Trusted bytecode guarantees that erased Unit bits are zero. The Unit layout has no-op retain and release behavior and does not describe a heap allocation.

Every bridge consumes its source and writes a logically dead destination without implicit retain, release, or overwrite cleanup. Preserving a trivial source requires a prior `copy`; preserving an owned source requires a prior `retain_copy`. Trusted metadata guarantees that LayoutId, payload kind, Bool bits, reference alignment, and callable structure agree. LoisVM performs no dynamic type or representation check.

Call instructions do not erase or unerase operands implicitly. Lowering establishes the required erased argument slots before a generic call and explicitly unerases generic results before natural-representation use. Ordinary `move` remains a cleanup-compatible ownership transfer and never crosses the erasure boundary.

When the erased payload itself contains a callable, an `erase_i64` bridge still moves only the packed callable bits and ownership. Before that bridge, lowering adapts the callable to the canonical erased-callable ABI when its typed parameter or result representations would otherwise differ. Unerasing performs the inverse sequence: move the packed bits into a callable slot, then wrap that callable in an ordinary adapter targeting the natural typed ABI. Layout witnesses guide the recursive conversions but never cause runtime type inspection.

Consequences:

- Generic payload slots always use `I64 + OwnedErased`.
- No-op primitive layouts do not change the erased cleanup category.
- Erased Unit is canonical zero with a nonzero no-op layout witness.
- `const_layout` materializes known witnesses without using the constant pool.
- Erase reads the destination companion and unerase reads the source companion.
- Bridge instructions carry no explicit witness operand.
- Companions are initialized first and immutable while dependent payloads live.
- Multiple payloads may share one witness slot.
- Natural bridge endpoints have representation-specific cleanup categories.
- Bridges consume sources and never clean overwritten destinations.
- Trusted bytecode establishes payload and witness compatibility.
- Calls contain no implicit representation conversion.
- Callable erasure adapts typed call ABI before moving packed bits.
- Callable unerasure adapts from the canonical erased-callable ABI afterward.
- Ordinary move does not perform erasure.
