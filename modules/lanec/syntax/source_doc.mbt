///|
fn keyword(value : String) -> Document {
  text(value)
}

///|
fn source_string(value : String) -> Document {
  text(value.escape())
}

///|
fn delimited_comma_list(
  open : Document,
  close : Document,
  edge : Document,
  docs : Array[Document],
  item_spans~ : Array[SourceSpan],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_list(
    open,
    close,
    edge,
    comma_separators(docs, item_spans, trivia),
    docs,
    dangling~,
    force_break~,
  )
}

///|
fn delimited_list(
  open : Document,
  close : Document,
  edge : Document,
  separators : Array[Document],
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      separate_documents(docs, separators) + hardline + dangling
    }
    open + nest(hardline + body) + hardline + close
  } else if docs.is_empty() {
    open + close
  } else {
    group(
      open + nest(edge + separate_documents(docs, separators)) + edge + close,
    )
  }
}

///|
fn separate_documents(
  docs : Array[Document],
  separators : Array[Document],
) -> Document {
  guard !docs.is_empty() else { return empty }
  let first = docs[0]
  let mut result = first
  for index in 1..<docs.length() {
    result = result + separators[index - 1] + docs[index]
  }
  result
}

///|
fn comma_separators(
  docs : Array[Document],
  item_spans : Array[SourceSpan],
  trivia : SourceFormatTrivia,
) -> Array[Document] {
  guard docs.length() == item_spans.length() else {
    abort("comma list documents and item spans must have equal lengths")
  }
  let separators = []
  for index in 1..<docs.length() {
    separators.push(
      (trivia.comma_separator)(item_spans[index - 1], item_spans[index]),
    )
  }
  separators
}

///|
fn bracketed_comma_list(
  docs : Array[Document],
  item_spans~ : Array[SourceSpan],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('['),
    char(']'),
    softline,
    docs,
    item_spans~,
    trivia~,
    dangling~,
    force_break~,
  )
}

///|
fn parenthesized_comma_list(
  docs : Array[Document],
  item_spans~ : Array[SourceSpan],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('('),
    char(')'),
    softline,
    docs,
    item_spans~,
    trivia~,
    dangling~,
    force_break~,
  )
}

///|
fn grouped_source_doc(
  child_span : SourceSpan,
  group_span : SourceSpan,
  trivia : SourceFormatTrivia,
  make_child_doc : () -> Document,
) -> Document {
  grouped_source_with_child(child_span, group_span, trivia, make_child_doc, fn(
    document,
  ) {
    document
  }).0
}

///|
fn[T] grouped_source_with_child(
  child_span : SourceSpan,
  group_span : SourceSpan,
  trivia : SourceFormatTrivia,
  make_child : () -> T,
  child_document : (T) -> Document,
) -> (Document, T) {
  let (child_trailing, child_has_trailing) = trivia.take_trailing(child_span)
  let child_value = make_child()
  let child = child_document(child_value) + child_trailing
  let (dangling, force_break) = trivia.take_delimited(
    '(',
    group_span.start_offset,
    group_span.end_offset,
    child_spans=[child_span],
  )
  let body = if force_break { child + hardline + dangling } else { child }
  let document = if child_has_trailing || force_break {
    char('(') + nest(hardline + body) + hardline + char(')')
  } else {
    char('(') + child + char(')')
  }
  (document, child_value)
}

///|
fn parenthesized_comma_list_with_suffix(
  docs : Array[Document],
  suffix : Document,
  item_spans~ : Array[SourceSpan],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  let separators = comma_separators(docs, item_spans, trivia)
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      separate_documents(docs, separators) + hardline + dangling
    }
    char('(') + nest(hardline + body) + hardline + char(')') + suffix
  } else if docs.is_empty() {
    char('(') + char(')') + suffix
  } else {
    group(
      char('(') +
      nest(softline + separate_documents(docs, separators)) +
      softline +
      char(')') +
      suffix,
    )
  }
}

///|
fn braced_comma_list(
  docs : Array[Document],
  item_spans~ : Array[SourceSpan],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('{'),
    char('}'),
    line,
    docs,
    item_spans~,
    trivia~,
    dangling~,
    force_break~,
  )
}

///|
fn breakable_head(keyword_doc : Document, body : Document) -> Document {
  source_prefixed(keyword_doc, body, body)
}

///|
fn source_prefixed(
  prefix : Document,
  body_first_line : Document,
  body : Document,
) -> Document {
  dynamic(fn(context) {
    let inline_first_line = prefix + space + body_first_line
    if inline_first_line.fits_current_line(context) {
      prefix + space + body
    } else {
      prefix + nest(line + body)
    }
  })
}

