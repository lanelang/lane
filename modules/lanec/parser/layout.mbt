///|
fn layout_yacc_tokens(
  concrete : @lexer.ConcreteSyntax,
) -> Array[(@yacc_parser.Token, SourceSpan, SourceSpan)] {
  let tokens = []
  let mut parenthesis_depth = 0
  let mut bracket_depth = 0
  for index, item in concrete.tokens {
    let (token, loc) = item
    if should_insert_layout_semicolon(
        concrete, index, parenthesis_depth, bracket_depth,
      ) {
      let separator = token_end_position(concrete.tokens[index - 1].1)
      tokens.push((@yacc_parser.SEMICOLON, separator, separator))
    }
    tokens.push(
      (
        token.to_yacc_token(),
        token_start_position(loc),
        token_end_position(loc),
      ),
    )
    match token {
      LPAREN => parenthesis_depth += 1
      RPAREN => parenthesis_depth -= 1
      LBRACKET => bracket_depth += 1
      RBRACKET => bracket_depth -= 1
      _ => ()
    }
  }
  tokens
}

///|
fn should_insert_layout_semicolon(
  concrete : @lexer.ConcreteSyntax,
  gap : Int,
  parenthesis_depth : Int,
  bracket_depth : Int,
) -> Bool {
  guard gap > 0 && parenthesis_depth == 0 && bracket_depth == 0 else {
    return false
  }
  let previous = concrete.tokens[gap - 1].0
  let next = concrete.tokens[gap].0
  token_ends_layout_item(previous) &&
  token_starts_layout_item(next) &&
  concrete.trivia.any(fn(trivia) { trivia.gap == gap && trivia.kind is Newline })
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
    | DOTSTAR => true
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
