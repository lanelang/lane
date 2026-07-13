# Erased payload and layout witness contract

Every representation-polymorphic runtime value uses one `I64 + OwnedErased` payload slot and one associated `I32 + Trivial` LayoutId witness slot. The cleanup category remains `OwnedErased` even when the selected layout has no ownership work, such as Unit, Int, Bool, or Double. This gives generic code one static slot discipline independent of the runtime witness.

`const_layout(destination, LayoutId)` materializes a known nonzero image LayoutId in a logically dead witness slot. Its binary encoding is destination `SlotId` followed by `u32le LayoutId`; it is an inline compiler-internal constant and does not occupy the String constant pool. Hidden function witnesses and copied witness slots provide the other LayoutId sources.

An erase bridge consults the destination erased slot's companion. That companion must contain the applicable LayoutId before the payload owner is established. An unerase bridge consults the source erased slot's companion. The six bridge opcodes encode only destination and source SlotIds and carry no witness operand.

The companion witness remains unchanged for the complete live interval of every erased payload that names it. One witness slot may serve multiple simultaneously live erased payloads when they use the same LayoutId. It may be reused only after all dependent payloads have been consumed.

Natural bridge endpoints follow representation and cleanup categories. I32 bridges accept or produce `Trivial` Bool and `OwnedRef` references. I64 bridges accept or produce `Trivial` Int and `OwnedCallable` callables. F64 bridges accept or produce `Trivial` Double. Every erased endpoint is `I64 + OwnedErased`.

Natural Unit has no slot. `erase_unit(destination)` establishes canonical zero in an erased destination whose companion already contains the nonzero Unit LayoutId. `unerase_unit(source)` consumes that erased payload and produces no destination. Trusted bytecode guarantees that erased Unit bits are zero. The Unit layout has no-op retain and release behavior and does not describe a heap allocation.

Every bridge consumes its source and writes a logically dead destination without implicit retain, release, or overwrite cleanup. Preserving a trivial source requires a prior `copy`; preserving an owned source requires a prior `retain_copy`. Trusted metadata guarantees that LayoutId, payload kind, Bool bits, reference alignment, and callable structure agree. LoisVM performs no dynamic type or representation check.

Call instructions do not erase or unerase operands implicitly. Lowering establishes the required erased argument slots before a generic call and explicitly unerases generic results before natural-representation use. Ordinary `move` remains a cleanup-compatible ownership transfer and never crosses the erasure boundary.

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
- Ordinary move does not perform erasure.
