///|
fn assert_format(
  source : String,
  expected : String,
  width? : Int = 100,
) -> Unit raise {
  let options = FormatOptions::{ width, }
  guard format_source_with_options(source, options) is Ok(formatted) else {
    abort("expected formatted source")
  }
  assert_eq(formatted, expected)
  guard format_source_with_options(formatted, options) is Ok(reformatted) else {
    abort("expected formatted source to parse after formatting")
  }
  assert_eq(reformatted, formatted)
}

///|
test "format source normalizes whitespace and final newline" {
  let source =
    #|module   Test
    #|pub   let answer   :   Int=42
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source reports parse diagnostics" {
  let result = format_source("module Test\npub let answer : =")
  guard result is Err(diagnostics) else { abort("expected diagnostics") }
  debug_inspect(
    diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: None,
      #|    message: "unexpected token",
      #|    span: Some(
      #|      Local(
      #|        {
      #|          start_offset: 29,
      #|          end_offset: 30,
      #|          start_line: 2,
      #|          start_column: 18,
      #|          end_line: 2,
      #|          end_column: 19,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E1100"),
      #|    labels: [
      #|      {
      #|        span: Local(
      #|          {
      #|            start_offset: 29,
      #|            end_offset: 30,
      #|            start_line: 2,
      #|            start_column: 18,
      #|            end_line: 2,
      #|            end_column: 19,
      #|          },
      #|        ),
      #|        message: "the parser did not expect `=`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["expected one of: identifier, `type`, `(`, `[`"],
      #|    helps: ["rewrite this position so it starts with one of: identifier, `type`, `(`, `[`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "format source preserves leading line comment block" {
  assert_format(
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|pub let answer : Int = 42
    ),
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source keeps struct literal and pattern fields parseable" {
  let source =
    #|module Test
    #|pub struct Point {
    #|  x : Int
    #|  y : Int
    #|}
    #|pub let origin : Point = Point::{ x: 0, y: 0 }
    #|pub fn sum(point : Point) -> Int {
    #|  match point {
    #|    Point::{ x, y } => x + y
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|pub let origin : Point = Point::{ x: 0, y: 0 }
      #|
      #|pub fn sum(point : Point) -> Int {
      #|  match point {
      #|    Point::{ x, y } => x + y
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source keeps struct literals tighter than binary operators" {
  let source =
    #|module Test
    #|struct Meter {
    #|  value : Int
    #|}
    #|pub let answer : Bool = Meter::{ value: 1 } == Meter::{ value: 1 }
  assert_format(
    source,
    (
      #|module Test
      #|
      #|struct Meter {
      #|  value : Int
      #|}
      #|
      #|pub let answer : Bool = Meter::{ value: 1 } == Meter::{ value: 1 }
      #|
    ),
  )
}

///|
test "format source keeps else-if chains parseable" {
  let source =
    #|module Test
    #|pub fn choose(first : Bool, second : Bool) -> Int {
    #|  if first { 1 } else if second { 2 } else { 3 }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn choose(first : Bool, second : Bool) -> Int {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source keeps selective imports parseable" {
  let source =
    #|module Test
    #|import Lib.{ value, Box }
    #|pub let item : Box = Box::{ value }
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Lib.{value, Box}
      #|
      #|pub let item : Box = Box::{ value }
      #|
    ),
  )
}

