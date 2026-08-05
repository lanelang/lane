///|
test "numeric literal suffix parsing and canonical text share one owner" {
  let suffixes = [@syntax.I32Suffix, I64Suffix, F32Suffix, F64Suffix]
  assert_eq(suffixes.map(fn(suffix) { suffix.canonical_text() }), [
    "i32", "i64", "f32", "f64",
  ])
  for suffix in suffixes {
    assert_eq(
      @syntax.NumericLiteralSuffix::parse(
        suffix.canonical_text(),
        floating=false,
      ),
      Ok(Some(suffix)),
    )
  }
  assert_eq(@syntax.NumericLiteralSuffix::parse("", floating=false), Ok(None))
  assert_eq(
    @syntax.NumericLiteralSuffix::parse("i32foo", floating=false),
    Err(UnknownSuffix),
  )
  assert_eq(
    @syntax.NumericLiteralSuffix::parse("i32", floating=true),
    Err(IntegerSuffixForFloatingBody),
  )
}
