# Bytecode constants and String pool

LoisVM encodes scalar constants directly in producing instructions. `const_int(destination, value)` carries signed `i64le` bits. `const_double(destination, bits)` carries raw `u64le` IEEE-754 binary64 bits, preserving NaN payloads and signed zero at load time; later arithmetic need not preserve a NaN payload. `const_bool(destination, value)` carries one byte and accepts only zero or one; every other byte is a decoding error. `Unit` has no slot and no constant instruction.

`const_layout(destination, LayoutId)` writes one nonzero static image layout identifier into a logically dead `I32 + Trivial` witness slot. Layout constants are compiler-internal inline instruction operands and do not occupy the String constant pool.

`const_function(destination, FunctionId)` constructs a capture-free callable. Its function component is the supplied valid nonzero no-context `FunctionId` and its environment is zero. The logically dead destination is `I64 + OwnedCallable`; its zero environment makes callable retain and release no-ops.

The v1 image constant pool contains Strings only. `const_string(destination, ConstantId)` obtains the pooled String selected by a zero-based identifier and establishes an owned logical `I32` reference in the destination. The runtime object is image-owned and stores the immortal count, so loading the constant performs no retain and later retain-copy or release leaves its count unchanged.

After whole-program reachability and optimization, the linker discards unreferenced String constants, deduplicates the remaining constants by exact ASCII bytes, and sorts them lexicographically by unsigned raw byte sequence. Sorting uses no locale or Unicode collation. `ConstantId` is the resulting zero-based table position, and the linker remaps every `const_string` operand after final ordering. If present, the empty String sorts first and receives `ConstantId = 0`. Numeric constants and function identifiers never consume pool entries.

The binary pool starts with `u32le` entry count. Each entry is `u32le` byte length followed by that many ASCII bytes. V1 entries need no kind tag because every entry is a String. Supporting another static constant kind requires a bytecode schema-version change and a corresponding producing opcode or explicitly generalized pool schema.

In the Wasm tier, active data segments materialize each pooled String with the common header, immortal count, String `LayoutId`, byte length, bytes, and alignment padding. `const_string` lowers to the object's static wasm32 address. The interpreter provides an ownership-equivalent image-owned String value rather than exposing a Wasm address.

Consequences:

- Int, Double, and Bool constants are inline instruction operands.
- Double serialization preserves raw IEEE-754 bits.
- Bool constants accept only byte zero or one.
- Layout constants are inline nonzero identifiers in trivial witness slots.
- Unit has no constant instruction.
- Capture-free function constants carry `FunctionId` and environment zero.
- V1 constant-pool entries are Strings only.
- String literals are deduplicated by exact ASCII bytes.
- Unreferenced String literals do not enter the linked pool.
- Constant IDs follow unsigned lexicographic byte order and are not language-observable.
- The empty String receives ID zero when present.
- Pooled Strings are immortal image-owned objects.
- Wasm constant loads produce static addresses without retain operations.
