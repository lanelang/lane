///|
test "typecheck accepts the I64 signed range including its minimum" {
  // `9223372036854775808` is not an I64 value, so the minimum is only writable
  // when negation is checked together with the literal it negates.
  let source =
    #|let op_neg : (I64) -> I64 = builtin("%i64_neg")
    #|let maximum : I64 = 9223372036854775807
    #|let minimum : I64 = -9223372036854775808
    #|let ordinary : I64 = -42
    #|fn is_minimum(value : I64) -> Bool {
    #|  match value {
    #|    -9223372036854775808 => true
    #|    _ => false
    #|  }
    #|}
  let result = expect_checked_source_result(source)
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects an I64 literal below the signed range" {
  let source =
    #|let op_neg : (I64) -> I64 = builtin("%i64_neg")
    #|let invalid : I64 = -9223372036854775809
  let result = expect_typecheck_result(source)
  assert_true(
    result.diagnostics
    is [{ kind: InvalidI64Literal("-9223372036854775809"), .. }],
  )
}

///|
test "typecheck rejects an unnegated I64 literal above the signed range" {
  let source =
    #|let invalid : I64 = 9223372036854775808
  let result = expect_typecheck_result(source)
  assert_true(
    result.diagnostics
    is [{ kind: InvalidI64Literal("9223372036854775808"), .. }],
  )
}
