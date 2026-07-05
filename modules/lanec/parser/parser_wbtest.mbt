///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() || !result.parse_errors.is_empty() {
    abort(
      "expected parse success, got lexical_errors=\{to_repr(result.lexical_errors)} parse_errors=\{to_repr(result.parse_errors)}",
    )
  }
  guard result.source is Some(file) else { abort("expected source file") }
  file
}

///|
fn parse_errors(source : String) -> Array[ParseError] {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() {
    abort("expected parser errors, got lexer errors")
  }
  result.parse_errors
}

///|
fn parse_error_kinds(source : String) -> Array[ParseErrorKind] {
  parse_errors(source).map(fn(error) { error.kind })
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
      #|    start_offset: 126,
      #|    end_offset: 131,
      #|    start_line: 9,
      #|    start_column: 14,
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
test "parse rejects empty explicit generic expression arguments" {
  assert_false(
    parse_errors(
      (
        #|fn[A] id(value : A) -> A {
        #|  value
        #|}
        #|fn use() -> Int {
        #|  id[](1)
        #|}
      ),
    ).is_empty(),
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
      #|type UI = { Console, Log }
      #|type Task[E : Effect] = { UI, E }
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
      #|type UI = { Console, Log }
      #|
      #|type Task[E : Effect] = { UI, E }
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
      #|  x |> fn (value : Int) {
      #|    value
      #|  }
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
      #|  offer equal_impl : Equal[A]
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
      #|  offer equal_impl : Equal[A]
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
      #|[UnexpectedToken({ label: "`]`" }, [{ label: "identifier" }])]
    ),
  )
  debug_inspect(
    parse_error_kinds("effect Prompt { choose[](Int, Int) -> Int }"),
    content=(
      #|[UnexpectedToken({ label: "`]`" }, [{ label: "identifier" }])]
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
      #|[
      #|  UnexpectedToken(
      #|    { label: "`]`" },
      #|    [
      #|      { label: "identifier" },
      #|      { label: "`type`" },
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|    ],
      #|  ),
      #|]
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
      #|[UnexpectedToken({ label: "`]`" }, [{ label: "identifier" }])]
    ),
  )
}

///|
test "parse existential surface syntax" {
  let file = expect_parse_ok(
    (
      #|struct Hide {
      #|  type T : Type
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
      #|  type T : Type
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
      #|[UnexpectedToken({ label: "`]`" }, [{ label: "identifier" }])]
    ),
  )
}

///|
test "parse rejects multi-layer type alias parameter header" {
  debug_inspect(
    parse_error_kinds("type Result[E][A] = Int"),
    content=(
      #|[UnexpectedToken({ label: "`[`" }, [{ label: "`=`" }])]
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
  let file = expect_parse_ok("enum Option[A] { none() some(A) }")
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
test "parse rejects else-if chain without final else" {
  debug_inspect(
    parse_error_kinds(
      (
        #|fn choose(first : Bool, second : Bool) -> Int {
        #|  if first {
        #|    1
        #|  } else if second {
        #|    2
        #|  }
        #|}
      ),
    ),
    content=(
      #|[UnexpectedToken({ label: "`}`" }, [{ label: "`else`" }])]
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
      #|enum Option[A] { none() some(A) }
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
