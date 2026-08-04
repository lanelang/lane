///|
priv enum FloatLiteralBits {
  F64Bits(UInt64)
  F32Bits(UInt)
} derive(Debug, Eq)

///|
fn float_literal_program(
  literal : @buslane.Literal,
) -> @buslane.Program raise @buslane.MetadataAllocationError {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_ = match literal {
    F64(_) => @buslane.Type::Primitive(F64)
    F32(_) => Primitive(F32)
    _ => abort("expected floating literal")
  }
  let value = metadata.define_value("value", Value, type_)
  { metadata, terms: [Let(value, Literal(literal))] }
}

///|
fn float_literal_bits(literal : @buslane.Literal) -> FloatLiteralBits {
  match literal {
    F64(value) => F64Bits(value.reinterpret_as_uint64())
    F32(value) => F32Bits(value.reinterpret_as_uint())
    _ => abort("expected floating literal")
  }
}

///|
fn roundtrip_float_literal(
  writer : CanonicalTextWriter,
  literal : @buslane.Literal,
) -> FloatLiteralBits raise @buslane.MetadataAllocationError {
  let text = writer.write_program(float_literal_program(literal))
  let decoded = match parse_program_text(text) {
    Ok(program) => program
    Err(message) => abort(message + "\n" + text)
  }
  guard decoded.terms is [Let(_, Literal(decoded_literal))] else {
    abort("expected one decoded floating literal")
  }
  float_literal_bits(decoded_literal)
}

///|
test "canonical Buslane float text uses fixed-width hexadecimal bits" {
  assert_eq(
    (
      @prettyprinter.render(@buslane.Literal::pretty(F64(42.0)), width=100),
      @prettyprinter.render(
        @buslane.Literal::pretty(F32(Float::reinterpret_from_uint(0xFFC00042U))),
        width=100,
      ),
    ),
    ("f64(0x4045000000000000)", "f32(0xffc00042)"),
  )
}

///|
test "canonical Buslane float text roundtrips every IEEE value class" {
  let writer = CanonicalTextWriter::CanonicalTextWriter()
  let f64_bits : Array[UInt64] = [
    0UL, 0x8000000000000000UL, 0x4045000000000000UL, 1UL, 0x7FF0000000000000UL, 0xFFF0000000000000UL,
    0x7FF8000000000001UL, 0xFFF8000000000042UL,
  ]
  let f32_bits : Array[UInt] = [
    0U, 0x80000000U, 0x42280000U, 1U, 0x7F800000U, 0xFF800000U, 0x7FC00001U, 0xFFC00042U,
  ]
  let actual = f64_bits.map(bits => {
      roundtrip_float_literal(writer, F64(bits.reinterpret_as_double()))
    }) +
    f32_bits.map(bits => {
      roundtrip_float_literal(writer, F32(Float::reinterpret_from_uint(bits)))
    })
  let expected = f64_bits.map(bits => F64Bits(bits)) +
    f32_bits.map(bits => F32Bits(bits))
  assert_eq(actual, expected)
}
