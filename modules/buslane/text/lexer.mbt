///|
priv suberror BuslaneTextLexerError {
  BuslaneTextLexerError(String)
} derive(Debug)

///|
fn[T] lexer_fail(message : String) -> T raise BuslaneTextLexerError {
  raise BuslaneTextLexerError(message)
}

///|
fn tokens_from_string(
  text : String,
) -> Array[(Token, SourceSpan)] raise BuslaneTextLexerError {
  let input = @utf8.encode(text)
  let tokens = []
  let mut index = 0
  while index < input.length() {
    let byte = input[index]
    if is_space(byte) {
      index = index + 1
    } else if byte == b'/' &&
      index + 1 < input.length() &&
      input[index + 1] == b'/' {
      index = skip_line_comment(input, index + 2)
    } else if byte == b'{' {
      tokens.push((LBRACE, ()))
      index = index + 1
    } else if byte == b'}' {
      tokens.push((RBRACE, ()))
      index = index + 1
    } else if byte == b'[' {
      tokens.push((LBRACKET, ()))
      index = index + 1
    } else if byte == b']' {
      tokens.push((RBRACKET, ()))
      index = index + 1
    } else if byte == b'(' {
      tokens.push((LPAREN, ()))
      index = index + 1
    } else if byte == b')' {
      tokens.push((RPAREN, ()))
      index = index + 1
    } else if byte == b',' {
      tokens.push((COMMA, ()))
      index = index + 1
    } else if byte == b':' {
      tokens.push((COLON, ()))
      index = index + 1
    } else if byte == b';' {
      tokens.push((SEMI, ()))
      index = index + 1
    } else if byte == b'=' &&
      index + 1 < input.length() &&
      input[index + 1] == b'>' {
      tokens.push((FAT_ARROW, ()))
      index = index + 2
    } else if byte == b'-' &&
      index + 1 < input.length() &&
      input[index + 1] == b'>' {
      tokens.push((ARROW, ()))
      index = index + 2
    } else if byte == b'!' {
      tokens.push((BANG, ()))
      index = index + 1
    } else if byte == b'.' {
      tokens.push((DOT, ()))
      index = index + 1
    } else if byte == b'=' {
      tokens.push((EQUAL, ()))
      index = index + 1
    } else if byte == b'"' {
      let (token, next) = read_quoted(input, index + 1)
      tokens.push((token, ()))
      index = next
    } else if is_digit(byte) || byte == b'-' {
      let (value, next) = read_integer(input, index)
      tokens.push((LITERAL(literal_value(parse_i64_literal(value))), ()))
      index = next
    } else if starts_with(input, index, "type#") {
      let (id, next) = read_prefixed_id(input, index, "type#")
      tokens.push((TYPE_ID(id), ()))
      index = next
    } else if starts_with(input, index, "tparam#") {
      let (id, next) = read_prefixed_id(input, index, "tparam#")
      tokens.push((TPARAM_ID(id), ()))
      index = next
    } else if starts_with(input, index, "value#") {
      let (id, next) = read_prefixed_id(input, index, "value#")
      tokens.push((VALUE_ID(id), ()))
      index = next
    } else if starts_with(input, index, "datacon#") {
      let (id, next) = read_prefixed_id(input, index, "datacon#")
      tokens.push((DATACON_ID(id), ()))
      index = next
    } else if starts_with(input, index, "effect#") {
      let (id, next) = read_prefixed_id(input, index, "effect#")
      tokens.push((EFFECT_ID(id), ()))
      index = next
    } else if starts_with(input, index, "operation#") {
      let (id, next) = read_prefixed_id(input, index, "operation#")
      tokens.push((OPERATION_ID(id), ()))
      index = next
    } else if is_name_start(byte) {
      let (token, next) = read_word(input, index)
      tokens.push((token, ()))
      index = next
    } else {
      lexer_fail("illegal Buslane text character")
    }
  }
  tokens.push((EOF, ()))
  tokens
}

