///|
fn canonical_void_source() -> String {
  (
    #|module Basic.Data.Void
    #|
    #|pub enum Void {}
    #|
    #|pub fn[T] absurd(value : Void) -> T {
    #|  match value {}
    #|}
  )
}

///|
fn check_panic_module(
  source : String,
  void_source? : String = canonical_void_source(),
) -> CompilationOutcome[Unit] {
  check({
    root: { source_id: "basic-io", text: source },
    libraries: [{ source_id: "basic-void", text: void_source }],
  })
}

///|
test "fatal builtin has the canonical Basic Void and Panic function type" {
  let valid = check_panic_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
    ),
  )
  assert_true(valid is Succeeded(_))

  let invalid_sources = [
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let panic : (I64) -> Void ! Panic = builtin("%panic")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let panic : (String) -> Void = builtin("%panic")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let panic : (String) -> Unit ! Panic = builtin("%panic")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub enum OtherVoid {}
      #|pub let panic : (String) -> OtherVoid ! Panic = builtin("%panic")
    ),
  ]
  for source in invalid_sources {
    guard check_panic_module(source) is Failed(failure) else {
      fail("invalid panic builtin type unexpectedly typechecked")
    }
    assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
      Some("E3027"),
    ])
  }
}

///|
test "fatal builtin requires the canonical public empty Void provider" {
  let outcome = check_panic_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
    ),
    void_source=(
      #|module Basic.Data.Void
      #|pub enum Void { impossible(Unit) }
    ),
  )
  guard outcome is Failed(failure) else {
    fail("inhabited canonical Void provider unexpectedly typechecked")
  }
  assert_true(
    failure.diagnostics().any(diagnostic => diagnostic.code == Some("E3039")),
  )
}

///|
test "fatal builtin reports a missing canonical Void provider" {
  guard check_source(
      (
        #|module Main
        #|pub fn answer() -> Unit {
        #|  let panic = builtin("%panic")
        #|  ()
        #|}
      ),
    )
    is Failed(failure) else {
    fail("panic unexpectedly synthesized without its canonical Void provider")
  }
  assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
    Some("E3039"),
  ])
}

///|
test "Void elimination composes panic into arbitrary result types" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|import Basic.Data.Void.{ absurd }
        #|import Basic.Io.{ panic }
        #|pub fn answer() -> I64 ! Panic {
        #|  absurd[I64](panic("missing integer"))
        #|}
      ),
    },
    libraries: [
      { source_id: "basic-void", text: canonical_void_source() },
      {
        source_id: "basic-io",
        text: (
          #|module Basic.Io
          #|import Basic.Data.Void.{ Void }
          #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
        ),
      },
    ],
  })
  assert_true(outcome is Succeeded(_))
}

///|
test "fatal builtin synthesizes its canonical nominal type" {
  let outcome = check_panic_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub fn answer() -> Unit {
      #|  let panic = builtin("%panic")
      #|  let _typed : (String) -> Void ! Panic = panic
      #|  ()
      #|}
    ),
  )
  assert_true(outcome is Succeeded(_))
}
