///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticLabel,
  compiler_error,
  compiler_local_span,
}

///|
using @prettyprinter {
  type Document,
  empty,
  hardline,
  line_comment,
  separate,
  text,
}

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
    Parsed(parsed) => format_parsed_source_with_options(parsed, options)
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
) -> Result[String, Array[CompilerDiagnostic]] {
  let trivia = TriviaPlan::make(parsed.concrete).start_session()
  let formatted = @prettyprinter.render(
      @syntax.format_source_file_with_trivia(
        parsed.syntax,
        trivia.source_format_trivia(),
      ),
      width=options.width,
    ) +
    "\n"
  let diagnostics = trivia.unconsumed_comment_diagnostics()
  if diagnostics.is_empty() {
    Ok(formatted)
  } else {
    Err(diagnostics)
  }
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
  span : @basic.SourceSpan
  placement : CommentPlacement
  blank_before : Bool
  blank_after : Bool
}

///|
priv struct TriviaPlan {
  comments : Array[AnchoredComment]
  tokens : Array[(@lexer.Token, @basic.SourceSpan)]
}

///|
priv struct TriviaSession {
  plan : TriviaPlan
  claimed : Array[Bool]
}

///|
fn TriviaPlan::make(concrete : @lexer.ConcreteSyntax) -> TriviaPlan {
  let source_tokens = non_eof_tokens(concrete.tokens)
  let comments : Array[FormatComment] = []
  for item in concrete.trivia {
    if item.kind is LineComment {
      let comment = FormatComment::{
        text: concrete.source_text.unsafe_substring(
          start=item.span.start_offset,
          end=item.span.end_offset,
        ),
        span: item.span,
        gap: item.gap,
      }
      if comments.last() is Some(previous) &&
        line_comments_are_adjacent(previous, comment, source_tokens) {
        comments[comments.length() - 1] = {
          text: "\{previous.text}\n\{comment.text}",
          span: @basic.SourceSpan::join(previous.span, comment.span),
          gap: previous.gap,
        }
      } else {
        comments.push(comment)
      }
    }
  }
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
  { comments: anchored, tokens: source_tokens }
}

///|
fn TriviaPlan::start_session(self : TriviaPlan) -> TriviaSession {
  { plan: self, claimed: Array::make(self.comments.length(), false) }
}

///|
fn line_comments_are_adjacent(
  previous : FormatComment,
  current : FormatComment,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> Bool {
  previous.gap == current.gap &&
  previous.span.end_line + 1 == current.span.start_line &&
  previous.span.start_column == current.span.start_column &&
  line_comment_is_standalone(previous, tokens) &&
  line_comment_is_standalone(current, tokens)
}

///|
fn line_comment_is_standalone(
  comment : FormatComment,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> Bool {
  comment.gap == 0 ||
  tokens[comment.gap - 1].1.end_line != comment.span.start_line
}

///|
fn TriviaSession::source_format_trivia(
  self : TriviaSession,
) -> @syntax.SourceFormatTrivia {
  let comments = self.plan.comments
  let tokens = self.plan.tokens
  let claimed = self.claimed
  if comments.is_empty() {
    return @syntax.SourceFormatTrivia::empty()
  }
  {
    leading: fn(span) { leading_comment_doc(comments, claimed, span) },
    trailing: fn(span) { trailing_comment_doc(comments, claimed, span) },
    has_leading: fn(span) { has_leading_comment(comments, span) },
    has_trailing: fn(span) { has_trailing_comment(comments, span) },
    boundary: fn(start, end) {
      dangling_comment_doc(comments, claimed, start, end)
    },
    has_boundary: fn(start, end) {
      has_dangling_comment(comments, claimed, start, end)
    },
    delimited: fn(open, start, end) {
      delimited_comment_doc(comments, claimed, tokens, open, start, end)
    },
    has_delimited: fn(open, start, end) {
      has_delimited_comment(comments, claimed, tokens, open, start, end)
    },
    eof: fn() { eof_comment_doc(comments, claimed) },
  }
}

///|
fn has_delimited_comment(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  open : Char,
  start_offset : Int,
  end_offset : Int,
) -> Bool {
  match delimiter_interior(tokens, open, start_offset, end_offset) {
    Some((start, end)) => has_dangling_comment(comments, claimed, start, end)
    None => false
  }
}

///|
fn delimited_comment_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  open : Char,
  start_offset : Int,
  end_offset : Int,
) -> Document {
  match delimiter_interior(tokens, open, start_offset, end_offset) {
    Some((start, end)) => dangling_comment_doc(comments, claimed, start, end)
    None => empty
  }
}

///|
fn delimiter_interior(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  open : Char,
  start_offset : Int,
  end_offset : Int,
) -> (Int, Int)? {
  let mut depth = 0
  let mut interior_start = -1
  for item in tokens {
    let (token, span) = item
    if span.start_offset < start_offset {
      continue
    }
    if span.end_offset > end_offset {
      break
    }
    if is_open_delimiter(token, open) {
      if depth == 0 {
        interior_start = span.end_offset
      }
      depth += 1
    } else if depth > 0 && is_close_delimiter(token, open) {
      depth -= 1
      if depth == 0 {
        return Some((interior_start, span.start_offset))
      }
    }
  }
  None
}

///|
fn is_open_delimiter(token : @lexer.Token, open : Char) -> Bool {
  match open {
    '[' => token is LBRACKET
    '(' => token is LPAREN
    '{' => token is LBRACE || token is DOTLBRACE
    _ => false
  }
}

///|
fn is_close_delimiter(token : @lexer.Token, open : Char) -> Bool {
  match open {
    '[' => token is RBRACKET
    '(' => token is RPAREN
    '{' => token is RBRACE
    _ => false
  }
}

///|
fn has_dangling_comment(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  start_offset : Int,
  end_offset : Int,
) -> Bool {
  for index, comment in comments {
    if !claimed[index] &&
      comment.placement is Leading(_) &&
      comment.span.start_offset >= start_offset &&
      comment.span.end_offset <= end_offset {
      return true
    }
  }
  false
}

///|
fn dangling_comment_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  start_offset : Int,
  end_offset : Int,
) -> Document {
  let docs = []
  for index, comment in comments {
    if !claimed[index] &&
      comment.placement is Leading(_) &&
      comment.span.start_offset >= start_offset &&
      comment.span.end_offset <= end_offset {
      claimed[index] = true
      push_leading_comment_docs(docs, comment)
    }
  }
  separate(hardline, docs)
}

