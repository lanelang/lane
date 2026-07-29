# LoisVM Bytecode

`Milky2018/loisvm/bytecode` owns the portable register-style execution image shared by the LoisVM interpreter and WebAssembly backend. This document is the producer-facing reference for the current bytecode model, instruction set, ownership contract, and binary instruction tags.

LoisVM bytecode is trusted compiler output rather than a sandbox format. The decoder validates framing, table references, local metadata, and basic image structure, but a producer remains responsible for type-compatible slots, valid data flow, call signatures, ownership balance, object-shape compatibility, and every instruction-specific precondition described below.

## Image model

A `BytecodeImage` contains one unified function table, an optional instance initializer, an instance-global table, layout recipes, object shapes, and an ASCII constant pool. `FunctionId` and `LayoutId` are nonzero one-based identifiers; `GlobalId`, `BlockId`, `SlotId`, `ConstantId`, and `ObjectShapeId` are zero-based dense table indices.

Each `FunctionEntry` is either a `BytecodeBody` or a `RuntimeImport`. The selected `entry` and optional `initializer` must name no-context, witness-free, zero-argument bytecode bodies returning `Unit`. A nonempty global table requires an initializer, and the initializer must initialize every global exactly once before the selected entry begins.

A `FunctionBody` owns its slot table and ordered blocks. Block zero is the entry block and has no block parameters. Every block contains ordinary instructions followed by exactly one terminator. An `Edge` transfers its arguments to the target block parameters in parallel.

```mbt check
///|
test "a minimal LoisVM bytecode image round-trips" {
  let image : BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    functions: [
      BytecodeBody({
        slots: [
          { representation: I64, cleanup: Trivial, erased_companion: None },
          { representation: I64, cleanup: Trivial, erased_companion: None },
          { representation: I64, cleanup: Trivial, erased_companion: None },
        ],
        inputs: { environment: None, witnesses: [], user_parameters: [] },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstInt({ value: 0 }, 40L),
              ConstInt({ value: 1 }, 2L),
              IntAdd({ value: 2 }, { value: 0 }, { value: 1 }),
            ],
            terminator: Return(None),
          },
        ],
      }),
    ],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let decoded = match
    parse_bytecode_image_binary(bytecode_image_to_binary(image)) {
    Ok(decoded) => decoded
    Err(error) => fail("bytecode round-trip failed: \{Repr(error)}")
  }
  assert_eq(decoded, image)
}
```

## Slots, representations, and ownership

Every `SlotId` has one immutable `SlotMetadata` entry. The representation fixes its physical value class, while cleanup determines whether the slot owns a resource.

| Representation | Runtime contents |
| --- | --- |
| `I32` | Boolean values, layout witnesses, object references, String references, and other 32-bit runtime values |
| `I64` | Lane `Int`, packed callable values, and erased payloads |
| `F64` | Lane `Double` |

| Cleanup | Legal representation | Meaning |
| --- | --- | --- |
| `Trivial` | `I32`, `I64`, or `F64` | The bits require no cleanup. |
| `OwnedRef` | `I32` | The slot owns one reference-counted object or String reference. |
| `OwnedCallable` | `I64` | The slot owns one callable value; a captured callable owns its environment reference. |
| `OwnedErased` | `I64` | The slot owns an erased payload whose retain and release operations are selected by an `I32 + Trivial` layout companion slot. |

Only `OwnedErased` slots have `erased_companion`. A slot containing an owner is live after an owning definition and must be consumed, moved, returned, or explicitly released exactly once. A borrowed definition does not create an owner and must not outlive the owner from which it was projected.

Instruction operands use the following conventions:

- `destination` is written by the instruction and must have metadata matching the documented result representation and ownership.
- A borrowed input remains owned by its existing owner and receives no retain.
- A consumed input transfers or destroys its ownership; subsequent use requires a separately retained owner.
- Witness arrays and `LayoutOperand::Witness` values are borrowed `I32 + Trivial` layout IDs.
- Argument, field, capture, edge, and result order is semantically significant.

