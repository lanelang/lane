///|
fn slot(value : Int) -> SlotId {
  { value, }
}

///|
fn function(value : Int) -> FunctionId {
  { value, }
}

///|
fn global(value : Int) -> GlobalId {
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
    initializer: None,
    functions: [BytecodeBody(minimal_body())],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn global_image() -> BytecodeImage {
  let initializer = {
    ..minimal_body(instructions=[
      InitGlobal(global(1), slot(1)),
      BorrowGlobal(slot(2), global(1)),
    ]),
    slots: [
      { representation: I32, cleanup: Trivial, erased_companion: None },
      {
        representation: I64,
        cleanup: OwnedErased,
        erased_companion: Some(slot(0)),
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        erased_companion: Some(slot(0)),
      },
    ],
  }
  {
    entry: function(1),
    initializer: Some(function(2)),
    functions: [BytecodeBody(minimal_body()), BytecodeBody(initializer)],
    globals: [
      { representation: I32, cleanup: Trivial, erased_companion: None },
      {
        representation: I64,
        cleanup: OwnedErased,
        erased_companion: Some(global(0)),
      },
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "minimal bytecode image has stable encoding" {
  let binary = bytecode_image_to_binary(minimal_image())
  assert_eq(binary.to_array().map(fn(byte) { byte.to_int() }), [
    1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  assert_eq(parse_bytecode_image_binary(binary), Ok(minimal_image()))
}

///|
test "minimal bytecode image has canonical disassembly" {
  inspect(
    @prettyprinter.render(minimal_image(), width=100),
    content=(
      #|LoisVM bytecode
      #|entry: f1
      #|initializer: none
      #|functions: 1
      #|globals: 0
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
test "minimal bytecode code view omits image summary" {
  inspect(
    bytecode_image_to_code(minimal_image()),
    content=(
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
test "globals and initializer roundtrip" {
  let image = global_image()
  let binary = bytecode_image_to_binary(image)
  assert_eq(parse_bytecode_image_binary(binary), Ok(image))
  let initializer_only = { ..minimal_image(), initializer: Some(function(1)) }
  let initializer_only_binary = bytecode_image_to_binary(initializer_only)
  assert_eq(
    parse_bytecode_image_binary(initializer_only_binary),
    Ok(initializer_only),
  )
}

///|
test "F32 bytecode instructions roundtrip" {
  let f32 : SlotMetadata = {
    representation: F32,
    cleanup: Trivial,
    erased_companion: None,
  }
  let i32 : SlotMetadata = {
    representation: I32,
    cleanup: Trivial,
    erased_companion: None,
  }
  let i64 : SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    erased_companion: None,
  }
  let f64 : SlotMetadata = {
    representation: F64,
    cleanup: Trivial,
    erased_companion: None,
  }
  let erased : SlotMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    erased_companion: Some(slot(6)),
  }
  let string : SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    erased_companion: None,
  }
  let body = {
    ..minimal_body(instructions=[
      ConstF32(slot(0), 0x3FC00000),
      ConstF32(slot(1), 0x40100000),
      F32Add(slot(2), slot(0), slot(1)),
      F32Sub(slot(2), slot(0), slot(1)),
      F32Mul(slot(2), slot(0), slot(1)),
      F32Div(slot(2), slot(0), slot(1)),
      F32Neg(slot(2), slot(0)),
      F32Eq(slot(3), slot(0), slot(1)),
      F32Ne(slot(3), slot(0), slot(1)),
      F32Lt(slot(3), slot(0), slot(1)),
      F32Le(slot(3), slot(0), slot(1)),
      F32Gt(slot(3), slot(0), slot(1)),
      F32Ge(slot(3), slot(0), slot(1)),
      ConstI64(slot(4), 42L),
      I64ToF32(slot(2), slot(4)),
      F32ToI64(slot(4), slot(2)),
      F32ToF64(slot(5), slot(2)),
      F64ToF32(slot(2), slot(5)),
      F32ToString(slot(8), slot(2)),
      F64ToString(slot(8), slot(5)),
      EraseF32(slot(7), slot(2)),
      UneraseF32(slot(2), slot(7)),
    ]),
    slots: [f32, f32, f32, i32, i64, f64, i32, erased, string],
  }
  let image = {
    ..minimal_image(),
    functions: [BytecodeBody(body)],
    layouts: [F32, ByteSequence],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(image)),
    Ok(image),
  )
}

///|
test "global image has canonical disassembly" {
  inspect(
    @prettyprinter.render(global_image(), width=100),
    content=(
      #|LoisVM bytecode
      #|entry: f1
      #|initializer: f2
      #|functions: 2
      #|globals: 2
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
      #|function f2(
      #|  environment=none,
      #|  witnesses=[],
      #|  parameters=[]
      #|) -> unit {
      #|  slots:
      #|    %0: i32 + trivial
      #|    %1: i64 + owned_erased, companion=%0
      #|    %2: i64 + owned_erased, companion=%0
      #|  b0([]):
      #|    init_global g1, %1
      #|    borrow_global %2, g1
      #|    return none
      #|}
      #|
      #|instance global table:
      #|  g0 = i32 + trivial
      #|  g1 = i64 + owned_erased, companion=g0
      #|
    ),
  )
}

///|
test "all instructions roundtrip" {
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
    ConstI64(zero, -42L),
    ConstI32(zero, -42),
    ConstChar(zero, 0x1F600),
    ConstF64(two, -1L),
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
    ByteToI64(one, zero),
    I64ToByte(zero, one),
    ByteSequenceMake(zero, one, zero),
    ByteSequenceLength(one, zero),
    ByteSequenceGet(zero, zero, one),
    ByteSequenceSet(zero, zero, one, zero),
    I32Add(zero, one, two),
    I32Sub(zero, one, two),
    I32Mul(zero, one, two),
    I32Neg(zero, one),
    I32Div(zero, one, two),
    I32Rem(zero, one, two),
    I32Eq(zero, one, two),
    I32Lt(zero, one, two),
    I32ToI64(one, zero),
    I64ToI32(zero, one),
    ByteSequenceConcat(zero, one, two),
    ByteSequenceSlice(zero, one, two, zero),
    ByteSequenceEqual(zero, one, two),
    ByteSequenceIsValidUtf8(zero, one),
    I64Add(zero, one, two),
    I64Sub(zero, one, two),
    I64Mul(zero, one, two),
    I64Neg(zero, one),
    I64Div(zero, one, two),
    I64Rem(zero, one, two),
    I64And(zero, one, two),
    I64Or(zero, one, two),
    I64Xor(zero, one, two),
    I64Not(zero, one),
    I64Shl(zero, one, two),
    I64ShrS(zero, one, two),
    I64Eq(zero, one, two),
    I64Ne(zero, one, two),
    I64Lt(zero, one, two),
    I64Le(zero, one, two),
    I64Gt(zero, one, two),
    I64Ge(zero, one, two),
    BoolNot(zero, one),
    BoolEq(zero, one, two),
    BoolNe(zero, one, two),
    F64Add(two, one, two),
    F64Sub(two, one, two),
    F64Mul(two, one, two),
    F64Div(two, one, two),
    F64Neg(two, one),
    F64Eq(zero, one, two),
    F64Ne(zero, one, two),
    F64Lt(zero, one, two),
    F64Le(zero, one, two),
    F64Gt(zero, one, two),
    F64Ge(zero, one, two),
    I64ToF64(two, zero),
    F64ToI64(zero, two),
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
    initializer: None,
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
    globals: [],
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
    initializer: None,
    functions: [
      BytecodeBody(minimal_body()),
      RuntimeImport({
        abi_major: 1,
        parameters: [I64, Opaque],
        result: String,
        symbol: "lane.host.print",
      }),
    ],
    globals: [],
    layouts: [
      Unit,
      Bool,
      I64,
      I32,
      Char,
      F64,
      Callable,
      ByteSequence,
      Data(shape(0)),
      Environment(shape(1)),
      Reference,
      Byte,
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
  let decoded = parse_bytecode_image_binary(bytecode_image_to_binary(image))
  assert_eq(decoded, Ok(image))
  guard decoded is Ok(decoded) else { fail("expected decoded image") }
  debug_inspect(
    decoded.functions[1],
    content=(
      #|RuntimeImport(
      #|  {
      #|    abi_major: 1,
      #|    parameters: [I64, Opaque],
      #|    result: String,
      #|    symbol: "lane.host.print",
      #|  },
      #|)
    ),
  )
}

///|
test "runtime import disassembly renders complete direct ABI signature" {
  let image = {
    ..minimal_image(),
    functions: [
      BytecodeBody(minimal_body()),
      RuntimeImport({
        abi_major: 1,
        parameters: [Unit, Bool, I64, F64, String, Opaque],
        result: Opaque,
        symbol: "lane.host.all",
      }),
    ],
  }
  inspect(
    @prettyprinter.render(image, width=100),
    content=(
      #|LoisVM bytecode
      #|entry: f1
      #|initializer: none
      #|functions: 2
      #|globals: 0
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
      #|function f2 = runtime_import(
      #|  symbol="lane.host.all",
      #|  abi_major=1,
      #|  parameters=[unit, bool, i64, f64, string, opaque],
      #|  result=opaque
      #|)
      #|
    ),
  )
}

///|
test "decoder rejects unknown function tag" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  writer.write_u8(0)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=12, detail="unknown function entry tag 0")),
  )
}

///|
test "decoder rejects unknown runtime value kind" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  writer.write_u8(2)
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(1)
  writer.write_u8(99)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      MalformedEncoding(offset=21, detail="unknown runtime value kind tag 99"),
    ),
  )
}

///|
test "decoder preserves truncation offsets with pattern parsing" {
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array([])),
    Err(MalformedEncoding(offset=0, detail="expected FunctionId")),
  )
  assert_eq(
    parse_bytecode_image_binary(
      Bytes::from_array([b'\x01', b'\x00', b'\x00', b'\x00']),
    ),
    Err(MalformedEncoding(offset=4, detail="expected optional FunctionId")),
  )
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      MalformedEncoding(
        offset=8,
        detail="function count exceeds enclosing payload",
      ),
    ),
  )
  writer.write_u8(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=13, detail="expected function body length")),
  )
}

