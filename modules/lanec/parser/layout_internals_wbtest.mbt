///|
fn expect_layout_parse_ok(source : String) -> @syntax.SourceFile {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort(
      "expected parse success, got lexical_errors=\{Repr(result.lexical_errors())} parse_errors=\{Repr(result.parse_errors())}",
    )
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|
fn synthetic_layout_newline_lines(source : String) -> Array[Int] raise {
  let lexed = @lexer.tokens_from_string(source)
  assert_true(lexed.errors.is_empty())
  let lines = []
  for item in prepare_layout_tokens(lexed.concrete).tokens {
    let (token, start, _) = item
    if token is LAYOUT_NEWLINE(_) {
      lines.push(start.start_line)
    }
  }
  lines
}

///|
fn claimed_layout_separator_lines(source : String) -> Array[Int] {
  guard parse_string(source) is Parsed(parsed) else {
    abort("expected parsed source")
  }
  let lines = []
  for gap, claimed in parsed.layout_separator_gaps {
    if claimed {
      guard gap > 0 else { abort("layout separator must follow a token") }
      lines.push(parsed.concrete.tokens[gap - 1].1.end_line)
    }
  }
  lines
}

///|
test "layout inserts semicolons between newline-delimited items" {
  let source =
    #|module Test
    #|struct Pair {
    #|  fst : I64
    #|  snd : I64
    #|}
    #|enum Choice {
    #|  left()
    #|  right()
    #|}
    #|effect Console {
    #|  read() -> I64
    #|  write(String) -> Unit
    #|}
    #|fn main() -> Unit {
    #|  print("hello")
    #|  print("world")
    #|}
  debug_inspect(
    synthetic_layout_newline_lines(source),
    content="[1, 3, 5, 7, 9, 11, 13, 15]",
  )
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
test "layout preserves delimited and operator continuations" {
  let source =
    #|module Test
    #|fn add(
    #|  left : I64,
    #|  right : I64
    #|) -> I64 {
    #|  left
    #|    + right
    #|}
  debug_inspect(synthetic_layout_newline_lines(source), content="[1]")
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
test "layout separates a tuple initializer from a following unit expression" {
  let source =
    #|module Test
    #|fn some_f() -> Unit {
    #|  let x : (I64, I64) = (1, 2)
    #|  ()
    #|}
  debug_inspect(synthetic_layout_newline_lines(source), content="[1, 3]")
  let file = expect_layout_parse_ok(
    (
      #|fn some_f() -> Unit {
      #|  let x : (I64, I64) = (1, 2)
      #|  ()
      #|}
    ),
  )
  guard file.declarations[0] is Function(function) else {
    abort("expected function declaration")
  }
  assert_true(
    function.body
    is Block(
      items=[
        Let(
          {
            name: "x",
            initializer: TupleLiteral(
              items=[IntegerLiteral("1", ..), IntegerLiteral("2", ..)],
              ..
            ),
            ..
          }
        ),
      ],
      result=UnitLiteral(..),
      ..
    ),
  )
}

///|
test "layout separates delimiter-led expressions" {
  let file = expect_layout_parse_ok(
    (
      #|fn delimiter_starts() -> Unit {
      #|  ()
      #|  []
      #|  { () }
      #|  ()
      #|}
    ),
  )
  guard file.declarations[0] is Function(function) else {
    abort("expected function declaration")
  }
  assert_true(
    function.body
    is Block(
      items=[
        Expression(expression=UnitLiteral(..)),
        Expression(expression=ListLiteral(items=[], ..)),
        Expression(expression=Block(items=[], result=UnitLiteral(..), ..)),
      ],
      result=UnitLiteral(..),
      ..
    ),
  )
}

///|
test "layout grammar claims item boundaries but not brace continuations" {
  let source =
    #|module Test
    #|struct Box
    #|{
    #|  value : I64
    #|}
    #|fn body() -> Unit
    #|{
    #|  ()
    #|  { () }
    #|  ()
    #|}
  debug_inspect(
    synthetic_layout_newline_lines(source),
    content="[1, 2, 5, 6, 8, 9]",
  )
  debug_inspect(claimed_layout_separator_lines(source), content="[1, 5, 8, 9]")
}

///|
test "layout grammar preserves delimiter continuations in incomplete headers" {
  let source =
    #|module Test
    #|struct Box
    #|[A]
    #|{
    #|  value : A
    #|}
    #|enum Option
    #|[A]
    #|{
    #|  some
    #|  (A)
    #|}
    #|fn identity
    #|(value : A) -> A
    #|{
    #|  value
    #|}
  debug_inspect(
    synthetic_layout_newline_lines(source),
    content="[1, 2, 3, 6, 7, 8, 10, 12, 13, 14]",
  )
  debug_inspect(claimed_layout_separator_lines(source), content="[1, 6, 12]")
}

///|
test "layout continues variant patterns and handler operation heads" {
  let file = expect_layout_parse_ok(
    (
      #|enum Option {
      #|  some(I64)
      #|}
      #|fn inspect(value : Option) -> Unit {
      #|  match value {
      #|    some
      #|    (item) => ()
      #|  }
      #|}
      #|fn handled() -> Unit {
      #|  handle () with {
      #|    op
      #|    (resume) => resume(())
      #|  } final value { value }
      #|}
    ),
  )
  guard file.declarations[1] is Function(inspect_function) &&
    inspect_function.body
    is Block(
      result=Match(
        arms=[
          {
            pattern: UnqualifiedVariant(
              variant="some",
              arguments=[Binding("item", ..)],
              ..
            ),
            ..
          },
        ],
        ..
      ),
      ..
    ) else {
    abort("expected continued variant pattern")
  }
  guard file.declarations[2] is Function(handler_function) &&
    handler_function.body is Block(result=Handler(handlers~, ..), ..) else {
    abort("expected continued handler operation head")
  }
  guard handlers is [{ arms, .. }] &&
    arms
    is [
      {
        name: Unqualified(operation="op", ..),
        payload_patterns: [],
        resume_binder: "resume",
        ..
      },
    ] else {
    abort("expected continued handler operation head")
  }
}

///|
test "layout resumes inside braces nested in call arguments" {
  let source =
    #|module Test
    #|fn apply(callback : () -> Unit) -> Unit {
    #|  callback()
    #|}
    #|fn main() -> Unit {
    #|  apply(fn() {
    #|    print("first")
    #|    print("second")
    #|  })
    #|}
  debug_inspect(synthetic_layout_newline_lines(source), content="[1, 4, 7]")
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
test "layout separates wildcard struct pattern fields" {
  let source =
    #|module Test
    #|struct Box[A] {
    #|  value : A
    #|}
    #|fn[A] unbox(box : Box[A]) -> A {
    #|  match box {
    #|    Box::{
    #|      _
    #|      value
    #|    } => value
    #|  }
    #|}
  debug_inspect(synthetic_layout_newline_lines(source), content="[1, 4, 8]")
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
