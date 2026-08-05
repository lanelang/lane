# LoisVM Bytecode

`Milky2018/loisvm/bytecode` owns the portable register-style execution image shared by the LoisVM interpreter and WebAssembly backend. This document is the producer-facing reference for the current bytecode model, instruction set, ownership contract, and binary instruction tags.

LoisVM bytecode is a verified execution IR rather than a sandbox format. The package-owned verifier checks table identities, runtime representations, instruction contracts, control-flow edges, initialization dataflow, ownership balance, object shapes, and statically known direct-call signatures. Binary decoding, interpreter loading, and Wasm compilation reject an image unless it passes this verifier. Resource limits still bound decoding and execution; verification is not a general malicious-input sandbox proof.

## Image model

A `BytecodeImage` contains one canonical Callable ABI table, one unified
function table, an optional instance initializer, an instance-global table,
layout recipes, object shapes, and a valid UTF-8 String constant pool.
`FunctionId` and `LayoutId` are nonzero one-based identifiers;
`CallableAbiId`, `GlobalId`, `BlockId`, `SlotId`, `ConstantId`, and
`DataFamilyId` and `ObjectShapeId` are zero-based dense table indices.

Each `FunctionEntry` is either a `BytecodeBody` or a `RuntimeImport`. The selected `entry` and optional `initializer` must name no-context, witness-free, zero-argument bytecode bodies returning `Unit`. A nonempty global table requires an initializer, and the initializer must initialize every global exactly once before the selected entry begins.

A `FunctionBody` owns its slot table and ordered blocks. Block zero is the entry block and has no block parameters. Every block contains ordinary instructions followed by exactly one terminator. An `Edge` transfers its arguments to the target block parameters in parallel.

