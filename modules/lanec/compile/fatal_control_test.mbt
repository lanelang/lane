///|
test "fatal builtin has one canonical Unit and Io function type" {
  let valid = check_source(
    (
      #|module Main
      #|pub let panic : (String) -> Unit ! Io = builtin("%panic")
    ),
  )
  assert_true(valid is Succeeded(_))

  let invalid_sources = [
    (
      #|module Main
      #|pub let panic : (I64) -> Unit ! Io = builtin("%panic")
    ),
    (
      #|module Main
      #|pub let panic : (String) -> Unit = builtin("%panic")
    ),
    (
      #|module Main
      #|pub enum Void {}
      #|pub let panic : (String) -> Void ! Io = builtin("%panic")
    ),
  ]
  for source in invalid_sources {
    guard check_source(source) is Failed(failure) else {
      fail("invalid panic builtin type unexpectedly typechecked")
    }
    assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
      Some("E3027"),
    ])
  }
}

///|
test "fatal builtin synthesizes its canonical type" {
  let outcome = check_source(
    (
      #|module Main
      #|pub fn answer() -> Unit {
      #|  let panic = builtin("%panic")
      #|  let _typed : (String) -> Unit ! Io = panic
      #|  ()
      #|}
    ),
  )
  assert_true(outcome is Succeeded(_))
}
