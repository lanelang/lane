///|
test "elaborate empty enum match into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|enum Void {}
      #|
      #|fn absurd(value : Void) -> Int {
      #|  match value {}
      #|}
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  debug_inspect(@buslane.verify_program(program), content="{ diagnostics: [] }")
}

///|
test "lowering does not treat type errors as uninhabited" {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  assert_true(lowerer.complete_alt_constructors_for_type(Error) is None)
}
