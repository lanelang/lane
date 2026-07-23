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
  MissingTupleItem
} derive(Debug, Eq)

///|
pub(all) struct ParseError {
  kind : ParseErrorKind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ParsedSource {
  syntax : @syntax.SourceFile
  concrete : @lexer.ConcreteSyntax
  layout_separator_gaps : Array[Bool]
} derive(Debug, Eq)

///|
pub(all) enum ParseFailure {
  Lexical(@lexer.ConcreteSyntax, Array[@lexer.LexError])
  Grammar(
    @lexer.ConcreteSyntax,
    Array[ParseError],
    @syntax.SyntacticIdentifierIndex
  )
} derive(Debug, Eq)

///|
pub(all) enum ParseResult {
  Parsed(ParsedSource)
  Failed(ParseFailure)
} derive(Debug, Eq)

///|
pub fn ParseResult::syntax(self : ParseResult) -> @syntax.SourceFile? {
  match self {
    Parsed(parsed) => Some(parsed.syntax)
    Failed(_) => None
  }
}

///|
pub fn ParseResult::lexical_errors(
  self : ParseResult,
) -> Array[@lexer.LexError] {
  match self {
    Failed(Lexical(_, errors)) => errors
    _ => []
  }
}

///|
pub fn ParseResult::parse_errors(self : ParseResult) -> Array[ParseError] {
  match self {
    Failed(Grammar(_, errors, _)) => errors
    _ => []
  }
}

///|
pub fn ParseResult::syntactic_identifier_index(
  self : ParseResult,
) -> @syntax.SyntacticIdentifierIndex {
  match self {
    Parsed({ syntax, .. }) => syntax.syntactic_identifier_index()
    Failed(Grammar(_, _, identifiers)) => identifiers
    Failed(Lexical(_, _)) => @syntax.SyntacticIdentifierIndex::empty()
  }
}
