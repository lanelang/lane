///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticLabel,
  compiler_error,
  compiler_local_span,
}

///|
using @prettyprinter {type Document, empty, hardline, separate, space, text}

///|
pub(all) struct FormatOptions {
  width : Int
} derive(Debug, Eq)

///|
pub fn default_options() -> FormatOptions {
  { width: 100 }
}

///|
pub fn format_source(
  source : String,
) -> Result[String, Array[CompilerDiagnostic]] {
  format_source_with_options(source, default_options())
}

///|
pub fn format_source_with_options(
  source : String,
  options : FormatOptions,
) -> Result[String, Array[CompilerDiagnostic]] {
  let parsed = @parser.parse_string(source)
  let diagnostics = parse_diagnostics(parsed)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  match parsed {
    Parsed(parsed) => Ok(format_parsed_source_with_options(parsed, options))
    Failed(_) =>
      Err([
        diagnostic(
          "parser did not produce a source file",
          span=None,
          code=Some("E1102"),
          labels=[],
          notes=[
            "the parser recovered enough to return no syntax tree but no concrete parse error was reported",
          ],
          helps=["report this as a compiler bug if the input is reproducible"],
        ),
      ])
  }
}

///|
fn format_parsed_source_with_options(
  parsed : @parser.ParsedSource,
  options : FormatOptions,
) -> String {
  @prettyprinter.render(
    @syntax.format_source_file_with_trivia(
      parsed.syntax,
      source_format_trivia(parsed.concrete),
    ),
    width=options.width,
  ) +
  "\n"
}

///|
pub fn format_source_file(source : @syntax.SourceFile) -> String {
  format_source_file_with_options(source, default_options())
}

///|
pub fn format_source_file_with_options(
  source : @syntax.SourceFile,
  options : FormatOptions,
) -> String {
  @prettyprinter.render(source, width=options.width) + "\n"
}

///|
priv struct FormatComment {
  text : String
  span : @basic.SourceSpan
  gap : Int
}

///|
priv enum CommentPlacement {
  Leading(@basic.SourceSpan)
  Trailing(@basic.SourceSpan)
  EndOfFile
}

///|
priv struct AnchoredComment {
  text : String
  placement : CommentPlacement
  blank_before : Bool
  blank_after : Bool
}

///|
priv struct TriviaView {
  comments : Array[FormatComment]
}

///|
fn TriviaView::make(concrete : @lexer.ConcreteSyntax) -> TriviaView {
  let comments = []
  for item in concrete.trivia {
    if item.kind is LineComment {
      comments.push({
        text: concrete.source_text.unsafe_substring(
          start=item.span.start_offset,
          end=item.span.end_offset,
        ),
        span: item.span,
        gap: item.gap,
      })
    }
  }
  { comments, }
}

///|
fn source_format_trivia(
  concrete : @lexer.ConcreteSyntax,
) -> @syntax.SourceFormatTrivia {
  let view = TriviaView::make(concrete)
  let comments = view.comments
  if comments.is_empty() {
    return @syntax.SourceFormatTrivia::empty()
  }
  let source_tokens = non_eof_tokens(concrete.tokens)
  let anchored = []
  for index, comment in comments {
    anchored.push(
      anchor_comment(
        comment,
        source_tokens,
        blank_before_comment(comment, comments, index, source_tokens),
        blank_after_comment(comment, comments, index, source_tokens),
      ),
    )
  }
  {
    leading: fn(span) { leading_comment_doc(anchored, span) },
    trailing: fn(span) { trailing_comment_doc(anchored, span) },
    eof: fn() { eof_comment_doc(anchored) },
  }
}

