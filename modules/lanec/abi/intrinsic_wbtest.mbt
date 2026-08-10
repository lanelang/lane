///|
test "panic intrinsic owns its exact Io signature" {
  assert_eq(
    (Intrinsic::from_name("%panic"), Panic.name(), Panic.signature()),
    (
      Some(Panic),
      "%panic",
      Function(parameters=[String], result=Unit, effect=Io),
    ),
  )
}

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
      ("%char_to_i32", Function(parameters=[Char], result=I32, effect=Pure)),
      ("%i32_to_char", Function(parameters=[I32], result=Char, effect=Pure)),
      (
        "%string_to_bytes",
        Function(parameters=[String], result=Bytes, effect=Pure),
      ),
      (
        "%bytes_is_valid_utf8",
        Function(parameters=[Bytes], result=Bool, effect=Pure),
      ),
      (
        "%bytes_to_string",
        Function(parameters=[Bytes], result=String, effect=Pure),
      ),
      (
        "%bytes_equal",
        Function(parameters=[Bytes, Bytes], result=Bool, effect=Pure),
      ),
      (
        "%bytes_concat",
        Function(parameters=[Bytes, Bytes], result=Bytes, effect=Pure),
      ),
      (
        "%bytes_slice",
        Function(parameters=[Bytes, I64, I64], result=Bytes, effect=Pure),
      ),
    ],
  )
}

///|
test "I64 and F64 conversion intrinsics have exact names and signatures" {
  assert_eq(
    (
      [Intrinsic::from_name("%i64_to_f64"), Intrinsic::from_name("%f64_to_i64")],
      [
        (I64ToF64.name(), I64ToF64.signature()),
        (F64ToI64.name(), F64ToI64.signature()),
      ],
    ),
    (
      [Some(I64ToF64), Some(F64ToI64)],
      [
        ("%i64_to_f64", Function(parameters=[I64], result=F64, effect=Pure)),
        ("%f64_to_i64", Function(parameters=[F64], result=I64, effect=Pure)),
      ],
    ),
  )
}

///|
test "floating-point string intrinsics have exact names and signatures" {
  assert_eq(
    (
      [
        Intrinsic::from_name("%f32_to_string"),
        Intrinsic::from_name("%f64_to_string"),
      ],
      [
        (F32ToString.name(), F32ToString.signature()),
        (F64ToString.name(), F64ToString.signature()),
      ],
    ),
    (
      [Some(F32ToString), Some(F64ToString)],
      [
        (
          "%f32_to_string",
          Function(parameters=[F32], result=String, effect=Pure),
        ),
        (
          "%f64_to_string",
          Function(parameters=[F64], result=String, effect=Pure),
        ),
      ],
    ),
  )
}
