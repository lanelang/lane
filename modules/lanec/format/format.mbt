///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticLabel,
  compiler_error,
  compiler_local_span,
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
  match parsed.source {
    Some(file) =>
      Ok(
        preserve_comments(
          source,
          format_source_file_with_options(file, options),
        ),
      )
    None =>
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
}

///|
priv enum CommentPlacement {
  Leading(Int)
  Trailing(Int)
  EndOfFile
}

///|
priv struct AnchoredComment {
  text : String
  placement : CommentPlacement
  blank_before : Bool
  blank_after : Bool
  indent : String
}

///|
priv struct CommentEdit {
  start : Int
  end : Int
  text : String
}

///|
fn preserve_comments(source : String, formatted : String) -> String {
  let comments = source_comments(source)
  if comments.is_empty() {
    return formatted
  }
  let source_tokens = non_eof_tokens(@lexer.tokens_from_string(source).tokens)
  let formatted_tokens = non_eof_tokens(
    @lexer.tokens_from_string(formatted).tokens,
  )
  if source_tokens.length() != formatted_tokens.length() {
    return formatted + trailing_comment_dump(comments)
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
  apply_comment_insertions(formatted, formatted_tokens, anchored)
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
  for index, item in tokens {
    let (_, span) = item
    if span.end_offset <= comment.span.start_offset {
      previous = Some(index)
    }
    if next is None && span.start_offset >= comment.span.end_offset {
      next = Some(index)
    }
  }
  let placement = match previous {
    Some(index) if is_same_line(tokens[index], comment) => Trailing(index)
    _ =>
      match next {
        Some(index) => Leading(index)
        None => EndOfFile
      }
  }
  {
    text: comment.text,
    placement,
    blank_before,
    blank_after,
    indent: comment_indent(comment),
  }
}

///|
fn comment_indent(comment : FormatComment) -> String {
  spaces(comment.span.start_column - 1)
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
fn apply_comment_insertions(
  formatted : String,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  comments : Array[AnchoredComment],
) -> String {
  let edits = sorted_comment_edits(comment_edits(formatted, tokens, comments))
  let builder = StringBuilder::new()
  let mut cursor = 0
  for edit in edits {
    if edit.start > cursor {
      builder.write_string(
        formatted.unsafe_substring(start=cursor, end=edit.start),
      )
    }
    builder.write_string(edit.text)
    cursor = edit.end
  }
  if cursor < formatted.length() {
    builder.write_string(
      formatted.unsafe_substring(start=cursor, end=formatted.length()),
    )
  }
  builder.to_string()
}

///|
fn sorted_comment_edits(edits : Array[CommentEdit]) -> Array[CommentEdit] {
  let mut result = []
  for edit in edits {
    result = push_ordered_edit(result, edit)
  }
  result
}

///|
fn push_ordered_edit(
  edits : Array[CommentEdit],
  edit : CommentEdit,
) -> Array[CommentEdit] {
  let result = []
  let mut inserted = false
  for existing in edits {
    if !inserted && edit.start < existing.start {
      result.push(edit)
      inserted = true
    }
    result.push(existing)
  }
  if !inserted {
    result.push(edit)
  }
  result
}

///|
fn comment_edits(
  formatted : String,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  comments : Array[AnchoredComment],
) -> Array[CommentEdit] {
  let edits = []
  for comment in comments {
    match comment.placement {
      Leading(index) => {
        let (_, span) = tokens[index]
        edits.push(leading_comment_edit(formatted, span, comment))
        if leading_comment_is_midline(formatted, span) {
          if next_compact_closer(tokens, index) is Some(close_span) {
            let expanded_indent = compact_child_indent(formatted, span)
            let start = trim_space_before(
              formatted,
              line_start_offset(formatted, close_span.start_offset),
              close_span.start_offset,
            )
            if !has_edit_at(edits, start, close_span.start_offset) {
              edits.push({
                start,
                end: close_span.start_offset,
                text: "\n" + dedent(expanded_indent),
              })
            }
          }
        }
      }
      Trailing(index) => {
        let (_, span) = tokens[index]
        let offset = line_end_offset(formatted, span.end_offset)
        edits.push({
          start: offset,
          end: offset,
          text: " " + comment.text.trim().to_owned(),
        })
      }
      EndOfFile =>
        edits.push({
          start: final_newline_offset(formatted),
          end: final_newline_offset(formatted),
          text: render_eof_comment(formatted, comment),
        })
    }
  }
  edits
}

///|
fn leading_comment_edit(
  formatted : String,
  span : @basic.SourceSpan,
  comment : AnchoredComment,
) -> CommentEdit {
  let line_start = line_start_offset(formatted, span.start_offset)
  if !leading_comment_is_midline(formatted, span) {
    let indent = formatted.unsafe_substring(
      start=line_start,
      end=span.start_offset,
    )
    {
      start: line_start,
      end: line_start,
      text: render_leading_comment(comment.text, indent, comment.blank_after),
    }
  } else {
    let start = trim_space_before(formatted, line_start, span.start_offset)
    let indent = compact_child_indent(formatted, span)
    {
      start,
      end: span.start_offset,
      text: "\n" +
      render_leading_comment(comment.text, indent, comment.blank_after) +
      indent,
    }
  }
}

///|
fn compact_child_indent(formatted : String, span : @basic.SourceSpan) -> String {
  let line_start = line_start_offset(formatted, span.start_offset)
  let line_indent_end = first_non_space_offset(formatted, line_start)
  formatted.unsafe_substring(start=line_start, end=line_indent_end) + "  "
}

///|
fn first_non_space_offset(source : String, offset : Int) -> Int {
  let mut index = offset
  while index < source.length() && is_space_or_tab_at(source, index) {
    index += 1
  }
  index
}

///|
fn leading_comment_is_midline(
  formatted : String,
  span : @basic.SourceSpan,
) -> Bool {
  let line_start = line_start_offset(formatted, span.start_offset)
  !line_prefix_is_indent(formatted, line_start, span.start_offset)
}

///|
fn next_compact_closer(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  start_index : Int,
) -> @basic.SourceSpan? {
  let (_, anchor_span) = tokens[start_index]
  for index in (start_index + 1)..<tokens.length() {
    let (token, span) = tokens[index]
    if span.start_line != anchor_span.start_line {
      return None
    }
    if token is RBRACE || token is RPAREN || token is RBRACKET {
      return Some(span)
    }
  }
  None
}

///|
fn has_edit_at(edits : Array[CommentEdit], start : Int, end : Int) -> Bool {
  for edit in edits {
    if edit.start == start && edit.end == end {
      return true
    }
  }
  false
}

///|
fn render_leading_comment(
  text : String,
  indent : String,
  blank_after : Bool,
) -> String {
  let rendered = render_comment_lines(text, indent)
  if blank_after {
    rendered + "\n\n"
  } else {
    rendered + "\n"
  }
}

///|
fn render_eof_comment(formatted : String, comment : AnchoredComment) -> String {
  let offset = final_newline_offset(formatted)
  let prefix = if comment.blank_before {
    "\n\n"
  } else if offset > 0 && !is_line_break_before(formatted, offset) {
    "\n"
  } else {
    ""
  }
  prefix + render_comment_lines(comment.text, comment.indent)
}

///|
fn render_comment_lines(text : String, indent : String) -> String {
  let lines = text
    .trim()
    .split("\n")
    .map(fn(line) { indent + line.trim().to_owned() })
    .collect()
  lines.join("\n")
}

///|
fn trailing_comment_dump(comments : Array[FormatComment]) -> String {
  "\n" +
  comments.map(fn(comment) { comment.text.trim().to_owned() }).join("\n") +
  "\n"
}

///|
fn source_comments(source : String) -> Array[FormatComment] {
  let comments = []
  let mut index = 0
  let mut line = 1
  let mut bol = 0
  while index < source.length() {
    if source_has_at(source, index, "\"") {
      let (next, next_line, next_bol) = skip_string(source, index, line, bol)
      index = next
      line = next_line
      bol = next_bol
    } else if source_has_at(source, index, "//") {
      let start = index
      let start_line = line
      let start_bol = bol
      index += 2
      while index < source.length() &&
            !source_has_at(source, index, "\n") &&
            !source_has_at(source, index, "\r") {
        index += 1
      }
      comments.push({
        text: source.unsafe_substring(start~, end=index),
        span: source_span(start, index, start_line, start_bol, line, bol),
      })
    } else {
      let (next, next_line, next_bol) = consume_source_char(
        source, index, line, bol,
      )
      index = next
      line = next_line
      bol = next_bol
    }
  }
  comments
}

///|
fn line_start_offset(source : String, offset : Int) -> Int {
  let mut index = offset
  while index > 0 &&
        !source_has_at(source, index - 1, "\n") &&
        !source_has_at(source, index - 1, "\r") {
    index -= 1
  }
  index
}

///|
fn line_prefix_is_indent(source : String, start : Int, end : Int) -> Bool {
  let mut index = start
  while index < end {
    if !is_space_or_tab_at(source, index) {
      return false
    }
    index += 1
  }
  true
}

///|
fn trim_space_before(source : String, line_start : Int, offset : Int) -> Int {
  let mut index = offset
  while index > line_start && is_space_or_tab_at(source, index - 1) {
    index -= 1
  }
  index
}

///|
fn line_end_offset(source : String, offset : Int) -> Int {
  let mut index = offset
  while index < source.length() &&
        !source_has_at(source, index, "\n") &&
        !source_has_at(source, index, "\r") {
    index += 1
  }
  index
}

///|
fn is_line_break_before(source : String, offset : Int) -> Bool {
  offset > 0 &&
  (
    source_has_at(source, offset - 1, "\n") ||
    source_has_at(source, offset - 1, "\r")
  )
}

///|
fn is_space_or_tab_at(source : String, offset : Int) -> Bool {
  source_has_at(source, offset, " ") || source_has_at(source, offset, "\t")
}

///|
fn spaces(count : Int) -> String {
  let builder = StringBuilder::new()
  for _ in 0..<count {
    builder.write_string(" ")
  }
  builder.to_string()
}

///|
fn dedent(indent : String) -> String {
  if indent.length() >= 2 {
    indent.unsafe_substring(start=0, end=indent.length() - 2)
  } else {
    ""
  }
}

///|
fn final_newline_offset(source : String) -> Int {
  if source.length() > 0 && source_has_at(source, source.length() - 1, "\n") {
    source.length() - 1
  } else {
    source.length()
  }
}

///|
fn skip_string(
  source : String,
  start : Int,
  line : Int,
  bol : Int,
) -> (Int, Int, Int) {
  let mut index = start + 1
  let mut current_line = line
  let mut current_bol = bol
  while index < source.length() {
    if source_has_at(source, index, "\\") {
      index += 2
      continue
    }
    if source_has_at(source, index, "\"") {
      return (index + 1, current_line, current_bol)
    }
    let (next, next_line, next_bol) = consume_source_char(
      source, index, current_line, current_bol,
    )
    index = next
    current_line = next_line
    current_bol = next_bol
  }
  (index, current_line, current_bol)
}

///|
fn consume_source_char(
  source : String,
  index : Int,
  line : Int,
  bol : Int,
) -> (Int, Int, Int) {
  if source_has_at(source, index, "\r\n") {
    (index + 2, line + 1, index + 2)
  } else if source_has_at(source, index, "\n") ||
    source_has_at(source, index, "\r") {
    (index + 1, line + 1, index + 1)
  } else {
    (index + 1, line, bol)
  }
}

///|
fn source_has_at(source : String, index : Int, text : String) -> Bool {
  index + text.length() <= source.length() &&
  source.unsafe_substring(start=index, end=index + text.length()) == text
}

///|
fn source_span(
  start : Int,
  end : Int,
  start_line : Int,
  start_bol : Int,
  end_line : Int,
  end_bol : Int,
) -> @basic.SourceSpan {
  {
    start_offset: start,
    end_offset: end,
    start_line,
    start_column: start - start_bol + 1,
    end_line,
    end_column: end - end_bol + 1,
  }
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors {
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
