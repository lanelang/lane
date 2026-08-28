///|
test "runtime arguments compare higher-kinded binders modulo alpha renaming" {
  let left = RuntimeEvidenceId::Projected(0)
  let right = RuntimeEvidenceId::Projected(1)
  let expressions : Array[RuntimeTypeExpression] = [
    Parameter(left),
    Lambda([{ id: left, arity: 0, }], { index: 0, }),
    Parameter(right),
    Lambda([{ id: right, arity: 0, }], { index: 2, }),
    Static(Unit),
    Lambda([{ id: right, arity: 0, }], { index: 4, }),
  ]
  let lookup = fn(id : RuntimeTypeExpressionId) { expressions.get(id.index) }
  let left_argument : RuntimeArgument = {
    type_expression: { index: 1, },
    evidence: Lambda([{ id: left, arity: 0, }], Parameter(left)),
  }
  let renamed_argument : RuntimeArgument = {
    type_expression: { index: 3, },
    evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
  }
  let different_argument : RuntimeArgument = {
    type_expression: { index: 5, },
    evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
  }
  assert_true(
    runtime_arguments_alpha_equivalent(
      [left_argument],
      [renamed_argument],
      lookup,
    ),
  )
  assert_false(
    runtime_arguments_alpha_equivalent(
      [left_argument],
      [different_argument],
      lookup,
    ),
  )
}
