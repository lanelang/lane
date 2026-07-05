///|
pub(all) struct TokenSummary {
  label : String
} derive(Debug, Eq)

///|
pub(all) struct ExpectedSyntax {
  label : String
} derive(Debug, Eq)

///|
pub(all) enum ParseErrorKind {
  UnexpectedToken(TokenSummary, Array[ExpectedSyntax])
  UnexpectedEndOfInput(Array[ExpectedSyntax])
  EmptyGenericArgumentList
  EmptyTypeParameterList
} derive(Debug, Eq)

///|
pub(all) struct ParseError {
  kind : ParseErrorKind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub struct ParseResult {
  source : @syntax.SourceFile?
  lexical_errors : Array[@lexer.LexError]
  parse_errors : Array[ParseError]
} derive(Debug, Eq)
