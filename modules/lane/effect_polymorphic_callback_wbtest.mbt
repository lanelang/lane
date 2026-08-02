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
