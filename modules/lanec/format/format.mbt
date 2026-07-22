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
  line,
  line_comment,
  separate,
  space,
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
  let layout = ConcreteLayout::make(
    parsed.concrete,
    parsed.layout_separator_gaps,
  ).start_session()
  let formatted = @prettyprinter.render(
      @syntax.format_source_file_with_trivia(
        parsed.syntax,
        layout.source_format_trivia(),
      ),
      width=options.width,
    ) +
    "\n"
  let diagnostics = layout.unconsumed_comment_diagnostics()
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
  Boundary
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
priv struct CommentAnchor {
  offset : Int
  comment_index : Int
}

///|
priv struct DelimiterPair {
  opening_start : Int
  interior_start : Int
  interior_end : Int
  closing_end : Int
}

///|
priv struct DelimiterPairIndex {
  parentheses : Array[DelimiterPair]
  brackets : Array[DelimiterPair]
  braces : Array[DelimiterPair]
}

///|
priv struct ConcreteLayout {
  comments : Array[AnchoredComment]
  leading_anchors : Array[CommentAnchor]
  trailing_anchors : Array[CommentAnchor]
  tokens : Array[(@lexer.Token, @basic.SourceSpan)]
  delimiter_pairs : DelimiterPairIndex
  layout_separator_gaps : Array[Bool]
}

///|
priv struct ConcreteLayoutSession {
  layout : ConcreteLayout
  claimed : Array[Bool]
}

///|
fn ConcreteLayout::make(
  concrete : @lexer.ConcreteSyntax,
  layout_separator_gaps : Array[Bool],
) -> ConcreteLayout {
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
  let leading_anchors = []
  let trailing_anchors = []
  for index, comment in comments {
    let anchored_comment = place_comment(
      comment,
      source_tokens,
      layout_separator_gaps,
      blank_before_comment(comment, comments, index, source_tokens),
      blank_after_comment(comment, comments, index, source_tokens),
    )
    let comment_index = anchored.length()
    if anchored_comment.placement is Leading(span) {
      leading_anchors.push({ offset: span.start_offset, comment_index })
    } else if anchored_comment.placement is Trailing(span) {
      trailing_anchors.push({ offset: span.end_offset, comment_index })
    }
    anchored.push(anchored_comment)
  }
  {
    comments: anchored,
    leading_anchors,
    trailing_anchors,
    tokens: source_tokens,
    delimiter_pairs: DelimiterPairIndex::make(source_tokens),
    layout_separator_gaps,
  }
}

///|
fn DelimiterPairIndex::make(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
) -> DelimiterPairIndex {
  let parentheses = []
  let brackets = []
  let braces = []
  let parenthesis_stack : Array[Int] = []
  let bracket_stack : Array[Int] = []
  let brace_stack : Array[Int] = []
  for item in tokens {
    let (token, span) = item
    match token {
      LPAREN => open_delimiter_pair(parentheses, parenthesis_stack, span)
      RPAREN => close_delimiter_pair(parenthesis_stack, parentheses, span)
      LBRACKET => open_delimiter_pair(brackets, bracket_stack, span)
      RBRACKET => close_delimiter_pair(bracket_stack, brackets, span)
      LBRACE | DOTLBRACE => open_delimiter_pair(braces, brace_stack, span)
      RBRACE => close_delimiter_pair(brace_stack, braces, span)
      _ => ()
    }
  }
  { parentheses, brackets, braces }
}

///|
fn open_delimiter_pair(
  pairs : Array[DelimiterPair],
  openings : Array[Int],
  opening : @basic.SourceSpan,
) -> Unit {
  openings.push(pairs.length())
  pairs.push({
    opening_start: opening.start_offset,
    interior_start: opening.end_offset,
    interior_end: -1,
    closing_end: -1,
  })
}

///|
fn close_delimiter_pair(
  openings : Array[Int],
  pairs : Array[DelimiterPair],
  closing : @basic.SourceSpan,
) -> Unit {
  if openings.pop() is Some(index) {
    pairs[index] = {
      ..pairs[index],
      interior_end: closing.start_offset,
      closing_end: closing.end_offset,
    }
  }
}

