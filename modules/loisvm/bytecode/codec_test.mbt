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
fn write_unit_callable_abi_table(writer : @bytecodec.ByteWriter) -> Unit {
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(0)
  writer.write_u8(1)
  writer.write_u32_le_int(0)
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
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
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
      ConstLayout(slot(0), layout(1)),
      EraseUnit(slot(1)),
      InitGlobal(global(1), slot(1)),
      BorrowGlobal(slot(2), global(1)),
    ]),
    slots: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(slot(0)),
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(slot(0)),
      },
    ],
  }
  {
    entry: function(1),
    initializer: Some(function(2)),
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [BytecodeBody(minimal_body()), BytecodeBody(initializer)],
    globals: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(global(0)),
      },
    ],
    layouts: [Unit],
    object_shapes: [],
    constants: [],
  }
}

///|
test "minimal bytecode image has stable encoding" {
  let binary = bytecode_image_to_binary(minimal_image()).unwrap()
  debug_inspect(
    binary.to_array().map(fn(byte) { byte.to_int() }),
    content=(
      #|[
      #|  1,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  1,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  1,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  1,
      #|  0,
      #|  0,
      #|  0,
      #|  1,
      #|  34,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  1,
      #|  1,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  4,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|]
    ),
  )
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
      #|callable ABIs: 1
      #|functions: 1
      #|globals: 0
      #|layouts: 0
      #|object shapes: 0
      #|constants: 0
      #|
      #|function f1 abi=abi0(
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
      #|callable ABI table:
      #|  abi0 = fn(witnesses=[], parameters=[]) -> unit
      #|
    ),
  )
}

///|
test "minimal bytecode code view omits image summary" {
  inspect(
    bytecode_image_to_code(minimal_image()),
    content=(
      #|function f1 abi=abi0(
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
      #|callable ABI table:
      #|  abi0 = fn(witnesses=[], parameters=[]) -> unit
      #|
    ),
  )
}

///|
test "globals and initializer roundtrip" {
  let image = global_image()
  let binary = bytecode_image_to_binary(image).unwrap()
  assert_eq(parse_bytecode_image_binary(binary), Ok(image))
  let initializer_only = { ..minimal_image(), initializer: Some(function(1)) }
  let initializer_only_binary = bytecode_image_to_binary(initializer_only).unwrap()
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
    kind: ScalarValue,
    erased_companion: None,
  }
  let i32 : SlotMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let layout_value : SlotMetadata = { ..i32, kind: LayoutValue }
  let i64 : SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let f64 : SlotMetadata = {
    representation: F64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let erased : SlotMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    erased_companion: Some(slot(6)),
  }
  let string : SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
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
      Release(slot(8)),
      F64ToString(slot(8), slot(5)),
      Release(slot(8)),
      ConstLayout(slot(6), layout(1)),
      EraseF32(slot(7), slot(2)),
      UneraseF32(slot(2), slot(7)),
    ]),
    slots: [f32, f32, f32, i32, i64, f64, layout_value, erased, string],
  }
  let image = {
    ..minimal_image(),
    functions: [BytecodeBody(body)],
    layouts: [F32, ByteSequence],
  }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(image).unwrap()),
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
      #|callable ABIs: 1
      #|functions: 2
      #|globals: 2
      #|layouts: 1
      #|object shapes: 0
      #|constants: 0
      #|
      #|function f1 abi=abi0(
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
      #|function f2 abi=abi0(
      #|  environment=none,
      #|  witnesses=[],
      #|  parameters=[]
      #|) -> unit {
      #|  slots:
      #|    %0: i32 + trivial + LayoutValue
      #|    %1: i64 + owned_erased + ErasedValue, companion=%0
      #|    %2: i64 + owned_erased + ErasedValue, companion=%0
      #|  b0([]):
      #|    const_layout %0, l1
      #|    erase_unit %1
      #|    init_global g1, %1
      #|    borrow_global %2, g1
      #|    return none
      #|}
      #|
      #|callable ABI table:
      #|  abi0 = fn(witnesses=[], parameters=[]) -> unit
      #|
      #|instance global table:
      #|  g0 = i32 + trivial + LayoutValue
      #|  g1 = i64 + owned_erased + ErasedValue, companion=g0
      #|
      #|layout table:
      #|  l1 = unit
      #|
    ),
  )
}

