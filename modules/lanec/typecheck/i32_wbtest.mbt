///|
test "typecheck accepts the complete I32 builtin contract" {
  let result = expect_checked_source_result(
    (
      #|let add : (I32, I32) -> I32 = builtin("%i32_add")
      #|let sub : (I32, I32) -> I32 = builtin("%i32_sub")
      #|let mul : (I32, I32) -> I32 = builtin("%i32_mul")
      #|let div : (I32, I32) -> I32 = builtin("%i32_div")
      #|let rem : (I32, I32) -> I32 = builtin("%i32_rem")
      #|let equal : (I32, I32) -> Bool = builtin("%i32_equal")
      #|let less : (I32, I32) -> Bool = builtin("%i32_less")
      #|let to_int : (I32) -> I64 = builtin("%i32_to_i64")
      #|let from_int : (I64) -> I32 = builtin("%i64_to_i32")
      #|let maximum : I32 = 2147483647i32
      #|let minimum : I32 = -2147483648i32
      #|fn is_minimum(value : I32) -> Bool {
      #|  match value {
      #|    -2147483648i32 => true
      #|    _ => false
      #|  }
      #|}
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects an I32 literal below the signed range" {
  let result = expect_typecheck_result(
    (
      #|let invalid : I32 = -2147483649i32
    ),
  )
  assert_true(
    result.diagnostics is [{ kind: InvalidI32Literal("-2147483649"), .. }],
  )
}

///|
test "typecheck rejects an out-of-range I32 literal" {
  let result = expect_typecheck_result(
    (
      #|let invalid : I32 = 2147483648i32
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InvalidI32Literal("2147483648"),
      #|    loc: {
      #|      start_offset: 32,
      #|      end_offset: 45,
      #|      start_line: 2,
      #|      start_column: 21,
      #|      end_line: 2,
      #|      end_column: 34,
      #|    },
      #|  },
      #|]
    ),
  )
}
