///|
test "writer and reader roundtrip primitive values" {
  let writer = ByteWriter::new()
  writer.write_u8(0xAB)
  writer.write_bool(true)
  writer.write_bool(false)
  writer.write_u32_le(0x12345678U)
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
  inspect(reader.read_u8(), content="171")
  inspect(reader.read_bool(), content="true")
  inspect(reader.read_bool(), content="false")
  inspect(reader.read_u32_le_int(), content="305419896")
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
test "fixed-width codecs preserve exact bit patterns" {
  let writer = ByteWriter::new()
  writer.write_i32_le(-1)
  writer.write_u32_le(0xFFFFFFFFU)
  writer.write_u64_le(0xFEDCBA9876543210UL)
  writer.write_f32_le(Float::from_double(-0.0))
  let reader = ByteReader::from_bytes(writer.to_bytes())
  inspect(reader.read_i32_le(), content="-1")
  inspect(reader.read_u32_le(), content="4294967295")
  inspect(reader.read_u64_le(), content="18364758544493064720")
  inspect(reader.read_f32_le().reinterpret_as_int(), content="-2147483648")
  reader.expect_end()
}

///|
test "signed-host u32 conversion reports its implementation limit" {
  let writer = ByteWriter::new()
  writer.write_u32_le(0xFFFFFFFFU)
  let reader = ByteReader::from_bytes(writer.to_bytes())
  let error = try {
    ignore(reader.read_u32_le_int())
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(
    (error, reader.offset(), reader.remaining()),
    content=(
      #|(Some(ImplementationLimit(offset=0, expected="u32le")), 4, 0)
    ),
  )
}

///|
test "panic writer rejects negative unsigned Int adapter input" {
  let writer = ByteWriter::new()
  writer.write_u32_le_int(-1)
}

///|
test "panic reader rejects suffix from different bytes" {
  let reader = ByteReader::from_bytes(b"abc")
  reader.update_view(b"xyz"[:])
}

///|
test "reader never adopts storage from an equivalent foreign suffix" {
  let source = Bytes::from_array([b'a', b'b', b'c'])
  let foreign = Bytes::from_array([b'a', b'b', b'c'])
  assert_false(physical_equal(source, foreign))
  let reader = ByteReader::from_bytes(source)
  reader.update_view(foreign[1:])
  assert_true(physical_equal(reader.view().data(), source))
  inspect(reader.read_raw_bytes(2), content="b\"bc\"")
}

///|
test "bounded readers preserve absolute offsets" {
  let reader = ByteReader::from_bytes(b"\x01\x02\x03\x04")
  inspect(reader.read_u8(), content="1")
  let section = reader.read_section(2, expected="test section")
  debug_inspect(
    (
      section.offset(),
      section.read_raw_view(2).to_owned(),
      section.offset(),
      reader.offset(),
      reader.read_u8(),
    ),
    content=(
      #|(1, <Bytes: [0x02, 0x03]>, 3, 3, 4)
    ),
  )
  section.expect_end()
  reader.expect_end()
}

///|
test "bounded reader rejects overrun without consuming its parent" {
  let reader = ByteReader::from_bytes(b"\x01\x02")
  let error = try {
    ignore(reader.read_section(3, expected="record"))
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(
    (error, reader.offset(), reader.remaining()),
    content=(
      #|(Some(UnexpectedEnd(offset=0, expected="record", available=2)), 0, 2)
    ),
  )
}

///|
test "reader reports unexpected end with offset" {
  let reader = ByteReader::from_bytes(Bytes::from_array([b'\x01', b'\x02']))
  let error = try {
    ignore(reader.read_u32_le_int())
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
