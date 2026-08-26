///|
test "F32 formatting is shortest and preserves floating spelling" {
  assert_eq(@float_format.format_f32(0.0F), "0.0")
  assert_eq(@float_format.format_f32(-0.0F), "-0.0")
  assert_eq(@float_format.format_f32(1.0F), "1.0")
  assert_eq(@float_format.format_f32(0.1F), "0.1")
  assert_eq(@float_format.format_f32(Float::reinterpret_from_int(1)), "1e-45")
  assert_eq(
    @float_format.format_f32(Float::reinterpret_from_int(0x7f7fffff)),
    "3.4028235e+38",
  )
}

///|
test "F32 formatting handles non-finite values" {
  assert_eq(
    @float_format.format_f32(Float::reinterpret_from_int(0x7f800000)),
    "inf",
  )
  assert_eq(
    @float_format.format_f32(Float::reinterpret_from_int(0xff800000)),
    "-inf",
  )
  assert_eq(
    @float_format.format_f32(Float::reinterpret_from_int(0x7fc00001)),
    "NaN",
  )
  assert_eq(
    @float_format.format_f32(Float::reinterpret_from_int(0xffc00001)),
    "NaN",
  )
}

///|
test "F64 formatting is shortest and preserves floating spelling" {
  assert_eq(@float_format.format_f64(0.0), "0.0")
  assert_eq(@float_format.format_f64(-0.0), "-0.0")
  assert_eq(@float_format.format_f64(1.0), "1.0")
  assert_eq(@float_format.format_f64(0.1), "0.1")
  assert_eq(@float_format.format_f64(1L.reinterpret_as_double()), "5e-324")
  assert_eq(
    @float_format.format_f64(0x7fefffffffffffffL.reinterpret_as_double()),
    "1.7976931348623157e+308",
  )
}

///|
test "F64 formatting handles non-finite values" {
  assert_eq(
    @float_format.format_f64(0x7ff0000000000000UL.reinterpret_as_double()),
    "inf",
  )
  assert_eq(
    @float_format.format_f64(0xfff0000000000000UL.reinterpret_as_double()),
    "-inf",
  )
  assert_eq(
    @float_format.format_f64(0x7ff8000000000001UL.reinterpret_as_double()),
    "NaN",
  )
  assert_eq(
    @float_format.format_f64(0xfff8000000000001UL.reinterpret_as_double()),
    "NaN",
  )
}

///|
test "F32 Ryū boundary and regression corpus" {
  let cases : Array[(Float, String)] = [
    (33554450.0F, "33554450.0"),
    (9000000000.0F, "9000000000.0"),
    (34366720000.0F, "34366720000.0"),
    (305404.12F, "305404.12"),
    (8099.0312F, "8099.0312"),
    (0.00024414062F, "0.00024414062"),
    (0.0024414062F, "0.0024414062"),
    (0.0043945312F, "0.0043945312"),
    (0.0063476562F, "0.0063476562"),
    (4.7223665e21F, "4.7223665e+21"),
    (1.9310392e-38F, "1.9310392e-38"),
    (-2.47e-43F, "-2.47e-43"),
    (4103.9004F, "4103.9004"),
    (6.0898e-39F, "6.0898e-39"),
    (1.00014165e-36F, "1.00014165e-36"),
  ]
  for case in cases {
    let (value, expected) = case
    assert_eq(@float_format.format_f32(value), expected)
  }
}