///|
fn DelimiterPairIndex::interior(
  self : DelimiterPairIndex,
  open : Char,
  start_offset : Int,
  end_offset : Int,
) -> (Int, Int)? {
  let pairs = match open {
    '(' => self.parentheses
    '[' => self.brackets
    '{' => self.braces
    _ => return None
  }
  let index = first_delimiter_pair_at_or_after(pairs, start_offset)
  guard pairs.get(index) is Some(pair) &&
    pair.closing_end >= 0 &&
    pair.closing_end <= end_offset else {
    return None
  }
  Some((pair.interior_start, pair.interior_end))
}

///|
fn first_delimiter_pair_at_or_after(
  pairs : Array[DelimiterPair],
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = pairs.length()
  while low < high {
    let middle = low + (high - low) / 2
    if pairs[middle].opening_start < offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn ConcreteLayout::start_session(
  self : ConcreteLayout,
) -> ConcreteLayoutSession {
  if self.layout_separator_gaps.length() != self.tokens.length() + 1 {
    abort("formatter concrete layout is out of sync with parser tokens")
  }
  { layout: self, claimed: Array::make(self.comments.length(), false) }
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
fn ConcreteLayoutSession::source_format_trivia(
  self : ConcreteLayoutSession,
) -> @syntax.SourceFormatTrivia {
  let comments = self.layout.comments
  let leading_anchors = self.layout.leading_anchors
  let trailing_anchors = self.layout.trailing_anchors
  let tokens = self.layout.tokens
  let delimiter_pairs = self.layout.delimiter_pairs
  let claimed = self.claimed
  if comments.is_empty() {
    return @syntax.SourceFormatTrivia::empty()
  }
  {
    leading: fn(span) {
      leading_comment_doc(comments, leading_anchors, claimed, span)
    },
    trailing: fn(span) {
      trailing_comment_doc(comments, trailing_anchors, claimed, span)
    },
    has_leading: fn(span) {
      has_comment_anchor(leading_anchors, span.start_offset)
    },
    boundary: fn(start, end) {
      dangling_comment_doc(comments, claimed, start, end)
    },
    token_separator: fn(span, left_token_index) {
      token_separator_doc(comments, claimed, tokens, span, left_token_index)
    },
    delimited: fn(open, start, end, children) {
      delimited_comment_doc(
        comments, claimed, delimiter_pairs, open, start, end, children,
      )
    },
    comma_separator: fn(left, right) {
      comma_separator_doc(comments, claimed, left, right)
    },
    item_separator: fn(left, right) {
      item_separator_doc(comments, claimed, left, right)
    },
    top_level_separator: fn(left, right) {
      top_level_separator_doc(comments, claimed, left, right)
    },
    struct_field_separator: fn(left, right) {
      struct_field_separator_doc(comments, claimed, tokens, left, right)
    },
    eof: fn() { eof_comment_doc(comments, claimed) },
  }
}

///|
fn delimited_comment_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  delimiter_pairs : DelimiterPairIndex,
  open : Char,
  start_offset : Int,
  end_offset : Int,
  child_spans : Array[@basic.SourceSpan],
) -> (Document, Bool) {
  match delimiter_pairs.interior(open, start_offset, end_offset) {
    Some((start, end)) =>
      dangling_comment_doc(
        comments,
        claimed,
        start,
        end,
        excluded_boundaries=child_spans,
        include_boundaries=true,
      )
    None => (empty, false)
  }
}

///|
fn dangling_comment_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  start_offset : Int,
  end_offset : Int,
  excluded_boundaries? : Array[@basic.SourceSpan] = [],
  include_boundaries? : Bool = false,
) -> (Document, Bool) {
  let docs = []
  let mut consumed = false
  let mut index = first_comment_at_or_after(comments, start_offset)
  while index < comments.length() {
    let comment = comments[index]
    if comment.span.start_offset > end_offset {
      break
    }
    if !claimed[index] &&
      (include_boundaries || !(comment.placement is Boundary)) &&
      comment.span.start_offset >= start_offset &&
      comment.span.end_offset <= end_offset &&
      !comment_is_between_children(comment, excluded_boundaries) {
      claimed[index] = true
      consumed = true
      push_leading_comment_docs(docs, comment)
    }
    index += 1
  }
  (separate(hardline, docs), consumed)
}

///|
fn comment_is_between_children(
  comment : AnchoredComment,
  children : Array[@basic.SourceSpan],
) -> Bool {
  for child in children {
    if comment.span.start_offset >= child.start_offset &&
      comment.span.end_offset <= child.end_offset {
      return true
    }
  }
  for index in 1..<children.length() {
    if comment.span.start_offset >= children[index - 1].end_offset &&
      comment.span.end_offset <= children[index].start_offset {
      return true
    }
  }
  false
}

///|
fn ConcreteLayoutSession::unconsumed_comment_diagnostics(
  self : ConcreteLayoutSession,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for index, comment in self.layout.comments {
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
fn has_comment_anchor(anchors : Array[CommentAnchor], offset : Int) -> Bool {
  let index = first_anchor_at_or_after(anchors, offset)
  index < anchors.length() && anchors[index].offset == offset
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
fn place_comment(
  comment : FormatComment,
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  layout_separator_gaps : Array[Bool],
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
  let is_separator_boundary = layout_separator_gaps[comment.gap] ||
    (match previous {
      Some(index) => tokens[index].0 is COMMA || tokens[index].0 is SEMICOLON
      None => false
    }) ||
    (match next {
      Some(index) => tokens[index].0 is COMMA || tokens[index].0 is SEMICOLON
      None => false
    })
  let placement = if is_separator_boundary {
    Boundary
  } else {
    match previous {
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
fn comma_separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  left : @basic.SourceSpan,
  right : @basic.SourceSpan,
) -> Document {
  separator_doc(comments, claimed, left, right, text(","), line, false)
}

///|
fn token_separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  span : @basic.SourceSpan,
  left_token_index : Int,
) -> Document {
  let index = first_token_at_or_after(tokens, span.start_offset) +
    left_token_index
  guard tokens.get(index) is Some((_, left)) &&
    tokens.get(index + 1) is Some((_, right)) &&
    right.end_offset <= span.end_offset else {
    return space
  }
  separator_doc(
    comments,
    claimed,
    left,
    right,
    empty,
    space,
    true,
    include_attached=true,
  )
}

///|
fn item_separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  left : @basic.SourceSpan,
  right : @basic.SourceSpan,
) -> Document {
  separator_doc(comments, claimed, left, right, empty, hardline, true)
}

///|
fn top_level_separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  left : @basic.SourceSpan,
  right : @basic.SourceSpan,
) -> Document {
  separator_doc(
    comments,
    claimed,
    left,
    right,
    empty,
    hardline + hardline,
    true,
    require_blank=true,
  )
}

///|
fn struct_field_separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  left : @basic.SourceSpan,
  right : @basic.SourceSpan,
) -> Document {
  let mut explicit_comma = false
  let mut token_index = first_token_at_or_after(tokens, left.end_offset)
  while token_index < tokens.length() {
    let (token, span) = tokens[token_index]
    if span.start_offset > right.start_offset {
      break
    }
    if span.end_offset <= right.start_offset && token is COMMA {
      explicit_comma = true
      break
    }
    token_index += 1
  }
  if !explicit_comma {
    let mut comment_index = first_comment_at_or_after(comments, left.end_offset)
    while comment_index < comments.length() {
      let comment = comments[comment_index]
      if comment.span.start_offset > right.start_offset {
        break
      }
      if comment.span.end_offset <= right.start_offset &&
        comment.span.start_line == left.end_line {
        return item_separator_doc(comments, claimed, left, right)
      }
      comment_index += 1
    }
  }
  comma_separator_doc(comments, claimed, left, right)
}

///|
fn separator_doc(
  comments : Array[AnchoredComment],
  claimed : Array[Bool],
  left : @basic.SourceSpan,
  right : @basic.SourceSpan,
  prefix : Document,
  empty_separator : Document,
  allow_inline : Bool,
  require_blank? : Bool = false,
  include_attached? : Bool = false,
) -> Document {
  let between = []
  let mut index = first_comment_at_or_after(comments, left.end_offset)
  while index < comments.length() {
    let comment = comments[index]
    if comment.span.start_offset > right.start_offset {
      break
    }
    if !claimed[index] &&
      (include_attached || comment.placement is Boundary) &&
      comment.span.start_offset >= left.end_offset &&
      comment.span.end_offset <= right.start_offset {
      claimed[index] = true
      between.push(comment)
    }
    index += 1
  }
  guard !between.is_empty() else { return prefix + empty_separator }
  let mut has_meaningful_blank = false
  for comment in between {
    if comment.blank_before || comment.blank_after {
      has_meaningful_blank = true
      break
    }
  }
  let first = between[0]
  let first_is_inline = allow_inline && first.span.start_line == left.end_line
  let mut result = prefix
  if first_is_inline {
    result = result + line_comment(first.text.trim().to_owned()) + hardline
  } else {
    result = result + hardline
    if first.blank_before || (require_blank && !has_meaningful_blank) {
      result = result + hardline
    }
    result = result + comment_lines_doc(first.text) + hardline
  }
  for index in 1..<between.length() {
    let comment = between[index]
    if comment.blank_before ||
      (require_blank && !has_meaningful_blank && index == 1 && first_is_inline) {
      result = result + hardline
    }
    result = result + comment_lines_doc(comment.text) + hardline
  }
  if between.last().unwrap().blank_after ||
    (
      require_blank &&
      !has_meaningful_blank &&
      between.length() == 1 &&
      first_is_inline
    ) {
    result = result + hardline
  }
  result
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
  if comment.gap > 0 {
    let (_, span) = tokens[comment.gap - 1]
    match previous_line {
      Some(line) if line >= span.end_line => ()
      _ => previous_line = Some(span.end_line)
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
  if comment.gap < tokens.length() {
    let (_, span) = tokens[comment.gap]
    match next_line {
      Some(line) if line <= span.start_line => ()
      _ => next_line = Some(span.start_line)
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
  anchors : Array[CommentAnchor],
  claimed : Array[Bool],
  span : @basic.SourceSpan,
) -> Document {
  let docs = []
  let mut anchor_index = first_anchor_at_or_after(anchors, span.start_offset)
  while anchor_index < anchors.length() &&
        anchors[anchor_index].offset == span.start_offset {
    let comment_index = anchors[anchor_index].comment_index
    if !claimed[comment_index] {
      claimed[comment_index] = true
      let comment = comments[comment_index]
      push_leading_comment_docs(docs, comment)
    }
    anchor_index += 1
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
  anchors : Array[CommentAnchor],
  claimed : Array[Bool],
  span : @basic.SourceSpan,
) -> (Document, Bool) {
  let docs = []
  let mut anchor_index = first_anchor_at_or_after(anchors, span.end_offset)
  while anchor_index < anchors.length() &&
        anchors[anchor_index].offset == span.end_offset {
    let comment_index = anchors[anchor_index].comment_index
    if !claimed[comment_index] {
      claimed[comment_index] = true
      let comment = comments[comment_index]
      docs.push(line_comment(comment.text.trim().to_owned()))
    }
    anchor_index += 1
  }
  (separate(empty, docs), !docs.is_empty())
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
fn first_anchor_at_or_after(
  anchors : Array[CommentAnchor],
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = anchors.length()
  while low < high {
    let middle = low + (high - low) / 2
    if anchors[middle].offset < offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn first_comment_at_or_after(
  comments : Array[AnchoredComment],
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = comments.length()
  while low < high {
    let middle = low + (high - low) / 2
    if comments[middle].span.start_offset < offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn first_token_at_or_after(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = tokens.length()
  while low < high {
    let middle = low + (high - low) / 2
    if tokens[middle].1.start_offset < offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
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
