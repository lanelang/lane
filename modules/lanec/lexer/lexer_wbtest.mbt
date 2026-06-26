///|
fn token_values(source : String) -> Array[Token] {
  let result = tokens_from_string(source)
  if !result.errors.is_empty() {
    abort("unexpected lexer error")
  }
  result.tokens.map(fn(item) {
    let (token, _span) = item
    token
  })
}

///|
test "tokenize keywords identifiers and literals" {
  let tokens = token_values("fn add(value : Int) -> Bool { true }")
  assert_true(
    tokens ==
    [
      FN,
      IDENT("add"),
      LPAREN,
      IDENT("value"),
      COLON,
      IDENT("Int"),
      RPAREN,
      THIN_ARROW,
      IDENT("Bool"),
      LBRACE,
      TRUE,
      RBRACE,
      EOF,
    ],
  )
}

///|
test "trait interface and mut are identifiers" {
  let tokens = token_values("trait interface mut")
  assert_true(tokens == [IDENT("trait"), IDENT("interface"), IDENT("mut"), EOF])
}

///|
test "tokenize maximal munch operators and punctuation" {
  let tokens = token_values(
    "a == b != c <= d >= e && f || g |> h :: k::. (::x) .{ _",
  )
  assert_true(
    tokens ==
    [
      IDENT("a"),
      EQEQ,
      IDENT("b"),
      BANGEQ,
      IDENT("c"),
      LTEQ,
      IDENT("d"),
      GTEQ,
      IDENT("e"),
      AMPAMP,
      IDENT("f"),
      BARBAR,
      IDENT("g"),
      PIPE,
      IDENT("h"),
      COLON,
      COLON,
      IDENT("k"),
      TIGHT_COLONCOLON,
      DOT,
      LPAREN,
      COLONCOLON,
      IDENT("x"),
      RPAREN,
      DOTLBRACE,
      UNDERSCORE,
      EOF,
    ],
  )
}

///|
test "skip comments and preserve following token positions" {
  let result = tokens_from_string("// hidden\nlet /* also hidden */x")
  assert_true(result.errors.is_empty())
  assert_true(
    result.tokens[0] ==
    (
      LET,
      {
        start_offset: 10,
        end_offset: 13,
        start_line: 2,
        start_column: 1,
        end_line: 2,
        end_column: 4,
      },
    ),
  )
  assert_true(
    result.tokens[1] ==
    (
      IDENT("x"),
      {
        start_offset: 31,
        end_offset: 32,
        start_line: 2,
        start_column: 22,
        end_line: 2,
        end_column: 23,
      },
    ),
  )
}

///|
test "preserve ascii string escape representation" {
  let tokens = token_values("\"a\\n\\x41\"")
  assert_true(tokens[0] == STRING("a\\n\\x41"))
}

///|
test "reject invalid string escape" {
  let result = tokens_from_string("\"\\q\"")
  assert_true(result.errors.length() == 1)
  assert_true(result.errors[0].error == InvalidStringEscape("\\q"))
}

///|
test "reject out of range hex string escape" {
  let result = tokens_from_string("\"\\x78\"")
  assert_true(result.errors.length() == 1)
  assert_true(result.errors[0].error == InvalidHexEscape("\\x78"))
}

///|
test "reject non ascii string content" {
  let result = tokens_from_string("\"你好\"")
  assert_true(result.errors.length() == 2)
  assert_true(result.errors[0].error == NonAsciiStringCharacter)
}

///|
test "reject non ascii identifier character" {
  let result = tokens_from_string("你好")
  assert_true(result.errors.length() == 2)
  assert_true(result.errors[0].error == IllegalCharacter("你"))
}

///|
test "reject unterminated block comment" {
  let result = tokens_from_string("/* open")
  assert_true(result.errors.length() == 1)
  assert_true(result.errors[0].error == UnterminatedBlockComment)
}
