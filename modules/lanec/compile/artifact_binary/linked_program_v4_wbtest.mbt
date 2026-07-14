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
    functions: [BytecodeBody(body)],
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
  writer.write_u32_le(4)
  writer.write_u32_le(3)
  let result = parse_loisvm_linked_program_binary(writer.to_bytes())
  assert_true(result is Err(_))
}

///|
test "linked executable lowers through the LoisVM boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let linked : @module_compile.LinkedExecutableProgram = {
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
    externals: { builtins: [] },
    entry: {
      module_path_text: "Main",
      name: "main",
      value: main,
      type_: main_type,
    },
    runtime_effect_operations: [],
  }
  assert_true(
    lower_linked_executable_to_loisvm_bytecode(linked)
    is Ok({ entry: { value: 1 }, functions: [BytecodeBody(_)], .. }),
  )
}
