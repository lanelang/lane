///|
test "typecheck accepts the complete Byte and Bytes builtin contract" {
  let result = expect_checked_source_result(
    (
      #|let byte_to_i64 : (Byte) -> I64 = builtin("%byte_to_i64")
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> I64 = builtin("%bytes_length")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, I64, Byte) -> Bytes = builtin("%bytes_set")
    ),
  )
  assert_eq(result.diagnostics, [])
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects a mismatched Bytes builtin signature" {
  let result = expect_typecheck_result(
    (
      #|let bytes_get : (Bytes) -> I64 = builtin("%bytes_get")
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  builtin_signature_mismatch %bytes_get expected=(Bytes) -> I64 actual=(Bytes, I64) -> Byte @ 2:34-2:55
      #|]
    ),
  )
}
