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
fn owner_visible_member_sources() -> Array[(String, String)] {
  [
    (
      "file:///A.lane",
      (
        #|module A
        #|
        #|pub struct TypeA {
        #|  field : I64
        #|}
        #|
        #|pub enum Shape {
        #|  circle(I64)
        #|  square(I64)
        #|}
        #|
        #|pub fn make() -> TypeA {
        #|  TypeA::{ field: 42 }
        #|}
        #|
        #|pub fn circle_of(radius : I64) -> Shape {
        #|  Shape::circle(radius)
        #|}
      ),
    ),
    (
      "file:///B.lane",
      (
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
      ),
    ),
  ]
}

///|
fn owner_visible_member_snapshot(main : String) -> SemanticSnapshot {
  let sources = owner_visible_member_sources().map(fn(entry) {
    let (source_id, text) = entry
    ({ source_id, text } : @module_frontend.SourceInput)
  })
  sources.push({ source_id: "file:///Main.lane", text: main })
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot
}

///|
test "field projection needs no import of the declaring module" {
  let snapshot = owner_visible_member_snapshot(
    (
      #|module Main
      #|
      #|import B.{ produce }
      #|
      #|pub fn read() -> I64 {
      #|  produce().field
      #|}
    ),
  )
  assert_eq(snapshot.diagnostics(), [])
}

///|
test "pattern matching needs no import of the declaring module" {
  let snapshot = owner_visible_member_snapshot(
    (
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
    ),
  )
  assert_eq(snapshot.diagnostics(), [])
}

///|
test "field completion offers members of a transitively reachable type" {
  let snapshot = owner_visible_member_snapshot(
    (
      #|module Main
      #|
      #|import B.{ produce }
      #|
      #|pub fn read() -> I64 {
      #|  let value = produce()
      #|  value.field
      #|}
    ),
  )
  let labels = snapshot
    .complete("file:///Main.lane", 7, 9, TriggerCharacter("."))
    .map(fn(entry) { entry.label })
  assert_true(labels.contains("field"))
}

///|
test "editing a transitively reachable module refreshes downstream analysis" {
  let sources = owner_visible_member_sources().map(fn(entry) {
    let (source_id, text) = entry
    ({ source_id, text } : @module_frontend.SourceInput)
  })
  sources.push({
    source_id: "file:///Main.lane",
    text: (
      #|module Main
      #|
      #|import B.{ produce }
      #|
      #|pub fn read() -> I64 {
      #|  produce().field
      #|}
    ),
  })
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])

  // Renaming the field leaves `B`'s interface presentation unchanged, so a
  // downstream module that only watched its direct imports would keep stale
  // nominal shapes and never report the now-invalid projection.
  guard workspace.upsert_source({
      source_id: "file:///A.lane",
      text: (
        #|module A
        #|
        #|pub struct TypeA {
        #|  renamed : I64
        #|}
        #|
        #|pub enum Shape {
        #|  circle(I64)
        #|  square(I64)
        #|}
        #|
        #|pub fn make() -> TypeA {
        #|  TypeA::{ renamed: 42 }
        #|}
        #|
        #|pub fn circle_of(radius : I64) -> Shape {
        #|  Shape::circle(radius)
        #|}
      ),
    })
    is Some(updated) else {
    abort("expected updated semantic snapshot")
  }
  assert_false(updated.diagnostics().is_empty())
}