## Object and layout model

`LayoutRecipe` describes a runtime layout. `Data(ObjectShapeId)` and `Environment(ObjectShapeId)` refer to entries in the object-shape table, while `Reference` is the witness-only erased reference layout. `LayoutOperand::Immediate` names an image layout directly and `LayoutOperand::Witness` reads a layout ID from a slot.

A `DataShape` stores a constructor tag, stored layout witnesses, and ordered field schemas. An `EnvironmentShape` stores layout witnesses and ordered capture schemas. A `MemberSchema` fixes the member representation and cleanup; an `OwnedErased` member must name the stored-witness ordinal used for its cleanup.

`ProjectionResult` always names a value destination and may name a layout-witness destination. The optional witness destination is required when the projected member is `OwnedErased` and absent otherwise. `ProjectionSelection` pairs one member index with its destinations.

## Function ABI

The callee receives an optional hidden environment, ordered layout witnesses, and ordered user arguments in the slots named by `FunctionInputs`. The caller and callee counts and representations must agree exactly.

Environments, callable values, and user arguments are transferred into calls. Layout witnesses are borrowed. A non-`Unit` call must provide a destination matching the callee result representation; a `Unit` call must omit the destination. `RuntimeImport` parameters of kind `Unit` are zero-width and do not consume an argument slot.

## Instruction encoding

Every ordinary instruction begins with the listed `u8` opcode. Operands follow in constructor order. IDs and collection lengths use little-endian `u32`; `ConstInt` and `ConstDouble` payloads use little-endian 64-bit bits; an optional slot uses zero for `None` and `slot.value + 1` for `Some`; an array uses a `u32` count followed by its elements.

The constructor spelling is the public MoonBit API. The lowercase spelling shown in descriptions is the human-readable disassembly name.

### Ownership and constants

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x01` | `Copy(destination, source)` | `copy`; copies bits between representation-compatible `Trivial` slots. It does not retain and must not duplicate an owner. |
| `0x02` | `Move(destination, source)` | `move`; transfers a representation- and cleanup-compatible logical value and its ownership from `source` to `destination`. |
| `0x03` | `RetainCopy(destination, source)` | `retain_copy`; retains the nontrivial value according to the destination cleanup and writes a second owner while leaving the source owner live. |
| `0x04` | `Release(source)` | `release`; performs cleanup selected by the source metadata and consumes the source owner. `Trivial` cleanup is a no-op. |
| `0x05` | `ConstInt(destination, value)` | `const_int`; writes the signed 64-bit integer to an `I64 + Trivial` destination. |
| `0x06` | `ConstDouble(destination, bits)` | `const_double`; reinterprets the supplied 64-bit pattern as an IEEE 754 `Double` and writes an `F64 + Trivial` destination. |
| `0x07` | `ConstBool(destination, value)` | `const_bool`; writes canonical `0` or `1` to an `I32 + Trivial` destination. |
| `0x08` | `ConstLayout(destination, layout)` | `const_layout`; writes the nonzero `LayoutId` value to an `I32 + Trivial` destination. |
| `0x09` | `ConstFunction(destination, function)` | `const_function`; creates a capture-free callable for the function-table entry in an `I64 + OwnedCallable` destination. |
| `0x0A` | `ConstString(destination, constant)` | `const_string`; creates an owning String reference for the ASCII constant-pool entry in an `I32 + OwnedRef` destination. |

### Calls and closures

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x0B` | `CallDirect(function, environment, witnesses, arguments, destination)` | `call_direct`; invokes the immediate function-table entry. The optional environment and all user arguments are consumed, witnesses are borrowed, and a non-`Unit` result is written to `destination`. |
| `0x0C` | `CallValue(callable, witnesses, arguments, destination)` | `call_value`; consumes the packed callable and user arguments, borrows witnesses, dispatches through the callable table, and writes an optional result. |
| `0x14` | `MakeClosure(destination, function, environment)` | `make_closure`; consumes one nonzero environment owner and packs it with the target function into an `I64 + OwnedCallable` destination. |

