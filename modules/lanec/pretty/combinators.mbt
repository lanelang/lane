///|
/// Returns a comma followed by a single space.
pub fn comma_space() -> Document {
  text(",") + space
}

///|
/// Returns a comma followed by a line break.
pub fn comma_line() -> Document {
  text(",") + line
}

///|
/// Joins documents with comma-space separators.
pub fn join_comma(docs : Array[Document]) -> Document {
  separate(comma_space(), docs)
}

///|
/// Joins documents with grouped comma-line separators.
pub fn join_comma_group(docs : Array[Document]) -> Document {
  group(separate(comma_line(), docs))
}

///|
/// Renders documents inside braces as an indented block.
pub fn braced_block(docs : Array[Document]) -> Document {
  if docs.is_empty() {
    surround(char('{'), char('}'), empty)
  } else {
    surround(
      char('{'),
      hardline + char('}'),
      nest(hardline + separate(hardline, docs)),
    )
  }
}

///|
/// Renders a titled section followed by a braced block.
pub fn section(title : String, docs : Array[Document]) -> Document {
  text(title) + space + braced_block(docs)
}

///|
/// Renders documents as a comma-separated inline bracketed list.
pub fn bracketed_inline(docs : Array[Document]) -> Document {
  surround(char('['), char(']'), join_comma(docs))
}

///|
/// Renders documents as a comma-separated inline parenthesized list.
pub fn parenthesized_inline(docs : Array[Document]) -> Document {
  surround(char('('), char(')'), join_comma(docs))
}

///|
/// Renders a source span as a stable line-column range.
pub fn source_span(span : SourceSpan) -> Document {
  text(span.start_line.to_string()) +
  text(":") +
  text(span.start_column.to_string()) +
  text("-") +
  text(span.end_line.to_string()) +
  text(":") +
  text(span.end_column.to_string())
}
