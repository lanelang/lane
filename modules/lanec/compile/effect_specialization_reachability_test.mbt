///|
fn assert_entry_elaborates(source : String, entry_name : String) -> Unit raise {
  let program = match compile_source(source) {
    Succeeded(program, _) => program
    Failed(failure) =>
      fail("source compilation failed: \{Repr(failure.diagnostics())}")
  }
  let mut selected = None
  for entry in program.entries() {
    if entry.name() == entry_name {
      selected = Some(entry)
      break
    }
  }
  guard selected is Some(entry) else {
    fail("compiled program has no `\{entry_name}` entry")
  }
  match program.elaborate_entry(entry) {
    Ok(_) => ()
    Err(error) => fail("entry elaboration failed: \{Repr(error)}")
  }
}

///|
test "unreachable constructor metadata does not require specialization" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|enum Box[E : Effect] {
      #|  box(() -> Unit ! E)
      #|}
      #|
      #|struct Holder {
      #|  boxed : Box[{}]
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  ()
      #|}
    ),
    "answer",
  )
}

///|
test "unreachable operation metadata does not require specialization" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|enum Box[E : Effect] {
      #|  box(() -> Unit ! E)
      #|}
      #|
      #|effect Dormant {
      #|  exchange(Box[{}]) -> Box[{}]
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  ()
      #|}
    ),
    "answer",
  )
}

///|
test "mutually referencing unreachable declarations require no specialization" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|enum Box[E : Effect] {
      #|  box(() -> Unit ! E)
      #|}
      #|
      #|struct Left {
      #|  right : Right
      #|}
      #|
      #|struct Right {
      #|  left : Left
      #|  boxed : Box[{}]
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  ()
      #|}
    ),
    "answer",
  )
}
