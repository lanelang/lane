///|
test "pure callback through effect-polymorphic field preserves its result" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Apply {
      #|  call : [T, Eff : Effect](T, (T) -> T ! Eff) -> T ! Eff
      #|}
      #|
      #|fn[T, Eff : Effect] apply_call(
      #|  value : T,
      #|  callback : (T) -> T ! Eff
      #|) -> T ! Eff {
      #|  callback(value)
      #|}
      #|
      #|fn answer_callback(_value : I64) -> I64 {
      #|  42
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let apply = Apply::{ call: apply_call }
      #|  observe(apply.call[I64, {}](41, answer_callback))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "effectful callback through effect-polymorphic field invokes and resumes once" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Apply {
      #|  call : [T, Eff : Effect](T, (T) -> T ! Eff) -> T ! Eff
      #|}
      #|
      #|fn[T, Eff : Effect] apply_call(
      #|  value : T,
      #|  callback : (T) -> T ! Eff
      #|) -> T ! Eff {
      #|  callback(value)
      #|}
      #|
      #|effect Tick {
      #|  tick(I64) -> I64
      #|}
      #|
      #|fn ticked(value : I64) -> I64 ! Tick {
      #|  Tick::tick!(value)
      #|}
      #|
      #|let record_callback : () -> Unit ! Io = extern("lane.test.callback")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let apply = Apply::{ call: apply_call }
      #|  let value = handle apply.call[I64, { Tick }](42, ticked) with {
      #|    Tick::tick(value, resume) => {
      #|      record_callback()
      #|      resume(value)
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|  observe(value)
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 1))
}

