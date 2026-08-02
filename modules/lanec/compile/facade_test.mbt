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
    warnings
    .diagnostics()
    .map(diagnostic => {
      (diagnostic.severity, diagnostic.code, diagnostic.message)
    }),
    content=(
      #|[(Warning, Some("W2001"), "unused local value binding")]
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
    failure
    .diagnostics()
    .map(diagnostic => {
      (diagnostic.severity, diagnostic.code, diagnostic.message)
    }),
    content=(
      #|[(Error, Some("E1100"), "unexpected token")]
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
    failure
    .diagnostics()
    .map(diagnostic => {
      (diagnostic.severity, diagnostic.code, diagnostic.message)
    }),
    content=(
      #|[(Error, Some("E2001"), "cannot find value `missing`")]
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
    failure
    .diagnostics()
    .map(diagnostic => {
      (diagnostic.severity, diagnostic.code, diagnostic.message)
    }),
    content=(
      #|[(Error, Some("E3006"), "type mismatch")]
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
