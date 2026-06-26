///|
priv suberror ArtifactLexerError {
  ArtifactLexerError(String)
} derive(Debug)

///|
fn[T] lexer_fail(message : String) -> T raise ArtifactLexerError {
  raise ArtifactLexerError(message)
}

///|
fn tokens_from_string(
  text : String,
) -> Array[(Token, @basic.SourceSpan)] raise ArtifactLexerError {
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
      tokens.push((LBRACE, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b'}' {
      tokens.push((RBRACE, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b':' {
      tokens.push((COLON, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b';' {
      tokens.push((SEMI, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b'.' {
      tokens.push((DOT, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b'-' {
      tokens.push((MINUS, @basic.SourceSpan::dummy()))
      index = index + 1
    } else if byte == b'"' {
      let (value, next) = read_string_literal(input, index + 1)
      tokens.push((STRING(value), @basic.SourceSpan::dummy()))
      index = next
    } else if is_digit(byte) {
      let (value, next) = read_int(input, index)
      tokens.push((INT(value), @basic.SourceSpan::dummy()))
      index = next
    } else if is_name_start(byte) {
      let (value, next) = read_ident(input, index)
      if value == "buslane" {
        let block_start = skip_spaces(input, next)
        if block_start < input.length() && input[block_start] == b'{' {
          let block_end = read_balanced_block_end(input, block_start)
          let block_text = @utf8.decode(input[index:block_end]) catch {
            _ => lexer_fail("invalid utf8 block")
          }
          tokens.push((BUSLANE_BLOCK(block_text), @basic.SourceSpan::dummy()))
          index = block_end
        } else {
          tokens.push((IDENT(value), @basic.SourceSpan::dummy()))
          index = next
        }
      } else {
        tokens.push((IDENT(value), @basic.SourceSpan::dummy()))
        index = next
      }
    } else {
      lexer_fail("illegal artifact character")
    }
  }
  tokens.push((EOF, @basic.SourceSpan::dummy()))
  tokens
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
  is_name_start(byte) || is_digit(byte) || byte == b'-'
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
fn skip_spaces(input : Bytes, index : Int) -> Int {
  let mut next = index
  while next < input.length() && is_space(input[next]) {
    next = next + 1
  }
  next
}

///|
fn read_balanced_block_end(
  input : Bytes,
  start : Int,
) -> Int raise ArtifactLexerError {
  let mut depth = 0
  let mut index = start
  while index < input.length() {
    let byte = input[index]
    if byte == b'"' {
      index = skip_string_literal(input, index + 1)
    } else if byte == b'/' &&
      index + 1 < input.length() &&
      input[index + 1] == b'/' {
      index = skip_line_comment(input, index + 2)
    } else if byte == b'{' {
      depth = depth + 1
      index = index + 1
    } else if byte == b'}' {
      depth = depth - 1
      index = index + 1
      if depth == 0 {
        return index
      }
    } else {
      index = index + 1
    }
  }
  lexer_fail("unterminated artifact block")
}

///|
fn skip_string_literal(
  input : Bytes,
  start : Int,
) -> Int raise ArtifactLexerError {
  let mut index = start
  while index < input.length() {
    let byte = input[index]
    if byte == b'"' {
      return index + 1
    } else if byte == b'\\' {
      index = index + 2
    } else {
      index = index + 1
    }
  }
  lexer_fail("unterminated string literal")
}

///|
fn read_ident(
  input : Bytes,
  start : Int,
) -> (String, Int) raise ArtifactLexerError {
  let output = []
  let mut index = start
  while index < input.length() && is_name_continue(input[index]) {
    output.push(input[index])
    index = index + 1
  }
  let value = @utf8.decode(Bytes::from_array(output)) catch {
    _ => lexer_fail("invalid utf8 identifier")
  }
  (value, index)
}

///|
fn read_int(
  input : Bytes,
  start : Int,
) -> (String, Int) raise ArtifactLexerError {
  let output = []
  let mut index = start
  while index < input.length() && is_digit(input[index]) {
    output.push(input[index])
    index = index + 1
  }
  let value = @utf8.decode(Bytes::from_array(output)) catch {
    _ => lexer_fail("invalid utf8 integer")
  }
  (value, index)
}

///|
fn read_string_literal(
  input : Bytes,
  start : Int,
) -> (String, Int) raise ArtifactLexerError {
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