///|
/// A word is a literal when it names one, and a keyword otherwise. Every
/// literal but the unit is read here, wrapper and all: which values a wrapper
/// admits is known exactly where the wrapper is recognised, and this is the
/// only stage that can refuse one, so it is also the only stage that decides
/// which spelling is which literal.
fn read_word(
  input : Bytes,
  index : Int,
) -> (Token, Int) raise BuslaneTextLexerError {
  let (name, next) = read_name(input, index)
  match name {
    "true" => (LITERAL(Bool(true)), next)
    "false" => (LITERAL(Bool(false)), next)
    "i32" => read_wrapped(input, next, read_integer, parse_i32_literal)
    "char" => read_wrapped(input, next, read_integer, parse_char_literal)
    "f32" => read_wrapped(input, next, read_float_bits, parse_f32_bits)
    "f64" => read_wrapped(input, next, read_float_bits, parse_f64_bits)
    _ => (keyword_token(name), next)
  }
}

///|
/// Reads `(payload)` and the literal it denotes. The pieces are read through
/// the same trivia rule the main loop uses, so a wrapper is spelled the way it
/// always was even when something separates its parts.
fn read_wrapped(
  input : Bytes,
  index : Int,
  read_payload : (Bytes, Int) -> (String, Int) raise BuslaneTextLexerError,
  parse : (String) -> Result[@buslane.Literal, String],
) -> (Token, Int) raise BuslaneTextLexerError {
  let open = expect_byte(input, index, b'(')
  let (payload, after_payload) = read_payload(input, skip_trivia(input, open))
  let close = expect_byte(input, after_payload, b')')
  (LITERAL(literal_value(parse(payload))), close)
}

///|
/// A quotation is a name when a unique follows it and a string literal
/// otherwise. The two share an opening quote, so one reader decides.
fn read_quoted(
  input : Bytes,
  index : Int,
) -> (Token, Int) raise BuslaneTextLexerError {
  let (value, after_quote) = read_string_literal(input, index)
  let after_trivia = skip_trivia(input, after_quote)
  guard after_trivia < input.length() && input[after_trivia] == b'#' else {
    return (LITERAL(String(value)), after_quote)
  }
  let (unique, after_unique) = read_index(
    input,
    skip_trivia(input, after_trivia + 1),
    "a name's unique",
  )
  (NAME((value, unique)), after_unique)
}

///|
fn literal_value(
  result : Result[@buslane.Literal, String],
) -> @buslane.Literal raise BuslaneTextLexerError {
  match result {
    Ok(literal) => literal
    Err(message) => lexer_fail(message)
  }
}

///|
fn expect_byte(
  input : Bytes,
  index : Int,
  byte : Byte,
) -> Int raise BuslaneTextLexerError {
  let next = skip_trivia(input, index)
  guard next < input.length() && input[next] == byte else {
    lexer_fail("expected `\{byte.to_int().unsafe_to_char()}` in a literal")
  }
  next + 1
}

///|
fn skip_trivia(input : Bytes, index : Int) -> Int {
  let mut next = index
  while next < input.length() {
    if is_space(input[next]) {
      next = next + 1
    } else if input[next] == b'/' &&
      next + 1 < input.length() &&
      input[next + 1] == b'/' {
      next = skip_line_comment(input, next + 2)
    } else {
      break
    }
  }
  next
}

///|
fn keyword_token(name : String) -> Token raise BuslaneTextLexerError {
  match name {
    "buslane" => BUSLANE
    "metadata" => METADATA
    "type" => TYPE
    "type_parameter" => TYPE_PARAMETER
    "value" => VALUE
    "datacon" => DATACON
    "effect" => EFFECT_DECL
    "operation" => OPERATION
    "function" => FUNCTION_KIND
    "external" => EXTERNAL
    "parameter" => PARAMETER_KIND
    "local" => LOCAL_KIND
    "match_binder" => MATCH_BINDER_KIND
    "Type" => TYPE_KIND
    "Effect" => EFFECT_KIND
    "Unit" => UNIT_TYPE
    "Bool" => BOOL_TYPE
    "I64" => I64_TYPE
    "I32" => I32_TYPE
    "Char" => CHAR_TYPE
    "F32" => F32_TYPE
    "F64" => F64_TYPE
    "String" => STRING_TYPE
    "Byte" => BYTE_TYPE
    "Bytes" => BYTES_TYPE
    "forall" => FORALL
    "in" => IN
    "as" => AS
    "final" => FINAL
    "Io" => IO
    "_" => UNDERSCORE
    "let" => LET
    "letrec" => LETREC
    "fn" => FN
    "perform" => PERFORM
    "handle" => HANDLE
    "resume" => RESUME
    "match" => MATCH
    _ => lexer_fail("unknown Buslane text keyword " + name)
  }
}

///|
fn is_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\n' || byte == b'\r' || byte == b'\t'
}

