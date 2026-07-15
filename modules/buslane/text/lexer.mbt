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
    } else if byte == b'=' {
      tokens.push((EQUAL, ()))
      index = index + 1
    } else if byte == b'"' {
      let (value, next) = read_string_literal(input, index + 1)
      tokens.push((STRING(value), ()))
      index = next
    } else if is_digit(byte) || byte == b'-' {
      let (value, next, is_double) = read_number(input, index)
      if is_double {
        tokens.push((DOUBLE(value), ()))
      } else {
        tokens.push((INT(value), ()))
      }
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
      let (name, next) = read_name(input, index)
      tokens.push((keyword_token(name), ()))
      index = next
    } else {
      lexer_fail("illegal Buslane text character")
    }
  }
  tokens.push((EOF, ()))
  tokens
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
    "name" => NAME
    "unique" => UNIQUE
    "parameters" => PARAMETERS
    "constructors" => CONSTRUCTORS
    "operations" => OPERATIONS
    "owner" => OWNER
    "hidden" => HIDDEN
    "payload" => PAYLOAD
    "result" => RESULT
    "function" => FUNCTION_KIND
    "external" => EXTERNAL
    "parameter" => PARAMETER_KIND
    "local" => LOCAL_KIND
    "match_binder" => MATCH_BINDER_KIND
    "Type" => TYPE_KIND
    "Effect" => EFFECT_KIND
    "Unit" => UNIT_TYPE
    "Bool" => BOOL_TYPE
    "Int" => INT_TYPE
    "Double" => DOUBLE_TYPE
    "String" => STRING_TYPE
    "kind_fn" => KIND_FN
    "empty_effect" => EMPTY_EFFECT
    "io_effect" => IO_EFFECT
    "effect_singleton" => EFFECT_SINGLETON
    "effect_union" => EFFECT_UNION
    "apply" => APPLY
    "type_fn" => TYPE_FN
    "fn_type" => FN_TYPE
    "forall" => FORALL
    "let" => LET
    "letrec" => LETREC
    "fn" => FN
    "call" => CALL
    "perform" => PERFORM
    "handle" => HANDLE
    "resume" => RESUME
    "handler" => HANDLER
    "op_alt" => OP_ALT
    "final" => FINAL
    "type_apply" => TYPE_APPLY
    "construct" => CONSTRUCT
    "let_in" => LET_IN
    "letrec_in" => LETREC_IN
    "match" => MATCH
    "alt" => ALT
    "default" => DEFAULT
    "literal" => LITERAL_ALT
    "true" => TRUE
    "false" => FALSE
    "int" => INT_LITERAL
    "double" => DOUBLE_LITERAL
    "string" => STRING_LITERAL
    "unit" => UNIT_LITERAL
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
  let mut next = index + @utf8.encode(prefix).length()
  let start = next
  while next < input.length() && is_digit(input[next]) {
    next = next + 1
  }
  if next == start {
    lexer_fail("expected numeric id after " + prefix)
  }
  let value = @utf8.decode(input[start:next]) catch {
    _ => lexer_fail("invalid utf8 id")
  }
  (
    @string.parse_int(value, base=10) catch {
      _ => lexer_fail("invalid id")
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
fn read_number(
  input : Bytes,
  index : Int,
) -> (String, Int, Bool) raise BuslaneTextLexerError {
  let mut next = index
  if input[next] == b'-' {
    next = next + 1
  }
  let start = next
  while next < input.length() && is_digit(input[next]) {
    next = next + 1
  }
  let mut is_double = false
  if next < input.length() && input[next] == b'.' {
    is_double = true
    next = next + 1
    while next < input.length() && is_digit(input[next]) {
      next = next + 1
    }
  }
  if next < input.length() && (input[next] == b'e' || input[next] == b'E') {
    is_double = true
    next = next + 1
    if next < input.length() && (input[next] == b'+' || input[next] == b'-') {
      next = next + 1
    }
    while next < input.length() && is_digit(input[next]) {
      next = next + 1
    }
  }
  if next == start {
    lexer_fail("expected number")
  }
  let value = @utf8.decode(input[index:next]) catch {
    _ => lexer_fail("invalid utf8 number")
  }
  (value, next, is_double)
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
      let escaped = input[index + 1]
      match escaped {
        b'"' => output.push(b'"')
        b'\\' => output.push(b'\\')
        b'n' => output.push(b'\n')
        b'r' => output.push(b'\r')
        b't' => output.push(b'\t')
        _ => lexer_fail("invalid string escape")
      }
      index = index + 2
    } else {
      output.push(byte)
      index = index + 1
    }
  }
  lexer_fail("unterminated string literal")
}
