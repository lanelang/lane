///|
fn validated_literal(
  result : Result[@buslane.Literal, String],
) -> @buslane.Literal {
  match result {
    Ok(literal) => literal
    Err(message) => abort("unvalidated Buslane literal: \{message}")
  }
}

///|
fn parse_i64_literal(text : String) -> Result[@buslane.Literal, String] {
  Ok(I64(@string.parse_int64(text, base=10))) catch {
    _ => Err("invalid i64 literal `\{text}`")
  }
}

///|
fn parse_i32_literal(text : String) -> Result[@buslane.Literal, String] {
  Ok(I32(@string.parse_int(text, base=10))) catch {
    _ => Err("invalid i32 literal `\{text}`")
  }
}

///|
fn parse_char_literal(text : String) -> Result[@buslane.Literal, String] {
  let value = @string.parse_int(text, base=10) catch {
    _ => return Err("invalid Char literal `\{text}`")
  }
  match value.to_char() {
    Some(scalar) => Ok(Char(scalar.to_int()))
    None => Err("Char literal `\{text}` is not a Unicode scalar value")
  }
}

///|
fn parse_f32_bits(text : String) -> Result[@buslane.Literal, String] {
  if text.length() != 10 {
    return Err("invalid f32 bit pattern `\{text}`")
  }
  let bits = @string.parse_uint(text, base=0) catch {
    _ => return Err("invalid f32 bit pattern `\{text}`")
  }
  Ok(F32(Float::reinterpret_from_uint(bits)))
}

///|
fn parse_f64_bits(text : String) -> Result[@buslane.Literal, String] {
  if text.length() != 18 {
    return Err("invalid f64 bit pattern `\{text}`")
  }
  let bits = @string.parse_uint64(text, base=0) catch {
    _ => return Err("invalid f64 bit pattern `\{text}`")
  }
  Ok(F64(bits.reinterpret_as_double()))
}

///|
fn validate_literal_tokens(
  tokens : Array[(Token, SourceSpan)],
) -> Result[Unit, String] {
  for index in 0..<tokens.length() {
    let kind = tokens[index].0
    let is_literal_kind = match kind {
      I64_LITERAL | I32_LITERAL | CHAR_LITERAL | F32_LITERAL | F64_LITERAL =>
        true
      _ => false
    }
    if !is_literal_kind {
      continue
    }
    guard tokens.get(index + 1) is Some((LPAREN, _)) else { continue }
    guard tokens.get(index + 2) is Some((token, _)) else { continue }
    let result = match (kind, token) {
      (I64_LITERAL, INT(text)) => Some(parse_i64_literal(text))
      (I32_LITERAL, INT(text)) => Some(parse_i32_literal(text))
      (CHAR_LITERAL, INT(text)) => Some(parse_char_literal(text))
      (F32_LITERAL, FLOAT_BITS(text)) => Some(parse_f32_bits(text))
      (F64_LITERAL, FLOAT_BITS(text)) => Some(parse_f64_bits(text))
      _ => None
    }
    if result is Some(Err(message)) {
      return Err(message)
    }
  }
  Ok(())
}
