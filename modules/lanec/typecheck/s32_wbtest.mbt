///|
test "typecheck accepts the complete S32 builtin contract" {
  let result = expect_checked_source_result(
    (
      #|let add : (S32, S32) -> S32 = builtin("%i32_add")
      #|let sub : (S32, S32) -> S32 = builtin("%i32_sub")
      #|let mul : (S32, S32) -> S32 = builtin("%i32_mul")
      #|let div : (S32, S32) -> S32 = builtin("%i32_div")
      #|let rem : (S32, S32) -> S32 = builtin("%i32_rem")
      #|let op_neg : (S32) -> S32 = builtin("%i32_neg")
      #|let equal : (S32, S32) -> Bool = builtin("%i32_equal")
      #|let less : (S32, S32) -> Bool = builtin("%i32_less")
      #|let to_int : (S32) -> Int = builtin("%s32_to_int")
      #|let from_int : (Int) -> S32 = builtin("%int_to_s32")
      #|let maximum : S32 = 2147483647
      #|let minimum : S32 = -2147483648
      #|fn is_minimum(value : S32) -> Bool {
      #|  match value {
      #|    -2147483648 => true
      #|    _ => false
      #|  }
      #|}
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects an S32 literal below the signed range" {
  let result = expect_typecheck_result(
    (
      #|let op_neg : (S32) -> S32 = builtin("%i32_neg")
      #|let invalid : S32 = -2147483649
    ),
  )
  assert_true(
    result.diagnostics is [{ kind: InvalidS32Literal("-2147483649"), .. }],
  )
}

///|
test "typecheck rejects an out-of-range S32 literal" {
  let result = expect_typecheck_result(
    (
      #|let invalid : S32 = 2147483648
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InvalidS32Literal("2147483648"),
      #|    loc: {
      #|      start_offset: 32,
      #|      end_offset: 42,
      #|      start_line: 2,
      #|      start_column: 21,
      #|      end_line: 2,
      #|      end_column: 31,
      #|    },
      #|  },
      #|]
    ),
  )
}
