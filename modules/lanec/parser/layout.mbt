///|
priv enum LayoutDelimiter {
  Parenthesis
  Bracket
  Brace
}

///|
priv struct LayoutTokenStream {
  tokens : Array[(@yacc_parser.Token, SourceSpan, SourceSpan)]
  separator_gaps : Array[Bool]
}

///|
fn prepare_layout_tokens(concrete : @lexer.ConcreteSyntax) -> LayoutTokenStream {
  let tokens = []
  let delimiters : Array[LayoutDelimiter] = []
  let newline_gaps = collect_newline_gaps(concrete)
  let owner_argument_openings = collect_owner_argument_openings(concrete)
  let separator_gaps = Array::make(concrete.tokens.length(), false)
  for index, item in concrete.tokens {
    let (token, loc) = item
    if should_insert_layout_semicolon(concrete, index, delimiters, newline_gaps) {
      separator_gaps[index] = true
      let separator = token_end_position(concrete.tokens[index - 1].1)
      tokens.push((@yacc_parser.LAYOUT_SEMICOLON, separator, separator))
    }
    tokens.push(
      (
        parser_token(token, owner_argument_openings[index]),
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
  { tokens, separator_gaps }
}

///|
fn parser_token(
  token : @lexer.Token,
  owner_argument_opening : Bool,
) -> @yacc_parser.Token {
  if owner_argument_opening {
    OWNER_LBRACKET
  } else {
    token.to_yacc_token()
  }
}

///|
fn collect_owner_argument_openings(
  concrete : @lexer.ConcreteSyntax,
) -> Array[Bool] {
  let result = Array::make(concrete.tokens.length(), false)
  let openings : Array[Int] = []
  for index, item in concrete.tokens {
    match item.0 {
      LBRACKET => openings.push(index)
      RBRACKET =>
        if openings.last() is Some(opening) {
          ignore(openings.pop())
          if concrete.tokens.get(index + 1).map(fn(next) { next.0 }) ==
            Some(TIGHT_COLONCOLON) {
            result[opening] = true
          }
        }
      _ => ()
    }
  }
  result
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
