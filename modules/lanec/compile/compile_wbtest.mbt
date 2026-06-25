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

///|
test "compile sources exposes only root public entries" {
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

///|
test "compile sources links only root reachable library modules" {
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
      (
        #|module Extra
        #|pub let extra : (Int, Int) -> Int = builtin("%i64_add")
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not expose private imported values" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="unresolved_value value")
}

///|
test "check sources does not expose private imported types" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="unresolved_type Hidden")
}

///|
test "check sources does not expose private imported nominal shape through public value" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = leak().value
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
        #|pub fn leak() -> Hidden {
        #|  Hidden::{ value: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="not_a_struct type#0")
}

///|
test "check sources exposes public imported nominal shape through public value" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = point().x
    ),
    [
      (
        #|module Lib
        #|pub struct Point {
        #|  x : Int
        #|}
        #|pub fn point() -> Point {
        #|  Point::{ x: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "check sources rejects missing import" {
  let result = check_sources(
    (
      #|module Main
      #|import Missing
      #|pub let answer : Int = 42
    ),
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="missing import Missing")
}

///|
test "check sources rejects duplicate module input" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="duplicate module input Main")
}

///|
test "check sources checks unimported library modules" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Extra
        #|pub let extra : Int = missing
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="unresolved_value missing")
}

///|
test "check sources rejects unimported library import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module ExtraA
        #|import ExtraB
        #|pub let value : Int = 1
      ),
      (
        #|module ExtraB
        #|import ExtraA
        #|pub let value : Int = 2
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="import cycle ExtraA")
}

///|
test "check sources rejects import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Lib
        #|import Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="import cycle Main")
}
