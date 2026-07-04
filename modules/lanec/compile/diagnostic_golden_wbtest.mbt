///|
fn single_check_diagnostic(source : String) -> CompilerDiagnostic {
  let result = check_source(source)
  guard result.diagnostics.length() == 1 else {
    abort("expected exactly one diagnostic")
  }
  result.diagnostics[0]
}

///|
fn assert_diagnostic_headline(
  diagnostic : CompilerDiagnostic,
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "unexpected token",
      #|  span: Some(
      #|    {
      #|      start_offset: 29,
      #|      end_offset: 30,
      #|      start_line: 2,
      #|      start_column: 18,
      #|      end_line: 2,
      #|      end_column: 19,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E1100"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 29,
      #|        end_offset: 30,
      #|        start_line: 2,
      #|        start_column: 18,
      #|        end_line: 2,
      #|        end_column: 19,
      #|      },
      #|      message: "the parser did not expect `=`",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["expected one of: identifier, `type`, `(`, `[`"],
      #|  helps: ["rewrite this position so it starts with one of: identifier, `type`, `(`, `[`"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: None,
      #|  message: "cannot find value `missing`",
      #|  span: Some(
      #|    {
      #|      start_offset: 35,
      #|      end_offset: 42,
      #|      start_line: 2,
      #|      start_column: 24,
      #|      end_line: 2,
      #|      end_column: 31,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E2001"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 35,
      #|        end_offset: 42,
      #|        start_line: 2,
      #|        start_column: 24,
      #|        end_line: 2,
      #|        end_column: 31,
      #|      },
      #|      message: "no value named `missing` is visible here",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane value lookup uses local bindings, top-level values, and explicitly imported public values"],
      #|  helps: ["define `missing` before this use, import it, or qualify it with its module path"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: None,
      #|  message: "type mismatch",
      #|  span: Some(
      #|    {
      #|      start_offset: 35,
      #|      end_offset: 39,
      #|      start_line: 2,
      #|      start_column: 24,
      #|      end_line: 2,
      #|      end_column: 28,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3006"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 35,
      #|        end_offset: 39,
      #|        start_line: 2,
      #|        start_column: 24,
      #|        end_line: 2,
      #|        end_column: 28,
      #|      },
      #|      message: "expected `Int`, found `Bool`",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane does not insert implicit conversions between different types"],
      #|  helps: ["change the expression type or adjust the annotation/expected type"],
      #|  facts: [
      #|    {
      #|      name: "expected type",
      #|      value: "`Int`",
      #|      span: Some(
      #|        {
      #|          start_offset: 35,
      #|          end_offset: 39,
      #|          start_line: 2,
      #|          start_column: 24,
      #|          end_line: 2,
      #|          end_column: 28,
      #|        },
      #|      ),
      #|    },
      #|    {
      #|      name: "actual type",
      #|      value: "`Bool`",
      #|      span: Some(
      #|        {
      #|          start_offset: 35,
      #|          end_offset: 39,
      #|          start_line: 2,
      #|          start_column: 24,
      #|          end_line: 2,
      #|          end_column: 28,
      #|        },
      #|      ),
      #|    },
      #|  ],
      #|  suggestions: [
      #|    {
      #|      message: "change the expression type or adjust the annotation/expected type",
      #|      edits: [],
      #|      applicability: Unspecified,
      #|    },
      #|  ],
      #|}
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: None,
      #|  message: "missing field `y`",
      #|  span: Some(
      #|    {
      #|      start_offset: 82,
      #|      end_offset: 88,
      #|      start_line: 6,
      #|      start_column: 30,
      #|      end_line: 6,
      #|      end_column: 36,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3101"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 82,
      #|        end_offset: 88,
      #|        start_line: 6,
      #|        start_column: 30,
      #|        end_line: 6,
      #|        end_column: 36,
      #|      },
      #|      message: "this struct construction or pattern omits required field `y`",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane struct literals and struct patterns must account for required fields"],
      #|  helps: ["add a `y: ...` field entry"],
      #|  facts: [],
      #|  suggestions: [
      #|    {
      #|      message: "add a `y: ...` field entry",
      #|      edits: [],
      #|      applicability: HasPlaceholders,
      #|    },
      #|  ],
      #|}
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: None,
      #|  message: "non-exhaustive match",
      #|  span: Some(
      #|    {
      #|      start_offset: 103,
      #|      end_offset: 141,
      #|      start_line: 7,
      #|      start_column: 16,
      #|      end_line: 9,
      #|      end_column: 4,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3200"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 103,
      #|        end_offset: 141,
      #|        start_line: 7,
      #|        start_column: 16,
      #|        end_line: 9,
      #|        end_column: 4,
      #|      },
      #|      message: "patterns do not cover every `Option` value",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane checks match coverage statically using the pattern matrix"],
      #|  helps: ["add a missing constructor case or a final `_` wildcard arm"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
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
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "missing imported module `Missing`",
      #|  span: Some(
      #|    {
      #|      start_offset: 19,
      #|      end_offset: 26,
      #|      start_line: 2,
      #|      start_column: 8,
      #|      end_line: 2,
      #|      end_column: 15,
      #|    },
      #|  ),
      #|  severity: Error,
      #|  code: Some("E4002"),
      #|  labels: [
      #|    {
      #|      span: {
      #|        start_offset: 19,
      #|        end_offset: 26,
      #|        start_line: 2,
      #|        start_column: 8,
      #|        end_line: 2,
      #|        end_column: 15,
      #|      },
      #|      message: "no explicit input provides this module",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane only compiles explicitly provided source files and interface artifacts"],
      #|  helps: ["pass an input whose declared module is `Missing`, or change the import to one of the listed modules"],
      #|  facts: [{ name: "considered source module", value: "`Main`", span: None }],
      #|  suggestions: [
      #|    {
      #|      message: "check the imported module name against the listed explicit inputs",
      #|      edits: [],
      #|      applicability: MaybeIncorrect,
      #|    },
      #|  ],
      #|}
    ),
  )
}
