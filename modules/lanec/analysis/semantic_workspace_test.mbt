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
test "semantic snapshot composes right-nested operator inlays inner first" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|pub struct Add[A] {
    #|  add : (A, A) -> A
    #|}
    #|
    #|pub struct Multiply[A] {
    #|  multiply : (A, A) -> A
    #|}
    #|
    #|pub fn[A] op_add(left : A, right : A, auto op : Add[A]) -> A {
    #|  op.add(left, right)
    #|}
    #|
    #|pub fn[A] op_mul(left : A, right : A, auto op : Multiply[A]) -> A {
    #|  op.multiply(left, right)
    #|}
    #|
    #|offer i64_add : Add[I64] = Add::{ add: fn(left : I64, right : I64) { builtin("%i64_add")(left, right) } }
    #|offer i64_multiply : Multiply[I64] = Multiply::{ multiply: fn(left : I64, right : I64) { builtin("%i64_mul")(left, right) } }
    #|
    #|pub let answer : I64 = 1 + 2 * 3
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])
  debug_inspect(
    snapshot
    .inlay_hints_in_range("file:///Main.lane", 1, 1, 24, 1)
    .filter(fn(hint) { hint.kind is ImplicitArgumentHint }),
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 22, column: 33 },
      #|    kind: ImplicitArgumentHint,
      #|    label: ", op=i64_multiply, op=i64_add",
      #|  },
      #|]
    ),
  )
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
      #|    position: { source_id: "file:///B.lane", line: 6, column: 16 },
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
