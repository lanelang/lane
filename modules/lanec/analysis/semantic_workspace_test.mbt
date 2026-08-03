///|
test "struct sequencing temporaries stay outside the semantic index" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|struct Pair {
    #|  first : I64
    #|  second : Bool
    #|}
    #|
    #|pub fn make() -> Pair {
    #|  Pair::{ second: true, first: 1 }
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  assert_eq(snapshot.inlay_hints_in_range("file:///Main.lane", 1, 0, 11, 0), [])
  assert_eq(snapshot.hover_at("file:///Main.lane", 9, 19), None)
}

///|
test "semantic snapshot queries use persistent source indexes" {
  let workspace = SemanticWorkspace::new()
  let source_a =
    #|module A
    #|
    #|pub let value : I64 = 1
  let source_b =
    #|module B
    #|
    #|import A
    #|
    #|pub fn use() -> I64 {
    #|  let dependent = A.value
    #|  dependent
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///A.lane", text: source_a },
      { source_id: "file:///B.lane", text: source_b },
    ])
    is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  guard initial.definition_at("file:///B.lane", 6, 22) is Some(initial_location) else {
    abort("expected imported definition")
  }
  assert_eq(initial_location.source_id, "file:///A.lane")
  assert_eq(initial_location.span.start_line, 3)
  guard initial.definition_at("file:///A.lane", 3, 10) is Some(local_location) else {
    abort("expected definition at its declaration")
  }
  assert_eq(local_location, initial_location)
  guard initial.hover_at("file:///B.lane", 6, 22) is Some(hover) else {
    abort("expected imported hover")
  }
  assert_eq(hover.contents, "A.value : I64")
  debug_inspect(
    initial.inlay_hints_in_range("file:///B.lane", 1, 0, 9, 0),
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///B.lane",
      #|      span: {
      #|        start_offset: 48,
      #|        end_offset: 57,
      #|        start_line: 6,
      #|        start_column: 7,
      #|        end_line: 6,
      #|        end_column: 16,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|]
    ),
  )
  guard workspace.upsert_source({
      source_id: "file:///A.lane",
      text: source_a.replace(old="\n\npub", new="\n\n\npub"),
    })
    is Some(updated) else {
    abort("expected updated semantic snapshot")
  }
  guard updated.definition_at("file:///B.lane", 6, 22) is Some(updated_location) else {
    abort("expected updated imported definition")
  }
  assert_eq(updated_location.span.start_line, 4)
  guard initial.definition_at("file:///B.lane", 6, 22)
    is Some(preserved_location) else {
    abort("expected preserved imported definition")
  }
  assert_eq(preserved_location.span.start_line, 3)
}

///|
test "local hover uses nominal tuple presentation" {
  let workspace = SemanticWorkspace::new()
  let main =
    #|module Main
    #|import Basic.Data.Tuple
    #|
    #|pub fn use() -> I64 {
    #|  let pair : (I64, Bool) = (1, true)
    #|  let (first, _) = pair
    #|  first
    #|}
  let tuple =
    #|module Basic.Data.Tuple
    #|pub enum Tuple[A, B] {
    #|  tuple(A, B)
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: main },
      { source_id: "file:///Tuple.lane", text: tuple },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  guard snapshot.hover_at("file:///Main.lane", 5, 8) is Some(hover) else {
    abort("expected local tuple hover")
  }
  assert_eq(hover.contents, "pair : Tuple[I64, Bool]")
}