///|
test "decoder reports u32 values beyond host I64 as resource limits" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  writer.write_u8(2)
  writer.write_i32_le(-1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  writer.write_u8(b'x'.to_int())
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(0)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      ResourceLimit(
        offset=13,
        detail="runtime import ABI major exceeds implementation limit",
      ),
    ),
  )
}

///|
test "decoder validates initializer and global metadata" {
  let missing_initializer = { ..global_image(), initializer: None }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(missing_initializer)),
    Err(
      MalformedEncoding(
        offset=4,
        detail="nonempty instance global table requires an initializer",
      ),
    ),
  )
  let invalid_initializer = { ..global_image(), initializer: Some(function(3)) }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(invalid_initializer)),
    Err(
      MalformedEncoding(
        offset=4,
        detail="instance initializer FunctionId is out of range",
      ),
    ),
  )
  let invalid_companion = {
    ..global_image(),
    globals: [
      {
        representation: I64,
        cleanup: OwnedErased,
        erased_companion: Some(global(0)),
      },
    ],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(invalid_companion)),
    Err(
      MalformedEncoding(
        offset=0,
        detail="OwnedErased global companion must immediately precede its owner",
      ),
    ),
  )
}

///|
test "global count beyond host I64 is a resource limit" {
  let image = {
    ..minimal_image(),
    initializer: Some(function(1)),
    globals: [{ representation: I32, cleanup: Trivial, erased_companion: None }],
  }
  let bytes = bytecode_image_to_binary(image).to_array()
  bytes[51] = b'\xFF'
  bytes[52] = b'\xFF'
  bytes[53] = b'\xFF'
  bytes[54] = b'\xFF'
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array(bytes)),
    Err(
      ResourceLimit(
        offset=51,
        detail="instance global count exceeds implementation limit",
      ),
    ),
  )
}

