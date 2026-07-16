# Function table and executable entry encoding

A LoisVM bytecode section starts with nonzero `entry_function_id:u32le`, `initializer_function_id:u32le`, and `function_count:u32le`. Zero initializer means absent. A zero function count is invalid. Function table position zero corresponds to `FunctionId = 1`; valid identifiers are the contiguous range `1..function_count`.

The selected executable entry must identify a BytecodeBody entry whose body metadata declares no environment, zero layout-witness parameters, zero user parameters, and Unit result. A RuntimeImport entry cannot be the selected entry. Link validates the original exported symbol, source type, and supported effects; executable bytecode retains only FunctionId.

Every function-table entry begins with `function_entry_tag:u8`. BytecodeBody is `0x01`, and RuntimeImport is `0x02`. Entries have no common byte-length field and unknown tags are decoding errors rather than skippable extensions.

A BytecodeBody entry contains the existing `u32le` body byte length and exact body bytes. FunctionId comes from table position. Context kind, witness arity, user arity, and result representation come from body metadata and are not duplicated in an entry header.

A RuntimeImport entry contains `abi_major:u32le`, `user_arity:u32le`, `symbol_length:u32le`, and exact symbol bytes. Runtime imports are implicitly no-context and have zero layout-witness parameters. Symbols are nonempty case-sensitive ASCII byte strings without NUL. The runtime symbol registry remains the sole authority for parameter and result primitive kinds, so bytecode stores no kind arrays.

After whole-program optimization and final body formation, the linker emits bytecode bodies in final deterministic body-list order. It deduplicates runtime imports by `(symbol, abi_major, user_arity)` and appends them sorted lexicographically by symbol bytes, then ABI major, then user arity. FunctionId assignment is deterministic for the same compiler version, exact inputs, options, and selected entry, but is not stable across compiler, optimization, or linked-program changes.

The selected entry is stored explicitly and need not be FunctionId 1. FunctionId is not a module ABI identity or persistent symbol. The linker performs no call-graph canonical labeling, body-hash ordering, sparse allocation, or hash-derived identifier assignment.

Strict decoding rejects malformed fields, unknown entry tags, and non-ASCII or otherwise invalid symbols before runtime import resolution begins. Loading additionally rejects zero function count, an out-of-range or incompatible selected entry, unresolved imports, and ABI-major or arity mismatch. Resolution occurs only after complete bytecode-section decoding and may not execute or re-enter Lane code. Any failure discards partial bindings. No host pointer or resolved binding is serialized.

Consequences:

- Executable bytecode stores one selected FunctionId.
- The selected entry is a no-context, witness-free, zero-argument Unit bytecode body.
- FunctionId is one-based over zero-based table position.
- Function entries are BytecodeBody or RuntimeImport.
- Their wire tags are BytecodeBody `0x01` and RuntimeImport `0x02`.
- Bytecode body signature metadata is not duplicated in its entry header.
- Runtime imports are no-context and witness-free.
- Runtime import symbols are nonempty case-sensitive ASCII without NUL.
- Runtime import parameter and result kinds remain registry-owned.
- Runtime imports are deduplicated and deterministically sorted after bodies.
- Body FunctionIds follow the final deterministic post-optimization body list.
- FunctionIds are reproducible within identical builds but unstable across build changes.
- The selected entry is not forced to FunctionId 1.
- FunctionId is not a module ABI or persistent identity.
- Unknown tags and incompatible imports fail decoding or loading.
- Source export names and types do not survive in executable bytecode.
