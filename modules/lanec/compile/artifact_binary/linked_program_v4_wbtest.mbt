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
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "schema 4 linked program contains only LoisVM bytecode" {
  let image = minimal_loisvm_image()
  let binary = loisvm_linked_program_to_binary(image)
  assert_eq(parse_loisvm_linked_program_binary(binary), Ok(image))
  assert_eq(binary.length(), 78)
}

///|
test "schema 4 linked program inspection delegates to LoisVM" {
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
      #|schema: 4
      #|
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
test "schema 4 rejects schema 3 linked program payload" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_raw_bytes(
    Bytes::from_array([b'L', b'A', b'N', b'E', b'A', b'R', b'T', b'\x00']),
  )
  writer.write_u8(1)
  writer.write_u8(3)
  writer.write_u32_le_int(4)
  writer.write_u32_le_int(3)
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
    Err(error) => fail("elaboration failed: \{to_repr(error)}")
  }
  assert_true(
    lower_executable_to_loisvm_bytecode(executable)
    is Ok({ entry: { value: 1 }, functions: [BytecodeBody(_)], .. }),
  )
}

///|
test "schema 4 roundtrips and inspects schema 2 instance globals" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let message = metadata.define_value("message", Local, string_type)
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
        Let(message, Literal(String("hello"))),
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
    Err(error) => fail("elaboration failed: \{to_repr(error)}")
  }
  let binary = match executable_to_loisvm_binary(executable) {
    Ok(binary) => binary
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard parse_loisvm_linked_program_binary(binary) is Ok(image) else {
    fail("schema 2 linked program did not roundtrip")
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
      #|schema: 4
      #|
      #|LoisVM bytecode
      #|schema: 2
      #|entry: f1
      #|initializer: f2
      #|functions: 2
      #|globals: 1
      #|layouts: 1
      #|object shapes: 0
      #|constants: 1
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
      #|    %0: i32 + owned_ref
      #|  b0([]):
      #|    const_string %0, c0
      #|    init_global g0, %0
      #|    return none
      #|}
      #|
      #|instance global table:
      #|  g0 = i32 + owned_ref
      #|
      #|layout table:
      #|  l1 = string
      #|
      #|constant table:
      #|  c0 = "hello"
      #|
    ),
  )
}
