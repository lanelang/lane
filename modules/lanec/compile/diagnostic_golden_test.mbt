///|
fn single_check_diagnostic(
  source : String,
) -> @compiler_diag.CompilerDiagnostic {
  let diagnostics = check_source(source).diagnostics()
  guard diagnostics is [diagnostic] else { abort("\{Repr(diagnostics)}") }
  diagnostic
}

///|
fn first_check_diagnostic(source : String) -> @compiler_diag.CompilerDiagnostic {
  let diagnostics = check_source(source).diagnostics()
  guard diagnostics is [diagnostic, ..] else {
    abort("expected at least one diagnostic")
  }
  diagnostic
}

///|
fn single_check_sources_diagnostic(
  root_source : String,
  library_sources : Array[String],
) -> @compiler_diag.CompilerDiagnostic {
  let diagnostics = check(
    test_compilation_request(root_source, library_sources),
  ).diagnostics()
  guard diagnostics is [diagnostic] else { abort("\{Repr(diagnostics)}") }
  diagnostic
}

///|
fn assert_diagnostic_headline(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  code : String,
  message : String,
) -> Unit {
  guard diagnostic.code == Some(code) else {
    abort("unexpected diagnostic: \{Repr(diagnostic)}")
  }
  guard diagnostic.message == message else {
    abort("unexpected diagnostic: \{Repr(diagnostic)}")
  }
}

///|
fn assert_single_help(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  help : String,
) -> Unit {
  guard diagnostic.helps.length() == 1 else {
    abort("expected one diagnostic help")
  }
  guard diagnostic.helps[0] == help else { abort("unexpected diagnostic help") }
}

///|
test "golden unknown builtin diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn bad() -> I64 {
      #|  {
      #|    let _ = builtin("%external_int")
      #|    1
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3026", "unknown builtin `%external_int`",
  )
  assert_single_help(
    diagnostic, "check the intrinsic name or use `extern` for a host symbol",
  )
}

///|
test "golden builtin signature mismatch diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|let bad : (I64) -> I64 = builtin("%i64_add")
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3027", "builtin `%i64_add` has the wrong type",
  )
  assert_single_help(
    diagnostic, "change the annotation or use the builtin with its canonical type",
  )
}

///|
test "golden extern missing expected type diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn bad() -> Bool {
      #|  {
      #|    let host = extern("host")
      #|    true
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3028", "extern `host` needs a complete expected function type",
  )
  assert_single_help(
    diagnostic, "add a complete function type annotation next to this extern",
  )
}

///|
test "golden unsupported extern type diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|let bad : I64 = extern("host")
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3029", "extern `host` has an unsupported type",
  )
  assert_single_help(
    diagnostic, "change the declaration to a supported direct host function signature",
  )
}

///|
test "golden function literal parameter diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn bad() -> I64 {
      #|  {
      #|    let _f = fn (value) {
      #|      value
      #|    }
      #|    1
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "function literal parameter needs a type annotation",
  )
  assert_single_help(diagnostic, "write the parameter as `name : Type`")
}

///|
test "golden empty match missing expected type diagnostic is specific" {
  let diagnostic = first_check_diagnostic(
    (
      #|module Test
      #|fn bad() -> I64 {
      #|  {
      #|    let _ = match true {
      #|    }
      #|    1
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "empty match needs an expected result type",
  )
  assert_single_help(
    diagnostic, "add an expected type with a binding annotation or use the empty match where a result type is already known",
  )
}

///|
test "golden unqualified variant pattern diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn bad(value : I64) -> I64 {
      #|  match value {
      #|    some(_) => 1
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "unqualified variant pattern `some` needs an expected enum type",
  )
  assert_single_help(
    diagnostic, "add a scrutinee type annotation or qualify the variant with its enum owner",
  )
}

///|
test "golden missing generic argument inference diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|enum Marker[A] {
      #|  marker()
      #|}
      #|fn[A] make() -> Marker[A] {
      #|  Marker::marker()
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let _value = make()
      #|    true
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "cannot infer generic arguments for `make`",
  )
  assert_single_help(
    diagnostic, "add explicit generic arguments for `make` or provide an expected result type",
  )
}

///|
test "golden conflicting generic argument inference renders type mismatch" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn[A] choose(left : A, right : A) -> A {
      #|  left
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let _ = choose(1, true)
      #|    true
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3006", "type mismatch")
  assert_single_help(
    diagnostic, "make this argument agree with the type inferred earlier, or pass explicit generic arguments",
  )
}

///|
test "golden ambiguous effect row inference requests explicit arguments" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|effect Mark[A] {
      #|  mark() -> Unit
      #|}
      #|fn[A, B] consume(callback : () -> Unit ! { Mark[A], Mark[B] }) -> Unit {
      #|  ()
      #|}
      #|fn callback() -> Unit ! { Mark[I64], Mark[Bool] } {
      #|  let _first : Unit = Mark[I64]::mark!()
      #|  Mark[Bool]::mark!()
      #|}
      #|fn use() -> Unit {
      #|  consume(callback)
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "cannot infer effect arguments uniquely for `consume`",
  )
  assert_single_help(
    diagnostic, "pass explicit generic arguments for `consume` to choose the intended effect instantiation",
  )
}

