///|
test "deferred generic application preserves its producer ABI" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum List[T] {
      #|  empty()
      #|  cons(T, List[T])
      #|}
      #|
      #|fn[T, R] fold_right(
      #|  combine : (T, R) -> R,
      #|  initial : R,
      #|  values : List[T]
      #|) -> R {
      #|  match values {
      #|    empty() => initial
      #|    cons(head, tail) => combine(head, fold_right(combine, initial, tail))
      #|  }
      #|}
      #|
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let values = List[I64]::cons(40, List[I64]::cons(2, List[I64]::empty()))
      #|  observe(fold_right[I64, I64](add, 0, values))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "applying an existing generic closure preserves its captures" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Applied {
      #|  apply : (I64) -> I64
      #|}
      #|
      #|fn captured_identity(captured : I64) -> [T](T) -> T {
      #|  fn[T](value) {
      #|    let _ = captured
      #|    value
      #|  }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let generic = captured_identity(7)
      #|  let applied = Applied::{ apply: generic[I64] }
      #|  observe(applied.apply(42))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}
