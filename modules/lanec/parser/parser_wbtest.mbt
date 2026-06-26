///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() || !result.parse_errors.is_empty() {
    abort("expected parse success")
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
test "parse nominal declarations and match" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none => fallback
      #|    Option::some(x) => x
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
      #|  none
      #|  some(A)
      #|}
      #|
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none => fallback
      #|    Option::some(x) => x
      #|  }
      #|}
    ),
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
      #|offer int_equal_ops : Equal[Int] = Equal::{
      #|  equal: int_equal
      #|}
      #|
      #|fn use(a : Int, b : Int) -> Bool {
      #|  op_equal(a, b, op=int_equal_ops)
      #|}
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
      #|let h : Hide = Hide::{
      #|  T = Int,
      #|  val: 5
      #|}
      #|
      #|let e : Any = Any::hide[Int](5)
      #|
      #|fn use(h : Hide, e : Any) -> Int {
      #|  match e {
      #|    Any::hide[T](value) => {
      #|      let Hide::{
      #|        _,
      #|        val
      #|      } = h
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
test "parse rejects empty enum variant payload syntax" {
  debug_inspect(
    parse_error_kinds("enum Option[A] { none() some(A) }"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`)`" },
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
test "parse rejects empty qualified variant argument syntax" {
  debug_inspect(
    parse_error_kinds(
      (
        #|enum Option[A] { none some(A) }
        #|let value : Option[Int] = Option::none()
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`)`" },
      #|    [
      #|      { label: "integer literal" },
      #|      { label: "string literal" },
      #|      { label: "identifier" },
      #|      { label: "`false`" },
      #|      { label: "`true`" },
      #|      { label: "`fn`" },
      #|      { label: "`if`" },
      #|      { label: "`match`" },
      #|      { label: "`builtin`" },
      #|      { label: "`-`" },
      #|      { label: "`!`" },
      #|      { label: "`(`" },
      #|      { label: "`{`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}
