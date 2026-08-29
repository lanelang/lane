///|
test "dependent initializers execute in term order before entry" {
  let source =
    #|module Test
    #|
    #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
    #|
    #|fn identity(value : I64) -> I64 { value }
    #|
    #|let first : I64 = 40
    #|let second : I64 = identity(first)
    #|let _dead : I64 = 99
    #|
    #|pub fn main() -> Unit ! Io { observe(second) }
  let outcomes = execute_compiler_test_matrix(source)
  assert_eq(outcomes, expected_i64_execution_matrix(40L, 0))
}

///|
test "function-valued initializer retains its producer callable contract" {
  let source =
    #|module Test
    #|
    #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
    #|
    #|let identity : (I64) -> I64 = fn(value) { value }
    #|
    #|pub fn main() -> Unit ! Io { observe(identity(42)) }
  let outcomes = execute_compiler_test_matrix(source)
  assert_eq(outcomes, expected_i64_execution_matrix(42L, 0))
}

///|
test "recursive function groups remain atomic around eager initialization" {
  let source =
    #|module Test
    #|
    #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
    #|
    #|fn first(stop : Bool) -> I64 {
    #|  if stop { 7 } else { second(true) }
    #|}
    #|
    #|fn second(stop : Bool) -> I64 {
    #|  if stop { 8 } else { first(true) }
    #|}
    #|
    #|let started : I64 = first(true)
    #|
    #|pub fn main() -> Unit ! Io { observe(started) }
  let outcomes = execute_compiler_test_matrix(source)
  assert_eq(outcomes, expected_i64_execution_matrix(7L, 0))
}
