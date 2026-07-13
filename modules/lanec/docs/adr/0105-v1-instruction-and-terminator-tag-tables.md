# V1 instruction and terminator tag tables

LoisVM v1 assigns one explicit opcode to every portable instruction. The instruction namespace is:

| Tag | Instruction | Tag | Instruction |
| --- | --- | --- | --- |
| `0x01` | `copy` | `0x02` | `move` |
| `0x03` | `retain_copy` | `0x04` | `release` |
| `0x05` | `const_int` | `0x06` | `const_double` |
| `0x07` | `const_bool` | `0x08` | `const_layout` |
| `0x09` | `const_function` | `0x0A` | `const_string` |
| `0x0B` | `call_direct` | `0x0C` | `call_value` |
| `0x0D` | `make_data` | `0x0E` | `load_tag` |
| `0x0F` | `borrow_field` | `0x10` | `consume_fields` |
| `0x11` | `make_env` | `0x12` | `borrow_capture` |
| `0x13` | `consume_captures` | `0x14` | `make_closure` |
| `0x15` | `string_length` | `0x16` | `string_concat` |
| `0x17` | `string_slice` | `0x18` | `string_eq` |
| `0x19` | `int_add` | `0x1A` | `int_sub` |
| `0x1B` | `int_mul` | `0x1C` | `int_neg` |
| `0x1D` | `int_div` | `0x1E` | `int_rem` |
| `0x1F` | `int_and` | `0x20` | `int_or` |
| `0x21` | `int_xor` | `0x22` | `int_not` |
| `0x23` | `int_shl` | `0x24` | `int_shr_s` |
| `0x25` | `int_eq` | `0x26` | `int_ne` |
| `0x27` | `int_lt` | `0x28` | `int_le` |
| `0x29` | `int_gt` | `0x2A` | `int_ge` |
| `0x2B` | `bool_not` | `0x2C` | `bool_eq` |
| `0x2D` | `bool_ne` | `0x2E` | `double_add` |
| `0x2F` | `double_sub` | `0x30` | `double_mul` |
| `0x31` | `double_div` | `0x32` | `double_neg` |
| `0x33` | `double_eq` | `0x34` | `double_ne` |
| `0x35` | `double_lt` | `0x36` | `double_le` |
| `0x37` | `double_gt` | `0x38` | `double_ge` |
| `0x39` | `int_to_double` | `0x3A` | `double_to_int` |
| `0x3B` | `erase_i32` | `0x3C` | `unerase_i32` |
| `0x3D` | `erase_i64` | `0x3E` | `unerase_i64` |
| `0x3F` | `erase_f64` | `0x40` | `unerase_f64` |
| `0x41` | `erase_unit` | `0x42` | `unerase_unit` |

The independent terminator namespace is:

| Tag | Terminator |
| --- | --- |
| `0x01` | `jump` |
| `0x02` | `branch_bool` |
| `0x03` | `switch_tag` |
| `0x04` | `return` |
| `0x05` | `tail_call_direct` |
| `0x06` | `tail_call_value` |
| `0x07` | `unreachable` |

Returning direct and value calls are instructions. Tail calls, returns, ordinary CFG transfers, and unreachable paths are terminators. A block's `instruction_count` covers only its instruction array and excludes its required final terminator. An instruction tag in terminator position or a terminator tag in instruction position is unknown in that namespace and makes loading fail.

V1 contains no `nop`, generic arithmetic instruction with an operation subtag, opcode alias, source-location instruction, profiling instruction, or debugging instruction. Source maps and diagnostics, if added, belong outside the executable instruction stream.

The lowercase snake-case names are canonical for specification text, disassembly, and diagnostics, but no name string appears in the binary. Numeric order improves human readability only; it has no relationship to Wasm opcodes, compiler enum ordinals, interpreter dispatch indices, or semantic family ranges.

The tables are normative encoder and decoder requirements. Adding an instruction or terminator, removing one, introducing an alias, or changing an assignment requires a new bytecode schema version rather than filling or reusing a v1 value.

Consequences:

- V1 has 66 instruction tags from `0x01` through `0x42`.
- V1 has seven terminator tags from `0x01` through `0x07`.
- Instruction and terminator positions decode against different namespaces.
- Calls return normally only as instructions and transfer tail control only as terminators.
- Every block stores its terminator outside the counted instruction array.
- Portable bytecode has no no-op, opcode alias, or embedded debug instruction.
- Opcode names are diagnostic vocabulary rather than serialized operands.
- Opcode evolution requires a bytecode schema-version change.
