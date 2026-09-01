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
fn check_abort_module(
  source : String,
  void_source? : String = canonical_void_source(),
) -> CompilationOutcome[Unit] {
  check({
    root: { source_id: "basic-io", text: source, },
    libraries: [{ source_id: "basic-void", text: void_source, }],
  })
}

///|
test "abort builtin has the canonical Basic Void and Panic function type" {
  let valid = check_abort_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let abort : () -> Void ! Panic = builtin("%abort")
    ),
  )
  assert_true(valid is Succeeded(_))

  let invalid_sources = [
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let abort : (I64) -> Void ! Panic = builtin("%abort")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let abort : () -> Void = builtin("%abort")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let abort : () -> Unit ! Panic = builtin("%abort")
    ),
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub enum OtherVoid {}
      #|pub let abort : () -> OtherVoid ! Panic = builtin("%abort")
    ),
  ]
  for source in invalid_sources {
    guard check_abort_module(source) is Failed(failure) else {
      fail("invalid abort builtin type unexpectedly typechecked")
    }
    assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
      Some("E3027"),
    ])
  }
}

///|
test "abort builtin requires the canonical public empty Void provider" {
  let outcome = check_abort_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub let abort : () -> Void ! Panic = builtin("%abort")
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
test "abort builtin reports a missing canonical Void provider" {
  guard check_source(
      (
        #|module Main
        #|pub fn answer() -> Unit {
        #|  let abort = builtin("%abort")
        #|  ()
        #|}
      ),
    )
    is Failed(failure) else {
    fail("abort unexpectedly synthesized without its canonical Void provider")
  }
  assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
    Some("E3039"),
  ])
}

///|
test "Void elimination composes effectful panic into arbitrary result types" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|import Basic.Data.Void.{ absurd }
        #|import Basic.Io.{ panic }
        #|pub fn answer() -> I64 ! { Io, Panic } {
        #|  absurd[I64](panic("missing integer"))
        #|}
      ),
    },
    libraries: [
      { source_id: "basic-void", text: canonical_void_source(), },
      {
        source_id: "basic-io",
        text: (
          #|module Basic.Io
          #|import Basic.Data.Void.{ Void }
          #|let abort : () -> Void ! Panic = builtin("%abort")
          #|pub fn panic(_message : String) -> Void ! { Io, Panic } {
          #|  let write : () -> Unit ! Io = extern("lane.test", "panic_message")
          #|  write()
          #|  abort()
          #|}
        ),
      },
    ],
  })
  assert_true(outcome is Succeeded(_))
}

///|
test "abort builtin synthesizes its canonical nominal type" {
  let outcome = check_abort_module(
    (
      #|module Basic.Io
      #|import Basic.Data.Void.{ Void }
      #|pub fn answer() -> Unit {
      #|  let abort = builtin("%abort")
      #|  let _typed : () -> Void ! Panic = abort
      #|  ()
      #|}
    ),
  )
  assert_true(outcome is Succeeded(_))
}
