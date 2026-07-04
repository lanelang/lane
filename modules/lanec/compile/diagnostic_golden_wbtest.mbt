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
fn inference_diagnostic_help(
  label : String,
  reason : @typecheck.CannotInferReason,
) -> String {
  let diagnostic = typecheck_diagnostic(
    {
      kind: CannotInferExpression(label~, reason~),
      loc: @basic.SourceSpan::dummy(),
    },
    TypeDisplayContext::from_registry(SymbolRegistry()),
  )
  guard diagnostic.helps.length() == 1 else {
    abort("expected one diagnostic help")
  }
  diagnostic.helps[0]
}

///|
test "golden inference diagnostic help uses structured reason" {
  assert_eq(
    inference_diagnostic_help("renamed contextual hint", ContextualOffer),
    "add a visible `offer` with the required type or pass the contextual argument explicitly",
  )
  assert_eq(
    inference_diagnostic_help("lambda binder", FunctionLiteralParameter),
    "add an explicit parameter type annotation to the function literal",
  )
  assert_eq(
    inference_diagnostic_help("argument count", CallArity),
    "check the number of arguments and type arguments at this call site",
  )
  assert_eq(
    inference_diagnostic_help("generic arguments", TypeArguments),
    "add explicit type arguments or provide an expected result type",
  )
  assert_eq(
    inference_diagnostic_help("intrinsic", Builtin),
    "add a type annotation so the builtin can be checked against a concrete function type",
  )
}

///|
test "golden syntax diagnostic renders span summary and guidance" {
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
      #|  span: 2:18-2:19
      #|  primary: 2:18-2:19: the parser did not expect `=`
      #|  note: expected one of: identifier, `type`, `(`, `[`
      #|  help: rewrite this position so it starts with one of: identifier, `type`, `(`, `[`
    ),
  )
}

///|
test "golden resolver diagnostic renders span summary and guidance" {
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
      #|  span: 2:24-2:31
      #|  primary: 2:24-2:31: no value named `missing` is visible here
      #|  note: Lane value lookup uses local bindings, top-level values, and explicitly imported public values
      #|  help: define `missing` before this use, import it, or qualify it with its module path
    ),
  )
}

///|
test "golden type diagnostic renders span summary and facts" {
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
      #|  span: 2:24-2:28
      #|  primary: 2:24-2:28: expected `Int`, found `Bool`
      #|  note: Lane does not insert implicit conversions between different types
      #|  expected type: `Int` at 2:24-2:28
      #|  actual type: `Bool` at 2:24-2:28
      #|  help: change the expression type or adjust the annotation/expected type
      #|  suggestion: change the expression type or adjust the annotation/expected type (unspecified)
    ),
  )
}

///|
test "golden struct diagnostic renders span summary and suggestion" {
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
      #|  span: 6:30-6:36
      #|  primary: 6:30-6:36: this struct construction or pattern omits required field `y`
      #|  note: Lane struct literals and struct patterns must account for required fields
      #|  help: add a `y: ...` field entry
      #|  suggestion: add a `y: ...` field entry (has-placeholders)
    ),
  )
}

///|
test "golden pattern diagnostic renders span summary and guidance" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|enum Option {
      #|  some(Int)
      #|  none()
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
      #|  span: 7:16-9:4
      #|  primary: 7:16-9:4: patterns do not cover every `Option` value
      #|  note: Lane checks match coverage statically using the pattern matrix
      #|  help: add a missing constructor case or a final `_` wildcard arm
    ),
  )
}

///|
test "golden module input diagnostic renders span summary and input facts" {
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
      #|  span: 2:8-2:15
      #|  primary: 2:8-2:15: no explicit input provides this module
      #|  note: Lane only compiles explicitly provided source files and interface artifacts
      #|  considered source module: `Main`
      #|  help: pass an input whose declared module is `Missing`, or change the import to one of the listed modules
      #|  suggestion: check the imported module name against the listed explicit inputs (maybe-incorrect)
    ),
  )
}
