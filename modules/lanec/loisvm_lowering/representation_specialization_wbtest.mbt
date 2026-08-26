///|
test "recursive demand produces a finite self-referential worker contract" {
  let lowerer = test_image_lowerer(
    @buslane.MetadataRegistry::MetadataRegistry(),
  )
  let demand = recursive_representation_test_demand(0, Semantic(0))
  let completed = lowerer.complete_representation_solution([demand])
  assert_eq(completed.length(), 1)
  assert_eq(completed[0].2.key.callable_result, Some(Semantic(0)))
}

///|
test "open representation evidence remains a residual worker parameter" {
  let lowerer = test_image_lowerer(
    @buslane.MetadataRegistry::MetadataRegistry(),
  )
  let parameter : @anf.RuntimeEvidenceParameter = {
    id: Projected(0),
    arity: 0,
  }
  let expression = lowerer.runtime_types.intern(Parameter(parameter.id))
  let argument : @anf.RuntimeArgument = {
    type_expression: expression,
    evidence: Parameter(parameter.id),
  }
  let value : @buslane.ValueId = { index: 0, }
  let erased = @anf.RuntimeType::Erased(expression, Parameter(parameter.id))
  let function : @anf.AnfFunction = {
    id: { value: 0, },
    source: None,
    parameters: [value],
    result_type: erased,
    body: Atom(Ref(value)),
  }
  let callable = CallableRepresentationTarget::Semantic(0)
  let instance : CallableInstance = {
    id: 0,
    key: { function: function.id, arguments: [], },
    definition: {
      function,
      type_: Forall([parameter], Callable([erased], erased)),
      parameters: [parameter],
      lexical_parameters: [],
      captures: [],
      owner: None,
      recursive_group: None,
    },
    substitution: RuntimeSubstitution::from_arguments([parameter], [argument]),
    own_arguments: [{ argument, transform: Projection(parameter.id), }],
    generic_fallback: true,
  }
  lowerer.representation_solution.scalar_replacements.parameters.push({
    owner: Callable(callable),
    parameter_index: 0,
    contract: {
      owner: { index: 0, },
      data_constructor: { index: 0, },
      type_: erased,
      payload_types: [],
    },
  })
  let demand = lowerer.representation_demand(callable, instance, None)
  assert_true(
    demand
    is Some({ specialized_parameters: [], residual_parameters: [residual], .. }) &&
    residual == parameter,
  )
}

///|
test "Physical ANF rejects two workers for one representation contract" {
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let draft = recursive_representation_test_demand(0, Semantic(0))
  let worker : PhysicalRepresentationWorkerContract = {
    worker: { value: 1, },
    key: draft.2.key,
  }
  physical.representation_workers.push(worker)
  physical.representation_workers.push({ ..worker, worker: { value: 2, }, })
  ignore(physical.callable_contracts.canonicalize())
  let result : Result[VerifiedPhysicalAnfProgram, LoisvmLoweringError] = Ok(
    physical.verify(),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
fn recursive_representation_test_demand(
  id : Int,
  result : CallableRepresentationTarget,
) -> (CallableRepresentationTarget, CallableInstance, RepresentationDemand) {
  let function_id : @anf.AnfFunctionId = { value: id, }
  let callable : CallableRepresentationTarget = Semantic(id)
  let function : @anf.AnfFunction = {
    id: function_id,
    source: None,
    parameters: [],
    result_type: Callable([], Unit),
    body: Atom(Literal(Unit)),
  }
  let instance : CallableInstance = {
    id,
    key: { function: function_id, arguments: [], },
    definition: {
      function,
      type_: Callable([], Callable([], Unit)),
      parameters: [],
      lexical_parameters: [],
      captures: [],
      owner: None,
      recursive_group: Some({ value: 0, }),
    },
    substitution: RuntimeSubstitution::new(),
    own_arguments: [],
    generic_fallback: true,
  }
  let demand : RepresentationDemand = {
    key: {
      source_function: function_id,
      specialized_evidence: [],
      data_ports: [],
      callable_ports: [],
      callable_allocations: [],
      callable_arguments: [],
      callable_result: Some(result),
      captures: [],
      parameters: [],
      scalar_parameters: [],
      result: Unit,
    },
    substitutions: RuntimeSubstitution::new(),
    specialized_parameters: [],
    residual_parameters: [],
    parameter_types: [],
    scalar_parameters: [],
    result_type: Callable([], Unit),
  }
  (callable, instance, demand)
}

///|
test "mutual representation demand SCC classification is order independent" {
  let first = recursive_representation_test_demand(0, Semantic(1))
  let second = recursive_representation_test_demand(1, Semantic(0))
  let forward = [first, second]
  let reversed = [second, first]
  let forward_sccs = representation_demand_sccs(forward)
  let reversed_sccs = representation_demand_sccs(reversed)
  assert_eq(forward_sccs.components, [[0, 1]])
  assert_eq(reversed_sccs.components, [[0, 1]])
  assert_true(representation_demand_edge_uses_worker(Semantic(1), forward))
  assert_true(representation_demand_edge_uses_worker(Semantic(0), reversed))
}

///|
test "finite scalarized callable ABI is selected across a first-class edge" {
  let source = recursive_representation_test_demand(0, Semantic(1))
  let target = recursive_representation_test_demand(1, Semantic(2))
  let plain_demands = [source, target]
  assert_true(
    representation_demand_edge_uses_worker(Semantic(1), plain_demands),
  )
  let scalarized_target = (
    target.0,
    target.1,
    {
      ..target.2,
      scalar_parameters: [
        {
          owner: callable_representation_owner(1),
          parameter_index: 0,
          contract: {
            owner: { index: 0, },
            data_constructor: { index: 0, },
            type_: Unit,
            payload_types: [],
          },
        },
      ],
    },
  )
  let demands = [source, scalarized_target]
  assert_true(representation_demand_edge_uses_worker(Semantic(1), demands))
}

///|
test "callable argument edges participate in demand SCC classification" {
  let first = recursive_representation_test_demand(0, Semantic(2))
  let second = recursive_representation_test_demand(1, Semantic(2))
  let first = (
    first.0,
    first.1,
    {
      ..first.2,
      key: {
        ..first.2.key,
        callable_result: None,
        callable_arguments: [(Temp({ index: 0, }), 0, Semantic(1))],
      },
    },
  )
  let second = (
    second.0,
    second.1,
    {
      ..second.2,
      key: {
        ..second.2.key,
        callable_result: None,
        callable_arguments: [(Temp({ index: 1, }), 0, Semantic(0))],
      },
    },
  )
  let sccs = representation_demand_sccs([first, second])
  assert_eq(sccs.components, [[0, 1]])
}

///|
test "recursive callable allocation edges retain the finite worker contract" {
  let draft = recursive_representation_test_demand(0, Semantic(1))
  let demand = (
    draft.0,
    draft.1,
    {
      ..draft.2,
      key: {
        ..draft.2.key,
        callable_result: None,
        callable_allocations: [({ value: 1, }, Semantic(0))],
      },
    },
  )
  let lowerer = test_image_lowerer(
    @buslane.MetadataRegistry::MetadataRegistry(),
  )
  let completed = lowerer.complete_representation_solution([demand])
  assert_eq(completed[0].2.key.callable_allocations, [
    ({ value: 1, }, Semantic(0)),
  ])
}