///|
test "pure callback through higher-kinded mappable field preserves its result" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Box[T] {
      #|  box(T)
      #|}
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|fn[T, R, Eff : Effect] box_map(
      #|  box : Box[T],
      #|  callback : (T) -> R ! Eff
      #|) -> Box[R] ! Eff {
      #|  match box {
      #|    Box::box(value) => Box::box(callback(value))
      #|  }
      #|}
      #|
      #|fn answer_callback(_value : I64) -> I64 {
      #|  42
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let mappable : Mappable[Box] = Mappable::{ map: box_map }
      #|  let mapped = mappable.map[I64, I64, {}](Box::box(41), answer_callback)
      #|  match mapped {
      #|    Box::box(value) => observe(value)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "effectful callback through nested mappable implementation preserves its result" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Box[T] {
      #|  box(T)
      #|}
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|struct Applicative[M : [Type] -> Type] {
      #|  mappable_impl : Mappable[M]
      #|}
      #|
      #|fn[M : [Type] -> Type, T, R, Eff : Effect] map(
      #|  applicative_impl : Applicative[M],
      #|  value : M[T],
      #|  callback : (T) -> R ! Eff
      #|) -> M[R] ! Eff {
      #|  applicative_impl.mappable_impl.map(value, callback)
      #|}
      #|
      #|fn[T, R, Eff : Effect] box_map(
      #|  box : Box[T],
      #|  callback : (T) -> R ! Eff
      #|) -> Box[R] ! Eff {
      #|  match box {
      #|    Box::box(value) => Box::box(callback(value))
      #|  }
      #|}
      #|
      #|let record_callback : () -> Unit ! Io = extern("lane.test.callback")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn observed_callback(value : I64) -> I64 ! Io {
      #|  record_callback()
      #|  builtin("%i64_add")(value, 1)
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let applicative : Applicative[Box] = Applicative::{
      #|    mappable_impl: Mappable::{ map: box_map }
      #|  }
      #|  let mapped = map(applicative, Box::box(41), observed_callback)
      #|  match mapped {
      #|    Box::box(value) => observe(value)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 1))
}

///|
test "type-lambda mappable instance beta-reduces callback parameter types" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|type Identity : [Type] -> Type = type[T] => T
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|fn[T, R, Eff : Effect] identity_map(
      #|  value : Identity[T],
      #|  callback : (T) -> R ! Eff
      #|) -> Identity[R] ! Eff {
      #|  callback(value)
      #|}
      #|
      #|let identity_mappable : Mappable[Identity] = Mappable::{
      #|  map: identity_map
      #|}
      #|
      #|fn keep_bool(value : Bool) -> Bool {
      #|  value
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let mapped = identity_mappable.map[Bool, Bool, {}](true, keep_bool)
      #|  match mapped {
      #|    true => observe(42)
      #|    false => observe(0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "partially applied type-lambda mappable verifies inline implementation" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Result[T, E] {
      #|  ok(T)
      #|  error(E)
      #|}
      #|
      #|type PartialResult[E] : [Type] -> Type = type[T] => Result[T, E]
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|let partial_result_mappable : Mappable[PartialResult[String]] = Mappable::{
      #|  map: fn[T, R, Eff : Effect](
      #|    value : PartialResult[String][T],
      #|    callback : (T) -> R ! Eff
      #|  ) -> PartialResult[String][R] ! Eff {
      #|    match value {
      #|      Result::ok(inner) => {
      #|        let result : Result[R, String] = Result::ok(callback(inner))
      #|        result
      #|      }
      #|      Result::error(error) => {
      #|        let result : Result[R, String] = Result::error(error)
      #|        result
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|fn keep_bool(value : Bool) -> Bool {
      #|  value
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let mapped = partial_result_mappable.map[Bool, Bool, {}](
      #|    Result::ok(true),
      #|    keep_bool
      #|  )
      #|  match mapped {
      #|    Result::ok(true) => observe(42)
      #|    _ => observe(0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "higher-kinded mappable factory forwards its callback effect" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Result[T, E] {
      #|  ok(T)
      #|  error(E)
      #|}
      #|
      #|type PartialResult[E] : [Type] -> Type = type[T] => Result[T, E]
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|fn[T, E, R, Eff : Effect] map(
      #|  result : Result[T, E],
      #|  callback : (T) -> R ! Eff
      #|) -> Result[R, E] ! Eff {
      #|  match result {
      #|    Result::ok(value) => Result::ok(callback(value))
      #|    Result::error(error) => Result::error(error)
      #|  }
      #|}
      #|
      #|fn[E] partial_result_impl_map() -> Mappable[PartialResult[E]] {
      #|  Mappable::{
      #|    map: fn[T, R, Eff : Effect](res, callback) {
      #|      map[T, E, R, Eff](res, callback)
      #|    }
      #|  }
      #|}
      #|
      #|let record_callback : () -> Unit ! Io = extern("lane.test.callback")
      #|
      #|fn increment(value : I64) -> I64 ! Io {
      #|  record_callback()
      #|  builtin("%i64_add")(value, 1)
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let mappable = partial_result_impl_map[String]()
      #|  let input : Result[I64, String] = Result::ok(41)
      #|  let mapped = mappable.map[I64, I64, { Io }](input, increment)
      #|  match mapped {
      #|    Result::ok(value) => observe(value)
      #|    Result::error(_) => observe(0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 1))
}

///|
/// The same generic definition is demanded in two ways: `main` applies it to
/// `Io` directly, while `forward` passes its still-symbolic effect parameter.
/// Both paths must execute identically regardless of whether specialization
/// keeps the generic body, creates a concrete clone, or does both.
test "direct and symbolically forwarded effect applications agree" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|fn[T, R, Eff : Effect] apply(
      #|  value : T,
      #|  callback : (T) -> R ! Eff
      #|) -> R ! Eff {
      #|  callback(value)
      #|}
      #|
      #|fn[T, R, Eff : Effect] forward(
      #|  value : T,
      #|  callback : (T) -> R ! Eff
      #|) -> R ! Eff {
      #|  apply[T, R, Eff](value, callback)
      #|}
      #|
      #|let record_callback : () -> Unit ! Io = extern("lane.test.callback")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn increment(value : I64) -> I64 ! Io {
      #|  record_callback()
      #|  builtin("%i64_add")(value, 1)
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe(apply[I64, I64, { Io }](41, increment))
      #|  observe(forward[I64, I64, { Io }](41, increment))
      #|}
    ),
  )
  let expected = [DirectInterpreter, WasmInterpreter, WasmJit].map(backend => {
    backend,
    result: Ok(()),
    i64_values: [42L, 42L],
    f64_bits: [],
    callback_calls: 2,
  })
  assert_eq(actual, expected)
}

///|
test "direct and forwarded elaboration agree across effect representations" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|fn[T, R, Eff : Effect] apply(
      #|  value : T,
      #|  callback : (T) -> R ! Eff
      #|) -> R ! Eff {
      #|  callback(value)
      #|}
      #|
      #|fn[T, R, Eff : Effect] forward(
      #|  value : T,
      #|  callback : (T) -> R ! Eff
      #|) -> R ! Eff {
      #|  apply[T, R, Eff](value, callback)
      #|}
      #|
      #|effect Tick {
      #|  tick(I64) -> I64
      #|}
      #|
      #|enum Box[T] {
      #|  box(T)
      #|}
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
      #|}
      #|
      #|fn[T, R, Eff : Effect] box_map(
      #|  value : Box[T],
      #|  callback : (T) -> R ! Eff
      #|) -> Box[R] ! Eff {
      #|  match value {
      #|    Box::box(inner) => Box::box(callback(inner))
      #|  }
      #|}
      #|
      #|fn[M : [Type] -> Type, T, R, Eff : Effect] forward_map(
      #|  mappable : Mappable[M],
      #|  value : M[T],
      #|  callback : (T) -> R ! Eff
      #|) -> M[R] ! Eff {
      #|  mappable.map(value, callback)
      #|}
      #|
      #|let record_callback : () -> Unit ! Io = extern("lane.test.callback")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn increment(value : I64) -> I64 {
      #|  builtin("%i64_add")(value, 1)
      #|}
      #|
      #|fn increment_io(value : I64) -> I64 ! Io {
      #|  record_callback()
      #|  increment(value)
      #|}
      #|
      #|fn increment_tick(value : I64) -> I64 ! Tick {
      #|  Tick::tick!(value)
      #|}
      #|
      #|fn increment_mixed(value : I64) -> I64 ! { Tick, Io } {
      #|  record_callback()
      #|  Tick::tick!(value)
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe(apply[I64, I64, {}](41, increment))
      #|  observe(forward[I64, I64, {}](41, increment))
      #|  observe(apply[I64, I64, { Io }](41, increment_io))
      #|  observe(forward[I64, I64, { Io }](41, increment_io))
      #|  let direct_tick = handle apply[I64, I64, { Tick }](41, increment_tick) with {
      #|    Tick::tick(value, resume) => resume(increment(value))
      #|  } final value {
      #|    value
      #|  }
      #|  observe(direct_tick)
      #|  let forwarded_tick = handle forward[I64, I64, { Tick }](41, increment_tick) with {
      #|    Tick::tick(value, resume) => resume(increment(value))
      #|  } final value {
      #|    value
      #|  }
      #|  observe(forwarded_tick)
      #|  let direct_mixed = handle apply[I64, I64, { Tick, Io }](41, increment_mixed) with {
      #|    Tick::tick(value, resume) => resume(increment(value))
      #|  } final value {
      #|    value
      #|  }
      #|  observe(direct_mixed)
      #|  let forwarded_mixed = handle forward[I64, I64, { Tick, Io }](41, increment_mixed) with {
      #|    Tick::tick(value, resume) => resume(increment(value))
      #|  } final value {
      #|    value
      #|  }
      #|  observe(forwarded_mixed)
      #|  let mappable : Mappable[Box] = Mappable::{ map: box_map }
      #|  let direct_box = mappable.map[I64, I64, { Io }](Box::box(41), increment_io)
      #|  match direct_box {
      #|    Box::box(value) => observe(value)
      #|  }
      #|  let forwarded_box = forward_map[Box, I64, I64, { Io }](
      #|    mappable,
      #|    Box::box(41),
      #|    increment_io
      #|  )
      #|  match forwarded_box {
      #|    Box::box(value) => observe(value)
      #|  }
      #|}
    ),
  )
  let expected = [DirectInterpreter, WasmInterpreter, WasmJit].map(backend => {
    backend,
    result: Ok(()),
    i64_values: [42L, 42L, 42L, 42L, 42L, 42L, 42L, 42L, 42L, 42L],
    f64_bits: [],
    callback_calls: 6,
  })
  assert_eq(actual, expected)
}
