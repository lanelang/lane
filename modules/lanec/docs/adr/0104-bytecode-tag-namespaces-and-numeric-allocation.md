# Bytecode tag namespaces and numeric allocation

Every LoisVM bytecode `u8` tag namespace has an explicit normative numeric assignment. Encoders and decoders must not derive wire values from MoonBit enum declaration order, generated variant ordinals, or backend-internal opcode numbers.

Tag namespaces are independent. Representation, cleanup, result, instruction, terminator, function-entry, layout-recipe, object-shape, and other tagged records may reuse the same numeric values because the surrounding schema determines the namespace.

Every namespace reserves `0x00` as invalid so zero-filled or uninitialized data does not silently denote a valid variant. `0xFF` is also reserved and invalid, but it is not an escape code or extension prefix. Unknown and reserved values make image loading fail.

Known tags are assigned contiguously from `0x01` in canonical declaration order. Declaration order groups related variants for human readability, but the numeric value itself carries no semantic family or range meaning. Artificial hexadecimal family ranges are not reserved.

Within one `bytecode_schema_version`, the complete accepted tag set and every numeric assignment are frozen. Adding, removing, or renumbering a tag requires a schema-version change. A removed assignment remains documented for its original schema and is not reinterpreted inside that version.

The v1 slot representation namespace is:

- `I32 = 0x01`
- `I64 = 0x02`
- `F64 = 0x03`

The v1 slot cleanup namespace is:

- `Trivial = 0x01`
- `OwnedRef = 0x02`
- `OwnedCallable = 0x03`
- `OwnedErased = 0x04`

The v1 function-result namespace is:

- `Unit = 0x01`
- `I32 = 0x02`
- `I64 = 0x03`
- `F64 = 0x04`

The v1 function-entry namespace is BytecodeBody `0x01` and RuntimeImport `0x02`. The layout-recipe namespace follows canonical recipe order from Unit `0x01` through Environment `0x08`. The Object Shape namespace is Data `0x01` and Environment `0x02`. LayoutOperand is Immediate `0x01` and Witness `0x02`.

Instruction and terminator tags use independent namespaces. ADR-0105 defines the exact canonical v1 tables: instructions occupy `0x01..0x42`, and terminators occupy `0x01..0x07`. Neither namespace shares ordinals with the other or with Wasm opcodes.

Consequences:

- Serialized tags remain stable across compiler implementation refactors.
- Zero-filled data cannot decode as a valid variant.
- `0xFF` remains unavailable without introducing an implicit extension mechanism.
- Independent namespaces keep local tables compact and readable.
- Contiguous numbering avoids compatibility claims implied by unused family ranges.
- Schema-version changes, not unknown-tag skipping, govern instruction-set evolution.
- Representation, cleanup, result, function-entry, layout-recipe, Object Shape, and LayoutOperand tags have complete v1 wire assignments.
- Instruction and terminator numbering is fixed by the canonical v1 tables.
