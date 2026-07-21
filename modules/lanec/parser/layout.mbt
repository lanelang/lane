///|
priv enum LayoutDelimiter {
  Parenthesis
  Bracket
  Brace
}

///|
fn layout_yacc_tokens(
  concrete : @lexer.ConcreteSyntax,
) -> Array[(@yacc_parser.Token, SourceSpan, SourceSpan)] {
  let tokens = []
  let delimiters : Array[LayoutDelimiter] = []
  let newline_gaps = collect_newline_gaps(concrete)
  for index, item in concrete.tokens {
    let (token, loc) = item
    if should_insert_layout_semicolon(concrete, index, delimiters, newline_gaps) {
      let separator = token_end_position(concrete.tokens[index - 1].1)
      tokens.push((@yacc_parser.LAYOUT_SEMICOLON, separator, separator))
    }
    tokens.push(
      (
        token.to_yacc_token(),
        token_start_position(loc),
        token_end_position(loc),
      ),
    )
    match token {
      LPAREN => delimiters.push(Parenthesis)
      LBRACKET => delimiters.push(Bracket)
      LBRACE => delimiters.push(Brace)
      RPAREN => pop_layout_delimiter(delimiters, Parenthesis)
      RBRACKET => pop_layout_delimiter(delimiters, Bracket)
      RBRACE => pop_layout_delimiter(delimiters, Brace)
      _ => ()
    }
  }
  tokens
}

///|
fn collect_newline_gaps(concrete : @lexer.ConcreteSyntax) -> Array[Bool] {
  let newline_gaps = Array::make(concrete.tokens.length(), false)
  for trivia in concrete.trivia {
    if trivia.kind is Newline &&
      trivia.gap >= 0 &&
      trivia.gap < newline_gaps.length() {
      newline_gaps[trivia.gap] = true
    }
  }
  newline_gaps
}

///|
fn should_insert_layout_semicolon(
  concrete : @lexer.ConcreteSyntax,
  gap : Int,
  delimiters : Array[LayoutDelimiter],
  newline_gaps : Array[Bool],
) -> Bool {
  guard gap > 0 && layout_semicolon_enabled(delimiters) else { return false }
  let previous = concrete.tokens[gap - 1].0
  let next = concrete.tokens[gap].0
  token_ends_layout_item(previous) &&
  token_starts_layout_item(next) &&
  newline_gaps[gap]
}

///|
fn layout_semicolon_enabled(delimiters : Array[LayoutDelimiter]) -> Bool {
  match delimiters.last() {
    None | Some(Brace) => true
    Some(Parenthesis) | Some(Bracket) => false
  }
}

///|
fn pop_layout_delimiter(
  delimiters : Array[LayoutDelimiter],
  expected : LayoutDelimiter,
) -> Unit {
  let matches = match (delimiters.last(), expected) {
    (Some(Parenthesis), Parenthesis)
    | (Some(Bracket), Bracket)
    | (Some(Brace), Brace) => true
    _ => false
  }
  if matches {
    ignore(delimiters.pop())
  }
}

///|
fn token_ends_layout_item(token : @lexer.Token) -> Bool {
  match token {
    INT(_)
    | DOUBLE(_)
    | STRING(_)
    | IDENT(_)
    | FALSE
    | TRUE
    | KIND_TYPE
    | KIND_EFFECT
    | RPAREN
    | RBRACKET
    | RBRACE
    | DOTSTAR
    | UNDERSCORE => true
    _ => false
  }
}

///|
fn token_starts_layout_item(token : @lexer.Token) -> Bool {
  match token {
    INT(_)
    | DOUBLE(_)
    | STRING(_)
    | IDENT(_)
    | RESERVED(_)
    | FALSE
    | TRUE
    | STRUCT
    | ENUM
    | EFFECT
    | FN
    | LET
    | TYPE
    | OFFER
    | IF
    | MATCH
    | HANDLE
    | BUILTIN
    | EXTERN
    | MODULE
    | IMPORT
    | PUB
    | UNDERSCORE => true
    _ => false
  }
}
