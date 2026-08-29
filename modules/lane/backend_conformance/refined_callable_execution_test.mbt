///|
test "refined run_write callable owns its closed result representation" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Semigroup[T] {
      #|  append : (T, T) -> T
      #|}
      #|
      #|struct Monoid[T] {
      #|  semigroup_impl : Semigroup[T]
      #|  empty : T
      #|}
      #|
      #|effect Write[T] {
      #|  write(T) -> Unit
      #|}
      #|
      #|struct WriteResult[A, W] {
      #|  result : A
      #|  log : W
      #|}
      #|
      #|let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
      #|
      #|fn[A, W, E : Effect] run_write(
      #|  action : () -> A ! { Write[W], E },
      #|  monoid_impl : Monoid[W]
      #|) -> () -> WriteResult[A, W] ! E {
      #|  fn() {
      #|    handle action() with {
      #|      write(message, resume) => {
      #|        let rest = resume(())
      #|        WriteResult::{
      #|          result: rest.result,
      #|          log: monoid_impl.semigroup_impl.append(message, rest.log)
      #|        }
      #|      }
      #|    } final result {
      #|      WriteResult[A, W]::{ result, log: monoid_impl.empty }
      #|    }
      #|  }
      #|}
      #|
      #|fn add(left : I64, right : I64) -> I64 {
      #|  i64_add(left, right)
      #|}
      #|
      #|let i64_monoid : Monoid[I64] = Monoid::{
      #|  semigroup_impl: Semigroup::{ append: add },
      #|  empty: 0
      #|}
      #|
      #|fn write_42() -> Unit ! Write[I64] {
      #|  Write[I64]::write!(42)
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let result = run_write[Unit, I64, {}](write_42, i64_monoid)()
      #|  observe(result.log)
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "one generic callable supports two independent refined contracts" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|fn[T] identity(value : T) -> T { value }
      #|
      #|let i64_identity : (I64) -> I64 = identity[I64]
      #|let bool_identity : (Bool) -> Bool = identity[Bool]
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  if bool_identity(true) {
      #|    observe(i64_identity(42))
      #|  } else {
      #|    observe(0)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}
