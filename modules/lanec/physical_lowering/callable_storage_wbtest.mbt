///|
/// White-box access is needed only to disable optional representation
/// specialization: the canonical generic implementation must work on its own.
/// Both modes otherwise use source compilation and real Wasm execution.
test "shared callable storage supports generic and concrete consumers" {
  let source =
    #|module Main
    #|pub extern type Host : Effect
    #|let depth : () -> I64 ! Host = extern("lane.test", "depth")
    #|let observe : (I64) -> Unit ! Host = extern("lane.test", "observe")
    #|let equal : (I64, I64) -> Bool = builtin("%i64_equal")
    #|let sub : (I64, I64) -> I64 = builtin("%i64_sub")
    #|let add : (I64, I64) -> I64 = builtin("%i64_add")
    #|let widen : (I32) -> I64 = builtin("%i32_to_i64")
    #|effect Check { check() -> Unit }
    #|enum Sequence[T] {
    #|  end()
    #|  next(T, Sequence[T])
    #|}
    #|fn consume(tests : Sequence[() -> I64 ! Check]) -> I64 {
    #|  match tests {
    #|    Sequence::end() => 0
    #|    Sequence::next(test, rest) => {
    #|      let result = handle test() with {
    #|        Check::check(resume) => resume(())
    #|      } final value { value }
    #|      add(result, consume(rest))
    #|    }
    #|  }
    #|}
    #|struct Box[T] { value : T }
    #|struct Pair[T] {
    #|  first : T
    #|  second : T
    #|}
    #|fn[A] generic(n : I64, box : Box[() -> A]) -> A {
    #|  if equal(n, 0) { box.value() }
    #|  else { generic[A](sub(n, 1), box) }
    #|}
    #|fn concrete(box : Box[() -> I32]) -> I32 { box.value() }
    #|fn[A] nested(n : I64, box : Box[(Pair[A]) -> A], x : A) -> A {
    #|  if equal(n, 0) { box.value(Pair::{ first: x, second: x }) }
    #|  else { nested[A](sub(n, 1), box, x) }
    #|}
    #|fn concrete_nested(box : Box[(Pair[I32]) -> I32], x : I32) -> I32 {
    #|  box.value(Pair::{ first: x, second: x })
    #|}
    #|fn capture(value : I64) -> Box[() -> I64] {
    #|  Box::{ value: fn() { value } }
    #|}
    #|pub fn answer() -> Unit ! Host {
    #|  let n = depth()
    #|  let small : Box[() -> I32] = Box::{ value: fn() { 42i32 } }
    #|  observe(widen(generic[I32](n, small)))
    #|  observe(widen(concrete(small)))
    #|  let wide : Box[() -> I64] = Box::{ value: fn() { 9000000000i64 } }
    #|  observe(generic[I64](n, wide))
    #|  observe(wide.value())
    #|  let pair : Box[(Pair[I32]) -> I32] = Box::{ value: fn(p) { p.first } }
    #|  observe(widen(nested[I32](n, pair, 51i32)))
    #|  observe(widen(concrete_nested(pair, 51i32)))
    #|  let first = capture(n)
    #|  let second = capture(sub(n, 1))
    #|  observe(generic[I64](n, first))
    #|  observe(second.value())
    #|  observe(consume(Sequence::next(
    #|    fn() { Check::check!(); n },
    #|    Sequence::next(fn() { Check::check!(); sub(n, 1) }, Sequence::end())
    #|  )))
    #|}
  let compiled = match @compile.compile_source(source) {
    Succeeded(compiled, _) => compiled
    Failed(failure) =>
      fail("compilation failed: \{Repr(failure.diagnostics())}")
  }
  guard compiled.entries() is [entry] else { fail("expected one public entry") }
  let executable = compiled
    .elaborate_entry(
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[],
        supports_external_effects=true,
      ),
    )
    .unwrap()
  for specialization in [false, true] {
    let lowered = lower_executable_program_to_physical_observed_with_specialization(
      executable,
      _ => (),
      specialization,
    )
    let image = match lowered {
      Ok(verified) => verified.image()
      Err(error) =>
        fail(
          "lowering failed (specialization=\{specialization}): \{Repr(error)}",
        )
    }
    let observed : Array[Int64] = []
    let host = TestHostBindings::new()
    host.provide_i64("depth", 2L)
    host.observe_i64("observe", value => observed.push(value))
    let loaded = load_physical_interpreted(image, host~).unwrap()
    assert_eq(loaded.execute(), Ok(Returned))
    assert_eq(observed, [
      42L, 42L, 9000000000L, 9000000000L, 51L, 51L, 2L, 1L, 3L,
    ])
  }
}

///|
test "state handler returning a callable preserves nested ABI adaptations" {
  let source =
    #|module Main
    #|pub extern type Host : Effect
    #|let observe : (I64) -> Unit ! Host = extern("lane.test", "observe")
    #|let add : (I64, I64) -> I64 = builtin("%i64_add")
    #|struct StateResult { value : I64; state : I64 }
    #|effect State { get() -> I64; put(I64) -> Unit }
    #|fn tick() -> I64 ! State {
    #|  let current = State::get!()
    #|  State::put!(add(current, 1))
    #|  State::get!()
    #|}
    #|fn run_tick() -> (I64) -> StateResult {
    #|  handle tick() with {
    #|    State::get(resume) => fn(state : I64) -> StateResult {
    #|      resume(state)(state)
    #|    }
    #|    State::put(next, resume) => fn(_state : I64) -> StateResult {
    #|      resume(())(next)
    #|    }
    #|  } final value {
    #|    fn(state : I64) -> StateResult { StateResult::{ value, state } }
    #|  }
    #|}
    #|let result : StateResult = run_tick()(41)
    #|pub fn answer() -> Unit ! Host {
    #|  observe(result.value)
    #|  observe(result.state)
    #|}
  let compiled = match @compile.compile_source(source) {
    Succeeded(compiled, _) => compiled
    Failed(failure) =>
      fail("compilation failed: \{Repr(failure.diagnostics())}")
  }
  guard compiled.entries() is [entry] else { fail("expected one public entry") }
  let executable = compiled
    .elaborate_entry(
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[],
        supports_external_effects=true,
      ),
    )
    .unwrap()
  let image = lower_executable_program_to_physical(executable).unwrap().image()
  let observed : Array[Int64] = []
  let host = TestHostBindings::new()
  host.observe_i64("observe", value => observed.push(value))
  let loaded = load_physical_interpreted(image, host~).unwrap()
  assert_eq(loaded.execute(), Ok(Returned))
  assert_eq(observed, [42L, 42L])
}
