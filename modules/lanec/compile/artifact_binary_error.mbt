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
fn[T] artifact_binary_decode_result(
  decode : () -> T raise,
) -> Result[T, String] {
  Ok(decode()) catch {
    ByteError(error) => Err("invalid artifact binary: \{to_repr(error)}")
    BuslaneError(error) => Err("invalid Buslane payload: \{to_repr(error)}")
    UnsupportedContainerVersion(version~) =>
      Err("unsupported artifact binary container version \{version}")
    UnsupportedArtifactSchema(kind~, version~) =>
      Err("unsupported \{kind} artifact schema version \{version}")
    InvalidMagic(offset~) =>
      Err(
        "invalid artifact binary: expected Lane artifact magic at byte \{offset}",
      )
    InvalidKind(kind~) =>
      Err("unknown artifact binary kind \{artifact_binary_kind_name(kind)}")
    InvalidTag(offset~, domain~, tag~) =>
      Err(
        "invalid artifact binary: unknown \{domain} tag \{tag} at byte \{offset}",
      )
    WrongKind(expected~, actual~) =>
      Err(
        "wrong artifact binary kind: expected \{artifact_binary_kind_name(expected)}, got \{artifact_binary_kind_name(actual)}",
      )
    error => Err("invalid artifact binary: \{to_repr(error)}")
  }
}

///|
fn[T] invalid_binary_tag(
  offset~ : Int,
  domain~ : String,
  tag~ : Int,
) -> T raise {
  raise InvalidTag(offset~, domain~, tag~)
}

///|
fn[T] unexpected_u8(reader : @bytecodec.ByteReader) -> T raise {
  raise ByteError(
    UnexpectedEnd(
      offset=reader.offset(),
      expected="u8",
      available=reader.remaining(),
    ),
  )
}