///|
fn non_eof_tokens(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> Array[(@lexer.Token, @basic.SourceSpan)] {
  tokens.filter(fn(item) {
    let (token, _) = item
    !(token is EOF)
  })
}

///|
fn anchor_comment(
  comment : FormatComment,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  blank_before : Bool,
  blank_after : Bool,
) -> AnchoredComment {
  let mut previous : Int? = None
  let mut next : Int? = None
  if comment.gap > 0 {
    previous = Some(comment.gap - 1)
  }
  if comment.gap < tokens.length() {
    next = Some(comment.gap)
  }
  let placement = match previous {
    Some(index) if is_same_line(tokens[index], comment) => {
      let (_, span) = tokens[index]
      Trailing(span)
    }
    _ =>
      match next {
        Some(index) => {
          let (_, span) = tokens[index]
          Leading(span)
        }
        None => EndOfFile
      }
  }
  { text: comment.text, placement, blank_before, blank_after }
}

///|
fn blank_before_comment(
  comment : FormatComment,
  comments : Array[FormatComment],
  comment_index : Int,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> Bool {
  let mut previous_line : Int? = None
  if comment_index > 0 {
    previous_line = Some(comments[comment_index - 1].span.end_line)
  }
  for item in tokens {
    let (_, span) = item
    if span.end_offset <= comment.span.start_offset {
      previous_line = Some(span.end_line)
    } else {
      break
    }
  }
  match previous_line {
    Some(line) => comment.span.start_line > line + 1
    None => false
  }
}

///|
fn blank_after_comment(
  comment : FormatComment,
  comments : Array[FormatComment],
  comment_index : Int,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> Bool {
  let mut next_line : Int? = None
  if comment_index + 1 < comments.length() {
    next_line = Some(comments[comment_index + 1].span.start_line)
  }
  for item in tokens {
    let (_, span) = item
    if span.start_offset >= comment.span.end_offset {
      match next_line {
        Some(line) if line <= span.start_line => ()
        _ => next_line = Some(span.start_line)
      }
      break
    }
  }
  match next_line {
    Some(line) => line > comment.span.end_line + 1
    None => false
  }
}

///|
fn is_same_line(
  token : (@lexer.Token, @basic.SourceSpan),
  comment : FormatComment,
) -> Bool {
  let (_, span) = token
  span.end_line == comment.span.start_line
}

///|
fn leading_comment_doc(
  comments : Array[AnchoredComment],
  span : @basic.SourceSpan,
) -> Document {
  let docs = []
  for comment in comments {
    match comment.placement {
      Leading(anchor) if same_leading_anchor(anchor, span) =>
        push_leading_comment_docs(docs, comment)
      _ => ()
    }
  }
  if docs.is_empty() {
    empty
  } else {
    separate(hardline, docs) + hardline
  }
}

///|
fn trailing_comment_doc(
  comments : Array[AnchoredComment],
  span : @basic.SourceSpan,
) -> Document {
  let docs = []
  for comment in comments {
    match comment.placement {
      Trailing(anchor) if same_trailing_anchor(anchor, span) =>
        docs.push(comment_lines_doc(comment.text))
      _ => ()
    }
  }
  if docs.is_empty() {
    empty
  } else {
    space + separate(space, docs)
  }
}

///|
fn eof_comment_doc(comments : Array[AnchoredComment]) -> Document {
  let docs = []
  let mut blank_before_first = false
  for comment in comments {
    match comment.placement {
      EndOfFile => {
        if docs.is_empty() && comment.blank_before {
          blank_before_first = true
        }
        push_leading_comment_docs(docs, comment)
      }
      _ => ()
    }
  }
  if docs.is_empty() {
    empty
  } else {
    let prefix = if blank_before_first { hardline + hardline } else { hardline }
    prefix + separate(hardline, docs)
  }
}

///|
fn push_leading_comment_docs(
  docs : Array[Document],
  comment : AnchoredComment,
) -> Unit {
  if comment.blank_before && !docs.is_empty() {
    docs.push(empty)
  }
  docs.push(comment_lines_doc(comment.text))
  if comment.blank_after {
    docs.push(empty)
  }
}

///|
fn comment_lines_doc(comment_text : String) -> Document {
  separate(
    hardline,
    comment_text
    .trim()
    .split("\n")
    .map(fn(line) { text(line.trim().to_owned()) })
    .collect(),
  )
}

///|
fn same_leading_anchor(
  anchor : @basic.SourceSpan,
  span : @basic.SourceSpan,
) -> Bool {
  anchor.start_line == span.start_line &&
  anchor.start_offset <= span.start_offset
}

///|
fn same_trailing_anchor(
  anchor : @basic.SourceSpan,
  span : @basic.SourceSpan,
) -> Bool {
  anchor.end_offset == span.end_offset
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors() {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors() {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompilerDiagnostic {
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: compiler_local_span(error.span),
        message: lex_error_label(error.error),
        style: Primary,
      },
    ],
    notes=lex_error_notes(error.error),
    helps=lex_error_helps(error.error),
  )
}

///|
fn lex_error_code(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "E1000"
    UnterminatedString => "E1002"
    InvalidStringEscape(_) => "E1003"
    InvalidHexEscape(_) => "E1004"
    NonAsciiStringCharacter => "E1005"
  }
}

///|
fn lex_error_title(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "illegal character in source"
    UnterminatedString => "unterminated string literal"
    InvalidStringEscape(_) => "invalid string escape"
    InvalidHexEscape(_) => "invalid hexadecimal escape"
    NonAsciiStringCharacter => "non-ASCII character in string literal"
  }
}

///|
fn lex_error_label(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
    UnterminatedString => "this string literal is never closed"
    InvalidStringEscape(value) =>
      "`\{value}` is not a supported escape sequence"
    InvalidHexEscape(value) => "`\{value}` is not a valid hexadecimal escape"
    NonAsciiStringCharacter =>
      "Lane string literals currently accept ASCII characters only"
  }
}

///|
fn lex_error_notes(error : @lexer.LexicalError) -> Array[String] {
  match error {
    NonAsciiStringCharacter =>
      [
        "the lexer rejects non-ASCII bytes inside string literals in the current language version",
      ]
    _ => []
  }
}

///|
fn lex_error_helps(error : @lexer.LexicalError) -> Array[String] {
  match error {
    IllegalCharacter(_) =>
      ["remove this character or replace it with a valid Lane token"]
    UnterminatedString => ["add a closing `\"` before the end of the line"]
    InvalidStringEscape(_) =>
      ["use a supported escape such as `\\n`, `\\t`, `\\\"`, or `\\\\`"]
    InvalidHexEscape(_) =>
      ["write hexadecimal escapes with exactly two hexadecimal digits"]
    NonAsciiStringCharacter =>
      ["replace the character with ASCII text or an explicit supported escape"]
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompilerDiagnostic {
  error.to_compiler_diagnostic(DiagnosticContext())
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> CompilerDiagnostic {
  compiler_error(message, span~, code~, labels~, notes~, helps~)
}
