///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort(
      "expected parse success, got lexical_errors=\{to_repr(result.lexical_errors())} parse_errors=\{to_repr(result.parse_errors())}",
    )
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|
fn parse_errors(source : String) -> Array[ParseError] {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() {
    abort("expected parser errors, got lexer errors")
  }
  result.parse_errors()
}

///|
fn parse_error_kinds(source : String) -> Array[ParseErrorKind] {
  parse_errors(source).map(fn(error) { error.kind })
}

///|
priv struct ParseFailureConcreteSummary {
  errors : Array[ParseErrorKind]
  trivia : Array[@lexer.TriviaKind]
} derive(Debug)

///|
test "parse grammar failure keeps concrete syntax" {
  let result = parse_string("module Test\nlet x : = // keep")
  guard result is Failed(Grammar(concrete, errors, _)) else {
    abort("expected grammar parse failure")
  }
  debug_inspect(
    ParseFailureConcreteSummary::{
      errors: errors.map(fn(error) { error.kind }),
      trivia: concrete.trivia.map(fn(item) { item.kind }),
    },
    content=(
      #|{
      #|  errors: [
      #|    UnexpectedToken(
      #|      { label: "`=`" },
      #|      [
      #|        { label: "identifier" },
      #|        { label: "`type`" },
      #|        { label: "`(`" },
      #|        { label: "`[`" },
      #|      ],
      #|    ),
      #|  ],
      #|  trivia: [
      #|    Whitespace,
      #|    Newline,
      #|    Whitespace,
      #|    Whitespace,
      #|    Whitespace,
      #|    Whitespace,
      #|    LineComment,
      #|  ],
      #|}
    ),
  )
}

///|
test "parse failures retain expected identifier slots" {
  let type_result = parse_string("module Test\npub let value :")
  guard type_result.parse_errors().get(0) is Some(type_error) else {
    abort("expected missing type parse error")
  }
  assert_eq(type_error.loc.start_offset, type_error.loc.end_offset)
  assert_eq(
    type_result
    .syntactic_identifier_index()
    .role_at(type_error.loc.start_offset),
    Some(TypeIdentifier),
  )
  let effect_result = parse_string("module Test\nfn run() -> Unit !")
  guard effect_result.parse_errors().get(0) is Some(effect_error) else {
    abort("expected missing effect parse error")
  }
  assert_eq(effect_error.loc.start_offset, effect_error.loc.end_offset)
  assert_eq(
    effect_result
    .syntactic_identifier_index()
    .role_at(effect_error.loc.start_offset),
    Some(EffectIdentifier),
  )
  let value_result = parse_string("module Test\npub let value : Int =")
  guard value_result.parse_errors().get(0) is Some(value_error) else {
    abort("expected missing value parse error")
  }
  assert_eq(
    value_result
    .syntactic_identifier_index()
    .role_at(value_error.loc.start_offset),
    None,
  )
}

///|
test "syntactic identifier roles include nested pattern type owners" {
  let source =
    #|module Test
    #|
    #|fn inspect(value : Int) -> Int {
    #|  match value {
    #|    MatchOwner::variant(NestedOwner::{ field }) => 0
    #|  }
    #|}
    #|
    #|fn destructure(value : Int) -> Int {
    #|  let LetOwner::{ field: LetNested::variant() } = value
    #|  0
    #|}
    #|
    #|fn handle_it(value : Int) -> Int {
    #|  handle value with {
    #|    Console::op(HandlerOwner::{ field: HandlerNested::variant() }, resume) => 0
    #|  } final result { result }
    #|}
  let result = parse_string(source)
  guard result is Parsed(_) else { abort("expected parsed source") }
  let index = result.syntactic_identifier_index()
  for
    owner in [
      "MatchOwner", "NestedOwner", "LetOwner", "LetNested", "HandlerOwner", "HandlerNested",
    ] {
    guard source.find(owner) is Some(offset) else {
      abort("expected pattern owner in source")
    }
    assert_eq(index.role_at(offset), Some(TypeIdentifier))
  }
}

///|
fn synthetic_layout_semicolon_lines(source : String) -> Array[Int] raise {
  let lexed = @lexer.tokens_from_string(source)
  assert_true(lexed.errors.is_empty())
  let lines = []
  for item in prepare_layout_tokens(lexed.concrete).tokens {
    let (token, start, _) = item
    if token is LAYOUT_SEMICOLON {
      lines.push(start.start_line)
    }
  }
  lines
}

