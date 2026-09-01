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
  let contracts : RepresentationWorkerContractCatalog = { entries: [], }
  let first = image.intern_representation_worker_contract(contracts, {
    source,
    callable,
    arguments: [
      {
        type_expression: left_expression,
        evidence: Lambda([{ id: left, arity: 0, }], Parameter(left)),
      },
    ],
  })
  let renamed = image.intern_representation_worker_contract(contracts, {
    source,
    callable,
    arguments: [
      {
        type_expression: right_expression,
        evidence: Lambda([{ id: right, arity: 0, }], Parameter(right)),
      },
    ],
  })
  let different = image.intern_representation_worker_contract(contracts, {
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
    (first, renamed, different, contracts.entries.length()),
    (first, first, second, 2),
  )
}

///|
fn specialization_test_function(index : Int) -> @anf.AnfFunction {
  {
    id: { value: index, },
    source: None,
    origin: SourceWritten,
    parameters: [],
    result_type: Unit,
    body: Atom(Literal(Unit)),
  }
}

///|
test "specialization planning joins partial evidence applications before demanding a worker" {
  let image = test_image_lowerer(MetadataRegistry())
  let runtime_types = image.runtime_types
  let first_parameter = @anf.RuntimeEvidenceId::Synthetic(20)
  let second_parameter = @anf.RuntimeEvidenceId::Synthetic(21)
  let candidate_value : @buslane.ValueId = { index: 10, }
  let partial_value : @buslane.ValueId = { index: 11, }
  let complete_value : @buslane.ValueId = { index: 12, }
  let i64_argument : @anf.RuntimeArgument = {
    type_expression: runtime_types.intern(Static(Scalar(I64))),
    evidence: Static(I64),
  }
  let bool_argument : @anf.RuntimeArgument = {
    type_expression: runtime_types.intern(Static(Scalar(Bool))),
    evidence: Static(Bool),
  }
  let candidates : Array[RepresentationCandidate] = [
    {
      value: candidate_value,
      function: specialization_test_function(10),
      parameters: [
        { id: first_parameter, arity: 0, },
        { id: second_parameter, arity: 0, },
      ],
      closed_applications: [],
      calls: [],
      open: false,
    },
  ]
  let expression : @anf.AnfExpr = Let(
    Value(
      id=partial_value,
      rhs=ApplyEvidence(callee=Ref(candidate_value), arguments=[i64_argument]),
    ),
    Let(
      Value(
        id=complete_value,
        rhs=ApplyEvidence(callee=Ref(partial_value), arguments=[bool_argument]),
      ),
      Atom(Ref(complete_value)),
    ),
  )
  ignore(
    collect_representation_candidate_expr(expression, candidates, None, {
      values: [],
      temps: [],
    }),
  )
  assert_eq(candidates[0].closed_applications, [[i64_argument, bool_argument]])
}

///|
test "specialization demand planning closes stable SCCs without expanding keys" {
  let image = test_image_lowerer(MetadataRegistry())
  let runtime_types = image.runtime_types
  let f_parameter = @anf.RuntimeEvidenceId::Synthetic(10)
  let g_parameter = @anf.RuntimeEvidenceId::Synthetic(11)
  let h_parameter = @anf.RuntimeEvidenceId::Synthetic(12)
  let parameter_argument : (@anf.RuntimeEvidenceId) -> @anf.RuntimeArgument = fn(
    parameter,
  ) {
    {
      type_expression: runtime_types.intern(Parameter(parameter)),
      evidence: Parameter(parameter),
    }
  }
  let closed_argument : (@anf.RuntimeType, @anf.RuntimeLayout) -> @anf.RuntimeArgument = fn(
    type_,
    layout,
  ) {
    {
      type_expression: runtime_types.intern(Static(type_)),
      evidence: Static(layout),
    }
  }
  let i64_argument = closed_argument(Scalar(I64), I64)
  let bool_argument = closed_argument(Scalar(Bool), Bool)
  let f : @buslane.ValueId = { index: 0, }
  let g : @buslane.ValueId = { index: 1, }
  let h : @buslane.ValueId = { index: 2, }
  let candidates : Array[RepresentationCandidate] = [
    {
      value: f,
      function: specialization_test_function(0),
      parameters: [{ id: f_parameter, arity: 0, }],
      closed_applications: [[i64_argument]],
      calls: [{ target: g, arguments: [parameter_argument(f_parameter)], }],
      open: false,
    },
    {
      value: g,
      function: specialization_test_function(1),
      parameters: [{ id: g_parameter, arity: 0, }],
      closed_applications: [],
      calls: [{ target: f, arguments: [parameter_argument(g_parameter)], }],
      open: false,
    },
    {
      value: h,
      function: specialization_test_function(2),
      parameters: [{ id: h_parameter, arity: 0, }],
      closed_applications: [[i64_argument]],
      calls: [{ target: h, arguments: [bool_argument], }],
      open: false,
    },
  ]
  let demands = solve_representation_specialization_demands(
    candidates, runtime_types,
  )
  assert_eq(demands.map(demand => demand.candidate), [0, 2, 1])
  assert_true(
    demands.all(demand => {
      demand.arguments.length() == 1 &&
      demand.arguments[0].evidence is Static(I64)
    }),
  )
}
