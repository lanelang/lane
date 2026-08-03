///|
test "type normalization accepts deeply nested inert structure" {
  let mut type_ = @buslane.Type::Primitive(Unit)
  for _ in 0..<1100 {
    type_ = Forall([], type_)
  }
  assert_eq(type_.normalize(), type_)
}

///|
fn non_normalizing_type_application(
  parameter : @buslane.TypeParameterId,
) -> @buslane.Type {
  let self_application = @buslane.Type::TypeLambda(
    [parameter],
    Apply(Parameter(parameter), [TypeArgument(Parameter(parameter))]),
  )
  Apply(self_application, [TypeArgument(self_application)])
}

///|
test "type normalization reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  try type_.normalize() catch {
    BetaReductionLimitExceeded(limit~) => assert_eq(limit, 1024)
    error => fail("unexpected normalization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected beta reduction to exhaust its budget")
  }
}

///|
test "program verifier diagnoses runaway type normalization" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  let value = metadata.define_value("value", Value, type_)
  let result = @buslane.verify_program({
    metadata,
    terms: [Let(value, Literal(Unit))],
  })
  assert_eq(result.diagnostics(), [
    { kind: KindMismatch(expected=Function([], Type), actual=Type) },
    { kind: KindMismatch(expected=Function([], Type), actual=Type) },
    { kind: KindMismatch(expected=Type, actual=Function([Type], Type)) },
    { kind: TypeNormalizationFailure(BetaReductionLimitExceeded(limit=1024)) },
    { kind: TypeMismatch(expected=type_, actual=Primitive(Unit)) },
  ])
}
