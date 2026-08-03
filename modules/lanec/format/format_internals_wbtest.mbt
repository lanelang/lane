///|
test "formatter consumes the complete trivia attachment view" {
  let source =
    #|// leading module
    #|module Test
    #|pub fn add(left : I64, right : I64) -> I64 { left + right }
    #|pub let answer : I64 = add(
    #|  20, // before second
    #|  22 // trailing second
    #|)
    #|// eof comment
  guard @parser.parse_string(source) is Parsed(parsed) else {
    abort("expected parsed source")
  }
  let trivia = ConcreteLayout::make(
    parsed.concrete,
    parsed.layout_separator_gaps,
  ).start_session()
  ignore(
    @prettyprinter.render(
      @syntax.format_source_file_with_trivia(
        parsed.syntax,
        trivia.source_format_trivia(),
      ),
      width=100,
    ),
  )
  debug_inspect(
    trivia.layout.comments.mapi(fn(index, comment) {
      let placement = match comment.placement {
        Leading(span) => ("leading", span.start_offset, span.end_offset)
        Trailing(span) => ("trailing", span.start_offset, span.end_offset)
        Boundary => ("boundary", -1, -1)
        EndOfFile => ("eof", -1, -1)
      }
      (
        comment.text,
        comment.span.start_offset,
        comment.span.end_offset,
        placement,
        comment.blank_before,
        comment.blank_after,
        trivia.claimed[index],
      )
    }),
    content=(
      #|[
      #|  ("// leading module", 0, 17, ("leading", 18, 24), false, false, true),
      #|  (
      #|    "// before second",
      #|    124,
      #|    140,
      #|    ("boundary", -1, -1),
      #|    false,
      #|    false,
      #|    true,
      #|  ),
      #|  (
      #|    "// trailing second",
      #|    146,
      #|    164,
      #|    ("trailing", 143, 145),
      #|    false,
      #|    false,
      #|    true,
      #|  ),
      #|  ("// eof comment", 167, 181, ("eof", -1, -1), false, false, true),
      #|]
    ),
  )
}

///|
test "concrete layout indexes nested delimiter pairs" {
  let concrete = @lexer.tokens_from_string("(([.{ }]))").concrete
  let layout = ConcreteLayout::make(
    concrete,
    Array::make(non_eof_tokens(concrete.tokens).length() + 1, false),
  )
  debug_inspect(
    [
      layout.delimiter_pairs.interior('(', 0, 10),
      layout.delimiter_pairs.interior('(', 1, 9),
      layout.delimiter_pairs.interior('[', 0, 10),
      layout.delimiter_pairs.interior('{', 0, 10),
      layout.delimiter_pairs.interior('[', 3, 10),
      layout.delimiter_pairs.interior('(', 0, 9),
    ],
    content=(
      #|[Some((1, 9)), Some((2, 8)), Some((3, 7)), Some((5, 6)), None, None]
    ),
  )
}

///|
test "formatter reports unconsumed concrete comments" {
  let source =
    #|module Test
    #|// unconsumed
    #|pub let answer : I64 = 42
  guard @parser.parse_string(source) is Parsed(parsed) else {
    abort("expected parsed source")
  }
  let trivia = ConcreteLayout::make(
    parsed.concrete,
    parsed.layout_separator_gaps,
  ).start_session()
  ignore(trivia.source_format_trivia())
  debug_inspect(
    trivia
    .unconsumed_comment_diagnostics()
    .map(fn(diagnostic) {
      (diagnostic.message, diagnostic.code, diagnostic.span)
    }),
    content=(
      #|[
      #|  (
      #|    "formatter could not preserve a source comment",
      #|    Some("E1103"),
      #|    Some(
      #|      Local(
      #|        {
      #|          start_offset: 12,
      #|          end_offset: 25,
      #|          start_line: 2,
      #|          start_column: 1,
      #|          end_line: 2,
      #|          end_column: 14,
      #|        },
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
