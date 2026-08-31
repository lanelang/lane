///|
test "alpha-equivalent runtime arguments share one representation worker contract" {
  let image = test_image_lowerer(MetadataRegistry())
  let runtime_types = image.runtime_types
  let left = @anf.RuntimeEvidenceId::Synthetic(0)
  let right = @anf.RuntimeEvidenceId::Synthetic(1)
  let left_body = runtime_types.intern(Parameter(left))
  let left_expression = runtime_types.intern(
    Lambda([{ id: left, arity: 0, }], left_body),
  )
  let right_body = runtime_types.intern(Parameter(right))
  let right_expression = runtime_types.intern(
    Lambda([{ id: right, arity: 0, }], right_body),
  )
  let unit_body = runtime_types.intern(Static(Unit))
  let different_expression = runtime_types.intern(
    Lambda([{ id: right, arity: 0, }], unit_body),
  )
  let source : @physical.FunctionId = { value: 1, }
  let callable = image.physical_callable_contract(
    Callable([], Unit),
    RuntimeSubstitution::new(),
    [],
  )
  let first = image.intern_representation_worker_contract({
    source,
    callable,
    arguments: [
      {
        type_expression: left_expression,
        evidence: Lambda([{ id: left, arity: 0, }], Parameter(left)),
      },
    ],
  })
  let renamed = image.intern_representation_worker_contract({
    source,
    callable,
    arguments: [
      {
        type_expression: right_expression,
        evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
      },
    ],
  })
  let different = image.intern_representation_worker_contract({
    source,
    callable,
    arguments: [
      {
        type_expression: different_expression,
        evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
      },
    ],
  })
  let second : RepresentationWorkerContractId = { value: 1, }
  assert_eq(
    (
      first,
      renamed,
      different,
      image.representation_worker_contracts.entries.length(),
    ),
    (first, first, second, 2),
  )
}
