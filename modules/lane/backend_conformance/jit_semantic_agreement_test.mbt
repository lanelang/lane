///|
test "higher-kinded top-level callable flow agrees across execution backends" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Box[T] {
      #|  box(T)
      #|}
      #|
      #|struct Mappable[M : [Type] -> Type] {
      #|  map : [T, R]((T) -> R, M[T]) -> M[R]
      #|}
      #|
      #|fn[T, R] box_map(callback : (T) -> R, box : Box[T]) -> Box[R] {
      #|  match box {
      #|    Box::box(value) => Box::box(callback(value))
      #|  }
      #|}
      #|
      #|fn increment(value : I64) -> I64 {
      #|  builtin("%i64_add")(value, 1)
      #|}
      #|
      #|let mappable : Mappable[Box] = Mappable::{ map: box_map }
      #|let mapped : Box[I64] = mappable.map(increment, Box::box(41))
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  match mapped {
      #|    Box::box(value) => observe(value)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "rounded F32 operations agree across execution backends" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|let f32_equal : (F32, F32) -> Bool = builtin("%f32_equal")
      #|let f32_to_f64 : (F32) -> F64 = builtin("%f32_to_f64")
      #|let observe : (F64) -> Unit ! Io = extern("lane.test.observe_f64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let rounded : F32 = 1.000000059604644775400625f32
      #|  let next_after_one : F32 = 1.00000011920928955078125f32
      #|  if f32_equal(rounded, next_after_one) {
      #|    observe(f32_to_f64(rounded))
      #|  } else {
      #|    observe(0.0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, [
    {
      backend: DirectInterpreter,
      result: Ok(()),
      i64_values: [],
      f64_bits: [0x3ff0000020000000UL],
      callback_calls: 0,
    },
    {
      backend: WasmInterpreter,
      result: Ok(()),
      i64_values: [],
      f64_bits: [0x3ff0000020000000UL],
      callback_calls: 0,
    },
    {
      backend: WasmJit,
      result: Ok(()),
      i64_values: [],
      f64_bits: [0x3ff0000020000000UL],
      callback_calls: 0,
    },
  ])
}

///|
test "existential ADT operations agree across execution backends" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct IntegerSet {
      #|  type Set
      #|  empty : Set
      #|  insert : (Set, I64) -> Set
      #|  contains : (Set, I64) -> Bool
      #|}
      #|
      #|enum Chain {
      #|  empty()
      #|  inserted(I64, Chain)
      #|}
      #|
      #|fn insert(set : Chain, value : I64) -> Chain {
      #|  inserted(value, set)
      #|}
      #|
      #|fn contains(set : Chain, value : I64) -> Bool {
      #|  match set {
      #|    empty() => false
      #|    inserted(head, tail) =>
      #|      if builtin("%i64_equal")(head, value) {
      #|        true
      #|      } else {
      #|        contains(tail, value)
      #|      }
      #|  }
      #|}
      #|
      #|let integer_set : IntegerSet = IntegerSet::{
      #|  Set = Chain,
      #|  empty: Chain::empty(),
      #|  insert,
      #|  contains,
      #|}
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let IntegerSet::{ Set, empty, insert, contains } = integer_set
      #|  let values : Set = insert(insert(empty, 41), 42)
      #|  if contains(values, 42) {
      #|    observe(42)
      #|  } else {
      #|    observe(0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}
