// Owner-visible members stay reachable through a transitively imported module.
//
// This mirrors the semantic-workspace regression in
// `modules/lanec/analysis/owner_visible_member_test.mbt`. Both entry points
// must agree on which interfaces a module resolves declarations against; they
// once disagreed, and only the language server rejected valid source.

///|
fn owner_visible_member_request(main : String) -> CompilationRequest {
  let module_a =
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
  {
    root: { source_id: "Main.lane", text: main },
    libraries: [
      { source_id: "A.lane", text: module_a },
      { source_id: "B.lane", text: module_b },
    ],
  }
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
  let result = check(owner_visible_member_request(main))
  assert_true(result is Succeeded(_, _))
  assert_eq(result.diagnostics(), [])
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
  let result = check(owner_visible_member_request(main))
  assert_true(result is Succeeded(_, _))
  assert_eq(result.diagnostics(), [])
}

///|
test "a transitively reachable module contributes no importable names" {
  // The closure widens declaration lookup, not name visibility: `Main` still
  // cannot name `A`'s declarations without importing `A`.
  let main =
    #|module Main
    #|
    #|import B.{ produce }
    #|
    #|pub fn read() -> I64 {
    #|  let value : TypeA = produce()
    #|  value.field
    #|}
  let result = check(owner_visible_member_request(main))
  assert_true(result is Failed(_))
}
