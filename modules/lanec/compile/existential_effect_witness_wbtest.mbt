///|
test "compile struct existential effect witnesses" {
  let result = compile_source_for_test(
    (
      #|module Test
      #|pub struct Task {
      #|  type E : Effect
      #|}
      #|pub fn[E : Effect] pack() -> Task {
      #|  Task::{ E = E }
      #|}
    ),
  )
  assert_eq(result.diagnostics, [])
  guard result.program is Some(program) else {
    abort("expected Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}
