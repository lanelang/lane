///|
test "I64 and F64 conversion intrinsics execute consistently across backends" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|let i64_to_f64 : (I64) -> F64 = builtin("%i64_to_f64")
      #|let f64_to_i64 : (F64) -> I64 = builtin("%f64_to_i64")
      #|let observe_i64 : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe_i64")
      #|let observe_f64 : (F64) -> Unit ! Io = extern("lane.test", "lane.test.observe_f64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe_f64(i64_to_f64(42))
      #|  observe_i64(f64_to_i64(42.75))
      #|}
    ),
  )
  assert_eq(actual, [
    {
      backend: WasmInterpreter,
      result: Ok(()),
      i64_values: [42L],
      f64_bits: [0x4045000000000000UL],
      callback_calls: 0,
    },
    {
      backend: WasmJit,
      result: Ok(()),
      i64_values: [42L],
      f64_bits: [0x4045000000000000UL],
      callback_calls: 0,
    },
  ])
}