Direct calls use `environment=None` for no-context functions and `Some(slot)` for functions that require a closure environment. A `CallValue` extracts the immediate function and optional environment from the packed callable. Call depth limits, unresolved imports, host failures, and indirect ABI mismatches are execution failures rather than valid alternate results.

### Data and environment objects

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x0D` | `MakeData(destination, shape, layout, witnesses, fields)` | `make_data`; borrows the layout and witnesses, consumes every field owner in declaration order, and creates an `I32 + OwnedRef` Data object. |
| `0x0E` | `LoadTag(destination, source)` | `load_tag`; borrows a Data object and writes its shape constructor tag to an `I32 + Trivial` destination. |
| `0x0F` | `BorrowField(shape, source, index, result)` | `borrow_field`; checks the Data shape, borrows one field without retaining it, and optionally writes its stored layout witness. |
| `0x10` | `ConsumeFields(shape, source, selections)` | `consume_fields`; obtains owning results for the selected Data fields, consumes and releases the source object, and releases unselected owned members with the object. |
| `0x11` | `MakeEnv(destination, shape, layout, witnesses, captures)` | `make_env`; borrows the layout and witnesses, consumes every capture owner in schema order, and creates an `I32 + OwnedRef` Environment object. |
| `0x12` | `BorrowCapture(shape, source, index, result)` | `borrow_capture`; checks the Environment shape, borrows one capture without retaining it, and optionally writes its stored layout witness. |
| `0x13` | `ConsumeCaptures(shape, source, selections)` | `consume_captures`; obtains owning results for the selected captures, consumes and releases the source environment, and releases unselected owned captures with it. |
| `0x43` | `LoadObjectWitness(destination, shape, object, ordinal)` | `load_object_witness`; borrows a shape-compatible Data or Environment object and writes the selected stored `LayoutId` to an `I32 + Trivial` destination. |

Shapes, member indices, witness ordinals, field counts, capture counts, member representations, and optional projection-witness destinations must match the corresponding object-shape metadata. Violations are malformed trusted IR.

### Strings

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x15` | `StringLength(destination, source)` | `string_length`; borrows an ASCII String and writes its byte length as an `I64 + Trivial` value. |
| `0x16` | `StringConcat(destination, left, right)` | `string_concat`; consumes two String owners and creates a newly allocated `I32 + OwnedRef` String containing their concatenation. |
| `0x17` | `StringSlice(destination, source, start, length)` | `string_slice`; consumes the source String, borrows nonnegative `I64` byte offset and length operands, and creates a new owning String for the requested in-bounds byte range. |
| `0x18` | `StringEq(destination, left, right)` | `string_eq`; borrows both Strings and writes canonical Boolean byte equality to an `I32 + Trivial` destination. |

Strings and constant-pool entries are ASCII in the current bytecode contract, so byte length and character length coincide. A producer must prove `start >= 0`, `length >= 0`, and `start + length <= source.length`.

### Integer operations

