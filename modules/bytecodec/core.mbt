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
  bytes : Bytes
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
  { bytes, offset: 0 }
}

///|
pub fn ByteReader::offset(self : ByteReader) -> Int {
  self.offset
}

///|
pub fn ByteReader::remaining(self : ByteReader) -> Int {
  self.bytes.length() - self.offset
}

///|
pub fn ByteReader::expect_end(self : ByteReader) -> Unit raise ByteDecodeError {
  let remaining = self.remaining()
  if remaining != 0 {
    raise TrailingBytes(offset=self.offset, remaining~)
  }
}

///|
pub fn ByteReader::read_u8(self : ByteReader) -> Int raise ByteDecodeError {
  self.require(1, expected="u8")
  let value = self.bytes[self.offset].to_int()
  self.offset += 1
  value
}

///|
pub fn ByteReader::read_bool(self : ByteReader) -> Bool raise ByteDecodeError {
  let offset = self.offset
  let value = self.read_u8()
  if value == 0 {
    false
  } else if value == 1 {
    true
  } else {
    raise InvalidBool(offset~, value~)
  }
}

///|
pub fn ByteReader::read_u32_le(self : ByteReader) -> Int raise ByteDecodeError {
  self.require(4, expected="u32le")
  let value = self.bytes[self.offset].to_int() |
    (self.bytes[self.offset + 1].to_int() << 8) |
    (self.bytes[self.offset + 2].to_int() << 16) |
    (self.bytes[self.offset + 3].to_int() << 24)
  self.offset += 4
  value
}

///|
pub fn ByteReader::read_i64_le(
  self : ByteReader,
) -> Int64 raise ByteDecodeError {
  self.require(8, expected="i64le")
  let mut value = 0L
  for index in 0..<8 {
    value = value |
      (Int64::from_int(self.bytes[self.offset + index].to_int()) << (index * 8))
  }
  self.offset += 8
  value
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
  self.require(length, expected="byte payload")
  let start = self.offset
  let end = start + length
  self.offset = end
  self.bytes[start:end].to_owned()
}

///|
pub fn ByteReader::read_bytes(self : ByteReader) -> Bytes raise ByteDecodeError {
  let length = self.read_u32_le()
  self.read_raw_bytes(length)
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

///|
fn ByteReader::require(
  self : ByteReader,
  count : Int,
  expected~ : String,
) -> Unit raise ByteDecodeError {
  let available = self.remaining()
  if count < 0 || available < count {
    raise UnexpectedEnd(offset=self.offset, expected~, available~)
  }
}
