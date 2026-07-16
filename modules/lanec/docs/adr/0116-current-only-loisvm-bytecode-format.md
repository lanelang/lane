# Current-only LoisVM bytecode format

LoisVM bytecode is an internal compiler-runtime contract maintained in lockstep. A bytecode section carries neither magic nor an independent schema version, and `loisvm/bytecode` retains no legacy decoder. `bytecode_image_to_binary` always emits the current canonical layout, while `parse_bytecode_image_binary` accepts only that layout.

The bytecode section has this fixed order:

1. nonzero `entry_function_id:u32le`;
2. `initializer_function_id:u32le`, where zero means absent;
3. `function_count:u32le` and the Function table;
4. `global_count:u32le` and the Instance Global table;
5. the Layout Recipe, Object Shape, and String Constant tables.

The initializer, Instance Global table, `init_global`, and `borrow_global` are therefore ordinary parts of the format rather than features selected by a bytecode version. Empty initializer and global fields are still encoded. The remaining records and tags keep the latest assignments established by the superseded versioned ADRs.

Persisted Lane programs use the enclosing linked-program artifact schema as their compatibility boundary. This format change raises `linked_program_schema_version` to 5. A loader rejects older linked-program artifacts before invoking the bytecode decoder, and users regenerate them with the matching compiler. A raw bytecode section exchanged outside that container has no compatibility guarantee and requires a matching LoisVM producer and consumer.

Future incompatible bytecode changes replace the current format directly and raise every enclosing persisted-artifact schema that embeds it. LoisVM does not add bytecode-local version negotiation, compatibility branches, optional legacy fields, or unknown-tag skipping.

## Consequences

- Bytecode encoding has no leading version byte.
- `UnsupportedSchema` is not a bytecode decode error.
- Every image encodes initializer and global-table fields.
- The encoder, decoder, disassembler, interpreter, and Wasm backend target one current model.
- Linked-program schema version 5 identifies the current persisted bytecode payload.
- Raw bytecode binaries are lockstep implementation artifacts, not independently versioned files.
- ADR-0085 and ADR-0114 remain historical records and are superseded for versioning and top-level layout.