///|
fn TriviaSession::unconsumed_comment_diagnostics(
  self : TriviaSession,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for index, comment in self.plan.comments {
    if !self.claimed[index] {
      diagnostics.push(
        diagnostic(
          "formatter could not preserve a source comment",
          span=Some(comment.span),
          code=Some("E1103"),
          labels=[
            {
              span: compiler_local_span(comment.span),
              message: "this comment has no unique formatting attachment",
              style: Primary,
            },
          ],
          notes=[
            "formatting stopped instead of silently dropping or moving the comment",
          ],
          helps=["report this source position as a formatter bug"],
        ),
      )
    }
  }
  diagnostics
}

///|
fn has_leading_comment(
  comments : Array[AnchoredComment],
  span : @basic.SourceSpan,
) -> Bool {
  for comment in comments {
    if comment.placement is Leading(anchor) && same_leading_anchor(anchor, span) {
      return true
    }
  }
  false
}

///|
fn has_trailing_comment(
  comments : Array[AnchoredComment],
  span : @basic.SourceSpan,
) -> Bool {
  for comment in comments {
    if comment.placement is Trailing(anchor) &&
      same_trailing_anchor(anchor, span) {
      return true
    }
  }
  false
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
  let placement = match next {
    Some(index) if tokens[index].0 is COMMA && index + 1 < tokens.length() =>
      Leading(leading_anchor_span(tokens, index + 1))
    _ =>
      match previous {
        Some(index) if is_same_line(tokens[index], comment) &&
          can_anchor_trailing(tokens[index].0) => {
          let (_, span) = tokens[index]
          Trailing(span)
        }
        _ =>
          match next {
            Some(index) => Leading(leading_anchor_span(tokens, index))
            None => EndOfFile
          }
      }
  }
  {
    text: comment.text,
    span: comment.span,
    placement,
    blank_before,
    blank_after,
  }
}

///|
fn can_anchor_trailing(token : @lexer.Token) -> Bool {
  match token {
    COMMA
    | PLUS
    | BANG
    | MINUS
    | STAR
    | SLASH
    | PERCENT
    | EQEQ
    | BANGEQ
    | LT
    | LTEQ
    | GT
    | GTEQ
    | AMPAMP
    | BARBAR
    | PIPE
    | EQUAL
    | THIN_ARROW
    | FAT_ARROW
    | LPAREN
    | LBRACE
    | LBRACKET
    | DOT
    | DOTLBRACE
    | COLON
    | COLONCOLON
    | TIGHT_COLONCOLON
    | PUB => false
    _ => true
  }
}

///|
fn leading_anchor_span(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  index : Int,
) -> @basic.SourceSpan {
  let (token, span) = tokens[index]
  if token is PUB && index + 1 < tokens.length() {
    let (_, next_span) = tokens[index + 1]
    next_span
  } else {
    span
  }
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
  claimed : Array[Bool],
  span : @basic.SourceSpan,
) -> Document {
  let docs = []
  for index, comment in comments {
    if comment.placement is Leading(anchor) &&
      !claimed[index] &&
      same_leading_anchor(anchor, span) {
      claimed[index] = true
      push_leading_comment_docs(docs, comment)
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
  claimed : Array[Bool],
  span : @basic.SourceSpan,
) -> Document {
  let docs = []
  for index, comment in comments {
    if comment.placement is Trailing(anchor) &&
      !claimed[index] &&
      same_trailing_anchor(anchor, span) {
      claimed[index] = true
      docs.push(line_comment(comment.text.trim().to_owned()))
    }
  }
  separate(empty, docs)
}

///|
fn eof_comment_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
) -> Document {
  let docs = []
  let mut blank_before_first = false
  for index, comment in comments {
    if comment.placement is EndOfFile && !claimed[index] {
      claimed[index] = true
      if docs.is_empty() && comment.blank_before {
        blank_before_first = true
      }
      push_leading_comment_docs(docs, comment)
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
  anchor.start_offset == span.start_offset
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