Integer operands and arithmetic destinations use `I64 + Trivial`; comparison destinations use `I32 + Trivial`. Arithmetic is signed 64-bit two's-complement arithmetic, comparisons are signed, and shift counts use their low six bits.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x19` | `IntAdd(destination, left, right)` | `int_add`; computes `left + right`. |
| `0x1A` | `IntSub(destination, left, right)` | `int_sub`; computes `left - right`. |
| `0x1B` | `IntMul(destination, left, right)` | `int_mul`; computes `left * right`. |
| `0x1C` | `IntNeg(destination, source)` | `int_neg`; computes `0 - source`. |
| `0x1D` | `IntDiv(destination, left, right)` | `int_div`; computes signed division truncated toward zero and traps on division by zero or `Int64::min_value() / -1`. |
| `0x1E` | `IntRem(destination, left, right)` | `int_rem`; computes the signed remainder, traps on division by zero, and yields zero for `Int64::min_value() % -1`. |
| `0x1F` | `IntAnd(destination, left, right)` | `int_and`; computes bitwise AND. |
| `0x20` | `IntOr(destination, left, right)` | `int_or`; computes bitwise OR. |
| `0x21` | `IntXor(destination, left, right)` | `int_xor`; computes bitwise XOR. |
| `0x22` | `IntNot(destination, source)` | `int_not`; complements all 64 bits. |
| `0x23` | `IntShl(destination, left, right)` | `int_shl`; shifts `left` left by `right & 63`. |
| `0x24` | `IntShrS(destination, left, right)` | `int_shr_s`; arithmetically shifts `left` right by `right & 63`. |
| `0x25` | `IntEq(destination, left, right)` | `int_eq`; writes whether the operands are equal. |
| `0x26` | `IntNe(destination, left, right)` | `int_ne`; writes whether the operands are unequal. |
| `0x27` | `IntLt(destination, left, right)` | `int_lt`; writes whether `left < right`. |
| `0x28` | `IntLe(destination, left, right)` | `int_le`; writes whether `left <= right`. |
| `0x29` | `IntGt(destination, left, right)` | `int_gt`; writes whether `left > right`. |
| `0x2A` | `IntGe(destination, left, right)` | `int_ge`; writes whether `left >= right`. |

### Boolean operations

Boolean inputs and outputs use canonical `I32 + Trivial` values.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x2B` | `BoolNot(destination, source)` | `bool_not`; writes `1` when `source` is zero and `0` otherwise. |
| `0x2C` | `BoolEq(destination, left, right)` | `bool_eq`; writes whether the `I32` operands are equal. |
| `0x2D` | `BoolNe(destination, left, right)` | `bool_ne`; writes whether the `I32` operands are unequal. |

### Double operations and conversions

Double operands and arithmetic destinations use `F64 + Trivial`; comparison destinations use `I32 + Trivial`. Arithmetic and ordered comparisons follow WebAssembly IEEE 754 semantics, including NaN behavior.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x2E` | `DoubleAdd(destination, left, right)` | `double_add`; computes `left + right`. |
| `0x2F` | `DoubleSub(destination, left, right)` | `double_sub`; computes `left - right`. |
| `0x30` | `DoubleMul(destination, left, right)` | `double_mul`; computes `left * right`. |
| `0x31` | `DoubleDiv(destination, left, right)` | `double_div`; computes IEEE 754 division. |
| `0x32` | `DoubleNeg(destination, source)` | `double_neg`; negates the source. |
| `0x33` | `DoubleEq(destination, left, right)` | `double_eq`; writes ordered equality. |
| `0x34` | `DoubleNe(destination, left, right)` | `double_ne`; writes inequality, including true for an unordered NaN comparison. |
| `0x35` | `DoubleLt(destination, left, right)` | `double_lt`; writes ordered `left < right`. |
| `0x36` | `DoubleLe(destination, left, right)` | `double_le`; writes ordered `left <= right`. |
| `0x37` | `DoubleGt(destination, left, right)` | `double_gt`; writes ordered `left > right`. |
| `0x38` | `DoubleGe(destination, left, right)` | `double_ge`; writes ordered `left >= right`. |
| `0x39` | `IntToDouble(destination, source)` | `int_to_double`; converts a signed `I64` integer to `F64`, rounding according to IEEE 754. |
| `0x3A` | `DoubleToInt(destination, source)` | `double_to_int`; truncates `F64` toward zero to signed `I64` and traps for NaN or a value outside `[-2^63, 2^63)`. |

### Representation erasure

