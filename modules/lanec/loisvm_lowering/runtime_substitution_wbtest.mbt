///|
test "runtime substitution does not expand a recursive replacement" {
  let parameter : @anf.RuntimeEvidenceParameter = { id: { index: 0 }, arity: 0 }
  let parameter_expression : @anf.RuntimeTypeExpressionId = { index: 0 }
  let box_expression : @anf.RuntimeTypeExpressionId = { index: 1 }
  let box : @buslane.TypeId = { index: 0 }
  let recursive_argument : @anf.RuntimeArgument = {
    type_expression: parameter_expression,
    evidence: Parameter(parameter.id),
  }
  let metadata : @anf.RuntimeMetadata = {
    values: [],
    types: [{ kind: Data, evidence_parameters: [parameter], constructors: [] }],
    data_constructors: [],
    evidence_parameters: [Some(parameter)],
    type_expressions: [
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
      metadata,
      Erased(parameter_expression, Parameter(parameter.id)),
    ),
    Data(box, [recursive_argument]),
  )
}
