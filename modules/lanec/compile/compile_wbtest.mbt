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

///|
test "analysis resolves same-file definition and hover" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected definition")
  }
  match result.hover_at("file:///Main.lane", 5, 24) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected hover")
  }
  match result.hover_at("file:///Main.lane", 3, 10) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected definition hover")
  }
  inspect(
    result.definition_at("file:///Main.lane", 5, 29) is None,
    content="true",
  )
}

///|
test "analysis resolves cross-module definition by source identity" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|import Lib.*
        #|
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|
          #|pub let value : Int = 42
        ),
      },
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Lib.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected cross-module definition")
  }
}

///|
test "analysis resolves types fields and variants" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|struct Point {
        #|  x : Int
        #|}
        #|
        #|enum Option {
        #|  some(Point)
        #|  none
        #|}
        #|
        #|pub let point : Point = Point::{ x: 1 }
        #|
        #|pub let field_value : Int = point.x
        #|
        #|pub let wrapped : Option = some(point)
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 12, 18) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected type definition")
  }
  match result.definition_at("file:///Main.lane", 12, 26) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected struct literal type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 12, 32) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 38) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 39) is None,
    content="true",
  )
  match result.hover_at("file:///Main.lane", 3, 9) {
    Some(hover) => inspect(hover.contents, content="type Point : Type")
    None => abort("expected type definition hover")
  }
  match result.definition_at("file:///Main.lane", 14, 35) {
    Some(location) => inspect(location.span.start_line, content="4")
    None => abort("expected field definition")
  }
  match result.hover_at("file:///Main.lane", 4, 3) {
    Some(hover) => inspect(hover.contents, content="x : Int")
    None => abort("expected field definition hover")
  }
  match result.definition_at("file:///Main.lane", 16, 29) {
    Some(location) => inspect(location.span.start_line, content="8")
    None => abort("expected variant definition")
  }
  match result.hover_at("file:///Main.lane", 16, 29) {
    Some(hover) => inspect(hover.contents, content="some(type#0)")
    None => abort("expected variant hover")
  }
}

///|
test "analysis narrows struct pattern type references" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|struct Point {
        #|  x : Int
        #|}
        #|
        #|pub fn get_x(point : Point) -> Int {
        #|  match point {
        #|    Point::{ x } => x
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 9, 6) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected pattern type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 9, 13) is None,
    content="true",
  )
}

///|
test "analysis keeps partial definitions when unrelated diagnostics exist" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
        #|
        #|pub let bad : Int = missing
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="unresolved_value missing")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected partial definition")
  }
}