Erasure instructions are ownership transfers between natural representations and the uniform `I64` erased representation. The source owner is consumed and the destination owner becomes live; no retain is implied.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x3B` | `EraseI32(destination, source)` | `erase_i32`; zero-extends the low 32 bits into an erased `I64` payload. |
| `0x3C` | `UneraseI32(destination, source)` | `unerase_i32`; extracts the low 32 bits of an erased `I64` payload into `I32`. |
| `0x3D` | `EraseI64(destination, source)` | `erase_i64`; transfers the unchanged 64-bit payload into erased form. |
| `0x3E` | `UneraseI64(destination, source)` | `unerase_i64`; transfers the unchanged erased payload into natural `I64` form. |
| `0x3F` | `EraseF64(destination, source)` | `erase_f64`; reinterprets the `F64` bit pattern as an erased `I64` payload. |
| `0x40` | `UneraseF64(destination, source)` | `unerase_f64`; reinterprets the erased `I64` bit pattern as `F64`. |
| `0x41` | `EraseUnit(destination)` | `erase_unit`; writes the canonical zero erased payload to an `I64` destination. |
| `0x42` | `UneraseUnit(source)` | `unerase_unit`; consumes an erased payload and produces no runtime value. |

An `OwnedErased` destination must name the layout companion governing the payload's retain and release behavior. Natural trivial values may use `Trivial` erased destinations when no ownership operation is required.

### Instance globals

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x44` | `InitGlobal(global, source)` | `init_global`; during the initializer only, consumes `source` into a previously uninitialized non-companion global and copies an erased layout companion when required. |
| `0x45` | `BorrowGlobal(destination, global)` | `borrow_global`; reads an initialized global into a borrowed destination without retaining it and copies its erased layout companion when required. |

Global metadata follows the same legal representation and cleanup combinations as slots. Every `OwnedErased` global must be immediately preceded by its `I32 + Trivial` companion global, and only the owning global is explicitly initialized.

## Terminators

Every terminator begins with the listed `u8` tag. Edge operands encode a target `BlockId` followed by an ordered slot array.

| Tag | Constructor | Semantics |
| --- | --- | --- |
| `0x01` | `Jump(edge)` | Transfers the edge arguments to the target parameters in parallel and begins the target block. |
| `0x02` | `BranchBool(condition, true_edge, false_edge)` | Borrows an `I32` condition, selects `true_edge` for nonzero and `false_edge` for zero, then performs the edge transfer. |
| `0x03` | `SwitchTag(tag, cases, default)` | Borrows an `I32` tag, selects `cases[tag]` when the tag is in range, otherwise selects `default`, then performs the edge transfer. |
| `0x04` | `Return(source)` | Returns `None` for a `Unit` function or consumes the owning source value for a non-`Unit` function. All other owned slots must already be dead. |
| `0x05` | `TailCallDirect(function, environment, witnesses, arguments)` | Replaces the current frame with a direct call, consuming the optional environment and arguments, borrowing witnesses, and preserving the current return destination. |
| `0x06` | `TailCallValue(callable, witnesses, arguments)` | Replaces the current frame with a callable-value call, consuming the callable and arguments, borrowing witnesses, and preserving the current return destination. |
| `0x07` | `Unreachable` | Traps if execution reaches the terminator. |

Edge arguments are logical transfers. Their count and representations must match the target block parameters exactly. Any owned value not transferred along the selected edge must already have been released.

## Producer checklist

Before publishing or executing an image, a producer must ensure:

- every identifier is in range and names an entry of the required category;
- every slot read is initialized and every destination has compatible representation and cleanup metadata;
- function, witness, argument, result, edge, field, capture, and projection arities agree exactly;
- every owning definition has one ownership-consuming path and every borrowed result remains within its owner's lifetime;
- object shapes, layout recipes, stored witness ordinals, and projection schemas agree;
- integer, conversion, String slicing, initialization, and `Unreachable` preconditions are respected;
- entry and initializer signatures satisfy the root-function contract;
- all constants and runtime-import symbols contain ASCII bytes;
- the image is encoded and decoded by the matching LoisVM implementation.

Use `bytecode_image_to_disassembly` for human inspection and `bytecode_image_to_binary` plus `parse_bytecode_image_binary` for persistence. The binary format has no independent compatibility version; compatibility belongs to the enclosing Lane linked-program artifact.

## Development

From the Lane workspace root:

```bash
moon test modules/loisvm/bytecode/README.mbt.md --target native
moon test modules/loisvm/bytecode --target native
moon info modules/loisvm/bytecode
moon fmt
```