```mbt check
///|
test "a minimal LoisVM bytecode image round-trips" {
  let image : BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [
      BytecodeBody({
        slots: [
          {
            representation: I64,
            cleanup: Trivial,
            kind: ScalarValue,
            erased_companion: None,
          },
          {
            representation: I64,
            cleanup: Trivial,
            kind: ScalarValue,
            erased_companion: None,
          },
          {
            representation: I64,
            cleanup: Trivial,
            kind: ScalarValue,
            erased_companion: None,
          },
        ],
        inputs: { environment: None, witnesses: [], user_parameters: [] },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstI64({ value: 0 }, 40L),
              ConstI64({ value: 1 }, 2L),
              I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
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

Every slot, global, member, parameter ABI, and non-Unit result also carries a
`SemanticValueKind`. Physical representation and cleanup describe storage;
semantic kind distinguishes scalars, layout witnesses, layout constructors, callables,
ByteSequences, Data families, exact Environment shapes, external opaque
references, and erased values. Equal bits and cleanup do not make different semantic kinds
interchangeable.

Every function result has one `ResultAbi`: `Unit` occupies no slot, while
`Value(representation, cleanup, kind)` records physical representation,
ownership cleanup, and semantic category. A return source, direct-call
destination, or statically known tail-call target must match the complete
result ABI.

| Representation | Runtime contents |
| --- | --- |
| `I32` | Lane `I32`, `Char`, Boolean and Byte values, layout witnesses, object references, ByteSequence references used by semantic String and Bytes values, and other 32-bit runtime values |
| `I64` | Lane `I64`, packed callable values, and erased payloads |
| `F64` | Lane `F64` |
| `F32` | Lane `F32` |

| Cleanup | Legal representation | Meaning |
| --- | --- | --- |
| `Trivial` | `I32`, `I64`, `F64`, or `F32` | The bits require no cleanup. |
| `OwnedRef` | `I32` | The slot owns one reference-counted object or ByteSequence reference. |
| `OwnedCallable` | `I64` | The slot owns one callable value; a captured callable owns its environment reference. |
| `OwnedErased` | `I64` | The slot owns an erased payload whose retain and release operations are selected by an `I32 + Trivial` layout companion slot. |

Only `OwnedErased` slots have `erased_companion`. A slot containing an owner is live after an owning definition and must be consumed, moved, returned, or explicitly released exactly once. A borrowed definition does not create an owner and must not outlive the owner from which it was projected.

Instruction operands use the following conventions:

- `destination` is written by the instruction and must have metadata matching the documented result representation and ownership.
- A borrowed input remains owned by its existing owner and receives no retain.
- A consumed input transfers or destroys its ownership; subsequent use requires a separately retained owner.
- Object witness arrays and `LayoutOperand::Witness` values are borrowed `I32 + Trivial` layout IDs. Callable evidence inputs use their complete ABI and transfer owned layout constructors into the callee.
- Argument, field, capture, edge, and result order is semantically significant.

## Object and layout model

`LayoutRecipe` describes a runtime layout. `I64`, `I32`, `F64`, and `F32` are the four trivial numeric layouts, `Char` is the trivial Unicode-scalar layout, `Byte` is the trivial scalar-byte layout, and `ByteSequence` is the single owned packed-byte-sequence layout shared by semantic String and Bytes values. `Data(ObjectShapeId)` and `Environment(ObjectShapeId)` refer to entries in the object-shape table, while `Reference` is the witness-only erased reference layout. `LayoutOperand::Immediate` names an image layout directly and `LayoutOperand::Witness` reads a layout ID from a slot.

A `DataShape` stores its `DataFamilyId`, constructor tag, stored layout
witnesses, and ordered field schemas. The family identifies one nominal data
boundary while dataflow refines a constructed or tag-switched value to its
exact `ObjectShapeId`. An `EnvironmentShape` stores layout witnesses and
ordered capture schemas. A `MemberSchema` fixes representation, cleanup, and
semantic kind; an `OwnedErased` member must name the stored-witness ordinal
used for its cleanup.

`ProjectionResult` always names a value destination and may name a layout-witness destination. The optional witness destination is required when the projected member is `OwnedErased` and absent otherwise. `ProjectionSelection` pairs one member index with its destinations.

## Function ABI

The callee receives an optional hidden environment, ordered representation evidence,
and ordered user arguments in the slots named by `FunctionInputs`. The caller
and callee counts and complete value ABIs must agree. An unresolved source type
is represented by `ErasedValue` plus explicit evidence; all bytecode call
parameter and result kinds are closed.

Environments, evidence inputs, callable values, and user arguments are
transferred into calls. Transferring a trivial `LayoutValue` is physically a
read; transferring an owned layout constructor moves or retains its callable
owner. A non-`Unit` call must provide a destination matching the callee's
complete result ABI; a `Unit` call must omit the destination. `RuntimeImport` parameters of
kind `Unit` are zero-width and do not consume an argument slot.

## Instruction encoding

Every ordinary instruction begins with the listed `u8` opcode. Operands follow in constructor order. IDs and collection lengths use little-endian `u32`; `ConstI32`, `ConstChar`, and `ConstF32` use little-endian 32-bit payloads; `ConstI64` and `ConstF64` use little-endian 64-bit payloads; an optional slot uses zero for `None` and `slot.value + 1` for `Some`; an array uses a `u32` count followed by its elements. A function result ABI uses tag `0x01` for `Unit`, or tag `0x02` followed by representation, cleanup, and semantic-kind tags for `Value`.

The constructor spelling is the public MoonBit API. The lowercase spelling shown in descriptions is the human-readable disassembly name.

### Ownership and constants

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x01` | `Copy(destination, source)` | `copy`; copies bits between representation-compatible `Trivial` slots. It does not retain and must not duplicate an owner. |
| `0x02` | `Move(destination, source)` | `move`; transfers a representation- and cleanup-compatible logical value and its ownership from `source` to `destination`. |
| `0x03` | `RetainCopy(destination, source)` | `retain_copy`; retains the nontrivial value according to the destination cleanup and writes a second owner while leaving the source owner live. |
| `0x04` | `Release(source)` | `release`; performs cleanup selected by the source metadata and consumes the source owner. `Trivial` cleanup is a no-op. |
| `0x05` | `ConstI64(destination, value)` | `const_i64`; writes the signed 64-bit integer to an `I64 + Trivial` destination. |
| `0x06` | `ConstF64(destination, bits)` | `const_f64`; reinterprets the supplied 64-bit pattern as an IEEE 754 binary64 value and writes an `F64 + Trivial` destination. |
| `0x07` | `ConstBool(destination, value)` | `const_bool`; writes canonical `0` or `1` to an `I32 + Trivial` destination. |
| `0x08` | `ConstLayout(destination, layout)` | `const_layout`; writes the nonzero `LayoutId` value to an `I32 + Trivial` destination. |
| `0x09` | `ConstFunction(destination, function)` | `const_function`; creates a capture-free callable for the function-table entry in an `I64 + OwnedCallable` destination. |
| `0x0A` | `ConstString(destination, constant)` | `const_string`; creates an owning String reference for the valid UTF-8 constant-pool entry in an `I32 + OwnedRef` destination. |
| `0x4C` | `ConstI32(destination, value)` | `const_i32`; writes the signed 32-bit integer to an `I32 + Trivial` destination. |
| `0x57` | `ConstChar(destination, value)` | `const_char`; writes the Unicode scalar value to an `I32 + Trivial` destination. |
| `0x5C` | `ConstF32(destination, bits)` | `const_f32`; reinterprets the supplied 32-bit pattern as an IEEE 754 binary32 value and writes an `F32 + Trivial` destination. |