///|
test "golden missing contextual offer diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|fn use() -> I64 {
      #|  op_add(1, 2)
      #|}
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3013", "missing contextual offer")
  assert_single_help(
    diagnostic, "pass `op=...` explicitly or add a visible `offer` with type `Add[I64]`",
  )
}

///|
test "missing contextual offers identify their call parameters" {
  let diagnostics = check_source(
    (
      #|module Test
      #|struct DebugCapability {}
      #|struct EqualCapability {}
      #|fn consume(
      #|  value : I64,
      #|  auto debug_impl : DebugCapability,
      #|  auto equal_impl : EqualCapability
      #|) -> I64 {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  consume(1)
      #|}
    ),
  ).diagnostics()
  let observation = diagnostics.map(fn(diagnostic) {
    guard diagnostic.labels is [primary] else {
      abort("expected one primary label: \{Repr(diagnostic)}")
    }
    (primary.message, diagnostic.helps)
  })
  debug_inspect(
    observation,
    content=(
      #|[
      #|  (
      #|    "auto offer parameter `debug_impl` requires `DebugCapability`, but no visible offer matches",
      #|    ["pass `debug_impl=...` explicitly or add a visible `offer` with type `DebugCapability`"],
      #|  ),
      #|  (
      #|    "auto offer parameter `equal_impl` requires `EqualCapability`, but no visible offer matches",
      #|    ["pass `equal_impl=...` explicitly or add a visible `offer` with type `EqualCapability`"],
      #|  ),
      #|]
    ),
  )
}

///|
test "golden ambiguous contextual offer diagnostic is specific" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let add_a : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let add_b : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_sub")(a, b) } }
      #|offer offer_a : Add[I64] = add_a
      #|offer offer_b : Add[I64] = add_b
      #|fn use() -> I64 {
      #|  op_add(1, 2)
      #|}
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3013", "ambiguous contextual offer")
  debug_inspect(
    (diagnostic.labels.map(fn(label) { label.message }), diagnostic.helps),
    content=(
      #|(
      #|  [
      #|    "auto offer parameter `op` requires `Add[I64]`, and 2 visible offers match",
      #|    "candidate `offer_a` has type `Add[I64]`",
      #|    "candidate `offer_b` has type `Add[I64]`",
      #|  ],
      #|  ["pass `op=...` explicitly or keep only one matching visible offer"],
      #|)
    ),
  )
}

