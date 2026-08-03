///|
test "extended stage verification retains the producer boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(Unit))
  let program : @effect_lowering_core.Program = {
    metadata,
    terms: [Let(value, Literal(I64(42L)))],
  }
  try require_extended_verified("handler elaboration", program) catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|UnverifiedProgram(
          #|  stage="handler elaboration",
          #|  result={
          #|    diagnostics: [
          #|      {
          #|        kind: TypeMismatch(expected=Primitive(Unit), actual=Primitive(I64)),
          #|        provenance: [TopTerm({ index: 0 })],
          #|      },
          #|    ],
          #|  },
          #|)
        ),
      )
  } noraise {
    _ => fail("expected extended stage verification to fail")
  }
}
