///|
test "typecheck accepts the complete Byte and Bytes builtin contract" {
  let result = expect_checked_source_result(
    (
      #|let byte_to_int : (Byte) -> Int = builtin("%byte_to_int")
      #|let int_to_byte : (Int) -> Byte = builtin("%int_to_byte")
      #|let bytes_make : (Int, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> Int = builtin("%bytes_length")
      #|let bytes_get : (Bytes, Int) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, Int, Byte) -> Bytes = builtin("%bytes_set")
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  assert_true(result.source is Some(_))
}

///|
test "typecheck rejects a mismatched Bytes builtin signature" {
  let result = expect_typecheck_result(
    (
      #|let bytes_get : (Bytes) -> Int = builtin("%bytes_get")
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  builtin_signature_mismatch %bytes_get expected=(Bytes) -> Int actual=(Bytes, Int) -> Byte @ 2:34-2:55
      #|]
    ),
  )
}