///|
fn brace_block(
  docs : Array[Document],
  item_spans? : Array[SourceSpan] = [],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      separate_source_items(docs, item_spans, trivia) + hardline + dangling
    }
    char('{') + nest(hardline + body) + hardline + char('}')
  } else if docs.is_empty() {
    surround(char('{'), char('}'), empty)
  } else {
    surround(
      char('{'),
      hardline + char('}'),
      nest(hardline + separate_source_items(docs, item_spans, trivia)),
    )
  }
}

///|
fn separate_source_items(
  docs : Array[Document],
  item_spans : Array[SourceSpan],
  trivia : SourceFormatTrivia,
) -> Document {
  guard !docs.is_empty() else { return empty }
  let first = docs[0]
  let mut result = first
  for index in 1..<docs.length() {
    let separator = if item_spans.length() == docs.length() {
      (trivia.item_separator)(item_spans[index - 1], item_spans[index])
    } else {
      hardline
    }
    result = result + separator + docs[index]
  }
  result
}

///|
fn source_assignment(
  head : Document,
  value_first_line : Document,
  value : Document,
  force_break? : Bool = false,
  separator_boundary? : Document = empty,
  force_separator_break? : Bool = false,
) -> Document {
  let assignment = if force_separator_break {
    head + hardline + separator_boundary + hardline + text("=")
  } else {
    head + space + text("=")
  }
  if force_break {
    return assignment + nest(hardline + value)
  }
  if force_separator_break {
    return assignment + space + value
  }
  dynamic(fn(context) {
    let inline_first_line = assignment + space + value_first_line
    if inline_first_line.fits_current_line(context) {
      assignment + space + value
    } else {
      assignment + nest(line + value)
    }
  })
}

///|
pub(all) struct SourceFormatTrivia {
  leading : (SourceSpan) -> Document
  trailing : (SourceSpan) -> (Document, Bool)
  has_leading : (SourceSpan) -> Bool
  boundary : (Int, Int) -> (Document, Bool)
  token_prefix_separators : (SourceSpan, Int) -> Array[Document]
  delimited : (Char, Int, Int, Array[SourceSpan]) -> (Document, Bool)
  comma_separator : (SourceSpan, SourceSpan) -> Document
  item_separator : (SourceSpan, SourceSpan) -> Document
  top_level_separator : (SourceSpan, SourceSpan) -> Document
  struct_field_separator : (SourceSpan, SourceSpan) -> Document
  eof : () -> Document
}

///|
pub fn SourceFormatTrivia::empty() -> SourceFormatTrivia {
  {
    leading: fn(_span) { empty },
    trailing: fn(_span) { (empty, false) },
    has_leading: fn(_span) { false },
    boundary: fn(_start, _end) { (empty, false) },
    token_prefix_separators: fn(_span, count) { Array::make(count, space) },
    delimited: fn(_open, _start, _end, _children) { (empty, false) },
    comma_separator: fn(_left, _right) { text(",") + line },
    item_separator: fn(_left, _right) { hardline },
    top_level_separator: fn(_left, _right) { hardline + hardline },
    struct_field_separator: fn(_left, _right) { text(",") + line },
    eof: fn() { empty },
  }
}

///|
fn SourceFormatTrivia::take_boundary(
  self : SourceFormatTrivia,
  start_offset : Int,
  end_offset : Int,
) -> (Document, Bool) {
  (self.boundary)(start_offset, end_offset)
}

///|
fn SourceFormatTrivia::join_token_prefix(
  self : SourceFormatTrivia,
  span : SourceSpan,
  parts : Array[Document],
) -> Document {
  guard parts.get(0) is Some(first) else { return empty }
  let separators = (self.token_prefix_separators)(span, parts.length() - 1)
  let mut result = first
  for index in 1..<parts.length() {
    let separator = separators.get(index - 1).unwrap_or(space)
    result = result + separator + parts[index]
  }
  result
}

///|
fn SourceFormatTrivia::take_trailing(
  self : SourceFormatTrivia,
  span : SourceSpan,
) -> (Document, Bool) {
  (self.trailing)(span)
}

///|
fn SourceFormatTrivia::take_delimited(
  self : SourceFormatTrivia,
  open : Char,
  start_offset : Int,
  end_offset : Int,
  child_spans~ : Array[SourceSpan],
) -> (Document, Bool) {
  (self.delimited)(open, start_offset, end_offset, child_spans)
}

///|
fn SourceFormatTrivia::decorate(
  self : SourceFormatTrivia,
  span : SourceSpan,
  doc : Document,
) -> Document {
  let (trailing, _) = self.take_trailing(span)
  (self.leading)(span) + doc + trailing
}

///|
fn SourceFormatTrivia::decorate_leading(
  self : SourceFormatTrivia,
  span : SourceSpan,
  doc : Document,
) -> Document {
  (self.leading)(span) + doc
}

///|
fn SourceFormatTrivia::decorate_trailing(
  self : SourceFormatTrivia,
  span : SourceSpan,
  doc : Document,
) -> Document {
  let (trailing, _) = self.take_trailing(span)
  doc + trailing
}
