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
      #|    0.0f32 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|let rounded : F32 = identity(0.1f32)
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "F32 literal rounds directly from the authored decimal" {
  let expression = expect_checked_let_initializer(
    "let rounded : F32 = 1.000000059604644775400625f32",
    "rounded",
    Primitive(F32),
  )
  guard expression is Literal(literal=F32(literal), ..) else {
    abort("expected a checked F32 literal")
  }
  assert_eq(literal.value.reinterpret_as_int(), 1065353217)
}

///|
test "F32 literal preserves zero signs subnormals and ties-to-even" {
  for
    case in [
      ("0f32", 0),
      ("-0f32", -2147483648),
      ("1.40129846e-45f32", 1),
      ("1.000000059604644775390625f32", 1065353216),
    ] {
    let (spelling, expected_bits) = case
    let expression = expect_checked_let_initializer(
      "let value : F32 = " + spelling,
      "value",
      Primitive(F32),
    )
    guard expression is Literal(literal=F32(literal), ..) else {
      abort("expected a checked F32 literal")
    }
    assert_eq(literal.value.reinterpret_as_int(), expected_bits)
  }
}

///|
test "typecheck rejects F32 overflow and underflow literals" {
  let result = expect_typecheck_result(
    (
      #|let overflow : F32 = 3.5e38f32
      #|let underflow : F32 = 1.0e-50f32
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[invalid_f32_literal 3.5e38 @ 2:22-2:31, invalid_f32_literal 1.0e-50 @ 3:23-3:33]
    ),
  )
}

///|
test "typecheck keeps F32 distinct from I32 and F64" {
  let result = expect_typecheck_result(
    (
      #|let value : F32 = 1.0f32
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