### Calls and closures

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x0B` | `CallDirect(function, environment, witnesses, arguments, destination)` | `call_direct`; invokes the immediate function-table entry. The optional environment, evidence inputs, and user arguments are transferred, and a non-`Unit` result is written to `destination`. |
| `0x0C` | `CallValue(callable, abi, witnesses, arguments, destination)` | `call_value`; validates the packed target against `abi`, transfers the packed callable, evidence inputs, and user arguments, dispatches through the callable table, and writes an optional result. |
| `0x14` | `MakeClosure(destination, function, environment)` | `make_closure`; consumes one nonzero environment owner and packs it with the target function into an `I64 + OwnedCallable` destination. |

Direct calls use `environment=None` for no-context functions and `Some(slot)`
for functions that require a closure environment. A `CallValue` extracts the
immediate target and optional environment from the packed callable. The
verifier checks direct target signatures and the complete semantic shape of
every indirect call site. At execution, the interpreter compares the dynamic
target ABI before consuming operands; the Wasm backend checks the target and
call-site pair in a precomputed compatibility matrix before `call_indirect`, then uses an ABI-derived
Wasm type. Call depth limits, unresolved imports, and host failures are likewise
execution failures rather than valid alternate results.

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

Shapes, member indices, witness ordinals, field counts, capture counts, member representations, and optional projection-witness destinations must match the corresponding object-shape metadata. The verifier rejects violations as invalid bytecode.

### Byte and ByteSequence

`Byte` values use canonical unsigned values in the low eight bits of an `I32 + Trivial` slot. ByteSequence values use `I32 + OwnedRef` slots and point to exact-length ARC objects whose elements occupy one byte each. Semantic String and Bytes conversions do not change this runtime representation or allocate another object.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x46` | `ByteToI64(destination, source)` | `byte_to_i64`; zero-extends a canonical Byte from `I32 + Trivial` to Lane `I64` in `I64 + Trivial`. |
| `0x47` | `I64ToByte(destination, source)` | `i64_to_byte`; writes the low eight bits of an `I64 + Trivial` Lane `I64` as a canonical `I32 + Trivial` Byte. |
| `0x48` | `ByteSequenceMake(destination, length, fill)` | `byte_sequence_make`; borrows an `I64` length and `I32` Byte, creates an exact-length packed object filled with that Byte, and writes one `I32 + OwnedRef` owner. |
| `0x49` | `ByteSequenceLength(destination, source)` | `byte_sequence_length`; borrows a ByteSequence owner and writes its nonnegative byte length as `I64 + Trivial`. |
| `0x4A` | `ByteSequenceGet(destination, source, index)` | `byte_sequence_get`; borrows a ByteSequence owner and an `I64` index and writes the selected Byte as `I32 + Trivial`. |
| `0x4B` | `ByteSequenceSet(destination, source, index, value)` | `byte_sequence_set`; consumes one ByteSequence owner, borrows the index and Byte, and writes one owning ByteSequence result with the selected element replaced. A unique source may be updated in place; a shared source must be copied so other owners retain their original value. |
| `0x58` | `ByteSequenceEqual(destination, left, right)` | `byte_sequence_equal`; borrows two ByteSequence owners and writes canonical Boolean byte equality to an `I32 + Trivial` destination. |
| `0x59` | `ByteSequenceConcat(destination, left, right)` | `byte_sequence_concat`; consumes two ByteSequence owners and creates an exact-size concatenated `I32 + OwnedRef` result. |
| `0x5A` | `ByteSequenceSlice(destination, source, start, length)` | `byte_sequence_slice`; consumes the source ByteSequence, borrows nonnegative `I64` byte offset and length operands, and creates an exact-size result for the requested in-bounds byte range. |
| `0x5B` | `ByteSequenceIsValidUtf8(destination, source)` | `byte_sequence_is_valid_utf8`; borrows a ByteSequence and writes whether its complete byte contents are canonical UTF-8. |

