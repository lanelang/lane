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
  match
    program.elaborate_entry(entry, @executable.ExecutionProfile::lane_cli()) {
    Ok(_) => ()
    Err(error) => fail("entry elaboration failed: \{Repr(error)}")
  }
}

///|
priv enum EffectSpecializedTopTermObservation {
  Value(String)
  RecursiveValues(Array[String])
  External(String)
} derive(Debug)

///|
fn effect_specialized_value_name(
  program : @buslane.Program,
  id : @buslane.ValueId,
) -> String {
  guard program.metadata.value_info(id) is Some(info) else {
    abort("effect-specialized value is missing metadata")
  }
  info.name.occurrence
}

///|
fn observe_effect_specialized_top_terms(
  source : String,
  entry_name : String,
) -> Array[EffectSpecializedTopTermObservation] raise {
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
  let observed = []
  match
    program.elaborate_entry_observed(
      entry,
      @executable.ExecutionProfile::lane_cli(),
      stage => {
        if stage is EffectSpecialized(specialized) {
          for term in specialized.terms {
            match term {
              Let(id, _) =>
                observed.push(
                  Value(effect_specialized_value_name(specialized, id)),
                )
              LetRec(bindings) =>
                observed.push(
                  RecursiveValues(
                    bindings.map(binding => {
                      effect_specialized_value_name(specialized, binding.id)
                    }),
                  ),
                )
              External(id) =>
                observed.push(
                  External(effect_specialized_value_name(specialized, id)),
                )
            }
          }
        }
      },
    ) {
    Ok(_) => observed
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

///|
test "effect specialization retains only reachable externals" {
  debug_inspect(
    observe_effect_specialized_top_terms(
      (
        #|module Main
        #|
        #|pub let reachable_host : () -> Unit = extern("reachable")
        #|let unreachable_host : () -> Unit = extern("unreachable")
        #|
        #|pub fn answer() -> Unit {
        #|  reachable_host()
        #|}
      ),
      "answer",
    ),
    content=(
      #|[
      #|  External("reachable"),
      #|  RecursiveValues(["answer"]),
      #|  Value("reachable_host"),
      #|]
    ),
  )
}

///|
test "effect specialization retains an ordinary value chain" {
  debug_inspect(
    observe_effect_specialized_top_terms(
      (
        #|module Main
        #|
        #|let leaf : I64 = 42
        #|let middle : I64 = leaf
        #|let unreachable : I64 = 0
        #|
        #|pub fn answer() -> Unit {
        #|  let _value : I64 = middle
        #|  ()
        #|}
      ),
      "answer",
    ),
    content=(
      #|[RecursiveValues(["answer"]), Value("leaf"), Value("middle")]
    ),
  )
}

///|
test "effect specialization retains a generic source beside its concrete clone" {
  debug_inspect(
    observe_effect_specialized_top_terms(
      (
        #|module Main
        #|
        #|pub struct Runner {
        #|  run : [E : Effect](() -> Unit ! E) -> Unit ! E
        #|}
        #|
        #|fn[E : Effect] forward(action : () -> Unit ! E) -> Unit ! E {
        #|  action()
        #|}
        #|
        #|pub fn answer() -> Unit {
        #|  let _done : Unit = forward[{}](fn () { () })
        #|  let _runner : Runner = Runner::{ run: forward }
        #|  ()
        #|}
      ),
      "answer",
    ),
    content=(
      #|[
      #|  RecursiveValues(["forward%effect"]),
      #|  RecursiveValues(["forward", "answer"]),
      #|]
    ),
  )
}

///|
test "effect specialization retains a reachable recursive cycle as one group" {
  debug_inspect(
    observe_effect_specialized_top_terms(
      (
        #|module Main
        #|
        #|fn left() -> Unit {
        #|  right()
        #|}
        #|
        #|fn right() -> Unit {
        #|  left()
        #|}
        #|
        #|fn unreachable() -> Unit {
        #|  unreachable()
        #|}
        #|
        #|pub fn answer() -> Unit {
        #|  left()
        #|}
      ),
      "answer",
    ),
    content=(
      #|[RecursiveValues(["left", "right", "answer"])]
    ),
  )
}
