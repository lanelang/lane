///|
test "UTF-8 and Char intrinsics have one exact name and signature" {
  assert_eq(
    [
      Intrinsic::from_name("%char_to_i32"),
      Intrinsic::from_name("%i32_to_char"),
      Intrinsic::from_name("%string_to_bytes"),
      Intrinsic::from_name("%bytes_is_valid_utf8"),
      Intrinsic::from_name("%bytes_to_string"),
      Intrinsic::from_name("%bytes_equal"),
      Intrinsic::from_name("%bytes_concat"),
      Intrinsic::from_name("%bytes_slice"),
      Intrinsic::from_name("%string_equal"),
    ],
    [
      Some(CharToI32),
      Some(I32ToChar),
      Some(StringToBytes),
      Some(BytesIsValidUtf8),
      Some(BytesToString),
      Some(BytesEqual),
      Some(BytesConcat),
      Some(BytesSlice),
      None,
    ],
  )
  assert_eq(
    [
      (CharToI32.name(), CharToI32.signature()),
      (I32ToChar.name(), I32ToChar.signature()),
      (StringToBytes.name(), StringToBytes.signature()),
      (BytesIsValidUtf8.name(), BytesIsValidUtf8.signature()),
      (BytesToString.name(), BytesToString.signature()),
      (BytesEqual.name(), BytesEqual.signature()),
      (BytesConcat.name(), BytesConcat.signature()),
      (BytesSlice.name(), BytesSlice.signature()),
    ],
    [
      ("%char_to_i32", Function(parameters=[Char], result=I32)),
      ("%i32_to_char", Function(parameters=[I32], result=Char)),
      ("%string_to_bytes", Function(parameters=[String], result=Bytes)),
      ("%bytes_is_valid_utf8", Function(parameters=[Bytes], result=Bool)),
      ("%bytes_to_string", Function(parameters=[Bytes], result=String)),
      ("%bytes_equal", Function(parameters=[Bytes, Bytes], result=Bool)),
      ("%bytes_concat", Function(parameters=[Bytes, Bytes], result=Bytes)),
      ("%bytes_slice", Function(parameters=[Bytes, I64, I64], result=Bytes)),
    ],
  )
}
