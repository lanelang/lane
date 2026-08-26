///|
test "runtime substitution does not expand a recursive replacement" {
  let parameter : @anf.RuntimeEvidenceParameter = {
    id: Projected(0),
    arity: 0,
  }
  let parameter_expression : @anf.RuntimeTypeExpressionId = { index: 0, }
  let box_expression : @anf.RuntimeTypeExpressionId = { index: 1, }
  let box : @buslane.TypeId = { index: 0, }
  let recursive_argument : @anf.RuntimeArgument = {
    type_expression: parameter_expression,
    evidence: Parameter(parameter.id),
  }
  let runtime_types : RuntimeTypeArena = {
    expressions: [
      Parameter(parameter.id),
      Static(Data(box, [recursive_argument])),
    ],
  }
  let substitution = RuntimeSubstitution::new()
  substitution.insert(parameter.id, {
    type_expression: box_expression,
    evidence: Static(Reference),
  })
  assert_eq(
    substitution.apply_type(
      runtime_types,
      Erased(parameter_expression, Parameter(parameter.id)),
    ),
    Data(box, [recursive_argument]),
  )
}

///|
test "projected and synthetic evidence identities cannot collide" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  ignore(
    metadata.define_value(
      "value",
      Function,
      Forall([parameter], Parameter(parameter)),
    ),
  )
  let image = test_image_lowerer(metadata)
  let projected = @anf.RuntimeEvidenceId::Projected(parameter.index)
  let synthetic = image.fresh_synthetic_parameter()
  assert_false(projected == synthetic)
  assert_true(image.evidence_parameter(projected) is Some({ arity: 0, .. }))
  assert_true(image.evidence_parameter(synthetic) is Some({ arity: 0, .. }))
  assert_true(image.metadata.evidence_parameter(synthetic) is None)
}

///|
test "Physical-Lowering-derived type expressions do not mutate Runtime ANF metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let image = test_image_lowerer(metadata)
  let original_count = image.metadata.type_expressions().length()
  ignore(image.runtime_types.intern(Static(Scalar(I64))))
  assert_eq(image.metadata.type_expressions().length(), original_count)
  assert_eq(image.runtime_types.expressions.length(), original_count + 1)
}
