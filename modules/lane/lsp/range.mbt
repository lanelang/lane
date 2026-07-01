///|
fn range_json(span : @basic.SourceSpan) -> Json {
  {
    "start": position_json(span.start_line, span.start_column),
    "end": position_json(span.end_line, span.end_column),
  }
}

///|
fn position_json(line : Int, column : Int) -> Json {
  {
    "line": if line > 0 {
      line - 1
    } else {
      0
    },
    "character": if column > 0 {
      column - 1
    } else {
      0
    },
  }
}
