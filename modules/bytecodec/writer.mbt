///|
/// An append-only in-memory writer for fixed-width binary formats.
pub struct ByteWriter {
  priv bytes : Array[Byte]
}

///|
/// Creates an empty writer.
pub fn ByteWriter::new() -> ByteWriter {
  { bytes: [] }
}

///|
/// Copies the accumulated output into immutable bytes.
pub fn ByteWriter::to_bytes(self : ByteWriter) -> Bytes {
  Bytes::from_array(self.bytes)
}

///|
/// Returns the number of bytes written so far.
pub fn ByteWriter::length(self : ByteWriter) -> Int {
  self.bytes.length()
}

///|
/// Writes the low eight bits of an integer.
pub fn ByteWriter::write_u8(self : ByteWriter, value : Int) -> Unit {
  self.bytes.push((value & 0xFF).to_byte())
}

///|
/// Writes a canonical one-byte boolean.
pub fn ByteWriter::write_bool(self : ByteWriter, value : Bool) -> Unit {
  self.write_u8(if value { 1 } else { 0 })
}

///|
/// Writes the exact two's-complement bit pattern of an `Int` in little-endian order.
pub fn ByteWriter::write_i32_le(self : ByteWriter, value : Int) -> Unit {
  self.write_u8(value)
  self.write_u8(value >> 8)
  self.write_u8(value >> 16)
  self.write_u8(value >> 24)
}

///|
/// Writes a nonnegative host `Int` as an unsigned 32-bit value.
///
/// This aborts when `value` is negative. Use `write_i32_le` when the signed bit
/// pattern is intentional.
pub fn ByteWriter::write_u32_le_int(self : ByteWriter, value : Int) -> Unit {
  if value < 0 {
    abort("ByteWriter::write_u32_le_int requires a nonnegative Int")
  }
  self.write_i32_le(value)
}

///|
/// Writes an unsigned 32-bit value in little-endian order.
pub fn ByteWriter::write_u32_le(self : ByteWriter, value : UInt) -> Unit {
  self.write_i32_le(value.reinterpret_as_int())
}

///|
/// Writes an unsigned 64-bit value in little-endian order.
pub fn ByteWriter::write_u64_le(self : ByteWriter, value : UInt64) -> Unit {
  self.write_raw_bytes(value.to_le_bytes())
}

///|
/// Writes a signed 64-bit value in little-endian order.
pub fn ByteWriter::write_i64_le(self : ByteWriter, value : Int64) -> Unit {
  self.write_u64_le(value.reinterpret_as_uint64())
}

///|
/// Writes the IEEE-754 bit pattern of a 32-bit float.
pub fn ByteWriter::write_f32_le(self : ByteWriter, value : Float) -> Unit {
  self.write_i32_le(value.reinterpret_as_int())
}

///|
/// Writes the IEEE-754 bit pattern of a 64-bit float.
pub fn ByteWriter::write_f64_le(self : ByteWriter, value : Double) -> Unit {
  self.write_i64_le(value.reinterpret_as_int64())
}

///|
/// Appends bytes without a length prefix.
pub fn ByteWriter::write_raw_bytes(self : ByteWriter, value : Bytes) -> Unit {
  for byte in value {
    self.bytes.push(byte)
  }
}

///|
/// Writes a u32-length-prefixed byte string.
pub fn ByteWriter::write_bytes(self : ByteWriter, value : Bytes) -> Unit {
  self.write_u32_le_int(value.length())
  self.write_raw_bytes(value)
}

///|
/// Writes a u32-length-prefixed UTF-8 string.
pub fn ByteWriter::write_string(self : ByteWriter, value : String) -> Unit {
  self.write_bytes(@utf8.encode(value))
}
