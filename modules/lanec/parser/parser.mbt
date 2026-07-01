///|
/// Parses a Lane2 source string after lexing it with the default lexer.
pub fn parse_string(source : String) -> ParseResult {
  let lexed = @lexer.tokens_from_string(source)
  if !lexed.errors.is_empty() {
    { source: None, lexical_errors: lexed.errors, parse_errors: [] }
  } else {
    let result = parse_tokens(lexed.tokens)
    {
      source: result.source,
      lexical_errors: [],
      parse_errors: result.parse_errors,
    }
  }
}

///|
/// Parses an already lexed token stream into a source file.
pub fn parse_tokens(tokens : Array[(@lexer.Token, SourceSpan)]) -> ParseResult {
  let yacc_tokens = tokens.map(fn(item) {
    let (token, loc) = item
    (token.to_yacc_token(), loc, loc)
  })
  let source = @yacc_parser.source_file(yacc_tokens) catch {
    UnexpectedEndOfInput(loc, expected) =>
      return {
        source: None,
        lexical_errors: [],
        parse_errors: [
          { kind: UnexpectedEndOfInput(expected_syntax(expected)), loc },
        ],
      }
    UnexpectedToken(token, (start, end), expected) =>
      return {
        source: None,
        lexical_errors: [],
        parse_errors: [
          {
            kind: UnexpectedToken(
              token_summary(token),
              expected_syntax(expected),
            ),
            loc: SourceSpan::join(start, end),
          },
        ],
      }
  }
  { source: Some(source), lexical_errors: [], parse_errors: [] }
}

///|
fn token_summary(token : @yacc_parser.Token) -> TokenSummary {
  { label: token_label(token) }
}

///|
fn expected_syntax(
  kinds : Array[@yacc_parser.TokenKind],
) -> Array[ExpectedSyntax] {
  let result = []
  for kind in kinds {
    let syntax : ExpectedSyntax = { label: token_kind_label(kind) }
    if !result.contains(syntax) {
      result.push(syntax)
    }
  }
  result
}

///|
fn token_label(token : @yacc_parser.Token) -> String {
  match token {
    INT(_) => "integer literal"
    STRING(_) => "string literal"
    IDENT(value) => "identifier `\{value}`"
    RESERVED(value) => "reserved word `\{value}`"
    EOF => "end of file"
    FALSE => "`false`"
    TRUE => "`true`"
    STRUCT => "`struct`"
    ENUM => "`enum`"
    EFFECT => "`effect`"
    FN => "`fn`"
    LET => "`let`"
    TYPE => "`type`"
    OFFER => "`offer`"
    AUTO => "`auto`"
    IF => "`if`"
    ELSE => "`else`"
    MATCH => "`match`"
    BUILTIN => "`builtin`"
    MODULE => "`module`"
    IMPORT => "`import`"
    PUB => "`pub`"
    PLUS => "`+`"
    MINUS => "`-`"
    STAR => "`*`"
    SLASH => "`/`"
    PERCENT => "`%`"
    EQEQ => "`==`"
    BANGEQ => "`!=`"
    LT => "`<`"
    LTEQ => "`<=`"
    GT => "`>`"
    GTEQ => "`>=`"
    AMPAMP => "`&&`"
    BARBAR => "`||`"
    BANG => "`!`"
    PIPE => "`|>`"
    LPAREN => "`(`"
    RPAREN => "`)`"
    LBRACE => "`{`"
    RBRACE => "`}`"
    LBRACKET => "`[`"
    RBRACKET => "`]`"
    COMMA => "`,`"
    DOTSTAR => "`.*`"
    DOTLBRACE => "`.{`"
    DOT => "`.`"
    COLON => "`:`"
    COLONCOLON => "`::`"
    TIGHT_COLONCOLON => "`::`"
    THIN_ARROW => "`->`"
    FAT_ARROW => "`=>`"
    EQUAL => "`=`"
    UNDERSCORE => "`_`"
  }
}