///|
test "layout inserts semicolons between newline-delimited items" {
  let source =
    #|module Test
    #|struct Pair {
    #|  fst : Int
    #|  snd : Int
    #|}
    #|enum Choice {
    #|  left()
    #|  right()
    #|}
    #|effect Console {
    #|  read() -> Int
    #|  write(String) -> Unit
    #|}
    #|fn main() -> Unit {
    #|  print("hello")
    #|  print("world")
    #|}
  debug_inspect(
    synthetic_layout_semicolon_lines(source),
    content="[1, 3, 5, 7, 9, 11, 13, 15]",
  )
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
test "layout preserves delimited and operator continuations" {
  let source =
    #|module Test
    #|fn add(
    #|  left : Int,
    #|  right : Int
    #|) -> Int {
    #|  left
    #|    + right
    #|}
  debug_inspect(synthetic_layout_semicolon_lines(source), content="[1]")
  debug_inspect(parse_string(source).parse_errors(), content="[]")
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
  debug_inspect(synthetic_layout_semicolon_lines(source), content="[1, 4, 7]")
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
  debug_inspect(synthetic_layout_semicolon_lines(source), content="[1, 4, 8]")
  debug_inspect(parse_string(source).parse_errors(), content="[]")
}

///|
test "parse rejects explicit semicolons outside item bodies" {
  debug_inspect(
    parse_string("module M;\npub let answer : Int = 42").parse_errors(),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "end of file" },
      #|        { label: "`struct`" },
      #|        { label: "`enum`" },
      #|        { label: "`effect`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`type`" },
      #|        { label: "`offer`" },
      #|        { label: "`extern`" },
      #|        { label: "`import`" },
      #|        { label: "`pub`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 8,
      #|      end_offset: 9,
      #|      start_line: 1,
      #|      start_column: 9,
      #|      end_line: 1,
      #|      end_column: 10,
      #|    },
      #|  },
      #|]
    ),
  )
  debug_inspect(
    parse_errors("let first : Int = 1;\nlet second : Int = 2"),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "end of file" },
      #|        { label: "`struct`" },
      #|        { label: "`enum`" },
      #|        { label: "`effect`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`type`" },
      #|        { label: "`offer`" },
      #|        { label: "`extern`" },
      #|        { label: "`pub`" },
      #|        { label: "`+`" },
      #|        { label: "`-`" },
      #|        { label: "`*`" },
      #|        { label: "`/`" },
      #|        { label: "`%`" },
      #|        { label: "`==`" },
      #|        { label: "`!=`" },
      #|        { label: "`<`" },
      #|        { label: "`<=`" },
      #|        { label: "`>`" },
      #|        { label: "`>=`" },
      #|        { label: "`&&`" },
      #|        { label: "`||`" },
      #|        { label: "`|>`" },
      #|        { label: "`(`" },
      #|        { label: "`[`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 31,
      #|      end_offset: 32,
      #|      start_line: 2,
      #|      start_column: 20,
      #|      end_line: 2,
      #|      end_column: 21,
      #|    },
      #|  },
      #|]
    ),
  )
  debug_inspect(
    parse_errors(
      (
        #|struct Box[A, B] {
        #|  first : A
        #|  second : B
        #|}
        #|fn bad(value : Box[Int; Bool]) -> Box[Int, Bool] {
        #|  value
        #|}
      ),
    ),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "`[`" },
      #|        { label: "`]`" },
      #|        { label: "`,`" },
      #|        { label: "`.`" },
      #|        { label: "`->`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 80,
      #|      end_offset: 81,
      #|      start_line: 6,
      #|      start_column: 23,
      #|      end_line: 6,
      #|      end_column: 24,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "parse rejects repeated item separators" {
  debug_inspect(
    parse_errors(
      (
        #|fn mark() -> Unit { () }
        #|fn bad() -> Unit {
        #|  mark();; // keep
        #|  ()
        #|}
      ),
    ),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "integer literal" },
      #|        { label: "double literal" },
      #|        { label: "string literal" },
      #|        { label: "identifier" },
      #|        { label: "`false`" },
      #|        { label: "`true`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`offer`" },
      #|        { label: "`if`" },
      #|        { label: "`match`" },
      #|        { label: "`handle`" },
      #|        { label: "`builtin`" },
      #|        { label: "`extern`" },
      #|        { label: "`-`" },
      #|        { label: "`!`" },
      #|        { label: "`(`" },
      #|        { label: "`{`" },
      #|        { label: "`[`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 65,
      #|      end_offset: 66,
      #|      start_line: 4,
      #|      start_column: 10,
      #|      end_line: 4,
      #|      end_column: 11,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "parse positional call argument keeps argument source span" {
  let file = expect_parse_ok(
    (
      #|struct Box {
      #|  field : Int
      #|}
      #|fn take(input : Int) -> Int {
      #|  input
      #|}
      #|fn answer(value : Box) -> Int {
      #|  take(value.field)
      #|}
    ),
  )
  guard file.declarations[2] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result~, ..) else {
    abort("expected block body")
  }
  guard result is Call(arguments~, ..) else { abort("expected call") }
  guard arguments[0] is Positional(value=Field(name~, loc=field_loc, ..), loc~) else {
    abort("expected positional field argument")
  }
  debug_inspect(
    (name, field_loc, loc),
    content=(
      #|(
      #|  "field",
      #|  {
      #|    start_offset: 120,
      #|    end_offset: 131,
      #|    start_line: 9,
      #|    start_column: 8,
      #|    end_line: 9,
      #|    end_column: 19,
      #|  },
      #|  {
      #|    start_offset: 120,
      #|    end_offset: 131,
      #|    start_line: 9,
      #|    start_column: 8,
      #|    end_line: 9,
      #|    end_column: 19,
      #|  },
      #|)
    ),
  )
}

