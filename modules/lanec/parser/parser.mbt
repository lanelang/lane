///|
/// Parses a Lane2 source string after lexing it with the default lexer.
pub fn parse_string(source : String) -> ParseResult {
  let lexed = @lexer.tokens_from_string(source)
  if !lexed.errors.is_empty() {
    Failed(Lexical(lexed.errors))
  } else {
    parse_concrete(lexed.concrete)
  }
}

///|
/// Parses a concrete token stream into a source file.
pub fn parse_concrete(concrete : @lexer.ConcreteSyntax) -> ParseResult {
  let source = @yacc_parser.source_file(layout_yacc_tokens(concrete)) catch {
    UnexpectedEndOfInput(loc, expected) =>
      return Failed(
        Grammar(concrete, [
          { kind: UnexpectedEndOfInput(expected_syntax(expected)), loc },
        ]),
      )
    UnexpectedToken(token, (start, end), expected) => {
      let kind = unexpected_token_error_kind(token, expected)
      return Failed(
        Grammar(concrete, [{ kind, loc: SourceSpan::join(start, end) }]),
      )
    }
  }
  Parsed({ syntax: source, concrete })
}

///|
fn token_start_position(span : @basic.SourceSpan) -> @basic.SourceSpan {
  {
    start_offset: span.start_offset,
    end_offset: span.start_offset,
    start_line: span.start_line,
    start_column: span.start_column,
    end_line: span.start_line,
    end_column: span.start_column,
  }
}

///|
fn token_end_position(span : @basic.SourceSpan) -> @basic.SourceSpan {
  {
    start_offset: span.end_offset,
    end_offset: span.end_offset,
    start_line: span.end_line,
    start_column: span.end_column,
    end_line: span.end_line,
    end_column: span.end_column,
  }
}

///|
fn unexpected_token_error_kind(
  token : @yacc_parser.Token,
  expected : Array[@yacc_parser.TokenKind],
) -> ParseErrorKind {
  if expected.contains(TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR) {
    EmptyGenericArgumentList
  } else if expected.contains(TK_EMPTY_TYPE_PARAMETER_LIST_ERROR) {
    EmptyTypeParameterList
  } else {
    UnexpectedToken(token_summary(token), expected_syntax(expected))
  }
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
    DOUBLE(_) => "double literal"
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
    KIND_TYPE => "`Type`"
    KIND_EFFECT => "`Effect`"
    OFFER => "`offer`"
    AUTO => "`auto`"
    IF => "`if`"
    ELSE => "`else`"
    MATCH => "`match`"
    HANDLE => "`handle`"
    WITH => "`with`"
    FINAL => "`final`"
    BUILTIN => "`builtin`"
    EXTERN => "`extern`"
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
    EMPTY_GENERIC_ARGUMENT_LIST_ERROR => "empty generic argument list"
    EMPTY_TYPE_PARAMETER_LIST_ERROR => "empty type parameter list"
    COMMA => "`,`"
    SEMICOLON => "`;`"
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
    TK_DOUBLE => "double literal"
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
    TK_KIND_TYPE => "`Type`"
    TK_KIND_EFFECT => "`Effect`"
    TK_OFFER => "`offer`"
    TK_AUTO => "`auto`"
    TK_IF => "`if`"
    TK_ELSE => "`else`"
    TK_MATCH => "`match`"
    TK_HANDLE => "`handle`"
    TK_WITH => "`with`"
    TK_FINAL => "`final`"
    TK_BUILTIN => "`builtin`"
    TK_EXTERN => "`extern`"
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
    TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => "empty generic argument list"
    TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => "empty type parameter list"
    TK_COMMA => "`,`"
    TK_SEMICOLON => "`;`"
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
    DOUBLE(value) => DOUBLE(value)
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
    KIND_TYPE => KIND_TYPE
    KIND_EFFECT => KIND_EFFECT
    OFFER => OFFER
    AUTO => AUTO
    IF => IF
    ELSE => ELSE
    MATCH => MATCH
    HANDLE => HANDLE
    WITH => WITH
    FINAL => FINAL
    BUILTIN => BUILTIN
    EXTERN => EXTERN
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
    SEMICOLON => SEMICOLON
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
