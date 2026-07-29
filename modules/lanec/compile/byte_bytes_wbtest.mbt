///|
fn byte_bytes_instruction_name(
  instruction : @loisvm_bytecode.Instruction,
) -> String? {
  match instruction {
    ByteToInt(_, _) => Some("byte_to_int")
    IntToByte(_, _) => Some("int_to_byte")
    BytesMake(_, _, _) => Some("bytes_make")
    BytesLength(_, _) => Some("bytes_length")
    BytesGet(_, _, _) => Some("bytes_get")
    BytesSet(_, _, _, _) => Some("bytes_set")
    _ => None
  }
}

///|
test "compiler preserves Byte and Bytes through executable lowering" {
  let compiled = compile_modules(
    (
      #|module Test
      #|
      #|let byte_to_int : (Byte) -> Int = builtin("%byte_to_int")
      #|let int_to_byte : (Int) -> Byte = builtin("%int_to_byte")
      #|let bytes_make : (Int, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> Int = builtin("%bytes_length")
      #|let bytes_get : (Bytes, Int) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, Int, Byte) -> Bytes = builtin("%bytes_set")
      #|let observe : (Int) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|fn[T] identity(value : T) -> T {
      #|  value
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let fill = identity(int_to_byte(255))
      #|  let original = identity(bytes_make(2, fill))
      #|  let updated = bytes_set(original, 1, int_to_byte(0))
      #|  observe(bytes_length(updated))
      #|  observe(byte_to_int(bytes_get(updated, 1)))
      #|}
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    fail("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics, [])
  guard linked.program is Some(program) else {
    fail("expected linked Buslane program")
  }
  guard program.entries is [entry] else { fail("expected one public entry") }
  let executable = match @executable.elaborate(program, entry) {
    Ok(executable) => executable
    Err(error) => fail("executable elaboration failed: \{Repr(error)}")
  }
  let artifact = match
    @artifact_binary.executable_to_loisvm_artifact(executable) {
    Ok(artifact) => artifact
    Err(error) => fail("LoisVM lowering failed: \{Repr(error)}")
  }
  let instructions : Array[String] = []
  for function in artifact.bytecode.functions {
    if function is BytecodeBody(body) {
      for block in body.blocks {
        instructions.append(
          block.instructions.filter_map(byte_bytes_instruction_name),
        )
      }
    }
  }
  assert_eq(instructions, [
    "int_to_byte", "bytes_make", "int_to_byte", "bytes_set", "bytes_length", "bytes_get",
    "byte_to_int",
  ])
  assert_eq(
    artifact.bytecode.layouts.filter(layout => layout is Byte || layout is Bytes),
    [Byte, Bytes],
  )
}
