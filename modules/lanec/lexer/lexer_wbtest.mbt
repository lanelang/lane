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
test "tokenize maximal munch operators and punctuation" {
  let tokens = token_values(
    "a == b != c <= d >= e && f || g |> h :: k::. (::x) .{ _",
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
test "preserve ascii string escape representation" {
  let tokens = token_values("\"a\\n\\x41\"")
  debug_inspect(
    tokens,
    content=(
      #|[STRING("a\\n\\x41"), EOF]
    ),
  )
}

///|
test "reject invalid string escape" {
  let result = tokens_from_string("\"\\q\"")
  debug_inspect(
    result.errors,
    content=(
      #|[
      #|  {
      #|    error: InvalidStringEscape("\\q"),
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 3,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 4,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "reject out of range hex string escape" {
  let result = tokens_from_string("\"\\x78\"")
  debug_inspect(
    result.errors,
    content=(
      #|[
      #|  {
      #|    error: InvalidHexEscape("\\x78"),
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 5,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 6,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "reject non ascii string content" {
  let result = tokens_from_string("\"你好\"")
  debug_inspect(
    result.errors,
    content=(
      #|[
      #|  {
      #|    error: NonAsciiStringCharacter,
      #|    span: {
      #|      start_offset: 1,
      #|      end_offset: 2,
      #|      start_line: 1,
      #|      start_column: 2,
      #|      end_line: 1,
      #|      end_column: 3,
      #|    },
      #|  },
      #|  {
      #|    error: NonAsciiStringCharacter,
      #|    span: {
      #|      start_offset: 2,
      #|      end_offset: 3,
      #|      start_line: 1,
      #|      start_column: 3,
      #|      end_line: 1,
      #|      end_column: 4,
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