`ByteSequenceMake` traps for a negative or unrepresentable length. `ByteSequenceGet` and `ByteSequenceSet` trap for a negative or out-of-bounds index. `ByteSequenceSlice` traps unless `start >= 0`, `length >= 0`, and `start + length <= source.length`. Allocation preflight happens before payload materialization, and failures do not publish a partial owner.

### I32 operations and conversions

I32 operands and arithmetic destinations use `I32 + Trivial`; comparison destinations also use canonical Boolean `I32 + Trivial`. Addition, subtraction, multiplication, and negation wrap modulo 2^32. Division and comparison interpret operands as signed values.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x4D` | `I32Add(destination, left, right)` | `i32_add`; computes wrapping `left + right`. |
| `0x4E` | `I32Sub(destination, left, right)` | `i32_sub`; computes wrapping `left - right`. |
| `0x4F` | `I32Mul(destination, left, right)` | `i32_mul`; computes wrapping `left * right`. |
| `0x50` | `I32Neg(destination, source)` | `i32_neg`; computes wrapping `0 - source`. |
| `0x51` | `I32Div(destination, left, right)` | `i32_div`; computes signed division truncated toward zero and traps on division by zero or `-2147483648 / -1`. |
| `0x52` | `I32Rem(destination, left, right)` | `i32_rem`; computes signed remainder, traps on division by zero, and yields zero for `-2147483648 % -1`. |
| `0x53` | `I32Eq(destination, left, right)` | `i32_eq`; writes whether the operands are equal. |
| `0x54` | `I32Lt(destination, left, right)` | `i32_lt`; writes whether `left < right` under signed ordering. |
| `0x55` | `I32ToI64(destination, source)` | `i32_to_i64`; sign-extends the Lane `I32` value into an `I64 + Trivial` Lane `I64`. |
| `0x56` | `I64ToI32(destination, source)` | `i64_to_i32`; retains the low 32 bits of an `I64 + Trivial` Lane `I64` in an `I32 + Trivial` Lane `I32` destination. |

### I64 operations

I64 operands and arithmetic destinations use `I64 + Trivial`; comparison destinations use `I32 + Trivial`. Arithmetic is signed 64-bit two's-complement arithmetic, comparisons are signed, and shift counts use their low six bits.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x19` | `I64Add(destination, left, right)` | `i64_add`; computes `left + right`. |
| `0x1A` | `I64Sub(destination, left, right)` | `i64_sub`; computes `left - right`. |
| `0x1B` | `I64Mul(destination, left, right)` | `i64_mul`; computes `left * right`. |
| `0x1C` | `I64Neg(destination, source)` | `i64_neg`; computes `0 - source`. |
| `0x1D` | `I64Div(destination, left, right)` | `i64_div`; computes signed division truncated toward zero and traps on division by zero or `Int64::min_value() / -1`. |
| `0x1E` | `I64Rem(destination, left, right)` | `i64_rem`; computes the signed remainder, traps on division by zero, and yields zero for `Int64::min_value() % -1`. |
| `0x1F` | `I64And(destination, left, right)` | `i64_and`; computes bitwise AND. |
| `0x20` | `I64Or(destination, left, right)` | `i64_or`; computes bitwise OR. |
| `0x21` | `I64Xor(destination, left, right)` | `i64_xor`; computes bitwise XOR. |
| `0x22` | `I64Not(destination, source)` | `i64_not`; complements all 64 bits. |
| `0x23` | `I64Shl(destination, left, right)` | `i64_shl`; shifts `left` left by `right & 63`. |
| `0x24` | `I64ShrS(destination, left, right)` | `i64_shr_s`; arithmetically shifts `left` right by `right & 63`. |
| `0x25` | `I64Eq(destination, left, right)` | `i64_eq`; writes whether the operands are equal. |
| `0x26` | `I64Ne(destination, left, right)` | `i64_ne`; writes whether the operands are unequal. |
| `0x27` | `I64Lt(destination, left, right)` | `i64_lt`; writes whether `left < right`. |
| `0x28` | `I64Le(destination, left, right)` | `i64_le`; writes whether `left <= right`. |
| `0x29` | `I64Gt(destination, left, right)` | `i64_gt`; writes whether `left > right`. |
| `0x2A` | `I64Ge(destination, left, right)` | `i64_ge`; writes whether `left >= right`. |

