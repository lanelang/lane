///|
fn[T] invalid_tag(
  offset~ : Int,
  domain~ : String,
  tag~ : Int,
) -> T raise BuslaneDecodeError {
  raise InvalidTag(offset~, domain~, tag~)
}

///|
fn read_u8(reader : @bytecodec.ByteReader) -> Int raise BuslaneDecodeError {
  reader.read_u8() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_bool(reader : @bytecodec.ByteReader) -> Bool raise BuslaneDecodeError {
  reader.read_bool() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_u32_le(reader : @bytecodec.ByteReader) -> Int raise BuslaneDecodeError {
  reader.read_u32_le() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_i64_le(
  reader : @bytecodec.ByteReader,
) -> Int64 raise BuslaneDecodeError {
  reader.read_i64_le() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_f64_le(
  reader : @bytecodec.ByteReader,
) -> Double raise BuslaneDecodeError {
  reader.read_f64_le() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_string(
  reader : @bytecodec.ByteReader,
) -> String raise BuslaneDecodeError {
  reader.read_string() catch {
    error => raise ByteError(error)
  }
}

///|
fn expect_end(reader : @bytecodec.ByteReader) -> Unit raise BuslaneDecodeError {
  reader.expect_end() catch {
    error => raise ByteError(error)
  }
}
