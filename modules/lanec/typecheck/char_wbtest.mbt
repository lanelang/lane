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
