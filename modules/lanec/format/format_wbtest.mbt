///|
test "format source normalizes whitespace and final newline" {
  let source =
    #|module   Test
    #|pub   let answer   :   Int=42
  let result = format_source(source)
  guard result is Ok(formatted) else { abort("expected formatted source") }
  inspect(
    formatted,
    content=(
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
  inspect(diagnostics.length(), content="1")
  inspect(
    @prettyprinter.render(diagnostics[0]),
    content="2:18-2:19: parse error: unexpected `=`, expected identifier, `type`, `(`, `[`",
  )
}

///|
test "format source preserves leading line comment block" {
  let result = format_source(
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|pub let answer : Int = 42
    ),
  )
  guard result is Ok(formatted) else { abort("expected formatted source") }
  inspect(
    formatted,
    content=(
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
  let result = format_source(source)
  guard result is Ok(formatted) else { abort("expected formatted source") }
  inspect(
    formatted,
    content=(
      #|module Test
      #|
      #|pub struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|pub let origin : Point = Point::{
      #|  x: 0,
      #|  y: 0
      #|}
      #|
      #|pub fn sum(point : Point) -> Int {
      #|  match point {
      #|    Point::{
      #|      x,
      #|      y
      #|    } => x + y
      #|  }
      #|}
      #|
    ),
  )
  guard format_source(formatted) is Ok(_) else {
    abort("expected formatted source to parse")
  }
}

///|
test "format source keeps else-if chains parseable" {
  let source =
    #|module Test
    #|pub fn choose(first : Bool, second : Bool) -> Int {
    #|  if first { 1 } else if second { 2 } else { 3 }
    #|}
  let result = format_source(source)
  guard result is Ok(formatted) else { abort("expected formatted source") }
  inspect(
    formatted,
    content=(
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
  guard format_source(formatted) is Ok(_) else {
    abort("expected formatted source to parse")
  }
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
  let result = format_source(source)
  guard result is Ok(formatted) else { abort("expected formatted source") }
  inspect(
    formatted,
    content=(
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