///|
test "golden named compiler intrinsic argument uses ordinary call diagnostic" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn use() -> I64 {
      #|  builtin("%i64_add")(1, value=2)
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3012", "named argument `value` is not accepted here",
  )
  assert_single_help(
    diagnostic, "remove the name or call a function with an auto parameter named `value`",
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
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 29,
      #|        end_offset: 30,
      #|        start_line: 2,
      #|        start_column: 18,
      #|        end_line: 2,
      #|        end_column: 19,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E1100"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 29,
      #|          end_offset: 30,
      #|          start_line: 2,
      #|          start_column: 18,
      #|          end_line: 2,
      #|          end_column: 19,
      #|        },
      #|      ),
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
test "golden block sequence help qualifies Unit expressions" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|fn bad(x : I64) -> I64 { x x }
    ),
  )
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "block result expression must be last",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 39,
      #|        end_offset: 40,
      #|        start_line: 2,
      #|        start_column: 28,
      #|        end_line: 2,
      #|        end_column: 29,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E1100"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 39,
      #|          end_offset: 40,
      #|          start_line: 2,
      #|          start_column: 28,
      #|          end_line: 2,
      #|          end_column: 29,
      #|        },
      #|      ),
      #|      message: "this appears after the block's final expression",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane blocks contain local items followed by exactly one final expression"],
      #|  helps: ["separate the expressions with a newline or `;`; either form requires the preceding expression to have type `Unit`; otherwise, bind or otherwise use its value"],
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
      #|pub let answer : I64 = missing
    ),
  )
  assert_diagnostic_headline(diagnostic, "E2001", "cannot find value `missing`")
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "cannot find value `missing`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 35,
      #|        end_offset: 42,
      #|        start_line: 2,
      #|        start_column: 24,
      #|        end_line: 2,
      #|        end_column: 31,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E2001"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 35,
      #|          end_offset: 42,
      #|          start_line: 2,
      #|          start_column: 24,
      #|          end_line: 2,
      #|          end_column: 31,
      #|        },
      #|      ),
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
test "golden missing selective import item diagnostic is specific" {
  let diagnostic = single_check_sources_diagnostic(
    (
      #|module Main
      #|import Lib.{ missing }
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 1
      ),
    ],
  )
  assert_diagnostic_headline(
    diagnostic, "E2009", "cannot import `missing` from `Lib`",
  )
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "cannot import `missing` from `Lib`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 25,
      #|        end_offset: 32,
      #|        start_line: 2,
      #|        start_column: 14,
      #|        end_line: 2,
      #|        end_column: 21,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E2009"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 25,
      #|          end_offset: 32,
      #|          start_line: 2,
      #|          start_column: 14,
      #|          end_line: 2,
      #|          end_column: 21,
      #|        },
      #|      ),
      #|      message: "`Lib` has no exported declaration named `missing`",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["selective imports can name only top-level declarations exported by the imported module"],
      #|  helps: ["check the name spelling or select a declaration exported by `Lib`"],
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
      #|pub let answer : I64 = true
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3006", "type mismatch")
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "type mismatch",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 35,
      #|        end_offset: 39,
      #|        start_line: 2,
      #|        start_column: 24,
      #|        end_line: 2,
      #|        end_column: 28,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3006"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 35,
      #|          end_offset: 39,
      #|          start_line: 2,
      #|          start_column: 24,
      #|          end_line: 2,
      #|          end_column: 28,
      #|        },
      #|      ),
      #|      message: "expected `I64`, found `Bool`",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane does not insert implicit conversions between different types"],
      #|  helps: ["change the expression type or adjust the annotation/expected type"],
      #|  facts: [],
      #|  suggestions: [],
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
      #|  x : I64
      #|  y : I64
      #|}
      #|pub let p : Point = Point::{ x: 1 }
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3101", "missing field `y`")
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "missing field `y`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 73,
      #|        end_offset: 88,
      #|        start_line: 6,
      #|        start_column: 21,
      #|        end_line: 6,
      #|        end_column: 36,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3101"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 73,
      #|          end_offset: 88,
      #|          start_line: 6,
      #|          start_column: 21,
      #|          end_line: 6,
      #|          end_column: 36,
      #|        },
      #|      ),
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
      #|  some(I64)
      #|  none()
      #|}
      #|pub fn value(option : Option) -> I64 {
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
      #|  source_id: Some("<root>"),
      #|  message: "non-exhaustive match",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 90,
      #|        end_offset: 141,
      #|        start_line: 7,
      #|        start_column: 3,
      #|        end_line: 9,
      #|        end_column: 4,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E3200"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 90,
      #|          end_offset: 141,
      #|          start_line: 7,
      #|          start_column: 3,
      #|          end_line: 9,
      #|          end_column: 4,
      #|        },
      #|      ),
      #|      message: "patterns do not cover every `Option` value",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane checks match coverage statically using the pattern matrix"],
      #|  helps: ["add a pattern that covers `none()`, or add a final `_` wildcard arm"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
    ),
  )
}

///|
test "golden missing handler operation diagnostic uses its source name" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Test
      #|effect Console {
      #|  read() -> I64
      #|  choose() -> Unit
      #|}
      #|pub fn program() -> I64 {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(diagnostic, "E3204", "missing handler operation")
  debug_inspect(
    diagnostic.labels.map(fn(label) { label.message }),
    content="[\"this handler does not cover operation `Console::choose`\"]",
  )
}

///|
test "golden imported handler operation diagnostic uses its source name" {
  let diagnostic = single_check_sources_diagnostic(
    (
      #|module Main
      #|import Effects.{ Console }
      #|pub fn program() -> I64 {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
    [
      (
        #|module Effects
        #|pub effect Console {
        #|  read() -> I64
        #|  choose() -> Unit
        #|}
      ),
    ],
  )
  assert_diagnostic_headline(diagnostic, "E3204", "missing handler operation")
  debug_inspect(
    diagnostic.labels.map(fn(label) { label.message }),
    content="[\"this handler does not cover operation `Console::choose`\"]",
  )
}

///|
test "golden handler operation pattern diagnostic uses its source name" {
  let diagnostic = first_check_diagnostic(
    (
      #|module Test
      #|effect Console {
      #|  write(String, I64) -> Unit
      #|}
      #|pub fn program() -> Unit {
      #|  handle Console::write!("message", 1) with {
      #|    Console::write(_, resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3203", "wrong number of fields for pattern `Console::write`",
  )
  debug_inspect(
    diagnostic.labels.map(fn(label) { label.message }),
    content=(
      #|["`Console::write` expects 2 payload field(s), but 1 were provided"]
    ),
  )
}

///|
test "golden module input diagnostic renders span summary and input facts" {
  let diagnostic = single_check_diagnostic(
    (
      #|module Main
      #|import Missing.*
      #|pub let answer : I64 = 1
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
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 19,
      #|        end_offset: 26,
      #|        start_line: 2,
      #|        start_column: 8,
      #|        end_line: 2,
      #|        end_column: 15,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E4002"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 19,
      #|          end_offset: 26,
      #|          start_line: 2,
      #|          start_column: 8,
      #|          end_line: 2,
      #|          end_column: 15,
      #|        },
      #|      ),
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
