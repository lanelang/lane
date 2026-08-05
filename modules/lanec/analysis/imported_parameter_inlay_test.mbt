///|
test "semantic workspace tracks imported auto arguments in top-level initializers" {
  let workspace = SemanticWorkspace::new()
  let consumer =
    #|module Data.I64
    #|import Trait.Iso.{ Into, From, into_by_from, from_by_into }
    #|
    #|offer i32_impl_from_i64 : From[I32, I64] = From::{ from: fn(_value : I64) -> I32 { 0i32 } }
    #|offer i32_impl_into_i64 : Into[I32, I64] = Into::{ into: fn(_value : I32) -> I64 { 0 } }
    #|
    #|pub offer i64_impl_into_i32 : Into[I64, I32] = into_by_from()
    #|pub offer i64_impl_from_i32 : From[I64, I32] = from_by_into()
  let provider =
    #|module Trait.Iso
    #|
    #|pub struct Into[T, R] {
    #|  into : (T) -> R
    #|}
    #|
    #|pub struct From[T, R] {
    #|  from : (R) -> T
    #|}
    #|
    #|pub offer fn[T, R] from_by_into(auto into : Into[T, R]) -> From[R, T] {
    #|  From::{ from: into.into }
    #|}
    #|
    #|pub offer fn[T, R] into_by_from(auto from : From[T, R]) -> Into[R, T] {
    #|  Into::{ into: from.from }
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///I64.lane", text: consumer },
      { source_id: "file:///Iso.lane", text: provider },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])
  assert_eq(
    snapshot
    .inlay_hints_in_range("file:///I64.lane", 1, 1, 20, 1)
    .filter(fn(hint) { hint.kind is ImplicitArgumentHint })
    .map(fn(hint) { hint.label }),
    ["from=i32_impl_from_i64", "into=i32_impl_into_i64"],
  )
  let updated_provider = provider
    .replace(old="auto from : From[T, R]", new="auto source : From[T, R]")
    .replace(old="from.from", new="source.from")
  guard workspace.upsert_source({
      source_id: "file:///Iso.lane",
      text: updated_provider,
    })
    is Some(updated) else {
    fail("expected updated semantic snapshot")
  }
  assert_eq(updated.diagnostics(), [])
  assert_eq(
    updated
    .inlay_hints_in_range("file:///I64.lane", 1, 1, 20, 1)
    .filter(fn(hint) { hint.kind is ImplicitArgumentHint })
    .map(fn(hint) { hint.label }),
    ["source=i32_impl_from_i64", "into=i32_impl_into_i64"],
  )
}

///|
test "semantic workspace names explicit arguments of imported functions" {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      {
        source_id: "file:///Main.lane",
        text: (
          #|module Main
          #|import Provider.{ choose }
          #|
          #|pub let answer : I64 = choose(1, 2)
        ),
      },
      {
        source_id: "file:///Provider.lane",
        text: (
          #|module Provider
          #|
          #|pub fn choose(left : I64, right : I64) -> I64 {
          #|  if true { left } else { right }
          #|}
        ),
      },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])
  assert_eq(
    snapshot
    .inlay_hints_in_range("file:///Main.lane", 1, 1, 6, 1)
    .filter(fn(hint) { hint.kind is ParameterHint })
    .map(fn(hint) { hint.label }),
    ["left=", "right="],
  )
}

///|
test "semantic workspace keeps imported pipeline parameter hints position-unique" {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      {
        source_id: "file:///Main.lane",
        text: (
          #|module Main
          #|import Provider.{ concat }
          #|
          #|pub fn answer(value : String) -> String {
          #|  "(" |> concat(value) |> concat(")")
          #|}
        ),
      },
      {
        source_id: "file:///Provider.lane",
        text: (
          #|module Provider
          #|
          #|pub fn concat(left : String, right : String) -> String {
          #|  if true { left } else { right }
          #|}
        ),
      },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])
  let hints = snapshot
    .inlay_hints_in_range("file:///Main.lane", 1, 1, 8, 1)
    .filter(fn(hint) { hint.kind is ParameterHint })
  debug_inspect(
    hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 115,
      #|        end_offset: 118,
      #|        start_line: 5,
      #|        start_column: 34,
      #|        end_line: 5,
      #|        end_column: 37,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "right=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 98,
      #|        end_offset: 103,
      #|        start_line: 5,
      #|        start_column: 17,
      #|        end_line: 5,
      #|        end_column: 22,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "right=",
      #|  },
      #|]
    ),
  )
  let positions : Map[String, Unit] = Map([])
  for hint in hints {
    let span = hint.location.span
    let position = "\{span.start_line}:\{span.start_column}"
    assert_false(positions.contains(position))
    positions[position] = ()
  }
}
