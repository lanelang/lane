///|
pub(all) enum Token {
  INT(String)
  DOUBLE(String)
  STRING(String)
  CHAR(Int)
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
  KIND_TYPE
  KIND_EFFECT
  OFFER
  AUTO
  IF
  ELSE
  MATCH
  HANDLE
  WITH
  FINAL
  DERIVE
  BUILTIN
  EXTERN
  MODULE
  IMPORT
  AS
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
  SEMICOLON
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
  UnterminatedChar
  InvalidLiteralEscape(String)
  InvalidUnicodeEscape(String, UnicodeEscapeError)
  EmptyCharLiteral
  MultipleCharLiteral
} derive(Debug, Eq)

///|
pub(all) enum UnicodeEscapeError {
  MissingBraces
  Empty
  TooManyDigits
  NonHexadecimal
  OutOfRange
  Surrogate
} derive(Debug, Eq)

///|
pub(all) struct LexError {
  error : LexicalError
  span : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum TriviaKind {
  Whitespace
  Newline
  LineComment
} derive(Debug, Eq)

///|
pub(all) struct GapIndexedTrivia {
  kind : TriviaKind
  span : SourceSpan
  gap : Int
} derive(Debug, Eq)

///|
pub(all) struct ConcreteSyntax {
  source_text : String
  tokens : Array[(Token, SourceSpan)]
  trivia : Array[GapIndexedTrivia]
} derive(Debug, Eq)

///|
pub struct LexResult {
  concrete : ConcreteSyntax
  errors : Array[LexError]
} derive(Debug, Eq)
