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
