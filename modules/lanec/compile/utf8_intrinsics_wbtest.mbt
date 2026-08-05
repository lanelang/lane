///|
test "module artifacts roundtrip every Char and UTF-8 intrinsic" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|
      #|pub let char_to_i32 : (Char) -> I32 = builtin("%char_to_i32")
      #|pub let i32_to_char : (I32) -> Char = builtin("%i32_to_char")
      #|pub let string_to_bytes : (String) -> Bytes = builtin("%string_to_bytes")
      #|pub let bytes_is_valid_utf8 : (Bytes) -> Bool = builtin("%bytes_is_valid_utf8")
      #|pub let bytes_to_string : (Bytes) -> String = builtin("%bytes_to_string")
      #|pub let bytes_equal : (Bytes, Bytes) -> Bool = builtin("%bytes_equal")
      #|pub let bytes_concat : (Bytes, Bytes) -> Bytes = builtin("%bytes_concat")
      #|pub let bytes_slice : (Bytes, I64, I64) -> Bytes = builtin("%bytes_slice")
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    fail("expected compiled modules")
  }
  guard modules.to_artifact().modules is [module_] else {
    fail("expected one module artifact")
  }
  let binary = @artifact.module_object_artifact_to_binary(module_.object)
  let decoded = match @artifact.parse_module_object_artifact_binary(binary) {
    Ok(object) => object
    Err(message) => fail(message)
  }
  assert_eq(decoded, module_.object)
}

///|
test "compiler erases representation-identical Char conversion" {
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let char_to_i32 : (Char) -> I32 = builtin("%char_to_i32")
      #|let i32_to_int : (I32) -> I64 = builtin("%i32_to_i64")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  observe(i32_to_int(char_to_i32('😀')))
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  callable_abis: [
      #|    { witness_count: 0, parameters: [], result: Unit },
      #|    {
      #|      witness_count: 0,
      #|      parameters: [{ representation: I64, cleanup: Trivial }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I64, cleanup: Trivial, erased_companion: None },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstChar({ value: 0 }, 128512),
      #|              I32ToI64({ value: 1 }, { value: 0 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 1 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        abi_major: 1,
      #|        parameters: [I64],
      #|        result: Unit,
      #|        symbol: "lane.test.observe",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [],
      #|  layouts: [],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}

///|
test "artifact decoders reject pre UTF-8 schema versions" {
  let compiled = compile_modules_for_test(
    (
      #|module Test
      #|pub fn answer() -> Unit {
      #|  ()
      #|}
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) && modules.modules is [module_] else {
    fail("expected one compiled module")
  }
  let interface = module_.to_interface_artifact()
  let object = module_.to_object_artifact()
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|pub fn answer() -> Unit {
      #|  ()
      #|}
    ),
  )
  assert_eq(
    (
      @artifact.parse_module_interface_artifact_binary(
        @artifact.module_interface_artifact_to_binary({
          ..interface,
          schema_version: 9,
        }),
      ),
      @artifact.parse_module_object_artifact_binary(
        @artifact.module_object_artifact_to_binary({
          ..object,
          schema_version: 12,
        }),
      ),
      @artifact.parse_linked_program_artifact_binary(
        @artifact.linked_program_artifact_to_binary({
          schema_version: 6,
          bytecode,
        }),
      ),
    ),
    (
      Err("unsupported interface artifact schema version 9"),
      Err("unsupported object artifact schema version 12"),
      Err("unsupported program artifact schema version 6"),
    ),
  )
}