### Boolean operations

Boolean inputs and outputs use canonical `I32 + Trivial` values.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x2B` | `BoolNot(destination, source)` | `bool_not`; writes `1` when `source` is zero and `0` otherwise. |
| `0x2C` | `BoolEq(destination, left, right)` | `bool_eq`; writes whether the `I32` operands are equal. |
| `0x2D` | `BoolNe(destination, left, right)` | `bool_ne`; writes whether the `I32` operands are unequal. |

### F64 operations and conversions

F64 operands and arithmetic destinations use `F64 + Trivial`; comparison destinations use `I32 + Trivial`. Arithmetic and ordered comparisons follow WebAssembly IEEE 754 semantics, including NaN behavior.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x2E` | `F64Add(destination, left, right)` | `f64_add`; computes `left + right`. |
| `0x2F` | `F64Sub(destination, left, right)` | `f64_sub`; computes `left - right`. |
| `0x30` | `F64Mul(destination, left, right)` | `f64_mul`; computes `left * right`. |
| `0x31` | `F64Div(destination, left, right)` | `f64_div`; computes IEEE 754 division. |
| `0x32` | `F64Neg(destination, source)` | `f64_neg`; negates the source. |
| `0x33` | `F64Eq(destination, left, right)` | `f64_eq`; writes ordered equality. |
| `0x34` | `F64Ne(destination, left, right)` | `f64_ne`; writes inequality, including true for an unordered NaN comparison. |
| `0x35` | `F64Lt(destination, left, right)` | `f64_lt`; writes ordered `left < right`. |
| `0x36` | `F64Le(destination, left, right)` | `f64_le`; writes ordered `left <= right`. |
| `0x37` | `F64Gt(destination, left, right)` | `f64_gt`; writes ordered `left > right`. |
| `0x38` | `F64Ge(destination, left, right)` | `f64_ge`; writes ordered `left >= right`. |
| `0x39` | `I64ToF64(destination, source)` | `i64_to_f64`; converts a signed `I64` integer to `F64`, rounding according to IEEE 754. |
| `0x3A` | `F64ToI64(destination, source)` | `f64_to_i64`; truncates `F64` toward zero to signed `I64` and traps for NaN or a value outside `[-2^63, 2^63)`. |

### F32 operations and conversions

