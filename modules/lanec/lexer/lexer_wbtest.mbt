///|
fn token_values(source : String) -> Array[Token] {
  let result = tokens_from_string(source)
  if !result.errors.is_empty() {
    abort("unexpected lexer error")
  }
  result.concrete.tokens.map(fn(item) {
    let (token, _span) = item
    token
  })
}

///|
test "tokenize keywords identifiers and literals" {
  let tokens = token_values(
    "fn add(value : Int) -> Bool { handle true with final false }",
  )
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  FN,
      #|  IDENT("add"),
      #|  LPAREN,
      #|  IDENT("value"),
      #|  COLON,
      #|  IDENT("Int"),
      #|  RPAREN,
      #|  THIN_ARROW,
      #|  IDENT("Bool"),
      #|  LBRACE,
      #|  HANDLE,
      #|  TRUE,
      #|  WITH,
      #|  FINAL,
      #|  FALSE,
      #|  RBRACE,
      #|  EOF,
      #|]
    ),
  )
}

///|
test "trait interface and mut are identifiers" {
  let tokens = token_values("trait interface mut")
  debug_inspect(
    tokens,
    content=(
      #|[IDENT("trait"), IDENT("interface"), IDENT("mut"), EOF]
    ),
  )
}

///|
test "Type and Effect are kind keywords" {
  debug_inspect(
    token_values("Type Effect type effect"),
    content=(
      #|[KIND_TYPE, KIND_EFFECT, TYPE, EFFECT, EOF]
    ),
  )
}

///|
test "as is a reserved import alias keyword" {
  debug_inspect(token_values("as alias"), content="[AS, IDENT(\"alias\"), EOF]")
}

///|
test "tokenize maximal munch operators and punctuation" {
  let tokens = token_values(
    "a == b != c <= d >= e && f || g |> h :: k::. (::x) .{ _ ;",
  )
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  IDENT("a"),
      #|  EQEQ,
      #|  IDENT("b"),
      #|  BANGEQ,
      #|  IDENT("c"),
      #|  LTEQ,
      #|  IDENT("d"),
      #|  GTEQ,
      #|  IDENT("e"),
      #|  AMPAMP,
      #|  IDENT("f"),
      #|  BARBAR,
      #|  IDENT("g"),
      #|  PIPE,
      #|  IDENT("h"),
      #|  COLON,
      #|  COLON,
      #|  IDENT("k"),
      #|  TIGHT_COLONCOLON,
      #|  DOT,
      #|  LPAREN,
      #|  COLONCOLON,
      #|  IDENT("x"),
      #|  RPAREN,
      #|  DOTLBRACE,
      #|  UNDERSCORE,
      #|  SEMICOLON,
      #|  EOF,
      #|]
    ),
  )
}

///|
test "skip comments and preserve following token positions" {
  let result = tokens_from_string("// hidden\nlet x")
  debug_inspect(result.errors, content="[]")
  debug_inspect(
    result.concrete.tokens,
    content=(
      #|[
      #|  (
      #|    LET,
      #|    {
      #|      start_offset: 10,
      #|      end_offset: 13,
      #|      start_line: 2,
      #|      start_column: 1,
      #|      end_line: 2,
      #|      end_column: 4,
      #|    },
      #|  ),
      #|  (
      #|    IDENT("x"),
      #|    {
      #|      start_offset: 14,
      #|      end_offset: 15,
      #|      start_line: 2,
      #|      start_column: 5,
      #|      end_line: 2,
      #|      end_column: 6,
      #|    },
      #|  ),
      #|  (
      #|    EOF,
      #|    {
      #|      start_offset: 15,
      #|      end_offset: 15,
      #|      start_line: 2,
      #|      start_column: 6,
      #|      end_line: 2,
      #|      end_column: 6,
      #|    },
      #|  ),
      #|]
    ),
  )
}

///|
test "collect comments and whitespace as gap indexed trivia" {
  let result = tokens_from_string("// hidden\nlet x // tail\n")
  debug_inspect(result.errors, content="[]")
  debug_inspect(
    result.concrete.trivia,
    content=(
      #|[
      #|  {
      #|    kind: LineComment,
      #|    span: {
      #|      start_offset: 0,
      #|      end_offset: 9,
      #|      start_line: 1,
      #|      start_column: 1,
      #|      end_line: 1,
      #|      end_column: 10,
      #|    },
      #|    gap: 0,
      #|  },
      #|  {
      #|    kind: Newline,
      #|    span: {
      #|      start_offset: 9,
      #|      end_offset: 10,
      #|      start_line: 1,
      #|      start_column: 10,
      #|      end_line: 1,
      #|      end_column: 11,
      #|    },
      #|    gap: 0,
      #|  },
      #|  {
      #|    kind: Whitespace,
      #|    span: {
      #|      start_offset: 13,
      #|      end_offset: 14,
      #|      start_line: 2,
      #|      start_column: 4,
      #|      end_line: 2,
      #|      end_column: 5,
      #|    },
      #|    gap: 1,
      #|  },
      #|  {
      #|    kind: Whitespace,
      #|    span: {
      #|      start_offset: 15,
      #|      end_offset: 16,
      #|      start_line: 2,
      #|      start_column: 6,
      #|      end_line: 2,
      #|      end_column: 7,
      #|    },
      #|    gap: 2,
      #|  },
      #|  {
      #|    kind: LineComment,
      #|    span: {
      #|      start_offset: 16,
      #|      end_offset: 23,
      #|      start_line: 2,
      #|      start_column: 7,
      #|      end_line: 2,
      #|      end_column: 14,
      #|    },
      #|    gap: 2,
      #|  },
      #|  {
      #|    kind: Newline,
      #|    span: {
      #|      start_offset: 23,
      #|      end_offset: 24,
      #|      start_line: 2,
      #|      start_column: 14,
      #|      end_line: 2,
      #|      end_column: 15,
      #|    },
      #|    gap: 2,
      #|  },
      #|]
    ),
  )
}

