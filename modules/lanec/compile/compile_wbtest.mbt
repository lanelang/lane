///|
test "compile source records builtin externals and public entries" {
  let result = compile_source(
    (
      #|module Test
      #|pub let int_add : (Int, Int) -> Int = builtin("%i64_add")
      #|let private_value : Int = 1
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="1")
  inspect(result.externals.builtins[0].name, content="%i64_add")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="int_add",
  )
  guard result.program is Some(_) else { abort("expected Buslane program") }
}

///|
test "check reports payloadless variant call" {
  let result = check_source(
    (
      #|module Test
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|let value : Option[Int] = none()
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="payloadless_variant_call none",
  )
}

///|
test "compile sources accepts explicit library modules" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}
