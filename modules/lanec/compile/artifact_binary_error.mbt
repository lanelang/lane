///|
priv suberror ArtifactBinaryDecodeError {
  ByteError(@bytecodec.ByteDecodeError)
  BuslaneError(@buslane_codec.BuslaneDecodeError)
  UnsupportedContainerVersion(version~ : Int)
  UnsupportedArtifactSchema(kind~ : String, version~ : Int)
  InvalidMagic(offset~ : Int)
  InvalidKind(kind~ : Int)
  InvalidTag(offset~ : Int, domain~ : String, tag~ : Int)
  WrongKind(expected~ : Int, actual~ : Int)
} derive(Debug)

///|
fn artifact_binary_decode_error(error : ArtifactBinaryDecodeError) -> String {
  match error {
    ByteError(error) => "invalid artifact binary: \{to_repr(error)}"
    BuslaneError(error) => "invalid Buslane payload: \{to_repr(error)}"
    UnsupportedContainerVersion(version~) =>
      "unsupported artifact binary container version \{version}"
    UnsupportedArtifactSchema(kind~, version~) =>
      "unsupported \{kind} artifact schema version \{version}"
    InvalidMagic(offset~) =>
      "invalid artifact binary: expected Lane artifact magic at byte \{offset}"
    InvalidKind(kind~) =>
      "unknown artifact binary kind \{artifact_binary_kind_name(kind)}"
    InvalidTag(offset~, domain~, tag~) =>
      "invalid artifact binary: unknown \{domain} tag \{tag} at byte \{offset}"
    WrongKind(expected~, actual~) =>
      "wrong artifact binary kind: expected \{artifact_binary_kind_name(expected)}, got \{artifact_binary_kind_name(actual)}"
  }
}

///|
fn[T] invalid_binary_tag(
  offset~ : Int,
  domain~ : String,
  tag~ : Int,
) -> T raise ArtifactBinaryDecodeError {
  raise InvalidTag(offset~, domain~, tag~)
}

///|
fn read_u8(
  reader : @bytecodec.ByteReader,
) -> Int raise ArtifactBinaryDecodeError {
  reader.read_u8() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_bool(
  reader : @bytecodec.ByteReader,
) -> Bool raise ArtifactBinaryDecodeError {
  reader.read_bool() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_u32_le(
  reader : @bytecodec.ByteReader,
) -> Int raise ArtifactBinaryDecodeError {
  reader.read_u32_le() catch {
    error => raise ByteError(error)
  }
}

///|
fn read_string(
  reader : @bytecodec.ByteReader,
) -> String raise ArtifactBinaryDecodeError {
  reader.read_string() catch {
    error => raise ByteError(error)
  }
}

///|
fn expect_end(
  reader : @bytecodec.ByteReader,
) -> Unit raise ArtifactBinaryDecodeError {
  reader.expect_end() catch {
    error => raise ByteError(error)
  }
}
