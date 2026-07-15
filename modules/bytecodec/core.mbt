///|
pub(all) suberror ByteDecodeError {
  UnexpectedEnd(offset~ : Int, expected~ : String, available~ : Int)
  InvalidUtf8(offset~ : Int)
  InvalidBool(offset~ : Int, value~ : Int)
  TrailingBytes(offset~ : Int, remaining~ : Int)
} derive(Debug, Eq)

///|
pub(all) struct ByteWriter {
  bytes : Array[Byte]
} derive(Debug, Eq)

///|
pub(all) struct ByteReader {
  mut view : BytesView
  mut offset : Int
} derive(Debug, Eq)

///|
pub fn ByteWriter::new() -> ByteWriter {
  { bytes: [] }
}

///|
pub fn ByteWriter::to_bytes(self : ByteWriter) -> Bytes {
  Bytes::from_array(self.bytes)
}

///|
pub fn ByteWriter::length(self : ByteWriter) -> Int {
  self.bytes.length()
}

///|
pub fn ByteWriter::write_u8(self : ByteWriter, value : Int) -> Unit {
  self.bytes.push((value & 0xFF).to_byte())
}

///|
pub fn ByteWriter::write_bool(self : ByteWriter, value : Bool) -> Unit {
  self.write_u8(if value { 1 } else { 0 })
}

///|
pub fn ByteWriter::write_u32_le(self : ByteWriter, value : Int) -> Unit {
  self.write_u8(value)
  self.write_u8(value >> 8)
  self.write_u8(value >> 16)
  self.write_u8(value >> 24)
}

///|
pub fn ByteWriter::write_i64_le(self : ByteWriter, value : Int64) -> Unit {
  self.write_raw_bytes(value.reinterpret_as_uint64().to_le_bytes())
}

///|
pub fn ByteWriter::write_f64_le(self : ByteWriter, value : Double) -> Unit {
  self.write_i64_le(value.reinterpret_as_int64())
}

///|
pub fn ByteWriter::write_raw_bytes(self : ByteWriter, value : Bytes) -> Unit {
  for byte in value {
    self.bytes.push(byte)
  }
}

///|
pub fn ByteWriter::write_bytes(self : ByteWriter, value : Bytes) -> Unit {
  self.write_u32_le(value.length())
  self.write_raw_bytes(value)
}

///|
pub fn ByteWriter::write_string(self : ByteWriter, value : String) -> Unit {
  self.write_bytes(@utf8.encode(value))
}

///|
pub fn ByteReader::from_bytes(bytes : Bytes) -> ByteReader {
  { view: bytes[:], offset: 0 }
}

///|
pub fn ByteReader::offset(self : ByteReader) -> Int {
  self.offset
}

///|
pub fn ByteReader::view(self : ByteReader) -> BytesView {
  self.view
}

///|
pub fn ByteReader::update_view(self : ByteReader, rest : BytesView) -> Unit {
  self.offset += self.view.length() - rest.length()
  self.view = rest
}

///|
pub fn ByteReader::remaining(self : ByteReader) -> Int {
  self.view.length()
}

///|
pub fn ByteReader::expect_end(self : ByteReader) -> Unit raise ByteDecodeError {
  let remaining = self.remaining()
  if remaining != 0 {
    raise TrailingBytes(offset=self.offset, remaining~)
  }
}

///|
pub fn ByteReader::read_bool(self : ByteReader) -> Bool raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      false
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      true
    }
    [u8be(value), .. rest] => {
      self.update_view(rest)
      raise InvalidBool(offset~, value=value.reinterpret_as_int())
    }
    _ => raise UnexpectedEnd(offset~, expected="u8", available=self.remaining())
  }
}

///|
pub fn ByteReader::read_u32_le(self : ByteReader) -> Int raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [i32le(value), .. rest] => {
      self.update_view(rest)
      value
    }
    _ =>
      raise UnexpectedEnd(offset~, expected="u32le", available=self.remaining())
  }
}

///|
pub fn ByteReader::read_i64_le(
  self : ByteReader,
) -> Int64 raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [i64le(value), .. rest] => {
      self.update_view(rest)
      value
    }
    _ =>
      raise UnexpectedEnd(offset~, expected="i64le", available=self.remaining())
  }
}

///|
pub fn ByteReader::read_f64_le(
  self : ByteReader,
) -> Double raise ByteDecodeError {
  self.read_i64_le().reinterpret_as_double()
}

///|
pub fn ByteReader::read_raw_bytes(
  self : ByteReader,
  length : Int,
) -> Bytes raise ByteDecodeError {
  let offset = self.offset
  if length < 0 {
    raise UnexpectedEnd(
      offset~,
      expected="byte payload",
      available=self.remaining(),
    )
  }
  if self.remaining() < length {
    raise UnexpectedEnd(
      offset~,
      expected="byte payload",
      available=self.remaining(),
    )
  }
  let payload = self.view[:length].to_owned()
  self.update_view(self.view[length:])
  payload
}

///|
pub fn ByteReader::read_bytes(self : ByteReader) -> Bytes raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [i32le(length), .. rest] if length >= 0 => {
      self.update_view(rest)
      self.read_raw_bytes(length)
    }
    [i32le(_), ..] => {
      self.update_view(self.view[4:])
      raise UnexpectedEnd(
        offset=offset + 4,
        expected="byte payload",
        available=self.remaining(),
      )
    }
    _ =>
      raise UnexpectedEnd(offset~, expected="u32le", available=self.remaining())
  }
}

///|
pub fn ByteReader::read_string(
  self : ByteReader,
) -> String raise ByteDecodeError {
  let offset = self.offset
  let bytes = self.read_bytes()
  @utf8.decode(bytes) catch {
    _ => raise InvalidUtf8(offset~)
  }
}
