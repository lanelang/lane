///|
test "typecheck accepts the complete F32 builtin contract" {
  let result = expect_checked_source_result(
    (
      #|let f32_add : (F32, F32) -> F32 = builtin("%f32_add")
      #|let f32_sub : (F32, F32) -> F32 = builtin("%f32_sub")
      #|let f32_mul : (F32, F32) -> F32 = builtin("%f32_mul")
      #|let f32_div : (F32, F32) -> F32 = builtin("%f32_div")
      #|let f32_neg : (F32) -> F32 = builtin("%f32_neg")
      #|let f32_equal : (F32, F32) -> Bool = builtin("%f32_equal")
      #|let f32_less : (F32, F32) -> Bool = builtin("%f32_less")
      #|let f32_inf : F32 = builtin("%f32_inf")
      #|let f32_ninf : F32 = builtin("%f32_ninf")
      #|let f32_nan : F32 = builtin("%f32_nan")
      #|let i64_to_f32 : (I64) -> F32 = builtin("%i64_to_f32")
      #|let f32_to_i64 : (F32) -> I64 = builtin("%f32_to_i64")
      #|let f32_to_f64 : (F32) -> F64 = builtin("%f32_to_f64")
      #|let f64_to_f32 : (F64) -> F32 = builtin("%f64_to_f32")
      #|
      #|fn identity(value : F32) -> F32 {
      #|  value
      #|}
      #|
      #|fn is_zero(value : F32) -> Bool {
      #|  match value {
      #|    0.0 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|let rounded : F32 = identity(0.1)
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects F32 overflow and underflow literals" {
  let result = expect_typecheck_result(
    (
      #|let overflow : F32 = 3.5e38
      #|let underflow : F32 = 1.0e-50
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[invalid_f32_literal 3.5e38 @ 2:22-2:28, invalid_f32_literal 1.0e-50 @ 3:23-3:30]
    ),
  )
}

///|
test "typecheck keeps F32 distinct from I32 and F64" {
  let result = expect_typecheck_result(
    (
      #|let value : F32 = 1.0
      #|let wider : F64 = value
      #|let integer : I32 = value
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  type_mismatch expected=F64 actual=F32 @ 3:19-3:24,
      #|  type_mismatch expected=I32 actual=F32 @ 4:21-4:26
      #|]
    ),
  )
}