///|
test "decoder accepts UTF-8 constants and rejects malformed UTF-8" {
  let utf8 = { ..minimal_image(), constants: [@utf8.encode("中\u{0}🙂")] }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(utf8)),
    Ok(utf8),
  )
  let malformed_utf8 = {
    ..minimal_image(),
    constants: [Bytes::from_array([b'\xFF'])],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(malformed_utf8)),
    Err(
      MalformedEncoding(
        offset=71,
        detail="String constant must contain valid UTF-8",
      ),
    ),
  )
}

///|
test "decoder rejects invalid Char constants" {
  let results = []
  for value in [-1, 0xD800, 0xDFFF, 0x110000] {
    let image = {
      ..minimal_image(),
      functions: [
        BytecodeBody(
          minimal_body(instructions=[ConstChar({ value: 0 }, value)]),
        ),
      ],
    }
    results.push(parse_bytecode_image_binary(bytecode_image_to_binary(image)))
  }
  debug_inspect(
    results,
    content=(
      #|[
      #|  Err(
      #|    MalformedEncoding(
      #|      offset=51,
      #|      detail="Char constant -1 is not a Unicode scalar value",
      #|    ),
      #|  ),
      #|  Err(
      #|    MalformedEncoding(
      #|      offset=51,
      #|      detail="Char constant 55296 is not a Unicode scalar value",
      #|    ),
      #|  ),
      #|  Err(
      #|    MalformedEncoding(
      #|      offset=51,
      #|      detail="Char constant 57343 is not a Unicode scalar value",
      #|    ),
      #|  ),
      #|  Err(
      #|    MalformedEncoding(
      #|      offset=51,
      #|      detail="Char constant 1114112 is not a Unicode scalar value",
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "decoder rejects illegal slot metadata" {
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
  debug_inspect(
    parse_bytecode_image_binary(bytecode_image_to_binary(illegal_image)),
    content=(
      #|Err(
      #|  MalformedEncoding(
      #|    offset=0,
      #|    detail="illegal slot representation and cleanup combination",
      #|  ),
      #|)
    ),
  )
}