///|
test "format source nests broken call arguments in match arms" {
  let source =
    #|module Test
    #|import Ops.*
    #|pub enum Term { var(Int) app(Term, Term) }
    #|pub fn shift_from(cutoff : Int, delta : Int, term : Term) -> Term {
    #|  match term {
    #|    Term::var(index) => Term::var(index)
    #|    Term::app(function, argument) => Term::app(shift_from(cutoff, delta, function), shift_from(cutoff, delta, argument))
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Ops.*
      #|
      #|pub enum Term {
      #|  var(Int)
      #|  app(Term, Term)
      #|}
      #|
      #|pub fn shift_from(cutoff : Int, delta : Int, term : Term) -> Term {
      #|  match term {
      #|    Term::var(index) => Term::var(index)
      #|    Term::app(function, argument) => Term::app(
      #|      shift_from(cutoff, delta, function),
      #|      shift_from(cutoff, delta, argument)
      #|    )
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source breaks list-like syntax at small width" {
  let source =
    #|module Test
    #|import Lib.{ alpha, beta, gamma, delta }
    #|pub struct Pair[First, Second] { first : First second : Second }
    #|pub enum Packed { hide[Hidden](Hidden) }
    #|effect Prompt { choose[Choice](Choice, Choice) -> Choice }
    #|pub fn run(first : Int, second : Int) -> Int ! { Prompt, Log } {
    #|  handle Prompt::choose![Int](first, second) with {
    #|    Prompt::choose[T](left, right, resume) => resume(left)
    #|  } final value {
    #|    match Packed::hide[Int](value) {
    #|      Packed::hide[T](item) => item
    #|    }
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Lib.{
      #|  alpha,
      #|  beta,
      #|  gamma,
      #|  delta
      #|}
      #|
      #|pub struct Pair[
      #|  First,
      #|  Second
      #|] {
      #|  first : First
      #|  second : Second
      #|}
      #|
      #|pub enum Packed {
      #|  hide[Hidden](
      #|    Hidden
      #|  )
      #|}
      #|
      #|effect Prompt {
      #|  choose[Choice](
      #|    Choice,
      #|    Choice
      #|  ) -> Choice
      #|}
      #|
      #|pub fn run(
      #|  first : Int,
      #|  second : Int
      #|) -> Int ! {
      #|  Prompt,
      #|  Log
      #|} {
      #|  handle
      #|    Prompt::choose![
      #|      Int
      #|    ](first, second) with {
      #|    Prompt::choose[
      #|      T
      #|    ](
      #|      left,
      #|      right,
      #|      resume
      #|    ) => resume(
      #|      left
      #|    )
      #|  } final value {
      #|    match
      #|      Packed::hide[
      #|        Int
      #|      ](value) {
      #|      Packed::hide[
      #|        T
      #|      ](item) => item
      #|    }
      #|  }
      #|}
      #|
    ),
    width=20,
  )
}

///|
test "format source breaks declarations and expression chains at small width" {
  let source =
    #|module Test
    #|pub fn compute(input : Input, fallback : Int) -> Int {
    #|  let result : Int = very_long_function_name(input.first.second.third, fallback)
    #|  let chain : Int = input.first.second.third.fourth
    #|  let piped : Int = input |> first_step |> second_step
    #|  if first_condition && second_condition && third_condition { result } else { chain }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn compute(
      #|  input : Input,
      #|  fallback : Int
      #|) -> Int {
      #|  let result : Int =
      #|    very_long_function_name(
      #|      input.first.second.third,
      #|      fallback
      #|    )
      #|  let chain : Int =
      #|    input
      #|      .first
      #|      .second
      #|      .third
      #|      .fourth
      #|  let piped : Int =
      #|    input
      #|      |> first_step
      #|      |> second_step
      #|  if
      #|    first_condition
      #|      && second_condition
      #|      && third_condition {
      #|    result
      #|  } else {
      #|    chain
      #|  }
      #|}
      #|
    ),
    width=30,
  )
}

///|
test "format source keeps short block-like assignment attached" {
  let source =
    #|module Test
    #|pub enum Maybe {
    #|  some(Int)
    #|  none()
    #|}
    #|pub fn bad(flag : Bool, item : Maybe) -> Int {
    #|  let id = fn (value) {
    #|    value
    #|  }
    #|  let choice = if flag {
    #|    1
    #|  } else {
    #|    0
    #|  }
    #|  let picked = match item {
    #|    Maybe::some(value) => value
    #|    Maybe::none() => 0
    #|  }
    #|  let called = apply(fn (value) {
    #|    value
    #|  }, choice)
    #|  id(called + picked)
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub enum Maybe {
      #|  some(Int)
      #|  none()
      #|}
      #|
      #|pub fn bad(flag : Bool, item : Maybe) -> Int {
      #|  let id = fn (value) {
      #|    value
      #|  }
      #|  let choice = if flag {
      #|    1
      #|  } else {
      #|    0
      #|  }
      #|  let picked = match item {
      #|    Maybe::some(value) => value
      #|    Maybe::none() => 0
      #|  }
      #|  let called = apply(
      #|    fn (value) {
      #|      value
      #|    },
      #|    choice
      #|  )
      #|  id(called + picked)
      #|}
      #|
    ),
    width=80,
  )
}
