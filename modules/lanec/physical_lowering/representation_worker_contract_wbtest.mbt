///|
test "alpha-equivalent runtime arguments share one representation worker contract" {
  let runtime_types : RuntimeTypeArena = { expressions: [], }
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
  let catalog : RepresentationWorkerContractCatalog = { entries: [], }
  let source : @physical.FunctionId = { value: 1, }
  let callable : PhysicalCallableContractId = { value: 2, }
  let first = catalog.intern(
    {
      source,
      callable,
      arguments: [
        {
          type_expression: left_expression,
          evidence: Lambda([{ id: left, arity: 0, }], Parameter(left)),
        },
      ],
    },
    runtime_types,
  )
  let renamed = catalog.intern(
    {
      source,
      callable,
      arguments: [
        {
          type_expression: right_expression,
          evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
        },
      ],
    },
    runtime_types,
  )
  let different = catalog.intern(
    {
      source,
      callable,
      arguments: [
        {
          type_expression: different_expression,
          evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
        },
      ],
    },
    runtime_types,
  )
  assert_eq(
    (first, renamed, different, catalog.entries.length()),
    (first, first, { value: 1, }, 2),
  )
}
