///|
test "source database maps offsets to lines and columns" {
  let sources = SourceDatabase::SourceDatabase()
  let source = sources.add("one\ntwo\nthree", path="sample.lane")
  let range = sources.range(sources.span(source, 4, 7)).unwrap()
  debug_inspect(range.start, content="{ line: 2, column: 1 }")
  debug_inspect(range.end, content="{ line: 2, column: 4 }")
  debug_inspect(sources.line_text(source, 3), content="Some(\"three\")")
}

///|
test "source database supports virtual source names" {
  let sources = SourceDatabase::SourceDatabase()
  let source = sources.add("let x = 1")
  let file = sources.file(source).unwrap()
  inspect(file.display_name(), content="<source#0>")
}

///|
test "source database maps unicode columns by character" {
  let sources = SourceDatabase::SourceDatabase()
  let source = sources.add("中x\nvalue", path="unicode.lane")
  let range = sources.range(sources.span(source, 3, 4)).unwrap()
  debug_inspect(range.start, content="{ line: 1, column: 2 }")
  debug_inspect(range.end, content="{ line: 1, column: 3 }")
}

///|
test "source database converts text offsets to byte offsets" {
  let sources = SourceDatabase::SourceDatabase()
  let source = sources.add("中x\nvalue", path="unicode.lane")
  let range = sources
    .range(sources.span_from_text_offsets(source, 1, 2))
    .unwrap()
  debug_inspect(range.start, content="{ line: 1, column: 2 }")
  debug_inspect(range.end, content="{ line: 1, column: 3 }")
}
