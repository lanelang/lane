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
fn comma_hardline_list(docs : Array[Document]) -> Document {
  separate(text(",") + hardline, docs)
}

///|
fn delimited_comma_list(
  open : Document,
  close : Document,
  edge : Document,
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_list(
    open,
    close,
    edge,
    text(",") + line,
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
  separator : Document,
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      separate(separator, docs) + hardline + dangling
    }
    open + nest(hardline + body) + hardline + close
  } else if docs.is_empty() {
    open + close
  } else {
    group(open + nest(edge + separate(separator, docs)) + edge + close)
  }
}

///|
fn bracketed_comma_list(
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('['),
    char(']'),
    softline,
    docs,
    dangling~,
    force_break~,
  )
}

///|
fn parenthesized_comma_list(
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('('),
    char(')'),
    softline,
    docs,
    dangling~,
    force_break~,
  )
}

///|
fn parenthesized_comma_list_with_suffix(
  docs : Array[Document],
  suffix : Document,
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      comma_hardline_list(docs) + hardline + dangling
    }
    char('(') + nest(hardline + body) + hardline + char(')') + suffix
  } else if docs.is_empty() {
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
fn braced_comma_list(
  docs : Array[Document],
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  delimited_comma_list(
    char('{'),
    char('}'),
    line,
    docs,
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
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  if force_break {
    let body = if docs.is_empty() {
      dangling
    } else {
      separate(hardline, docs) + hardline + dangling
    }
    char('{') + nest(hardline + body) + hardline + char('}')
  } else if docs.is_empty() {
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
  trailing : (SourceSpan) -> Document
  has_leading : (SourceSpan) -> Bool
  has_trailing : (SourceSpan) -> Bool
  boundary : (Int, Int) -> Document
  has_boundary : (Int, Int) -> Bool
  delimited : (Char, Int, Int) -> Document
  has_delimited : (Char, Int, Int) -> Bool
  eof : () -> Document
}

///|
pub fn SourceFormatTrivia::empty() -> SourceFormatTrivia {
  {
    leading: fn(_span) { empty },
    trailing: fn(_span) { empty },
    has_leading: fn(_span) { false },
    has_trailing: fn(_span) { false },
    boundary: fn(_start, _end) { empty },
    has_boundary: fn(_start, _end) { false },
    delimited: fn(_open, _start, _end) { empty },
    has_delimited: fn(_open, _start, _end) { false },
    eof: fn() { empty },
  }
}

///|
fn SourceFormatTrivia::take_boundary(
  self : SourceFormatTrivia,
  start_offset : Int,
  end_offset : Int,
) -> (Document, Bool) {
  let force_break = (self.has_boundary)(start_offset, end_offset)
  ((self.boundary)(start_offset, end_offset), force_break)
}

///|
fn SourceFormatTrivia::take_delimited(
  self : SourceFormatTrivia,
  open : Char,
  start_offset : Int,
  end_offset : Int,
) -> (Document, Bool) {
  let force_break = (self.has_delimited)(open, start_offset, end_offset)
  ((self.delimited)(open, start_offset, end_offset), force_break)
}

///|
fn SourceFormatTrivia::decorate(
  self : SourceFormatTrivia,
  span : SourceSpan,
  doc : Document,
) -> Document {
  (self.leading)(span) + doc + (self.trailing)(span)
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
  doc + (self.trailing)(span)
}