///|
test "block comment markers are ordinary tokens" {
  let tokens = token_values("let /*x*/ y")
  debug_inspect(
    tokens,
    content=(
      #|[LET, SLASH, STAR, IDENT("x"), STAR, SLASH, IDENT("y"), EOF]
    ),
  )
}

///|
test "decode Unicode string and character literals" {
  assert_eq(
    token_values(
      "\"A你好😀\\n\\u{41}\" 'A' '你' '\\u{1F600}' '\\0' '\\'' \"\\\"\"",
    ),
    [
      STRING("A你好😀\nA"),
      CHAR(0x41),
      CHAR(0x4F60),
      CHAR(0x1F600),
      CHAR(0),
      CHAR(0x27),
      STRING("\""),
      EOF,
    ],
  )
}

///|
test "reject unsupported literal escape" {
  debug_inspect(
    tokens_from_string("\"\\q\" '\\x41'").errors,
    content=(
      #|[
      #|  {
      #|    error: InvalidLiteralEscape("\\q"),
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 3,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 4,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidLiteralEscape("\\x"),
      #|    span: {
      #|      start_offset: 6,
      #|      end_offset: 8,
      #|      start_line: 1,
      #|      start_column: 7,
      #|      end_line: 1,
      #|      end_column: 9,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "reject malformed Unicode escapes" {
  debug_inspect(
    tokens_from_string(
      "\"\\u\" \"\\u{}\" \"\\u{1234567}\" \"\\u{12Q}\" \"\\u{110000}\" \"\\u{D800}\"",
    ).errors,
    content=(
      #|[
      #|  {
      #|    error: InvalidUnicodeEscape("\\u", MissingBraces),
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 3,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 4,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidUnicodeEscape("", Empty),
      #|    span: {
      #|      start_offset: 6,
      #|      end_offset: 10,
      #|      start_line: 1,
      #|      start_column: 7,
      #|      end_line: 1,
      #|      end_column: 11,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidUnicodeEscape("1234567", TooManyDigits),
      #|    span: {
      #|      start_offset: 13,
      #|      end_offset: 24,
      #|      start_line: 1,
      #|      start_column: 14,
      #|      end_line: 1,
      #|      end_column: 25,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidUnicodeEscape("12Q", NonHexadecimal),
      #|    span: {
      #|      start_offset: 27,
      #|      end_offset: 34,
      #|      start_line: 1,
      #|      start_column: 28,
      #|      end_line: 1,
      #|      end_column: 35,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidUnicodeEscape("110000", OutOfRange),
      #|    span: {
      #|      start_offset: 37,
      #|      end_offset: 47,
      #|      start_line: 1,
      #|      start_column: 38,
      #|      end_line: 1,
      #|      end_column: 48,
      #|    },
      #|  },
      #|  {
      #|    error: InvalidUnicodeEscape("D800", Surrogate),
      #|    span: {
      #|      start_offset: 50,
      #|      end_offset: 58,
      #|      start_line: 1,
      #|      start_column: 51,
      #|      end_line: 1,
      #|      end_column: 59,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "reject invalid character literal cardinality" {
  debug_inspect(
    tokens_from_string("'' 'ab' '").errors,
    content=(
      #|[
      #|  {
      #|    error: EmptyCharLiteral,
      #|    span: {
      #|      start_offset: 0,
      #|      end_offset: 2,
      #|      start_line: 1,
      #|      start_column: 1,
      #|      end_line: 1,
      #|      end_column: 3,
      #|    },
      #|  },
      #|  {
      #|    error: MultipleCharLiteral,
      #|    span: {
      #|      start_offset: 3,
      #|      end_offset: 7,
      #|      start_line: 1,
      #|      start_column: 4,
      #|      end_line: 1,
      #|      end_column: 8,
      #|    },
      #|  },
      #|  {
      #|    error: UnterminatedChar,
      #|    span: {
      #|      start_offset: 8,
      #|      end_offset: 9,
      #|      start_line: 1,
      #|      start_column: 9,
      #|      end_line: 1,
      #|      end_column: 10,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "reject non ascii identifier character" {
  let result = tokens_from_string("你好")
  debug_inspect(
    result.errors,
    content=(
      #|[
      #|  {
      #|    error: IllegalCharacter("你"),
      #|    span: {
      #|      start_offset: 0,
      #|      end_offset: 1,
      #|      start_line: 1,
      #|      start_column: 1,
      #|      end_line: 1,
      #|      end_column: 2,
      #|    },
      #|  },
      #|  {
      #|    error: IllegalCharacter("好"),
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 2,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 3,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "tokenize long sources without recursive token dispatch" {
  let source = Array::make(2000, "value").join(" ")
  let result = tokens_from_string(source)
  debug_inspect(
    (result.errors, result.concrete.tokens.length()),
    content="([], 2001)",
  )
}