///|
fn token_kind_label(kind : @yacc_parser.TokenKind) -> String {
  match kind {
    TK_INT => "integer literal"
    TK_STRING => "string literal"
    TK_IDENT => "identifier"
    TK_RESERVED => "reserved word"
    TK_EOF => "end of file"
    TK_FALSE => "`false`"
    TK_TRUE => "`true`"
    TK_STRUCT => "`struct`"
    TK_ENUM => "`enum`"
    TK_EFFECT => "`effect`"
    TK_FN => "`fn`"
    TK_LET => "`let`"
    TK_TYPE => "`type`"
    TK_OFFER => "`offer`"
    TK_AUTO => "`auto`"
    TK_IF => "`if`"
    TK_ELSE => "`else`"
    TK_MATCH => "`match`"
    TK_BUILTIN => "`builtin`"
    TK_MODULE => "`module`"
    TK_IMPORT => "`import`"
    TK_PUB => "`pub`"
    TK_PLUS => "`+`"
    TK_MINUS => "`-`"
    TK_STAR => "`*`"
    TK_SLASH => "`/`"
    TK_PERCENT => "`%`"
    TK_EQEQ => "`==`"
    TK_BANGEQ => "`!=`"
    TK_LT => "`<`"
    TK_LTEQ => "`<=`"
    TK_GT => "`>`"
    TK_GTEQ => "`>=`"
    TK_AMPAMP => "`&&`"
    TK_BARBAR => "`||`"
    TK_BANG => "`!`"
    TK_PIPE => "`|>`"
    TK_LPAREN => "`(`"
    TK_RPAREN => "`)`"
    TK_LBRACE => "`{`"
    TK_RBRACE => "`}`"
    TK_LBRACKET => "`[`"
    TK_RBRACKET => "`]`"
    TK_COMMA => "`,`"
    TK_DOTSTAR => "`.*`"
    TK_DOTLBRACE => "`.{`"
    TK_DOT => "`.`"
    TK_COLON => "`:`"
    TK_COLONCOLON => "`::`"
    TK_TIGHT_COLONCOLON => "`::`"
    TK_THIN_ARROW => "`->`"
    TK_FAT_ARROW => "`=>`"
    TK_EQUAL => "`=`"
    TK_UNDERSCORE => "`_`"
  }
}

///|
fn @lexer.Token::to_yacc_token(self : @lexer.Token) -> @yacc_parser.Token {
  match self {
    INT(value) => INT(value)
    STRING(value) => STRING(value)
    IDENT(value) => IDENT(value)
    RESERVED(value) => RESERVED(value)
    EOF => EOF
    FALSE => FALSE
    TRUE => TRUE
    STRUCT => STRUCT
    ENUM => ENUM
    EFFECT => EFFECT
    FN => FN
    LET => LET
    TYPE => TYPE
    OFFER => OFFER
    AUTO => AUTO
    IF => IF
    ELSE => ELSE
    MATCH => MATCH
    BUILTIN => BUILTIN
    MODULE => MODULE
    IMPORT => IMPORT
    PUB => PUB
    PLUS => PLUS
    MINUS => MINUS
    STAR => STAR
    SLASH => SLASH
    PERCENT => PERCENT
    EQEQ => EQEQ
    BANGEQ => BANGEQ
    LT => LT
    LTEQ => LTEQ
    GT => GT
    GTEQ => GTEQ
    AMPAMP => AMPAMP
    BARBAR => BARBAR
    BANG => BANG
    PIPE => PIPE
    LPAREN => LPAREN
    RPAREN => RPAREN
    LBRACE => LBRACE
    RBRACE => RBRACE
    LBRACKET => LBRACKET
    RBRACKET => RBRACKET
    COMMA => COMMA
    DOTSTAR => DOTSTAR
    DOTLBRACE => DOTLBRACE
    DOT => DOT
    COLON => COLON
    COLONCOLON => COLONCOLON
    TIGHT_COLONCOLON => TIGHT_COLONCOLON
    THIN_ARROW => THIN_ARROW
    FAT_ARROW => FAT_ARROW
    EQUAL => EQUAL
    UNDERSCORE => UNDERSCORE
  }
}
