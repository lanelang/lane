///|
test "recursive demand produces a worker with a generic recursive callable edge" {
  let lowerer = test_image_lowerer(
    @buslane.MetadataRegistry::MetadataRegistry(),
  )
  let demand = recursive_representation_test_demand(0, Semantic(0))
  let completed = lowerer.complete_representation_solution([demand])
  assert_eq(completed.length(), 1)
  assert_eq(completed[0].2.key.callable_result, None)
}

///|
test "Physical ANF rejects two workers for one representation contract" {
  let physical = PhysicalAnfProgram::new()
  let draft = recursive_representation_test_demand(0, Semantic(0))
  let worker : RepresentationSpecializationPlan = {
    worker: { value: 1, },
    owner: draft.0,
    aliases: [draft.0],
    data_components: [],
    callable_components: [],
    key: draft.2.key,
    function: draft.1.definition.function,
    substitutions: draft.2.substitutions,
    specialized_parameters: draft.2.specialized_parameters,
    residual_parameters: draft.2.residual_parameters,
    parameter_types: draft.2.parameter_types,
    scalar_parameters: draft.2.scalar_parameters,
    result_type: draft.2.result_type,
    recursive_functions: [],
  }
  physical.representation_workers.push(worker)
  physical.representation_workers.push({ ..worker, worker: { value: 2, }, })
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
  assert_eq(forward_sccs.components, [0, 0])
  assert_eq(forward_sccs.recursive, [true])
  assert_eq(reversed_sccs.components, [0, 0])
  assert_eq(reversed_sccs.recursive, [true])
  assert_false(
    representation_demand_edge_uses_worker(Semantic(1), forward, forward_sccs),
  )
  assert_false(
    representation_demand_edge_uses_worker(Semantic(0), reversed, reversed_sccs),
  )
}

///|
test "scalarized callable ABI is not selected across a first-class edge" {
  let source = recursive_representation_test_demand(0, Semantic(1))
  let target = recursive_representation_test_demand(1, Semantic(2))
  let plain_demands = [source, target]
  assert_true(
    representation_demand_edge_uses_worker(
      Semantic(1),
      plain_demands,
      representation_demand_sccs(plain_demands),
    ),
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
  let sccs = representation_demand_sccs(demands)
  assert_false(
    representation_demand_edge_uses_worker(Semantic(1), demands, sccs),
  )
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
  assert_eq(sccs.components, [0, 0])
  assert_eq(sccs.recursive, [true])
}

///|
test "recursive callable allocation edges use the generic implementation" {
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
  assert_eq(completed[0].2.key.callable_allocations, [])
}
