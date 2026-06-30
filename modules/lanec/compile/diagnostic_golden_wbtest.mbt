///|
fn single_check_diagnostic(source : String) -> CompileDiagnostic {
  let result = check_source(source)
  guard result.diagnostics.length() == 1 else {
    abort("expected exactly one diagnostic")
  }
  result.diagnostics[0]
}

///|
fn assert_diagnostic_headline(
  diagnostic : CompileDiagnostic,
  code : String,
  message : String,
) -> Unit {
  guard diagnostic.code == Some(code) else {
    abort("unexpected diagnostic code")
  }
  guard diagnostic.message == message else {
    abort("unexpected diagnostic message")
  }
}

///|
test "golden syntax diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|pub let answer : =
    ),
  )
  assert_diagnostic_headline(diagnostic, "E1100", "unexpected token")
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E1100]: unexpected token
      #|  --> 2:18-2:19
      #|  = label: 2:18-2:19 the parser did not expect `=`
      #|  = note: expected one of: identifier, `type`, `(`, `[`
      #|  = help: rewrite this position so it starts with one of: identifier, `type`, `(`, `[`
    ),
  )
}

///|
test "golden resolver diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|pub let answer : Int = missing
    ),
  )
  assert_diagnostic_headline(diagnostic, "E2001", "cannot find value `missing`")
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E2001]: cannot find value `missing`
      #|  --> 2:24-2:31
      #|  = label: 2:24-2:31 no value named `missing` is visible here
      #|  = note: Lane value lookup uses local bindings, top-level values, and explicitly imported public values
      #|  = help: define `missing` before this use, import it, or qualify it with its module path
    ),
  )
}

///|
test "golden type diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|pub let answer : Int = true
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3006", "type mismatch")
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E3006]: type mismatch
      #|  --> 2:24-2:28
      #|  = label: 2:24-2:28 expected `Int`, found `Bool`
      #|  = note: Lane does not insert implicit conversions between different types
      #|  = help: change the expression type or adjust the annotation/expected type
    ),
  )
}

///|
test "golden struct diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|pub struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|pub let p : Point = Point::{ x: 1 }
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3101", "missing field `y`")
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E3101]: missing field `y`
      #|  --> 6:30-6:36
      #|  = label: 6:30-6:36 this struct construction or pattern omits required field `y`
      #|  = note: Lane struct literals and struct patterns must account for required fields
      #|  = help: add a `y: ...` field entry
    ),
  )
}

///|
test "golden pattern diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|enum Option {
      #|  some(Int)
      #|  none
      #|}
      #|pub fn value(option : Option) -> Int {
      #|  match option {
      #|    Option::some(value) => value
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3200", "non-exhaustive match")
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E3200]: non-exhaustive match
      #|  --> 7:16-9:4
      #|  = label: 7:16-9:4 patterns do not cover every `type#0` value
      #|  = note: Lane checks match coverage statically using the pattern matrix
      #|  = help: add a missing constructor case or a final `_` wildcard arm
    ),
  )
}

///|
test "golden module input diagnostic includes code headline label note and help" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Main
      #|import Missing.*
      #|pub let answer : Int = 1
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E4002", "missing imported module `Missing`",
  )
  inspect(
    @prettyprinter.render(diagnostic),
    content=(
      #|error[E4002]: missing imported module `Missing`
      #|  --> 2:15-2:17
      #|  = label: 2:15-2:17 this import has no matching module input or interface artifact
      #|  = note: Lane does not search the file system by module name during compilation
      #|  = help: pass the imported module as a library source or compiled interface
    ),
  )
}