F32 operands and arithmetic destinations use `F32 + Trivial`; comparison destinations use `I32 + Trivial`. Arithmetic and ordered comparisons follow WebAssembly IEEE 754 binary32 semantics, including NaN behavior.

| Opcode | Constructor | Semantics |
| --- | --- | --- |
| `0x5D` | `F32Add(destination, left, right)` | `f32_add`; computes `left + right`. |
| `0x5E` | `F32Sub(destination, left, right)` | `f32_sub`; computes `left - right`. |
| `0x5F` | `F32Mul(destination, left, right)` | `f32_mul`; computes `left * right`. |
| `0x60` | `F32Div(destination, left, right)` | `f32_div`; computes IEEE 754 division. |
| `0x61` | `F32Neg(destination, source)` | `f32_neg`; negates the source. |
| `0x62` | `F32Eq(destination, left, right)` | `f32_eq`; writes ordered equality. |
| `0x63` | `F32Ne(destination, left, right)` | `f32_ne`; writes inequality, including true for an unordered NaN comparison. |
| `0x64` | `F32Lt(destination, left, right)` | `f32_lt`; writes ordered `left < right`. |
| `0x65` | `F32Le(destination, left, right)` | `f32_le`; writes ordered `left <= right`. |
| `0x66` | `F32Gt(destination, left, right)` | `f32_gt`; writes ordered `left > right`. |
| `0x67` | `F32Ge(destination, left, right)` | `f32_ge`; writes ordered `left >= right`. |
| `0x68` | `I64ToF32(destination, source)` | `i64_to_f32`; converts a signed `I64` integer to `F32`, rounding according to IEEE 754. |
| `0x69` | `F32ToI64(destination, source)` | `f32_to_i64`; truncates `F32` toward zero to signed `I64` and traps for NaN or a value outside the I64 range. |
| `0x6A` | `F32ToF64(destination, source)` | `f32_to_f64`; exactly widens binary32 to binary64. |
| `0x6B` | `F64ToF32(destination, source)` | `f64_to_f32`; narrows binary64 to binary32 using IEEE 754 rounding. |
| `0x6E` | `F32ToString(destination, source)` | `f32_to_string`; creates the canonical shortest round-tripping decimal String for binary32. |
| `0x6F` | `F64ToString(destination, source)` | `f64_to_string`; creates the canonical shortest round-tripping decimal String for binary64. |

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
| `0x6C` | `EraseF32(destination, source)` | `erase_f32`; zero-extends the raw binary32 bits into an erased `I64` payload. |
| `0x6D` | `UneraseF32(destination, source)` | `unerase_f32`; extracts the low 32 bits of an erased `I64` payload as `F32`. |

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
| `0x05` | `TailCallDirect(function, environment, witnesses, arguments)` | Replaces the current frame with a direct call, transferring the optional environment, evidence inputs, and arguments while preserving the current return destination. |
| `0x06` | `TailCallValue(callable, abi, witnesses, arguments)` | Validates the packed target against `abi`, then replaces the current frame with a callable-value call, transferring the callable, evidence inputs, and arguments while preserving the current return destination. |
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
- every String constant contains valid UTF-8, while runtime-import symbols remain nonempty ASCII without NUL;
- the image is encoded and decoded by the matching LoisVM implementation.

The verifier derives ownership tokens from function inputs and owning
instructions. Retained aliases share a token, moves and consuming object
operations transfer tokens, and borrowed projections record their root plus the
object-shape/member path. Control-flow joins preserve alternative token sets. A
borrow is rejected when a later read cannot find every possible root in a live
owner. This provenance is verifier state only; it does not change the serialized
slot or instruction format.

Use `bytecode_image_to_disassembly` for human inspection and `bytecode_image_to_binary` plus `parse_bytecode_image_binary` for persistence. The binary format has no independent compatibility version; compatibility belongs to the enclosing Lane linked-program artifact.

## Development

From the Lane workspace root:

```bash
moon test modules/loisvm/bytecode/README.mbt.md --target native
moon test modules/loisvm/bytecode --target native
moon info modules/loisvm/bytecode
moon fmt
```