///|
test "function, layout, shape, and constant tables roundtrip" {
  let image : BytecodeImage = {
    entry: function(1),
    initializer: None,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue },
          { representation: I32, cleanup: OwnedRef, kind: OpaqueReferenceValue },
        ],
        result: Value(I32, OwnedRef, ByteSequenceValue),
      },
      {
        witnesses: [
          {
            representation: I64,
            cleanup: OwnedCallable,
            kind: LayoutConstructorValue(1),
          },
        ],
        parameters: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: @bytecode.DataValue({ value: 0 }),
          },
        ],
        result: Value(I32, OwnedRef, @bytecode.DataValue({ value: 0 })),
      },
    ],
    data_family_count: 1,
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
        family: { value: 0 },
        constructor_tag: 7,
        stored_witness_count: 1,
        members: [
          {
            representation: I64,
            cleanup: OwnedErased,
            kind: ErasedValue,
            witness_ordinal: Some(0),
          },
        ],
      }),
      Environment({
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
    constants: [Bytes::from_array([]), Bytes::from_array([b'a', b'b', b'c'])],
  }
  let decoded = parse_bytecode_image_binary(
    bytecode_image_to_binary(image).unwrap(),
  )
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
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: Trivial, kind: ScalarValue },
          { representation: I64, cleanup: Trivial, kind: ScalarValue },
          { representation: F64, cleanup: Trivial, kind: ScalarValue },
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
          { representation: I32, cleanup: OwnedRef, kind: OpaqueReferenceValue },
        ],
        result: Value(I32, OwnedRef, OpaqueReferenceValue),
      },
    ],
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
      #|callable ABIs: 2
      #|functions: 2
      #|globals: 0
      #|layouts: 0
      #|object shapes: 0
      #|constants: 0
      #|
      #|function f1 abi=abi0(
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
      #|function f2 abi=abi1 = runtime_import(
      #|  symbol="lane.host.all",
      #|  abi_major=1,
      #|  parameters=[unit, bool, i64, f64, string, opaque],
      #|  result=opaque
      #|)
      #|
      #|callable ABI table:
      #|  abi0 = fn(witnesses=[], parameters=[]) -> unit
      #|  abi1 = fn(witnesses=[], parameters=[i32 + trivial + ScalarValue, i64 + trivial + ScalarValue, f64 + trivial + ScalarValue, i32 + owned_ref + ByteSequenceValue, i32 + owned_ref + OpaqueReferenceValue]) -> i32 + owned_ref + OpaqueReferenceValue
      #|
    ),
  )
}

///|
test "decoder rejects unknown function tag" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  write_unit_callable_abi_table(writer)
  writer.write_u32_le_int(1)
  writer.write_u8(0)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=29, detail="unknown function entry tag 0")),
  )
}

///|
test "decoder rejects unknown runtime value kind" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  write_unit_callable_abi_table(writer)
  writer.write_u32_le_int(1)
  writer.write_u8(2)
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(1)
  writer.write_u8(99)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      MalformedEncoding(offset=38, detail="unknown runtime value kind tag 99"),
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
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=8, detail="expected callable ABI count")),
  )
  writer.write_u32_le_int(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(
      MalformedEncoding(
        offset=8,
        detail="callable ABI count exceeds enclosing payload",
      ),
    ),
  )
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(0)
  writer.write_u8(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=21, detail="expected data family count")),
  )
  writer.write_u32_le_int(0)
  writer.write_u32_le_int(1)
  writer.write_u8(1)
  assert_eq(
    parse_bytecode_image_binary(writer.to_bytes()),
    Err(MalformedEncoding(offset=30, detail="expected function body length")),
  )
}

///|
test "decoder reports u32 values beyond host I64 as resource limits" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(1)
  writer.write_u32_le_int(0)
  write_unit_callable_abi_table(writer)
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
        offset=30,
        detail="runtime import ABI major exceeds implementation limit",
      ),
    ),
  )
}

///|
test "binary loader round-trips UTF-8 String constants" {
  let utf8 = { ..minimal_image(), constants: [@utf8.encode("中\u{0}🙂")] }
  assert_eq(
    parse_bytecode_image_binary(bytecode_image_to_binary(utf8).unwrap()),
    Ok(utf8),
  )
}

///|
test "result ABI round-trips" {
  let owned_result = {
    ..minimal_body(),
    slots: [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
    ],
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstString(slot(0), { value: 0 })],
        terminator: Return(Some(slot(0))),
      },
    ],
  }
  let valid = {
    ..minimal_image(),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      {
        witnesses: [],
        parameters: [],
        result: Value(I32, OwnedRef, ByteSequenceValue),
      },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
        ],
        result: Unit,
      },
    ],
    functions: [
      BytecodeBody(minimal_body()),
      BytecodeBody(owned_result),
      BytecodeBody({
        slots: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            erased_companion: None,
          },
        ],
        inputs: { environment: None, witnesses: [], user_parameters: [slot(0)] },
        result: Unit,
        blocks: [
          { parameters: [], instructions: [], terminator: Fatal(slot(0)) },
        ],
      }),
    ],
    constants: [b"owned"],
  }
  let encoded = match bytecode_image_to_binary(valid) {
    Ok(encoded) => encoded
    Err(error) => fail("valid image failed verification: \{Repr(error)}")
  }
  assert_eq(parse_bytecode_image_binary(encoded), Ok(valid))
}
