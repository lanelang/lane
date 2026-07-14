///|
fn slot(value : Int) -> SlotId {
  { value, }
}

///|
fn function(value : Int) -> FunctionId {
  { value, }
}

///|
fn layout(value : Int) -> LayoutId {
  { value, }
}

///|
fn shape(value : Int) -> ObjectShapeId {
  { value, }
}

///|
fn constant(value : Int) -> ConstantId {
  { value, }
}

///|
fn minimal_body(instructions? : Array[Instruction] = []) -> FunctionBody {
  {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn minimal_image() -> BytecodeImage {
  {
    entry: function(1),
    functions: [BytecodeBody(minimal_body())],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "minimal bytecode image has stable encoding" {
  let binary = bytecode_image_to_binary(minimal_image())
  assert_eq(binary.to_array().map(fn(byte) { byte.to_int() }), [
    1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  ])
  assert_eq(parse_bytecode_image_binary(binary), Ok(minimal_image()))
}

///|
test "minimal bytecode image has canonical disassembly" {
  inspect(
    bytecode_image_to_disassembly(minimal_image()),
    content=(
      #|LoisVM bytecode
      #|schema: 1
      #|entry: f1
      #|functions: 1
      #|layouts: 0
      #|object shapes: 0
      #|constants: 0
      #|
      #|function f1(
      #|  environment=none,
      #|  witnesses=[],
      #|  parameters=[]
      #|) -> unit {
      #|  slots:
      #|    (none)
      #|  b0([]):
      #|    return none
      #|}
      #|
    ),
  )
}

///|
test "all v1 instructions roundtrip" {
  let zero = slot(0)
  let one = slot(1)
  let two = slot(2)
  let projection : ProjectionResult = {
    value_destination: zero,
    witness_destination: Some(one),
  }
  let instructions : Array[Instruction] = [
    Copy(zero, one),
    Move(zero, one),
    RetainCopy(zero, one),
    Release(zero),
    ConstInt(zero, -42L),
    ConstDouble(two, -1L),
    ConstBool(zero, true),
    ConstLayout(zero, layout(1)),
    ConstFunction(one, function(1)),
    ConstString(zero, constant(0)),
    CallDirect(function(1), Some(zero), [zero], [one], None),
    CallValue(one, [zero], [one], Some(two)),
    MakeData(zero, shape(0), Immediate(layout(1)), [zero], [one]),
    LoadTag(zero, one),
    BorrowField(shape(0), one, 0, projection),
    ConsumeFields(shape(0), one, [{ member_index: 0, result: projection }]),
    MakeEnv(zero, shape(1), Witness(zero), [zero], [one]),
    BorrowCapture(shape(1), one, 0, projection),
    ConsumeCaptures(shape(1), one, [{ member_index: 0, result: projection }]),
    MakeClosure(one, function(1), zero),
    StringLength(zero, one),
    StringConcat(zero, one, two),
    StringSlice(zero, one, two, zero),
    StringEq(zero, one, two),
    IntAdd(zero, one, two),
    IntSub(zero, one, two),
    IntMul(zero, one, two),
    IntNeg(zero, one),
    IntDiv(zero, one, two),
    IntRem(zero, one, two),
    IntAnd(zero, one, two),
    IntOr(zero, one, two),
    IntXor(zero, one, two),
    IntNot(zero, one),
    IntShl(zero, one, two),
    IntShrS(zero, one, two),
    IntEq(zero, one, two),
    IntNe(zero, one, two),
    IntLt(zero, one, two),
    IntLe(zero, one, two),
    IntGt(zero, one, two),
    IntGe(zero, one, two),
    BoolNot(zero, one),
    BoolEq(zero, one, two),
    BoolNe(zero, one, two),
    DoubleAdd(two, one, two),
    DoubleSub(two, one, two),
    DoubleMul(two, one, two),
    DoubleDiv(two, one, two),
    DoubleNeg(two, one),
    DoubleEq(zero, one, two),
    DoubleNe(zero, one, two),
    DoubleLt(zero, one, two),
    DoubleLe(zero, one, two),
    DoubleGt(zero, one, two),
    DoubleGe(zero, one, two),
    IntToDouble(two, zero),
    DoubleToInt(zero, two),
    EraseI32(one, zero),
    UneraseI32(zero, one),
    EraseI64(one, one),
    UneraseI64(one, one),
    EraseF64(one, two),
    UneraseF64(two, one),
    EraseUnit(one),
    UneraseUnit(one),
    LoadObjectWitness(zero, shape(0), one, 1),
  ]
  let body = minimal_body(instructions~)
  let image : BytecodeImage = {
    entry: function(1),
    functions: [
      BytecodeBody({
        ..body,
        slots: [
          { representation: I32, cleanup: Trivial, erased_companion: None },
          { representation: I64, cleanup: Trivial, erased_companion: None },
          { representation: F64, cleanup: Trivial, erased_companion: None },
        ],
      }),
    ],
    layouts: [Unit],
    object_shapes: [
      Data({ constructor_tag: 0, stored_witness_count: 0, members: [] }),
      Environment({ stored_witness_count: 0, members: [] }),
    ],
    constants: [Bytes::from_array([b'L', b'a', b'n', b'e'])],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(image)),
    Ok(image),
  )
}

///|
test "function, layout, shape, and constant tables roundtrip" {
  let image : BytecodeImage = {
    entry: function(1),
    functions: [
      BytecodeBody(minimal_body()),
      RuntimeImport({ abi_major: 1, user_arity: 2, symbol: "lane.host.print" }),
    ],
    layouts: [
      Unit,
      Bool,
      Int,
      Double,
      Callable,
      String,
      Data(shape(0)),
      Environment(shape(1)),
      Reference,
    ],
    object_shapes: [
      Data({
        constructor_tag: 7,
        stored_witness_count: 1,
        members: [
          {
            representation: I64,
            cleanup: OwnedErased,
            witness_ordinal: Some(0),
          },
        ],
      }),
      Environment({
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
    constants: [Bytes::from_array([]), Bytes::from_array([b'a', b'b', b'c'])],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(image)),
    Ok(image),
  )
}

///|
test "decoder rejects unsupported schema and unknown function tag" {
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array([b'\x02'])),
    Err(UnsupportedSchema(version=2)),
  )
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u8(1)
  writer.write_u32_le(1)
  writer.write_u32_le(1)
  writer.write_u8(0)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=9, detail="unknown function entry tag 0")),
  )
}

