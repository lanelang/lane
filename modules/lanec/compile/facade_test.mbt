///|
test "check facade returns success with warnings" {
  let outcome = check_source(
    (
      #|module Main
      #|pub fn answer() -> I64 {
      #|  let unused = 1
      #|  0
      #|}
    ),
  )
  guard outcome is Succeeded(_, warnings) else {
    abort("expected checking to succeed")
  }
  debug_inspect(
    warnings.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 43,
      #|          end_offset: 49,
      #|          start_line: 3,
      #|          start_column: 7,
      #|          end_line: 3,
      #|          end_column: 13,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 43,
      #|            end_offset: 49,
      #|            start_line: 3,
      #|            start_column: 7,
      #|            end_line: 3,
      #|            end_column: 13,
      #|          },
      #|        ),
      #|        message: "`unused` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "check facade returns parse failure" {
  let outcome = check_source(
    (
      #|module Main
      #|pub let answer : =
    ),
  )
  guard outcome is Failed(failure) else { abort("expected parsing to fail") }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unexpected token",
      #|    span: Some(
      #|      Source(
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
      #|    ),
      #|    severity: Error,
      #|    code: Some("E1100"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
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
test "check facade returns resolution failure" {
  let outcome = check_source(
    (
      #|module Main
      #|pub let answer : I64 = missing
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected name resolution to fail")
  }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "cannot find value `missing`",
      #|    span: Some(
      #|      Source(
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
      #|    ),
      #|    severity: Error,
      #|    code: Some("E2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 35,
      #|            end_offset: 42,
      #|            start_line: 2,
      #|            start_column: 24,
      #|            end_line: 2,
      #|            end_column: 31,
      #|          },
      #|        ),
      #|        message: "no value named `missing` is visible here",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["Lane value lookup uses local bindings, top-level values, and explicitly imported public values"],
      #|    helps: ["define `missing` before this use, import it, or qualify it with its module path"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "check facade returns type failure" {
  let outcome = check_source(
    (
      #|module Main
      #|pub let answer : I64 = true
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected type checking to fail")
  }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "type mismatch",
      #|    span: Some(
      #|      Source(
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
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3006"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 35,
      #|            end_offset: 39,
      #|            start_line: 2,
      #|            start_column: 24,
      #|            end_line: 2,
      #|            end_column: 28,
      #|          },
      #|        ),
      #|        message: "expected `I64`, found `Bool`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["Lane does not insert implicit conversions between different types"],
      #|    helps: ["change the expression type or adjust the annotation/expected type"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "diagnostic access is isolated from nested mutation" {
  let outcome = check_source(
    (
      #|module Main
      #|pub struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|pub let point : Point = Point::{ x: 1 }
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected type checking to fail")
  }
  guard failure.diagnostics() is [first] &&
    first.labels is [label] &&
    first.suggestions is [suggestion] else {
    abort("expected one structured diagnostic")
  }
  first.labels.push(label)
  first.notes.push("mutated note")
  first.helps.push("mutated help")
  first.facts.push({ name: "mutated", value: "fact", span: first.span })
  suggestion.edits.push({ span: label.span, replacement: "mutated" })
  first.suggestions.push(suggestion)
  guard failure.diagnostics() is [second] else {
    abort("expected one isolated diagnostic")
  }
  debug_inspect(
    second,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "missing field `y`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 77,
      #|        end_offset: 92,
      #|        start_line: 6,
      #|        start_column: 25,
      #|        end_line: 6,
      #|        end_column: 40,
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
      #|          start_offset: 77,
      #|          end_offset: 92,
      #|          start_line: 6,
      #|          start_column: 25,
      #|          end_line: 6,
      #|          end_column: 40,
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
test "module compilation and linking expose facade-owned results" {
  let request : CompilationRequest = {
    root: {
      source_id: "Main.lane",
      text: (
        #|module Main
        #|import Lib.{ double }
        #|pub fn main() -> I64 {
        #|  double(21)
        #|}
      ),
    },
    libraries: [
      {
        source_id: "Lib.lane",
        text: (
          #|module Lib
          #|pub fn double(value : I64) -> I64 {
          #|  builtin("%i64_add")(value, value)
          #|}
        ),
      },
    ],
  }
  let compiled = compile_modules(request)
  guard compiled is Succeeded(modules, compilation_warnings) else {
    abort("expected module compilation to succeed")
  }
  debug_inspect(
    (
      modules.root_module_path_text(),
      modules.module_count(),
      compilation_warnings.diagnostics(),
    ),
    content=(
      #|("Main", 2, [])
    ),
  )
  let linked = link_modules(modules)
  guard linked is Succeeded(program, linking_warnings) else {
    abort("expected linking to succeed")
  }
  debug_inspect(
    (
      program.module_path_texts(),
      program
      .entries()
      .map(entry => (entry.module_path_text(), entry.name(), entry.type_text())),
      linking_warnings.diagnostics(),
    ),
    content=(
      #|(["Lib", "Main"], [("Main", "main", "() -> I64")], [])
    ),
  )
}
