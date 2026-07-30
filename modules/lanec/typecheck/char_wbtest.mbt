///|
test "typecheck accepts Unicode character literals and patterns" {
  let result = expect_checked_source_result(
    (
      #|fn classify(value : Char) -> Char {
      #|  match value {
      #|    '你' => '😀'
      #|    _ => '\0'
      #|  }
      #|}
      #|let greeting : String = "你好😀"
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "type mismatch diagnostics preserve I32 and Char identity" {
  let result = expect_typecheck_result("let invalid : I32 = '你'")
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: TypeMismatch(expected=Primitive(I32), actual=Primitive(Char)),
      #|    loc: {
      #|      start_offset: 32,
      #|      end_offset: 35,
      #|      start_line: 2,
      #|      start_column: 21,
      #|      end_line: 2,
      #|      end_column: 24,
      #|    },
      #|  },
      #|]
    ),
  )
}
