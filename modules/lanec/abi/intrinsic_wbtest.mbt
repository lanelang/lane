///|
fn expected_direct_intrinsic(
  parameters~ : Array[IntrinsicType],
  result~ : IntrinsicType,
) -> IntrinsicSignature {
  Function(
    type_parameters=[],
    parameters~,
    result~,
    effect=Pure,
    implementation=Direct,
  )
}

///|
test "panic intrinsic owns its exact Panic signature" {
  assert_eq(
    (
      Intrinsic::from_name("%panic"),
      Intrinsic::Panic.name(),
      Intrinsic::Panic.signature(),
    ),
    (
      Some(Panic),
      "%panic",
      Function(
        type_parameters=[],
        parameters=[String],
        result=CanonicalBasicVoid,
        effect=BuiltinPanic,
        implementation=Fatal(message_parameter=0),
      ),
    ),
  )
}

///|
test "Bytes indexing has one precondition-based intrinsic contract" {
  assert_eq(
    (
      [
        (BytesGet.name(), BytesGet.signature()),
        (BytesSet.name(), BytesSet.signature()),
      ],
      [
        Intrinsic::from_name("%bytes_get_unchecked"),
        Intrinsic::from_name("%bytes_set_unchecked"),
      ],
    ),
    (
      [
        (
          "%bytes_get",
          expected_direct_intrinsic(parameters=[Bytes, I64], result=Byte),
        ),
        (
          "%bytes_set",
          expected_direct_intrinsic(parameters=[Bytes, I64, Byte], result=Bytes),
        ),
      ],
      [None, None],
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
      ("%char_to_i32", expected_direct_intrinsic(parameters=[Char], result=I32)),
      ("%i32_to_char", expected_direct_intrinsic(parameters=[I32], result=Char)),
      (
        "%string_to_bytes",
        expected_direct_intrinsic(parameters=[String], result=Bytes),
      ),
      (
        "%bytes_is_valid_utf8",
        expected_direct_intrinsic(parameters=[Bytes], result=Bool),
      ),
      (
        "%bytes_to_string",
        expected_direct_intrinsic(parameters=[Bytes], result=String),
      ),
      (
        "%bytes_equal",
        expected_direct_intrinsic(parameters=[Bytes, Bytes], result=Bool),
      ),
      (
        "%bytes_concat",
        expected_direct_intrinsic(parameters=[Bytes, Bytes], result=Bytes),
      ),
      (
        "%bytes_slice",
        expected_direct_intrinsic(parameters=[Bytes, I64, I64], result=Bytes),
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
        ("%i64_to_f64", expected_direct_intrinsic(parameters=[I64], result=F64)),
        ("%f64_to_i64", expected_direct_intrinsic(parameters=[F64], result=I64)),
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
          expected_direct_intrinsic(parameters=[F32], result=String),
        ),
        (
          "%f64_to_string",
          expected_direct_intrinsic(parameters=[F64], result=String),
        ),
      ],
    ),
  )
}

///|
test "WASI fd_write bridge owns its exact effectful signature" {
  assert_eq(
    (
      Intrinsic::from_name("%wasi_fd_write"),
      WasiFdWrite.name(),
      WasiFdWrite.signature(),
    ),
    (
      Some(WasiFdWrite),
      "%wasi_fd_write",
      Function(
        type_parameters=[],
        parameters=[I32, Bytes],
        result=I32,
        effect=BuiltinIo,
        implementation=Direct,
      ),
    ),
  )
}

///|
test "Array intrinsics own one closed polymorphic contract" {
  let array = Apply(Array, [Parameter(0)])
  assert_eq(
    [
      (ArrayEmpty.name(), ArrayEmpty.signature()),
      (ArrayMake.name(), ArrayMake.signature()),
      (ArrayLength.name(), ArrayLength.signature()),
      (ArrayGet.name(), ArrayGet.signature()),
      (ArraySet.name(), ArraySet.signature()),
    ],
    [
      (
        "%array_empty",
        Function(
          type_parameters=[Type],
          parameters=[],
          result=array,
          effect=Pure,
          implementation=Direct,
        ),
      ),
      (
        "%array_make",
        Function(
          type_parameters=[Type],
          parameters=[I64, Parameter(0)],
          result=array,
          effect=Pure,
          implementation=Direct,
        ),
      ),
      (
        "%array_length",
        Function(
          type_parameters=[Type],
          parameters=[array],
          result=I64,
          effect=Pure,
          implementation=Direct,
        ),
      ),
      (
        "%array_get",
        Function(
          type_parameters=[Type],
          parameters=[array, I64],
          result=Parameter(0),
          effect=Pure,
          implementation=Direct,
        ),
      ),
      (
        "%array_set",
        Function(
          type_parameters=[Type],
          parameters=[array, I64, Parameter(0)],
          result=array,
          effect=Pure,
          implementation=Direct,
        ),
      ),
    ],
  )
}
