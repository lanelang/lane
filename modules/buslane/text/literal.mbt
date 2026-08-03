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
    let result = match tokens[index].0 {
      // A bare integer is an `I64` literal unless it is the unique half of a
      // name, which is an identity rather than a value.
      INT(text) =>
        if is_wrapped_literal_argument(tokens, index) ||
          tokens.get(index - 1) is Some((HASH, _)) {
          None
        } else {
          Some(parse_i64_literal(text))
        }
      I32_LITERAL => wrapped_literal_argument(tokens, index, parse_i32_literal)
      CHAR_LITERAL =>
        wrapped_literal_argument(tokens, index, parse_char_literal)
      F32_LITERAL => wrapped_float_argument(tokens, index, parse_f32_bits)
      F64_LITERAL => wrapped_float_argument(tokens, index, parse_f64_bits)
      _ => None
    }
    if result is Some(Err(message)) {
      return Err(message)
    }
  }
  Ok(())
}

///|
fn is_wrapped_literal_argument(
  tokens : Array[(Token, SourceSpan)],
  index : Int,
) -> Bool {
  guard tokens.get(index - 1) is Some((LPAREN, _)) else { return false }
  match tokens.get(index - 2) {
    Some((I32_LITERAL, _)) | Some((CHAR_LITERAL, _)) => true
    _ => false
  }
}

///|
fn wrapped_literal_argument(
  tokens : Array[(Token, SourceSpan)],
  index : Int,
  parse : (String) -> Result[@buslane.Literal, String],
) -> Result[@buslane.Literal, String]? {
  guard tokens.get(index + 1) is Some((LPAREN, _)) else { return None }
  guard tokens.get(index + 2) is Some((INT(text), _)) else { return None }
  Some(parse(text))
}

///|
fn wrapped_float_argument(
  tokens : Array[(Token, SourceSpan)],
  index : Int,
  parse : (String) -> Result[@buslane.Literal, String],
) -> Result[@buslane.Literal, String]? {
  guard tokens.get(index + 1) is Some((LPAREN, _)) else { return None }
  guard tokens.get(index + 2) is Some((FLOAT_BITS(text), _)) else {
    return None
  }
  Some(parse(text))
}
