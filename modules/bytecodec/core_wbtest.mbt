///|
test "writer and reader roundtrip primitive values" {
  let writer = ByteWriter::new()
  writer.write_u8(0xAB)
  writer.write_bool(true)
  writer.write_bool(false)
  writer.write_u32_le(0x12345678)
  writer.write_i64_le(-42L)
  writer.write_f64_le(1.25)
  writer.write_raw_bytes(Bytes::from_array([b'L', b'A']))
  writer.write_string("Lane")
  writer.write_bytes(Bytes::from_array([b'\xFE', b'\xDC']))
  debug_inspect(
    writer.to_bytes().to_array().map(fn(byte) { byte.to_int() }),
    content=(
      #|[
      #|  171,
      #|  1,
      #|  0,
      #|  120,
      #|  86,
      #|  52,
      #|  18,
      #|  214,
      #|  255,
      #|  255,
      #|  255,
      #|  255,
      #|  255,
      #|  255,
      #|  255,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  244,
      #|  63,
      #|  76,
      #|  65,
      #|  4,
      #|  0,
      #|  0,
      #|  0,
      #|  76,
      #|  97,
      #|  110,
      #|  101,
      #|  2,
      #|  0,
      #|  0,
      #|  0,
      #|  254,
      #|  220,
      #|]
    ),
  )
  let reader = ByteReader::from_bytes(writer.to_bytes())
  inspect(reader.read_raw_bytes(1).to_string(), content="b\"\\xab\"")
  inspect(reader.read_bool(), content="true")
  inspect(reader.read_bool(), content="false")
  inspect(reader.read_u32_le(), content="305419896")
  inspect(reader.read_i64_le(), content="-42")
  inspect(reader.read_f64_le(), content="1.25")
  inspect(reader.read_raw_bytes(2).to_string(), content="b\"LA\"")
  inspect(reader.read_string(), content="Lane")
  debug_inspect(
    reader.read_bytes().to_array().map(fn(byte) { byte.to_int() }),
    content="[254, 220]",
  )
  reader.expect_end()
}

///|
test "reader reports unexpected end with offset" {
  let reader = ByteReader::from_bytes(Bytes::from_array([b'\x01', b'\x02']))
  let error = try {
    ignore(reader.read_u32_le())
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(
    error,
    content=(
      #|Some(UnexpectedEnd(offset=0, expected="u32le", available=2))
    ),
  )
}

///|
test "reader rejects invalid bool" {
  let reader = ByteReader::from_bytes(Bytes::from_array([b'\x02']))
  let error = try {
    ignore(reader.read_bool())
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(error, content="Some(InvalidBool(offset=0, value=2))")
}

///|
test "reader rejects invalid utf8" {
  let writer = ByteWriter::new()
  writer.write_bytes(Bytes::from_array([b'\xFF']))
  let reader = ByteReader::from_bytes(writer.to_bytes())
  let error = try {
    ignore(reader.read_string())
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(error, content="Some(InvalidUtf8(offset=0))")
}

///|
test "reader rejects trailing bytes" {
  let reader = ByteReader::from_bytes(Bytes::from_array([b'\x00', b'\x01']))
  inspect(reader.read_bool(), content="false")
  let error = try {
    reader.expect_end()
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(error, content="Some(TrailingBytes(offset=1, remaining=1))")
}
