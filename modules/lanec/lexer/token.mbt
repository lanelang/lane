///|
pub(all) enum Token {
  INT(String)
  DOUBLE(String)
  STRING(String)
  IDENT(String)
  RESERVED(String)
  EOF
  FALSE
  TRUE
  STRUCT
  ENUM
  EFFECT
  FN
  LET
  TYPE
  OFFER
  AUTO
  IF
  ELSE
  MATCH
  HANDLE
  WITH
  FINAL
  BUILTIN
  MODULE
  IMPORT
  PUB
  PLUS
  MINUS
  STAR
  SLASH
  PERCENT
  EQEQ
  BANGEQ
  LT
  LTEQ
  GT
  GTEQ
  AMPAMP
  BARBAR
  BANG
  PIPE
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  LBRACKET
  RBRACKET
  COMMA
  DOTSTAR
  DOTLBRACE
  DOT
  COLON
  COLONCOLON
  TIGHT_COLONCOLON
  THIN_ARROW
  FAT_ARROW
  EQUAL
  UNDERSCORE
} derive(Debug, Eq)

///|
pub(all) enum LexicalError {
  IllegalCharacter(String)
  UnterminatedString
  InvalidStringEscape(String)
  InvalidHexEscape(String)
  NonAsciiStringCharacter
} derive(Debug, Eq)

///|
pub(all) struct LexError {
  error : LexicalError
  span : SourceSpan
} derive(Debug, Eq)

///|
pub struct LexResult {
  tokens : Array[(Token, SourceSpan)]
  errors : Array[LexError]
} derive(Debug, Eq)
