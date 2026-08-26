///|
fn minimal_wasm_module() -> Bytes {
  Bytes::from_array([
    b'\x00', b'\x61', b'\x73', b'\x6d', b'\x01', b'\x00', b'\x00', b'\x00',
  ])
}

///|
test "linked program persists Wasm and its semantic runtime imports" {
  let artifact : LinkedProgramArtifact = {
    wasm: minimal_wasm_module(),
    runtime_imports: [
      {
        abi_major: 1,
        parameters: [@lane_runtime.String],
        result: @lane_runtime.Unit,
        symbol: "println",
      },
    ],
  }
  let binary = linked_program_artifact_to_binary(artifact)
  assert_eq(parse_linked_program_artifact_binary(binary), Ok(artifact))
  guard binary
    is [
      .. b"LANEART\x00",
      u8be(1),
      u8be(3),
      i32le(_),
      i32le(schema_version),
      ..,
    ] else {
    fail("expected linked-program artifact framing")
  }
  assert_eq(schema_version, 17)
}

///|
test "linked program rejects the previous linked schema" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_raw_bytes(b"LANEART\x00")
  writer.write_u8(1)
  writer.write_u8(3)
  writer.write_u32_le_int(4)
  writer.write_u32_le_int(16)
  debug_inspect(
    parse_linked_program_artifact_binary(writer.to_bytes()),
    content="Err(\"unsupported program artifact schema version 16\")",
  )
}
