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
test "format source preserves comments around declarations and blocks" {
  assert_format(
    (
      #|module Test
      #|
      #|// before declaration
      #|pub let answer : Int = 42 // trailing declaration
      #|
      #|pub fn main() -> Unit {
      #|  // inside block
      #|  ()
      #|}
    ),
    (
      #|module Test
      #|
      #|// before declaration
      #|pub let answer : Int = 42 // trailing declaration
      #|
      #|pub fn main() -> Unit {
      #|  // inside block
      #|  ()
      #|}
      #|
    ),
  )
}

///|
test "format source does not treat comment markers inside strings as comments" {
  assert_format(
    (
      #|module Test
      #|pub let url : String = "http://example"
    ),
    (
      #|module Test
      #|
      #|pub let url : String = "http://example"
      #|
    ),
  )
}

///|
test "format source preserves comments in top-level and type bodies" {
  assert_format(
    (
      #|module Test
      #|
      #|// before import
      #|import Basic.Ops.* // trailing import
      #|
      #|// before effect
      #|effect Console {
      #|  // before operation
      #|  read() -> Int // trailing operation
      #|}
      #|
      #|/* before struct */
      #|struct Pair {
      #|  // before field
      #|  left : Int
      #|  right : Int // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option {
      #|  // before variant
      #|  none()
      #|  some(Int) // trailing variant
      #|}
    ),
    (
      #|module Test
      #|
      #|// before import
      #|import Basic.Ops.* // trailing import
      #|
      #|// before effect
      #|effect Console {
      #|  // before operation
      #|  read() -> Int // trailing operation
      #|}
      #|
      #|/* before struct */
      #|struct Pair {
      #|  // before field
      #|  left : Int
      #|  right : Int // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option {
      #|  // before variant
      #|  none()
      #|  some(Int) // trailing variant
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments in control flow" {
  assert_format(
    (
      #|module Test
      #|
      #|pub fn choose(input : Int) -> Int {
      #|  // before let
      #|  let base : Int = input + 1 // trailing let
      #|  // before if
      #|  if base == 0 {
      #|    // then branch
      #|    1
      #|  } else {
      #|    // else branch
      #|    base
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn choose(input : Int) -> Int {
      #|  // before let
      #|  let base : Int = input + 1 // trailing let
      #|  // before if
      #|  if base == 0 {
      #|    // then branch
      #|    1
      #|  } else {
      #|    // else branch
      #|    base
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments in match and handler arms" {
  assert_format(
    (
      #|module Test
      #|
      #|effect Console {
      #|  read() -> Int
      #|}
      #|
      #|enum Option {
      #|  none()
      #|  some(Int)
      #|}
      #|
      #|pub fn read_or_default(value : Option) -> Int {
      #|  match value {
      #|    // none arm
      #|    none() => 0 // trailing none arm
      #|    // some arm
      #|    some(x) => x
      #|  }
      #|}
      #|
      #|pub let handled : Int = {
      #|  handle {
      #|    // before perform
      #|    Console::read!()
      #|  } with {
      #|    // before handler arm
      #|    Console::read(resume) => resume(1) // trailing handler arm
      #|  } final value {
      #|    // final branch
      #|    value
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|effect Console {
      #|  read() -> Int
      #|}
      #|
      #|enum Option {
      #|  none()
      #|  some(Int)
      #|}
      #|
      #|pub fn read_or_default(value : Option) -> Int {
      #|  match value {
      #|    // none arm
      #|    none() => 0 // trailing none arm
      #|    // some arm
      #|    some(x) => x
      #|  }
      #|}
      #|
      #|pub let handled : Int = {
      #|  handle {
      #|    // before perform
      #|    Console::read!()
      #|  } with {
      #|    // before handler arm
      #|    Console::read(resume) => resume(1) // trailing handler arm
      #|  } final value {
      #|    // final branch
      #|    value
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments around literals and end of file" {
  assert_format(
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub let pair : Pair = Pair::{
      #|  // left value
      #|  left: 1,
      #|  // right value
      #|  right: 2
      #|}
      #|
      #|// eof marker
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub let pair : Pair = Pair::{
      #|  // left value
      #|  left: 1,
      #|  // right value
      #|  right: 2
      #|}
      #|
      #|// eof marker
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