///|
test "parse declarations and blocks keep complete source spans" {
  let file = expect_parse_ok("pub fn answer() -> Int { 42 }")
  guard file.declarations[0] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result~, loc=body_loc, ..) else {
    abort("expected function block")
  }
  debug_inspect(
    (function.loc, body_loc, result.loc()),
    content=(
      #|(
      #|  {
      #|    start_offset: 12,
      #|    end_offset: 41,
      #|    start_line: 2,
      #|    start_column: 1,
      #|    end_line: 2,
      #|    end_column: 30,
      #|  },
      #|  {
      #|    start_offset: 35,
      #|    end_offset: 41,
      #|    start_line: 2,
      #|    start_column: 24,
      #|    end_line: 2,
      #|    end_column: 30,
      #|  },
      #|  {
      #|    start_offset: 37,
      #|    end_offset: 39,
      #|    start_line: 2,
      #|    start_column: 26,
      #|    end_line: 2,
      #|    end_column: 28,
      #|  },
      #|)
    ),
  )
}

///|
test "parse sequential unit expressions as block local items" {
  let file = expect_parse_ok(
    (
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|fn main() -> Unit {
      #|  print("hello");
      #|  print("world")
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected main function")
  }
  guard function.body
    is Block(items=[Expression(expression=Call(..))], result=Call(..), ..) else {
    abort("expected one sequential expression and one block result")
  }
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
}

///|
test "parse newline-separated unit expressions as block local items" {
  let file = expect_parse_ok(
    (
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected main function")
  }
  assert_true(
    function.body
    is Block(items=[Expression(expression=Call(..))], result=Call(..), ..),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
}

///|
test "parse newline after if expression as a sequence separator" {
  let file = expect_parse_ok(
    (
      #|fn main(condition : Bool) -> Unit {
      #|  if condition {
      #|    ()
      #|  }
      #|  if condition {
      #|    ()
      #|  }
      #|}
    ),
  )
  guard file.declarations[0] is Function(function) else {
    abort("expected main function")
  }
  assert_true(
    function.body
    is Block(items=[Expression(expression=If(..))], result=If(..), ..),
  )
}

///|
test "parse newline-separated struct literal fields" {
  let file = expect_parse_ok(
    (
      #|struct Pair {
      #|  fst : Int
      #|  snd : Int
      #|}
      #|fn make() -> Pair {
      #|  Pair::{ fst: 1
      #|    snd: 2 }
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected make function")
  }
  assert_true(
    function.body
    is Block(result=StructLiteral(fields=[Value(..), Value(..)], ..), ..),
  )
}

///|
test "parse unit literal as a sequential expression" {
  let result = parse_string(
    (
      #|module Test
      #|fn main() -> Unit {
      #|  ();
      #|  ()
      #|}
    ),
  )
  debug_inspect(result.parse_errors(), content="[]")
}

///|
test "parse declarations between sequential expressions" {
  let result = parse_string(
    (
      #|module Test
      #|fn mark() -> Unit {
      #|  ()
      #|}
      #|fn build() -> Int {
      #|  mark();
      #|  let answer : Int = 42
      #|  mark();
      #|  answer
      #|}
    ),
  )
  debug_inspect(result.parse_errors(), content="[]")
}

///|
test "parse nominal declarations and match" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
}

///|
test "parse unqualified enum variant pattern" {
  let file = expect_parse_ok(
    (
      #|enum Single {
      #|  wrap(Int)
      #|}
      #|fn unwrap(value : Single) -> Int {
      #|  match value {
      #|    wrap(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Single {
      #|  wrap(Int)
      #|}
      #|
      #|fn unwrap(value : Single) -> Int {
      #|  match value {
      #|    wrap(x) => x
      #|  }
      #|}
    ),
  )
}

///|
test "parse single-constructor enum pattern let" {
  let file = expect_parse_ok(
    (
      #|enum Single {
      #|  wrap(Int)
      #|}
      #|fn unwrap(value : Single) -> Int {
      #|  {
      #|    let wrap(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Single {
      #|  wrap(Int)
      #|}
      #|
      #|fn unwrap(value : Single) -> Int {
      #|  {
      #|    let wrap(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
}

///|
test "parse does not recognize spaced double colon as qualified variant pattern" {
  debug_inspect(
    parse_error_kinds(
      (
        #|enum Option[A] {
        #|  none()
        #|  some(A)
        #|}
        #|fn unwrap(value : Option[Int], fallback : Int) -> Int {
        #|  match value {
        #|    Option :: none() => fallback
        #|  }
        #|}
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`:`" },
      #|    [
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|      { label: "`::`" },
      #|      { label: "`=>`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse does not recognize right-spaced double colon as variant pattern" {
  debug_inspect(
    parse_error_kinds(
      (
        #|enum Option[A] {
        #|  none()
        #|  some(A)
        #|}
        #|fn unwrap(value : Option[Int], fallback : Int) -> Int {
        #|  match value {
        #|    Option:: none() => fallback
        #|  }
        #|}
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`:`" },
      #|    [
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|      { label: "`::`" },
      #|      { label: "`=>`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects leading double colon enum variant pattern" {
  assert_false(
    parse_errors(
      (
        #|enum Single {
        #|  wrap(Int)
        #|}
        #|fn unwrap(value : Single) -> Int {
        #|  match value {
        #|    ::wrap(x) => x
        #|  }
        #|}
      ),
    ).is_empty(),
  )
}

///|
test "parse type aliases and F-omega type expressions" {
  let file = expect_parse_ok(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|type Id[A] = A
      #|type ApplyInt[F : [Type] -> Type] = F[Int]
      #|fn get(box : ApplyInt[Box]) -> Id[Int] {
      #|  box.value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|type Id[A] = A
      #|
      #|type ApplyInt[F : [Type] -> Type] = F[Int]
      #|
      #|fn get(box : ApplyInt[Box]) -> Id[Int] {
      #|  box.value
      #|}
    ),
  )
}

///|
test "parse explicit generic expression application" {
  let file = expect_parse_ok(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  {
      #|    let id_int : (Int) -> Int = id[Int]
      #|    id[Int](id_int(1))
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|
      #|fn use() -> Int {
      #|  {
      #|    let id_int : (Int) -> Int = id[Int]
      #|    id[Int](id_int(1))
      #|  }
      #|}
    ),
  )
}

///|
test "parse braced effect generic arguments" {
  let file = expect_parse_ok(
    (
      #|effect Log {
      #|  write(Int) -> Unit
      #|}
      #|effect Ops {
      #|  ping[E : Effect]() -> Unit
      #|}
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|struct Box[A, E : Effect] {
      #|  value : A
      #|}
      #|enum Task {
      #|  task[E : Effect]()
      #|}
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|fn pure() -> Unit {
      #|  ()
      #|}
      #|fn use() -> Int ! Ops {
      #|  {
      #|    let ran : Unit = run[{}](pure)
      #|    let box : Box[Int, {}] = Box[Int, {}]::{ value: 1 }
      #|    let task : Task = Task::task[{ Log }]()
      #|    let pinged : Unit = Ops::ping![{}]()
      #|    box.value
      #|  }
      #|}
      #|fn handled() -> Unit {
      #|  handle Coroutine[{}]::yield!() with {
      #|    Coroutine[{}]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Log {
      #|  write(Int) -> Unit
      #|}
      #|
      #|effect Ops {
      #|  ping[E : Effect]() -> Unit
      #|}
      #|
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|
      #|struct Box[A, E : Effect] {
      #|  value : A
      #|}
      #|
      #|enum Task {
      #|  task[E : Effect]()
      #|}
      #|
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|
      #|fn pure() -> Unit {
      #|  ()
      #|}
      #|
      #|fn use() -> Int ! Ops {
      #|  {
      #|    let ran : Unit = run[{}](pure)
      #|    let box : Box[Int, {}] = Box[Int, {}]::{ value: 1 }
      #|    let task : Task = Task::task[{ Log }]()
      #|    let pinged : Unit = Ops::ping![{}]()
      #|    box.value
      #|  }
      #|}
      #|
      #|fn handled() -> Unit {
      #|  handle Coroutine[{}]::yield!() with {
      #|    Coroutine[{}]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects empty explicit generic expression arguments" {
  debug_inspect(
    parse_error_kinds(
      (
        #|fn[A] id(value : A) -> A {
        #|  value
        #|}
        #|fn use() -> Int {
        #|  id[](1)
        #|}
      ),
    ),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
}

///|
test "parse type alias with effect set body" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect Log {
      #|  write(Int) -> Unit
      #|}
      #|type Answer : Type = Int
      #|type Identity : [Type] -> Type = type[A] => A
      #|type UI : Effect = { Console, Log }
      #|type Task[E : Effect] : Effect = { UI, E }
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  read() -> Int
      #|}
      #|
      #|effect Log {
      #|  write(Int) -> Unit
      #|}
      #|
      #|type Answer : Type = Int
      #|
      #|type Identity : [Type] -> Type = type[A] => A
      #|
      #|type UI : Effect = { Console, Log }
      #|
      #|type Task[E : Effect] : Effect = { UI, E }
    ),
  )
}

///|
test "parse rejects unknown kind names in every kind position" {
  let accepted = [
    "type A : Banana = Int",
    "type A[T : Banana] = T",
    (
      #|struct S {
      #|  type A : Banana
      #|}
    ),
    "extern type A : Banana",
    "type A : [Banana] -> Type = Int",
    "type A : [Type] -> Banana = Int",
    "type A : effect = Int",
  ].filter(fn(source) { parse_errors(source).is_empty() })
  debug_inspect(accepted, content="[]")
  debug_inspect(
    parse_error_kinds("type A : Banana = Int"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "identifier `Banana`" },
      #|    [
      #|      { label: "`Type`" },
      #|      { label: "`Effect`" },
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects value block as type alias body" {
  assert_false(parse_errors("type Bad = { let x : Int = 1 x }").is_empty())
}

///|
test "parse function literal and pipeline" {
  let file = expect_parse_ok(
    (
      #|fn pipeline_literal(x : Int) -> Int {
      #|  x |> fn(value : Int) {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn pipeline_literal(x : Int) -> Int {
      #|  x
      #|    |> fn(value : Int) {
      #|      value
      #|    }
      #|}
    ),
  )
}

///|
test "parse else-if chain" {
  let file = expect_parse_ok(
    (
      #|fn choose(first : Bool, second : Bool) -> Int {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn choose(first : Bool, second : Bool) -> Int {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
    ),
  )
}

///|
test "parse offered value definitions and contextual parameter syntax" {
  let file = expect_parse_ok(
    (
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|struct Compare[A] {
      #|  equal_impl : Equal[A]
      #|  less : (A, A) -> Bool
      #|}
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|offer int_equal_ops : Equal[Int] = Equal::{ equal: int_equal }
      #|fn use(a : Int, b : Int) -> Bool {
      #|  op_equal(a, b, op=int_equal_ops)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|
      #|struct Compare[A] {
      #|  equal_impl : Equal[A]
      #|  less : (A, A) -> Bool
      #|}
      #|
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|
      #|offer int_equal_ops : Equal[Int] = Equal::{ equal: int_equal }
      #|
      #|fn use(a : Int, b : Int) -> Bool {
      #|  op_equal(a, b, op=int_equal_ops)
      #|}
    ),
  )
}

///|
test "parse offered function definitions" {
  let file = expect_parse_ok(
    (
      #|pub offer fn[A] provide(value : A) -> A {
      #|  value
      #|}
      #|fn outer() -> Int {
      #|  offer fn local() -> Int {
      #|    42
      #|  }
      #|  local()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|pub offer fn[A] provide(value : A) -> A {
      #|  value
      #|}
      #|
      #|fn outer() -> Int {
      #|  offer fn local() -> Int {
      #|    42
      #|  }
      #|  local()
      #|}
    ),
  )
}

///|
test "parse effect declarations and effect kind" {
  let file = expect_parse_ok(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|struct Runner[F : Effect] {
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|struct Runner[F : Effect] {}
    ),
  )
}

///|
test "parse effect operation calls" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|fn write_hello() -> String ! Console {
      #|  let ignored : Unit = Console::write!("hi")
      #|  Console::choose![String]("left", "right")
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  write(String) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|fn write_hello() -> String ! Console {
      #|  let ignored : Unit = Console::write!("hi")
      #|  Console::choose![String]("left", "right")
      #|}
    ),
  )
}

///|
test "parse qualified postfix forms inside expressions" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  choose[A](A, A) -> A
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some[A](A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|let boxed : Box[Int] = Box[Int]::{
      #|  value: Console::choose![Int](1, 2)
      #|}
      #|fn use(box : Box[Int]) -> Option[Int] ! Console {
      #|  Option::some[Int](Console::choose![Int](box.value, 0))
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some[A](A)
      #|}
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|let boxed : Box[Int] = Box[Int]::{ value: Console::choose![Int](1, 2) }
      #|
      #|fn use(box : Box[Int]) -> Option[Int] ! Console {
      #|  Option::some[Int](Console::choose![Int](box.value, 0))
      #|}
    ),
  )
}

///|
test "parse member forms with generic owner types" {
  let file = expect_parse_ok(
    (
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|effect Log {
      #|  log(String) -> Unit
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn handled() -> Unit {
      #|  handle Coroutine[Log]::yield!() with {
      #|    Coroutine[Log]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|fn use(box : Box[Int]) -> Option[Int] ! Coroutine[Log] {
      #|  let copied : Box[Int] = Box[Int]::{ value: box.value }
      #|  let ignored : Unit = Coroutine[Log]::yield!()
      #|  Option[Int]::some(copied.value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|
      #|effect Log {
      #|  log(String) -> Unit
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|fn handled() -> Unit {
      #|  handle Coroutine[Log]::yield!() with {
      #|    Coroutine[Log]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|
      #|fn use(box : Box[Int]) -> Option[Int] ! Coroutine[Log] {
      #|  let copied : Box[Int] = Box[Int]::{ value: box.value }
      #|  let ignored : Unit = Coroutine[Log]::yield!()
      #|  Option[Int]::some(copied.value)
      #|}
    ),
  )
}

///|
test "parse rejects expression-shaped member owner" {
  debug_inspect(
    parse_error_kinds(
      (
        #|struct Box[A] {
        #|  value : A
        #|}
        #|fn make() -> Box[Int] {
        #|  Box[Int]::{ value: 1 }
        #|}
        #|let bad : Box[Int] = make()::{ value: 2 }
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`::`" },
      #|    [
      #|      { label: "end of file" },
      #|      { label: "`struct`" },
      #|      { label: "`enum`" },
      #|      { label: "`effect`" },
      #|      { label: "`fn`" },
      #|      { label: "`let`" },
      #|      { label: "`type`" },
      #|      { label: "`offer`" },
      #|      { label: "`extern`" },
      #|      { label: "`pub`" },
      #|      { label: "`+`" },
      #|      { label: "`-`" },
      #|      { label: "`*`" },
      #|      { label: "`/`" },
      #|      { label: "`%`" },
      #|      { label: "`==`" },
      #|      { label: "`!=`" },
      #|      { label: "`<`" },
      #|      { label: "`<=`" },
      #|      { label: "`>`" },
      #|      { label: "`>=`" },
      #|      { label: "`&&`" },
      #|      { label: "`||`" },
      #|      { label: "`|>`" },
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse handler expressions" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  read() -> String
      #|  write(String) -> Unit
      #|}
      #|fn program() -> String ! Console {
      #|  handle Console::read!() with {
      #|    Console::write(message, resume) => resume(())
      #|    Console::choose[A](left, right, resume) => resume(left)
      #|    Console::read(resume) => "fallback"
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  read() -> String
      #|  write(String) -> Unit
      #|}
      #|
      #|fn program() -> String ! Console {
      #|  handle Console::read!() with {
      #|    Console::write(message, resume) => resume(())
      #|    Console::choose[A](left, right, resume) => resume(left)
      #|    Console::read(resume) => "fallback"
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse handler operation keeps exact operation token span" {
  let file = expect_parse_ok(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn handled() -> Int {
      #|  handle Prompt::choose![Int](1, 2) with {
      #|    Prompt::choose[A](left, right, resume) => resume(left)
      #|  } final value { value }
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result=Handler(handlers~, ..), ..) else {
    abort("expected handler expression")
  }
  guard handlers[0].arms[0].name
    is Qualified(owner~, operation~, operation_loc~) else {
    abort("expected qualified handler operation")
  }
  debug_inspect(
    (owner.loc(), operation, operation_loc),
    content=(
      #|(
      #|  {
      #|    start_offset: 122,
      #|    end_offset: 128,
      #|    start_line: 7,
      #|    start_column: 5,
      #|    end_line: 7,
      #|    end_column: 11,
      #|  },
      #|  "choose",
      #|  {
      #|    start_offset: 130,
      #|    end_offset: 136,
      #|    start_line: 7,
      #|    start_column: 13,
      #|    end_line: 7,
      #|    end_column: 19,
      #|  },
      #|)
    ),
  )
}

///|
test "parse handler owner type arguments" {
  let file = expect_parse_ok(
    (
      #|effect State[S] {
      #|  get() -> S
      #|}
      #|fn good() -> Int ! State[Int] {
      #|  handle State[Int]::get!() with {
      #|    State[Int]::get(resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect State[S] {
      #|  get() -> S
      #|}
      #|
      #|fn good() -> Int ! State[Int] {
      #|  handle State[Int]::get!() with {
      #|    State[Int]::get(resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects effect arguments as unqualified handler binders" {
  debug_inspect(
    parse_error_kinds(
      (
        #|fn bad() -> Int {
        #|  handle 0 with {
        #|    ask[{}](resume) => resume(0)
        #|  } final value {
        #|    value
        #|  }
        #|}
      ),
    ),
    content=(
      #|[UnexpectedToken({ label: "`{`" }, [{ label: "identifier" }])]
    ),
  )
}

///|
test "parse unqualified handler operation type binders" {
  let file = expect_parse_ok(
    (
      #|fn good() -> Int {
      #|  handle 0 with {
      #|    ask[A](resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn good() -> Int {
      #|  handle 0 with {
      #|    ask[A](resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects malformed handler expressions" {
  let empty_with_errors = parse_error_kinds(
    (
      #|fn bad() -> Unit {
      #|  handle () with {} final value {
      #|    value
      #|  }
      #|}
    ),
  )
  assert_false(empty_with_errors.is_empty())
  let missing_final_errors = parse_error_kinds(
    (
      #|fn bad() -> Unit {
      #|  handle () with {
      #|    op(resume) => ()
      #|  }
      #|}
    ),
  )
  assert_false(missing_final_errors.is_empty())
}

///|
test "parse rejects empty enum and effect operation parameter headers" {
  debug_inspect(
    parse_error_kinds("enum Empty[] { value }"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
  debug_inspect(
    parse_error_kinds("effect Prompt { choose[](Int, Int) -> Int }"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects empty operation witness and handler binder lists" {
  debug_inspect(
    parse_error_kinds(
      (
        #|effect Prompt {
        #|  choose[A](A, A) -> A
        #|}
        #|fn bad() -> Int ! Prompt {
        #|  Prompt::choose![](1, 2)
        #|}
      ),
    ),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
  debug_inspect(
    parse_error_kinds(
      (
        #|effect Prompt {
        #|  choose[A](A, A) -> A
        #|}
        #|fn bad() -> Int {
        #|  handle Prompt::choose![Int](1, 2) with {
        #|    Prompt::choose[](left, right, resume) => resume(left)
        #|  } final value {
        #|    value
        #|  }
        #|}
      ),
    ),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects empty type application arguments" {
  debug_inspect(
    parse_error_kinds("type Bad = Option[]"),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
  debug_inspect(
    parse_error_kinds("type Bad = [](Int) -> Int"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse existential surface syntax" {
  let file = expect_parse_ok(
    (
      #|struct Hide {
      #|  type T
      #|  val : T
      #|}
      #|enum Any {
      #|  hide[T](T)
      #|}
      #|let h : Hide = Hide::{ T = Int, val: 5 }
      #|let e : Any = Any::hide[Int](5)
      #|fn use(h : Hide, e : Any) -> Int {
      #|  match e {
      #|    Any::hide[T](value) => {
      #|      let Hide::{ _, val } = h
      #|      1
      #|    }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Hide {
      #|  type T
      #|  val : T
      #|}
      #|
      #|enum Any {
      #|  hide[T](T)
      #|}
      #|
      #|let h : Hide = Hide::{ T = Int, val: 5 }
      #|
      #|let e : Any = Any::hide[Int](5)
      #|
      #|fn use(h : Hide, e : Any) -> Int {
      #|  match e {
      #|    Any::hide[T](value) => {
      #|      let Hide::{ _, val } = h
      #|      1
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects empty type alias parameter header" {
  debug_inspect(
    parse_error_kinds("type Empty[] = Int"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects multi-layer type alias parameter header" {
  debug_inspect(
    parse_error_kinds("type Result[E][A] = Int"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`[`" },
      #|    [{ label: "`:`" }, { label: "`=`" }],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects equals function body syntax" {
  debug_inspect(
    parse_error_kinds("fn add(a : Int, b : Int) -> Int = a + b"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`=`" },
      #|    [
      #|      { label: "`!`" },
      #|      { label: "`{`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|      { label: "`->`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse accepts empty enum variant payload syntax" {
  let file = expect_parse_ok(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
    ),
  )
}

///|
test "parse rejects payloadless enum variant declaration syntax without parentheses" {
  assert_false(parse_errors("enum Option[A] { none some(A) }").is_empty())
}

///|
test "parse accepts else-if chain without final else" {
  let file = expect_parse_ok(
    (
      #|fn choose(first : Bool, second : Bool) -> Unit {
      #|  if first {
      #|    ()
      #|  } else if second {
      #|    ()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn choose(first : Bool, second : Bool) -> Unit {
      #|  if first {
      #|    ()
      #|  } else if second {
      #|    ()
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects payloadless qualified variant expression syntax without parentheses" {
  assert_false(
    parse_errors(
      (
        #|enum Option[A] { none() some(A) }
        #|let value : Option[Int] = Option::none
      ),
    ).is_empty(),
  )
}

///|
test "parse rejects payloadless qualified variant pattern syntax without parentheses" {
  assert_false(
    parse_errors(
      (
        #|enum Option[A] { none() some(A) }
        #|fn qualified(value : Option[Int]) -> Int {
        #|  match value {
        #|    Option::none => 0
        #|    Option::some(x) => x
        #|  }
        #|}
      ),
    ).is_empty(),
  )
}

///|
test "parse accepts empty qualified variant argument syntax" {
  let file = expect_parse_ok(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|let value : Option[Int] = Option::none()
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|let value : Option[Int] = Option::none()
    ),
  )
}

///|
test "parse external host type and effect declarations" {
  let file = expect_parse_ok(
    (
      #|extern type Fd : Type
      #|pub extern type VectorOp[A : Type] : Effect
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|extern type Fd : Type
      #|
      #|pub extern type VectorOp[A : Type] : Effect
    ),
  )
}

///|
test "parse rejects external declaration bodies" {
  assert_false(parse_errors("extern type Fd : Type = Int").is_empty())
  assert_false(parse_errors("extern type VectorOp : Effect {}").is_empty())
}
