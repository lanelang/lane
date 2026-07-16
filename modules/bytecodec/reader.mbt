///|
/// A forward-only cursor over immutable bytes with absolute offset tracking.
pub struct ByteReader {
  priv mut view : BytesView
  priv mut offset : Int
}

///|
/// Creates a reader positioned at byte zero.
pub fn ByteReader::from_bytes(bytes : Bytes) -> ByteReader {
  { view: bytes[:], offset: 0 }
}

///|
/// Returns the absolute offset of the next unread byte.
pub fn ByteReader::offset(self : ByteReader) -> Int {
  self.offset
}

///|
/// Returns the unread suffix for a small bitstring-pattern parser.
pub fn ByteReader::view(self : ByteReader) -> BytesView {
  self.view
}

///|
/// Commits a suffix obtained by pattern matching `view()`.
///
/// Passing a view that is not a suffix of the current view is a programmer
/// error and aborts. The reader retains its current backing bytes rather than
/// adopting storage from the supplied view.
pub fn ByteReader::update_view(self : ByteReader, rest : BytesView) -> Unit {
  let current_start = self.view.start_offset()
  let current_end = current_start + self.view.length()
  let rest_start = rest.start_offset()
  let rest_end = rest_start + rest.length()
  if rest_start < current_start || rest_end != current_end {
    abort("ByteReader::update_view requires a suffix of the current view")
  }
  let consumed = rest_start - current_start
  let suffix = self.view[consumed:]
  if !physical_equal(self.view.data(), rest.data()) && suffix != rest {
    abort("ByteReader::update_view requires a suffix of the current view")
  }
  self.offset += consumed
  self.view = suffix
}

///|
/// Returns the number of unread bytes in the current reader.
pub fn ByteReader::remaining(self : ByteReader) -> Int {
  self.view.length()
}

///|
/// Rejects trailing bytes.
pub fn ByteReader::expect_end(self : ByteReader) -> Unit raise ByteDecodeError {
  let remaining = self.remaining()
  if remaining != 0 {
    raise TrailingBytes(offset=self.offset, remaining~)
  }
}

///|
/// Reads one unsigned byte as an `Int` in `0..=255`.
pub fn ByteReader::read_u8(self : ByteReader) -> Int raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [u8be(value), .. rest] => {
      self.update_view(rest)
      value.reinterpret_as_int()
    }
    _ => raise UnexpectedEnd(offset~, expected="u8", available=self.remaining())
  }
}

///|
/// Reads a canonical boolean and rejects bytes other than zero or one.
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
/// Reads a signed 32-bit little-endian value.
pub fn ByteReader::read_i32_le(self : ByteReader) -> Int raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [i32le(value), .. rest] => {
      self.update_view(rest)
      value
    }
    _ =>
      raise UnexpectedEnd(offset~, expected="i32le", available=self.remaining())
  }
}

///|
/// Reads an unsigned 32-bit little-endian value without host-range loss.
pub fn ByteReader::read_u32_le(self : ByteReader) -> UInt raise ByteDecodeError {
  let offset = self.offset
  match self.view {
    [i32le(value), .. rest] => {
      self.update_view(rest)
      value.reinterpret_as_uint()
    }
    _ =>
      raise UnexpectedEnd(offset~, expected="u32le", available=self.remaining())
  }
}

///|
/// Reads an unsigned 32-bit value into a nonnegative host `Int`.
///
/// Values above `Int::max_value()` raise `ImplementationLimit` after consuming
/// the four encoded bytes.
pub fn ByteReader::read_u32_le_int(
  self : ByteReader,
) -> Int raise ByteDecodeError {
  let offset = self.offset
  let value = self.read_u32_le()
  if value > 0x7FFFFFFFU {
    raise ImplementationLimit(offset~, expected="u32le")
  }
  value.reinterpret_as_int()
}

///|
/// Reads a signed 64-bit little-endian value.
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
/// Reads an unsigned 64-bit little-endian value.
pub fn ByteReader::read_u64_le(
  self : ByteReader,
) -> UInt64 raise ByteDecodeError {
  self.read_i64_le().reinterpret_as_uint64()
}

///|
/// Reads an IEEE-754 32-bit float bit pattern.
pub fn ByteReader::read_f32_le(
  self : ByteReader,
) -> Float raise ByteDecodeError {
  Float::reinterpret_from_int(self.read_i32_le())
}

///|
/// Reads an IEEE-754 64-bit float bit pattern.
pub fn ByteReader::read_f64_le(
  self : ByteReader,
) -> Double raise ByteDecodeError {
  self.read_i64_le().reinterpret_as_double()
}

///|
/// Reads an exact byte view without allocating.
pub fn ByteReader::read_raw_view(
  self : ByteReader,
  length : Int,
  expected? : String = "byte payload",
) -> BytesView raise ByteDecodeError {
  let offset = self.offset
  if length < 0 || self.remaining() < length {
    raise UnexpectedEnd(offset~, expected~, available=self.remaining())
  }
  let payload = self.view[:length]
  self.update_view(self.view[length:])
  payload
}

///|
/// Reads and copies an exact number of bytes.
pub fn ByteReader::read_raw_bytes(
  self : ByteReader,
  length : Int,
) -> Bytes raise ByteDecodeError {
  self.read_raw_view(length).to_owned()
}

///|
/// Consumes a bounded section and returns a child reader for it.
///
/// The child reports offsets relative to the original input, while the parent
/// is positioned immediately after the complete section.
pub fn ByteReader::read_section(
  self : ByteReader,
  length : Int,
  expected? : String = "section",
) -> ByteReader raise ByteDecodeError {
  let offset = self.offset
  let view = self.read_raw_view(length, expected~)
  { view, offset }
}

///|
/// Reads a u32-length-prefixed byte string.
pub fn ByteReader::read_bytes(self : ByteReader) -> Bytes raise ByteDecodeError {
  let offset = self.offset
  let length = self.read_u32_le_int()
  self.read_raw_view(length, expected="byte payload").to_owned() catch {
    UnexpectedEnd(available~, ..) =>
      raise UnexpectedEnd(
        offset=offset + 4,
        expected="byte payload",
        available~,
      )
    error => raise error
  }
}

///|
/// Reads a u32-length-prefixed UTF-8 string.
pub fn ByteReader::read_string(
  self : ByteReader,
) -> String raise ByteDecodeError {
  let offset = self.offset
  let bytes = self.read_bytes()
  @utf8.decode(bytes) catch {
    _ => raise InvalidUtf8(offset~)
  }
}
