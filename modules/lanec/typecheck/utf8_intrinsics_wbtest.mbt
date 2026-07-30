///|
test "typecheck accepts the complete Char and UTF-8 intrinsic contract" {
  let result = expect_checked_source_result(
    (
      #|let char_to_i32 : (Char) -> I32 = builtin("%char_to_i32")
      #|let i32_to_char : (I32) -> Char = builtin("%i32_to_char")
      #|let string_to_bytes : (String) -> Bytes = builtin("%string_to_bytes")
      #|let bytes_is_valid_utf8 : (Bytes) -> Bool = builtin("%bytes_is_valid_utf8")
      #|let bytes_to_string : (Bytes) -> String = builtin("%bytes_to_string")
      #|let bytes_equal : (Bytes, Bytes) -> Bool = builtin("%bytes_equal")
      #|let bytes_concat : (Bytes, Bytes) -> Bytes = builtin("%bytes_concat")
      #|let bytes_slice : (Bytes, I64, I64) -> Bytes = builtin("%bytes_slice")
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects removed string equality intrinsic" {
  let result = expect_typecheck_result(
    (
      #|let string_equal : (String, String) -> Bool = builtin("%string_equal")
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unknown_builtin %string_equal @ 2:47-2:71]
    ),
  )
}
