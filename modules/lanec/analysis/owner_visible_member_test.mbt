// Fields, variants, and effect operations are owner-visible members: their
// visibility follows the exported type, not the importing module. A module that
// receives a value of a transitively reachable type must therefore be able to
// project it without importing the module that declares it.
//
// These tests drive the public semantic workspace because the language server
// reaches the compiler only through that boundary, and because the workspace
// once built a direct-imports-only environment for type checking while batch
// compilation used the transitive interface closure.

///|
/// `A` declares the owner-visible members, `B` re-exports them only through the
/// types in its signatures. `field` is a parameter so that a test can rename it
/// without changing `B`'s interface presentation.
fn owner_visible_member_library(
  field? : String = "field",
) -> Array[@module_frontend.SourceInput] {
  let module_a =
    $|module A
    $|
    $|pub struct TypeA {
    $|  \{field} : I64
    $|}
    $|
    $|pub enum Shape {
    $|  circle(I64)
    $|  square(I64)
    $|}
    $|
    $|pub fn make() -> TypeA {
    $|  TypeA::{ \{field}: 42 }
    $|}
    $|
    $|pub fn circle_of(radius : I64) -> Shape {
    $|  Shape::circle(radius)
    $|}
  let module_b =
    #|module B
    #|
    #|import A
    #|
    #|pub fn produce() -> A.TypeA {
    #|  A.make()
    #|}
    #|
    #|pub fn shape() -> A.Shape {
    #|  A.circle_of(1)
    #|}
  [
    { source_id: "file:///A.lane", text: module_a, },
    { source_id: "file:///B.lane", text: module_b, },
  ]
}

///|
fn owner_visible_member_snapshot(main : String) -> SemanticSnapshot {
  let sources = owner_visible_member_library()
  sources.push({ source_id: "file:///Main.lane", text: main, })
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot
}

///|
test "field projection needs no import of the declaring module" {
  let main =
    #|module Main
    #|
    #|import B.{ produce }
    #|
    #|pub fn read() -> I64 {
    #|  produce().field
    #|}
  let snapshot = owner_visible_member_snapshot(main)
  assert_eq(snapshot.diagnostics(), [])
}

///|
test "pattern matching needs no import of the declaring module" {
  let main =
    #|module Main
    #|
    #|import B.{ shape }
    #|
    #|pub fn measure() -> I64 {
    #|  match shape() {
    #|    circle(radius) => radius
    #|    square(side) => side
    #|  }
    #|}
  let snapshot = owner_visible_member_snapshot(main)
  assert_eq(snapshot.diagnostics(), [])
}

///|
test "field completion offers members of a transitively reachable type" {
  let main =
    #|module Main
    #|
    #|import B.{ produce }
    #|
    #|pub fn read() -> I64 {
    #|  let value = produce()
    #|  value.field
    #|}
  let snapshot = owner_visible_member_snapshot(main)
  let labels = snapshot
    .complete("file:///Main.lane", 7, 9, TriggerCharacter("."))
    .map(fn(entry) { entry.label })
  assert_true(labels.contains("field"))
}

///|
test "editing a transitively reachable module refreshes downstream analysis" {
  let main =
    #|module Main
    #|
    #|import B.{ produce }
    #|
    #|pub fn read() -> I64 {
    #|  produce().field
    #|}
  let sources = owner_visible_member_library()
  sources.push({ source_id: "file:///Main.lane", text: main, })
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])

  // Renaming the field leaves `B`'s interface presentation unchanged, so a
  // downstream module that only watched its direct imports would keep stale
  // nominal shapes and never report the now-invalid projection.
  guard owner_visible_member_library(field="renamed") is [renamed_a, ..] else {
    abort("expected the renamed library source")
  }
  guard workspace.upsert_source(renamed_a) is Some(updated) else {
    abort("expected updated semantic snapshot")
  }
  assert_false(updated.diagnostics().is_empty())
}