///|
fn is_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
fn is_hex_digit(byte : Byte) -> Bool {
  is_digit(byte) ||
  (byte >= b'a' && byte <= b'f') ||
  (byte >= b'A' && byte <= b'F')
}

///|
fn is_name_start(byte : Byte) -> Bool {
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'A' && byte <= b'Z') ||
  byte == b'_'
}

///|
fn is_name_continue(byte : Byte) -> Bool {
  is_name_start(byte) || is_digit(byte)
}

///|
fn skip_line_comment(input : Bytes, index : Int) -> Int {
  let mut next = index
  while next < input.length() && input[next] != b'\n' {
    next = next + 1
  }
  next
}

///|
fn starts_with(input : Bytes, index : Int, prefix : String) -> Bool {
  let bytes = @utf8.encode(prefix)
  if index + bytes.length() > input.length() {
    return false
  }
  for offset in 0..<bytes.length() {
    if input[index + offset] != bytes[offset] {
      return false
    }
  }
  true
}

///|
fn read_prefixed_id(
  input : Bytes,
  index : Int,
  prefix : String,
) -> (Int, Int) raise BuslaneTextLexerError {
  read_index(input, index + @utf8.encode(prefix).length(), prefix)
}

///|
/// Reads the unsigned index an identity is written with. An index that does
/// not fit is refused here rather than silently becoming another one.
fn read_index(
  input : Bytes,
  index : Int,
  what : String,
) -> (Int, Int) raise BuslaneTextLexerError {
  let mut next = index
  while next < input.length() && is_digit(input[next]) {
    next = next + 1
  }
  if next == index {
    lexer_fail("expected a number after " + what)
  }
  let text = @utf8.decode(input[index:next]) catch {
    _ => lexer_fail("invalid utf8 number")
  }
  (
    @string.parse_int(text, base=10) catch {
      _ => lexer_fail("number `\{text}` after \{what} is out of range")
    },
    next,
  )
}

///|
fn read_name(
  input : Bytes,
  index : Int,
) -> (String, Int) raise BuslaneTextLexerError {
  let mut next = index
  while next < input.length() && is_name_continue(input[next]) {
    next = next + 1
  }
  let value = @utf8.decode(input[index:next]) catch {
    _ => lexer_fail("invalid utf8 keyword")
  }
  (value, next)
}

///|
fn read_integer(
  input : Bytes,
  index : Int,
) -> (String, Int) raise BuslaneTextLexerError {
  let mut next = index
  if input[next] == b'-' {
    next = next + 1
  }
  let start = next
  while next < input.length() && is_digit(input[next]) {
    next = next + 1
  }
  if next == start {
    lexer_fail("expected integer")
  }
  let value = @utf8.decode(input[index:next]) catch {
    _ => lexer_fail("invalid utf8 integer")
  }
  (value, next)
}

///|
fn read_float_bits(
  input : Bytes,
  index : Int,
) -> (String, Int) raise BuslaneTextLexerError {
  let mut next = index + 2
  let start = next
  while next < input.length() && is_hex_digit(input[next]) {
    next = next + 1
  }
  if next == start {
    lexer_fail("expected hexadecimal float bits")
  }
  let value = @utf8.decode(input[index:next]) catch {
    _ => lexer_fail("invalid utf8 float bits")
  }
  (value, next)
}

///|
fn read_string_literal(
  input : Bytes,
  start : Int,
) -> (String, Int) raise BuslaneTextLexerError {
  let output = []
  let mut index = start
  while index < input.length() {
    let byte = input[index]
    if byte == b'"' {
      let value = @utf8.decode(Bytes::from_array(output)) catch {
        _ => lexer_fail("invalid utf8 string literal")
      }
      return (value, index + 1)
    } else if byte == b'\\' {
      guard index + 1 < input.length() else {
        lexer_fail("unterminated string escape")
      }
      // The escape table lives with the renderer that writes it, so the two
      // directions cannot drift apart. Every escape is ASCII, so one byte
      // names one.
      let escaped = input[index + 1].to_int().unsafe_to_char()
      match @buslane.text_string_unescape(escaped) {
        Some(character) => output.push(character.to_int().to_byte())
        None => lexer_fail("invalid string escape")
      }
      index = index + 2
    } else {
      output.push(byte)
      index = index + 1
    }
  }
  lexer_fail("unterminated string literal")
}