///|
test "decoder preserves truncation offsets with pattern parsing" {
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array([])),
    Err(MalformedEncoding(offset=0, detail="expected bytecode schema version")),
  )
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array([b'\x01'])),
    Err(MalformedEncoding(offset=1, detail="expected FunctionId")),
  )
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u8(1)
  writer.write_u32_le(1)
  writer.write_u32_le(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      MalformedEncoding(
        offset=5,
        detail="function count exceeds enclosing payload",
      ),
    ),
  )
  writer.write_u8(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=10, detail="expected function body length")),
  )
}

///|
test "decoder reports schema-valid u32 values beyond host Int as resource limits" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u8(1)
  writer.write_u32_le(1)
  writer.write_u32_le(1)
  writer.write_u8(2)
  writer.write_u32_le(-1)
  writer.write_u32_le(0)
  writer.write_u32_le(1)
  writer.write_u8(b'x'.to_int())
  writer.write_u32_le(0)
  writer.write_u32_le(0)
  writer.write_u32_le(0)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      ResourceLimit(
        offset=10,
        detail="runtime import ABI major exceeds implementation limit",
      ),
    ),
  )
}

///|
test "decoder rejects non-ASCII constants and illegal slot metadata" {
  let non_ascii = {
    ..minimal_image(),
    constants: [Bytes::from_array([b'\xFF'])],
  }
  assert_true(
    parse_bytecode_image_binary(bytecode_image_to_binary(non_ascii)) is Err(_),
  )
  let illegal_body = {
    ..minimal_body(),
    slots: [
      { representation: I32, cleanup: OwnedCallable, erased_companion: None },
    ],
  }
  let illegal_image = {
    ..minimal_image(),
    functions: [BytecodeBody(illegal_body)],
  }
  assert_true(
    parse_bytecode_image_binary(bytecode_image_to_binary(illegal_image))
    is Err(_),
  )
}
