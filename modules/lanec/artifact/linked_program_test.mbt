///|
fn minimal_loisvm_image() -> @loisvm_bytecode.BytecodeImage {
  let body : @loisvm_bytecode.FunctionBody = {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
  }
  {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "linked program contains only current LoisVM bytecode" {
  let image = minimal_loisvm_image()
  let binary = loisvm_linked_program_to_binary(image)
  assert_eq(parse_loisvm_linked_program_binary(binary), Ok(image))
  assert_eq(binary.length(), 98)
}

///|
test "linked program inspection delegates to LoisVM" {
  let text = match
    artifact_binary_to_inspect_text(
      loisvm_linked_program_to_binary(minimal_loisvm_image()),
    ) {
    Ok(text) => text
    Err(message) => fail(message)
  }
  inspect(
    text,
    content=(
      #|Lane program artifact
      #|schema: 10
      #|
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
      #|  abi0 = fn(witnesses=0, parameters=[]) -> unit
      #|
    ),
  )
}

///|
test "schema 10 rejects schema 9 linked program payload" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_raw_bytes(
    Bytes::from_array([b'L', b'A', b'N', b'E', b'A', b'R', b'T', b'\x00']),
  )
  writer.write_u8(1)
  writer.write_u8(3)
  writer.write_u32_le_int(9)
  writer.write_u32_le_int(4)
  let result = parse_loisvm_linked_program_binary(writer.to_bytes())
  assert_true(result is Err(_))
}

///|
test "linked executable lowers through the LoisVM boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
    type_: main_type,
  }
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        Let(
          main,
          Function({
            parameters: [],
            result_type: unit_type,
            body: Literal(Unit),
          }),
        ),
      ],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
  }
  let executable = match @executable.elaborate(linked, entry) {
    Ok(executable) => executable
    Err(error) => fail("elaboration failed: \{Repr(error)}")
  }
  assert_true(
    lower_executable_to_loisvm_bytecode(executable)
    is Ok({ entry: { value: 1 }, functions: [BytecodeBody(_)], .. }),
  )
}

///|
test "linked program roundtrips and inspects instance globals" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let message = metadata.define_value("message", Value, string_type)
  let produce_type = @buslane.Type::Function([], string_type, Empty)
  let produce = metadata.define_value("produce", External, produce_type)
  let consume_type = @buslane.Type::Function([string_type], unit_type, Empty)
  let consume = metadata.define_value("consume", External, consume_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
    type_: main_type,
  }
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        External(produce),
        External(consume),
        Let(message, Call(Ref(produce), [])),
        Let(
          main,
          Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(consume), [Ref(message)]),
          }),
        ),
      ],
    },
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: produce,
          symbol: "lane.test.produce",
          signature: { parameters: [], result: String },
          type_: produce_type,
        },
        {
          value: consume,
          symbol: "lane.test.consume",
          signature: { parameters: [String], result: Unit },
          type_: consume_type,
        },
      ],
    },
    entries: [entry],
  }
  let executable = match @executable.elaborate(linked, entry) {
    Ok(executable) => executable
    Err(error) => fail("elaboration failed: \{Repr(error)}")
  }
  let binary = match executable_to_loisvm_binary(executable) {
    Ok(binary) => binary
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard parse_loisvm_linked_program_binary(binary) is Ok(image) else {
    fail("linked program did not roundtrip")
  }
  assert_eq(image.initializer, Some({ value: 2 }))
  assert_eq(image.globals, [
    { representation: I32, cleanup: OwnedRef, erased_companion: None },
  ])
  let text = match artifact_binary_to_inspect_text(binary) {
    Ok(text) => text
    Err(message) => fail(message)
  }
  inspect(
    text,
    content=(
      #|Lane program artifact
      #|schema: 10
      #|
      #|LoisVM bytecode
      #|entry: f1
      #|initializer: f2
      #|callable ABIs: 3
      #|functions: 4
      #|globals: 1
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
      #|    %0: i32 + trivial
      #|    %1: i32 + owned_ref
      #|  b0([]):
      #|    borrow_global %0, g0
      #|    retain_copy %1, %0
      #|    tail_call_direct f3 env=none witnesses=[] arguments=[%1]
      #|}
      #|
      #|function f2 abi=abi0(
      #|  environment=none,
      #|  witnesses=[],
      #|  parameters=[]
      #|) -> unit {
      #|  slots:
      #|    %0: i32 + owned_ref
      #|  b0([]):
      #|    call_direct %0 = f4 env=none witnesses=[] arguments=[]
      #|    init_global g0, %0
      #|    return none
      #|}
      #|
      #|function f3 abi=abi1 = runtime_import(
      #|  symbol="lane.test.consume",
      #|  abi_major=1,
      #|  parameters=[string],
      #|  result=unit
      #|)
      #|
      #|function f4 abi=abi2 = runtime_import(
      #|  symbol="lane.test.produce",
      #|  abi_major=1,
      #|  parameters=[],
      #|  result=string
      #|)
      #|
      #|callable ABI table:
      #|  abi0 = fn(witnesses=0, parameters=[]) -> unit
      #|  abi1 = fn(witnesses=0, parameters=[i32 + owned_ref]) -> unit
      #|  abi2 = fn(witnesses=0, parameters=[]) -> i32 + owned_ref
      #|
      #|instance global table:
      #|  g0 = i32 + owned_ref
      #|
    ),
  )
}
