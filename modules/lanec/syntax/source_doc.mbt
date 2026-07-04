///|
fn keyword(value : String) -> Document {
  text(value)
}

///|
fn source_string(value : String) -> Document {
  text(value.escape())
}

///|
fn join_comma(docs : Array[Document]) -> Document {
  separate(text(",") + space, docs)
}

///|
fn comma_line_list(docs : Array[Document]) -> Document {
  separate(text(",") + line, docs)
}

///|
fn comma_hardline_list(docs : Array[Document]) -> Document {
  separate(text(",") + hardline, docs)
}

///|
fn delimited_comma_list(
  open : Document,
  close : Document,
  edge : Document,
  docs : Array[Document],
) -> Document {
  if docs.is_empty() {
    open + close
  } else {
    group(open + nest(edge + comma_line_list(docs)) + edge + close)
  }
}

///|
fn bracketed_comma_list(docs : Array[Document]) -> Document {
  delimited_comma_list(char('['), char(']'), softline, docs)
}

///|
fn parenthesized_comma_list(docs : Array[Document]) -> Document {
  delimited_comma_list(char('('), char(')'), softline, docs)
}

///|
fn parenthesized_comma_list_with_suffix(
  docs : Array[Document],
  suffix : Document,
) -> Document {
  if docs.is_empty() {
    char('(') + char(')') + suffix
  } else {
    group(
      switch(
        char('(') + join_comma(docs) + char(')') + suffix,
        char('(') +
        nest(hardline + comma_hardline_list(docs)) +
        hardline +
        char(')') +
        suffix,
      ),
    )
  }
}

///|
fn braced_comma_list(docs : Array[Document]) -> Document {
  delimited_comma_list(char('{'), char('}'), line, docs)
}

///|
fn braced_comma_list_compact(docs : Array[Document]) -> Document {
  delimited_comma_list(char('{'), char('}'), softline, docs)
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
    if inline_first_line.requirement() <= context.current_remain() {
      prefix + space + body
    } else {
      prefix + nest(line + body)
    }
  })
}

///|
fn brace_block(docs : Array[Document]) -> Document {
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
fn source_assignment(
  head : Document,
  value_first_line : Document,
  value : Document,
) -> Document {
  dynamic(fn(context) {
    let inline_first_line = head + space + text("=") + space + value_first_line
    if inline_first_line.requirement() <= context.current_remain() {
      head + space + text("=") + space + value
    } else {
      head + space + text("=") + nest(line + value)
    }
  })
}
