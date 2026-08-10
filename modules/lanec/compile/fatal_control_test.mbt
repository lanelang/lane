///|
test "fatal builtin accepts only a closed String to empty-enum Io function" {
  let valid = check_source(
    (
      #|module Main
      #|pub enum Void {}
      #|pub type Empty = Void
      #|pub let panic : (String) -> Empty ! Io = builtin("%panic")
    ),
  )
  assert_true(valid is Succeeded(_))

  let invalid = check_source(
    (
      #|module Main
      #|pub let panic : (String) -> Unit ! Io = builtin("%panic")
    ),
  )
  guard invalid is Failed(failure) else {
    fail("inhabited fatal result unexpectedly typechecked")
  }
  assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
    Some("E3037"),
  ])
}

///|
test "fatal builtin rejects every noncanonical function shape" {
  let sources = [
    (
      #|module Main
      #|pub enum Void {}
      #|pub let panic : (I64) -> Void ! Io = builtin("%panic")
    ),
    (
      #|module Main
      #|pub enum Void {}
      #|pub let panic : (String) -> Void = builtin("%panic")
    ),
    (
      #|module Main
      #|pub enum Void {}
      #|pub let panic : [T](String) -> Void ! Io = builtin("%panic")
    ),
  ]
  for source in sources {
    guard check_source(source) is Failed(failure) else {
      fail("invalid fatal builtin shape unexpectedly typechecked")
    }
    assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
      Some("E3037"),
    ])
  }
}

///|
test "fatal builtin needs a complete declaration type" {
  let outcome = check_source(
    (
      #|module Main
      #|pub fn answer() -> Unit {
      #|  let _panic = builtin("%panic")
      #|  ()
      #|}
    ),
  )
  guard outcome is Failed(failure) else {
    fail("unannotated fatal builtin unexpectedly typechecked")
  }
  assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
    Some("E3036"),
  ])
}

///|
test "Void elimination gives fatal calls unrelated explicit result types" {
  let outcome = check_source(
    (
      #|module Main
      #|pub enum Void {}
      #|let panic : (String) -> Void ! Io = builtin("%panic")
      #|fn[T] absurd(value : Void) -> T { match value {} }
      #|pub fn text() -> String ! Io {
      #|  absurd[String](panic("text"))
      #|}
      #|pub fn number() -> I64 ! Io {
      #|  absurd[I64](panic("number"))
      #|}
    ),
  )
  assert_true(outcome is Succeeded(_))
}
