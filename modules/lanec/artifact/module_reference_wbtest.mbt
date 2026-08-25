///|
test "module references roundtrip every closed variant" {
  let references : Array[@buslane_lowering.BuslaneModuleReference] = [
    Type({ index: 1, }),
    DataConstructor({ index: 2, }),
    Effect({ index: 3, }),
    Operation({ index: 4, }),
    FieldSelector({ index: 5, }),
    Value({ index: 6, }),
  ]
  let writer = @bytecodec.ByteWriter::new()
  for reference in references {
    write_module_reference(writer, reference)
  }
  let reader = @bytecodec.ByteReader::from_bytes(writer.to_bytes())
  let decoded = []
  for _ in 0..<references.length() {
    decoded.push(reader.read_module_reference())
  }
  reader.expect_end()
  assert_eq(decoded, references)
}

///|
test "module reference decoder rejects unknown tag" {
  let result = artifact_binary_decode_result(() => {
    let reader = @bytecodec.ByteReader::from_bytes(b"\x06")
    ignore(reader.read_module_reference())
    reader.expect_end()
  })
  assert_eq(
    result,
    Err(
      "invalid artifact binary: unknown BuslaneModuleReference tag 6 at byte 0",
    ),
  )
}
