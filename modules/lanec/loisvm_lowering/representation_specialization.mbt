///|
fn ImageLowerer::plan_representation_specializations(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  instances : CallableInstancePlan,
) -> Unit raise LoisvmLoweringError {
  let demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ] = []
  for instance in instances.instances {
    let callable = CallableRepresentationTarget::Semantic(instance.id)
    if instance.definition.recursive_group is Some(group) &&
      instances.rejected_recursive_groups.contains(group) {
      continue
    }
    let forced_callable_type = self.representation_solution.callable_representation_target_type(
      callable,
    )
    let closed_call_target = instances.is_closed_call_target(instance.id)
    let physical_value = self.representation_solution.demands_callable_instance(
      callable,
    )
    guard forced_callable_type is Some(_) ||
      closed_call_target ||
      physical_value else {
      continue
    }
    guard self.representation_demand(callable, instance, forced_callable_type)
      is Some(demand) else {
      continue
    }
    demands.push((callable, instance, demand))
  }
  let refined_targets = self.representation_solution.refined_callable_targets()
  for callable in refined_targets {
    guard callable.instance(instances) is Some(instance) else {
      raise RepresentationSpecializationInvariant(
        detail="physical callable target has no semantic source instance",
      )
    }
    let forced_callable_type = instance.substitution.apply_type(
      self.runtime_types,
      instance.definition.type_,
    )
    guard self.representation_demand(
        callable,
        instance,
        Some(forced_callable_type),
      )
      is Some(demand) else {
      continue
    }
    demands.push((callable, instance, demand))
  }
  let completed = self.complete_representation_solution(demands)
  for draft in completed {
    let callable = draft.0
    let instance = draft.1
    let demand = draft.2
    let mut existing = false
    for planned in self.plans.entries {
      if planned.entry is RepresentationWorker(plan) && plan.key == demand.key {
        if !plan.aliases.contains(callable) {
          plan.aliases.push(callable)
        }
        for
          component in self.representation_solution.data_components_for_owner(
            CallableRepresentationOwner::Callable(callable),
          ) {
          if !plan.data_components.contains(component) {
            plan.data_components.push(component)
          }
        }
        for
          component in self.representation_solution.callable_components_for_target(
            callable,
          ) {
          if !plan.callable_components.contains(component) {
            plan.callable_components.push(component)
          }
        }
        existing = true
        break
      }
    }
    guard !existing else { continue }
    let recursive_functions = match instance.definition.owner {
      Some(_) => {
        guard instances.generic_instance(instance.definition.function.id)
          is Some(generic) &&
          self.lifted_function(generic) is Some(fallback) else {
          raise RepresentationSpecializationInvariant(
            detail="nested specialization has no planned generic closure",
          )
        }
        fallback.recursive_functions
      }
      _ => []
    }
    let (_, plan) = self.plans.append_with_result(
      RepresentationSpecialization(
        function=instance.definition.function.id,
        source=instance.definition.function.source,
      ),
      fn(worker) {
        let plan : RepresentationSpecializationPlan = {
          worker,
          owner: callable,
          aliases: [callable],
          data_components: self.representation_solution.data_components_for_owner(
            CallableRepresentationOwner::Callable(callable),
          ),
          callable_components: self.representation_solution.callable_components_for_target(
            callable,
          ),
          key: demand.key,
          function: instance.definition.function,
          substitutions: demand.substitutions,
          specialized_parameters: demand.specialized_parameters,
          residual_parameters: demand.residual_parameters,
          parameter_types: demand.parameter_types,
          scalar_parameters: demand.scalar_parameters,
          result_type: demand.result_type,
          recursive_functions,
        }
        (RepresentationWorker(plan), plan)
      },
    )
    physical.representation_workers.push({ worker: plan.worker, key: plan.key, })
  }
}

///|
fn ImageLowerer::complete_representation_solution(
  self : ImageLowerer,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
) -> Array[
  (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
] raise LoisvmLoweringError {
  let sccs = representation_demand_sccs(demands)
  let states = Array::make(
    demands.length(),
    RepresentationDemandCompletion::Unvisited,
  )
  let completed = []
  for index, draft in demands {
    completed.push(
      (
        draft.0,
        draft.1,
        self.complete_representation_demand(index, demands, sccs, states),
      ),
    )
  }
  completed
}

///|
priv struct RepresentationDemandSccs {
  components : Array[Int]
  recursive : Array[Bool]
}

///|
priv enum RepresentationDemandCompletion {
  Unvisited
  Visiting
  Completed(RepresentationDemand)
}

///|
fn ImageLowerer::complete_representation_demand(
  self : ImageLowerer,
  index : Int,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> RepresentationDemand raise LoisvmLoweringError {
  match states[index] {
    Completed(demand) => return demand
    Visiting =>
      raise RepresentationSpecializationInvariant(
        detail="representation demand SCC completion followed an unclassified recursive edge",
      )
    Unvisited => ()
  }
  states[index] = Visiting
  let draft = demands[index]
  let callable_allocations = draft.2.key.callable_allocations.filter(entry => {
    representation_demand_edge_uses_worker(entry.1, demands, sccs)
  })
  let callable_ports = draft.2.key.callable_ports.filter(entry => {
    representation_demand_edge_uses_worker(entry.1, demands, sccs)
  })
  let callable_arguments = draft.2.key.callable_arguments.filter(entry => {
    representation_demand_edge_uses_worker(entry.2, demands, sccs)
  })
  let callable_result = draft.2.key.callable_result.bind(callable => {
    if representation_demand_edge_uses_worker(callable, demands, sccs) {
      Some(callable)
    } else {
      None
    }
  })
  let boundary_demand = {
    ..draft.2,
    key: {
      ..draft.2.key,
      callable_allocations,
      callable_ports,
      callable_arguments,
      callable_result,
    },
  }
  let demand = {
    ..boundary_demand,
    key: {
      ..boundary_demand.key,
      parameters: self.representation_parameter_shapes(
        draft.0,
        draft.1,
        boundary_demand,
        demands,
        sccs,
        states,
      ),
      result: self.representation_result_shape(
        draft.0,
        boundary_demand,
        demands,
        sccs,
        states,
      ),
      captures: self.representation_capture_shapes(
        draft.0,
        draft.1,
        boundary_demand,
        demands,
        sccs,
        states,
      ),
    },
  }
  states[index] = Completed(demand)
  demand
}

///|
fn ImageLowerer::representation_result_shape(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match
    self.representation_result_callable_abi(
      CallableRepresentationOwner::Callable(callable),
      demand,
      demands,
      sccs,
      states,
    ) {
    Some(abi) => CanonicalRuntimeTypeKey::Callable(abi)
    None =>
      self.canonical_runtime_value_key_for_family(
        demand.result_type,
        self.representation_solution.data_family_at_result([
          CallableRepresentationOwner::Callable(callable),
        ]),
      )
  }
}

///|
fn ImageLowerer::representation_result_callable_abi(
  self : ImageLowerer,
  owner : CallableRepresentationOwner,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi? raise LoisvmLoweringError {
  guard self.representation_solution.callable_instance_at_result([owner])
    is Some(callable) else {
    return None
  }
  if demand.key.callable_result == Some(callable) {
    return Some(
      self.representation_callable_abi(callable, demands, sccs, states),
    )
  }
  Some(self.generic_callable_representation_physical_abi(callable))
}

///|
fn ImageLowerer::representation_port_callable_abi(
  self : ImageLowerer,
  owner : CallableRepresentationOwner,
  binding : @anf.AnfBindingId,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi? raise LoisvmLoweringError {
  guard self.representation_solution.callable_instance_at_port([owner], binding)
    is Some(callable) else {
    return None
  }
  if demand.key.callable_ports.any(entry => {
      entry.0 == binding && entry.1 == callable
    }) {
    return Some(
      self.representation_callable_abi(callable, demands, sccs, states),
    )
  }
  Some(self.generic_callable_representation_physical_abi(callable))
}

///|
fn ImageLowerer::representation_callable_abi(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  guard representation_demand_index(demands, callable) is Some(target) else {
    return self.generic_callable_representation_physical_abi(callable)
  }
  if sccs.recursive[sccs.components[target]] ||
    !demands[target].2.scalar_parameters.is_empty() {
    return self.generic_callable_representation_physical_abi(callable)
  }
  self.representation_demand_invocation(
    self.complete_representation_demand(target, demands, sccs, states),
  )
}

///|
fn representation_demand_edge_uses_worker(
  callable : CallableRepresentationTarget,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
) -> Bool {
  guard representation_demand_index(demands, callable) is Some(target) else {
    return false
  }
  !sccs.recursive[sccs.components[target]] &&
  demands[target].2.scalar_parameters.is_empty()
}

///|
fn representation_demand_sccs(
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
) -> RepresentationDemandSccs {
  let count = demands.length()
  let adjacency : Array[Array[Int]] = Array::makei(count, _ => [])
  let reverse : Array[Array[Int]] = Array::makei(count, _ => [])
  for index, draft in demands {
    let targets = draft.2.key.callable_ports.map(entry => entry.1)
    for entry in draft.2.key.callable_allocations {
      if !targets.contains(entry.1) {
        targets.push(entry.1)
      }
    }
    for entry in draft.2.key.callable_arguments {
      if !targets.contains(entry.2) {
        targets.push(entry.2)
      }
    }
    if draft.2.key.callable_result is Some(callable) {
      targets.push(callable)
    }
    for callable in targets {
      guard representation_demand_index(demands, callable) is Some(target) &&
        !adjacency[index].contains(target) else {
        continue
      }
      adjacency[index].push(target)
      reverse[target].push(index)
    }
  }
  let visited = Array::make(count, false)
  let order : Array[Int] = []
  for index in 0..<count {
    finish_representation_demand(index, adjacency, visited, order)
  }
  let components = Array::make(count, -1)
  let recursive : Array[Bool] = []
  for index in order.rev_iter() {
    if components[index] >= 0 {
      continue
    }
    let members : Array[Int] = []
    collect_representation_demand_component(
      index,
      reverse,
      components,
      recursive.length(),
      members,
    )
    recursive.push(
      members.length() > 1 || adjacency[members[0]].contains(members[0]),
    )
  }
  { components, recursive, }
}

///|
fn representation_demand_index(
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  callable : CallableRepresentationTarget,
) -> Int? {
  for index, demand in demands {
    if demand.0 == callable {
      return Some(index)
    }
  }
  None
}

///|
fn finish_representation_demand(
  index : Int,
  adjacency : Array[Array[Int]],
  visited : Array[Bool],
  order : Array[Int],
) -> Unit {
  if visited[index] {
    return
  }
  visited[index] = true
  for target in adjacency[index] {
    finish_representation_demand(target, adjacency, visited, order)
  }
  order.push(index)
}

///|
fn collect_representation_demand_component(
  index : Int,
  reverse : Array[Array[Int]],
  components : Array[Int],
  component : Int,
  members : Array[Int],
) -> Unit {
  if components[index] >= 0 {
    return
  }
  components[index] = component
  members.push(index)
  for target in reverse[index] {
    collect_representation_demand_component(
      target, reverse, components, component, members,
    )
  }
}

///|
fn ImageLowerer::representation_parameter_shapes(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  instance : CallableInstance,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> Array[CanonicalRuntimeTypeKey] raise LoisvmLoweringError {
  let owner = CallableRepresentationOwner::Callable(callable)
  let parameters : Array[CanonicalRuntimeTypeKey] = []
  for index, type_ in demand.parameter_types {
    let mut scalar : ClosedAggregateContract? = None
    for projection in demand.scalar_parameters {
      if projection.parameter_index == index {
        scalar = Some(projection.contract)
        break
      }
    }
    match scalar {
      Some(contract) =>
        for payload in contract.payload_types {
          let key = self.canonical_runtime_value_key(payload)
          if !(key is Unit) {
            parameters.push(key)
          }
        }
      None => {
        let key = match instance.definition.function.parameters.get(index) {
          Some(parameter) =>
            match
              self.representation_port_callable_abi(
                owner,
                Value(parameter),
                demand,
                demands,
                sccs,
                states,
              ) {
              Some(abi) => CanonicalRuntimeTypeKey::Callable(abi)
              None =>
                self.canonical_runtime_value_key_for_family(
                  type_,
                  self.representation_solution.data_family_at_port(
                    [owner],
                    Value(parameter),
                  ),
                )
            }
          None => self.canonical_runtime_type_key(type_)
        }
        if !(key is Unit) {
          parameters.push(key)
        }
      }
    }
  }
  parameters
}

///|
fn ImageLowerer::generic_callable_representation_target(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  guard callable.instance(self.callable_instances) is Some(instance) &&
    self.callable_instances.generic_instance(instance.definition.function.id)
    is Some(generic) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation has no semantic generic fallback",
    )
  }
  Semantic(generic)
}

///|
fn ImageLowerer::callable_representation_target(
  self : ImageLowerer,
  function : @anf.AnfFunctionId,
  substitutions : RuntimeSubstitution,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  self.generic_callable_representation_target(
    self.callable_representation_candidate(function, substitutions),
  )
}

///|
fn ImageLowerer::callable_representation_candidate(
  self : ImageLowerer,
  function : @anf.AnfFunctionId,
  substitutions : RuntimeSubstitution,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  self.callable_instances.callable_representation_candidate(
    self, function, substitutions,
  )
}

///|
fn CallableInstancePlan::callable_representation_candidate(
  self : CallableInstancePlan,
  image : ImageLowerer,
  function : @anf.AnfFunctionId,
  substitutions : RuntimeSubstitution,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  guard image.callable_catalog.find(function) is Some(definition) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation target is absent from the Runtime ANF catalog",
    )
  }
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    substitutions
    .argument(parameter.id)
    .map(argument => substitutions.apply_argument(image.runtime_types, argument))
    .unwrap_or_else(() => image.identity_runtime_argument(parameter))
  })
  let own_arguments = definition.parameters.map(parameter => {
    argument: image.identity_runtime_argument(parameter),
    transform: RuntimeArgumentTransform::Projection(parameter.id),
  })
  let arguments = lexical_arguments +
    own_arguments.map(argument => argument.argument)
  for instance in self.instances {
    if instance.key.function == function && instance.key.arguments == arguments {
      return Semantic(instance.id)
    }
  }
  guard self.generic_instance(function) is Some(source) else {
    raise RepresentationSpecializationInvariant(
      detail="refined callable target for function \{function.value} has no semantic generic source",
    )
  }
  Refined(source_instance=source, lexical_arguments~, own_arguments~)
}

///|
fn ImageLowerer::freeze_callable_representation_targets(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for index, demand in self.representation_solution.callable_ports {
    self.representation_solution.callable_ports[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for index, demand in self.representation_solution.callable_results {
    self.representation_solution.callable_results[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for index, demand in self.representation_solution.callable_arguments {
    self.representation_solution.callable_arguments[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  let data = self.representation_solution.data_representations
  for index, demand in data.callable_payloads {
    data.callable_payloads[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for index, demand in data.callable_arguments {
    data.callable_arguments[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for family in self.data_families {
    for constructor_plan in family.constructors {
      for index, demands in constructor_plan.storage_callable_demands {
        constructor_plan.storage_callable_demands[index] = demands.map(demand => {
          ..demand,
          callable: self.frozen_callable_representation_target(demand.callable),
        })
      }
    }
  }
}

///|
fn ImageLowerer::frozen_callable_representation_target(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  guard callable.instance(self.callable_instances) is Some(_) &&
    self.callable_representation_implementation(callable, true) is Some(_) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation target has no frozen semantic instance and generic implementation pair",
    )
  }
  callable
}

///|
fn ImageLowerer::identity_runtime_argument(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  guard self.metadata.parameter_type_expression(parameter.id)
    is Some(type_expression) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF parameter lacks a type-expression identity",
    )
  }
  { type_expression, evidence: Parameter(parameter.id), }
}

///|
priv struct RepresentationDemand {
  key : RepresentationSpecializationKey
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  residual_parameters : Array[@anf.RuntimeEvidenceParameter]
  parameter_types : Array[@anf.RuntimeType]
  scalar_parameters : Array[ScalarParameterPlan]
  result_type : @anf.RuntimeType
}

///|
fn ImageLowerer::representation_demand(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  instance : CallableInstance,
  forced_callable_type : @anf.RuntimeType?,
) -> RepresentationDemand? raise LoisvmLoweringError {
  let owner = CallableRepresentationOwner::Callable(callable)
  let definition = instance.definition
  guard instance.own_arguments.length() == definition.parameters.length() else {
    return None
  }
  let (_, formal_parameters, formal_result) = function_type_parts(
    definition.type_,
  )
  let instance_substitutions = match forced_callable_type {
    Some(target) => {
      guard self.refine_callable_representation_substitution(
          definition.type_,
          target,
          instance.substitution,
          (definition.lexical_parameters + definition.parameters).map(parameter => {
            parameter.id
          }),
        )
        is Some(substitutions) else {
        return None
      }
      substitutions
    }
    None => instance.substitution
  }
  for index, parameter in definition.lexical_parameters {
    let argument = instance_substitutions
      .argument(parameter.id)
      .unwrap_or(instance.key.arguments[index])
    guard self.generic_argument_is_closed(argument) else { return None }
  }
  for index, parameter in definition.parameters {
    let argument = instance_substitutions
      .argument(parameter.id)
      .unwrap_or(instance.own_arguments[index].argument)
    guard self.generic_argument_is_closed(argument) else { return None }
  }
  let specialized_parameters = []
  let specialized_evidence = []
  let substitutions = RuntimeSubstitution::new()
  for index, parameter in definition.lexical_parameters {
    let argument = instance_substitutions
      .argument(parameter.id)
      .unwrap_or(instance.key.arguments[index])
    substitutions.insert(parameter.id, argument)
    specialized_parameters.push(parameter.id)
    specialized_evidence.push(
      (
        index,
        self.canonical_specialized_evidence_key(
          parameter, argument, instance_substitutions,
        ),
      ),
    )
  }
  for index, parameter in definition.parameters {
    let argument = instance_substitutions
      .argument(parameter.id)
      .unwrap_or(instance.own_arguments[index].argument)
    substitutions.insert(parameter.id, argument)
    specialized_parameters.push(parameter.id)
    specialized_evidence.push(
      (
        definition.lexical_parameters.length() + index,
        self.canonical_specialized_evidence_key(
          parameter, argument, instance_substitutions,
        ),
      ),
    )
  }
  let parameter_types = formal_parameters.map(type_ => {
    substitutions.apply_type(self.runtime_types, type_)
  })
  let result_type = substitutions.apply_type(self.runtime_types, formal_result)
  let (all_parameters, _, _) = function_type_parts(definition.type_)
  let residual_parameters = all_parameters.filter(parameter => {
    !specialized_parameters.contains(parameter.id)
  })
  let scalar_parameters = []
  for index in 0..<parameter_types.length() {
    if self.representation_solution.scalar_parameter_contract(owner, index)
      is Some(contract) {
      scalar_parameters.push({ owner, parameter_index: index, contract, })
    }
  }
  let data_ports = self.representation_solution.data_port_assignments(owner)
  let data_capture = self.representation_solution.has_data_capture_assignment(
    owner,
  )
  let callable_ports = self.representation_solution.callable_port_assignments(
    owner,
  )
  let callable_allocations = self.representation_solution.callable_allocation_assignments(
    owner,
  )
  let callable_result = self.representation_solution.worker_callable_at_result([
    owner,
  ])
  guard !data_ports.is_empty() ||
    data_capture ||
    !callable_ports.is_empty() ||
    !callable_allocations.is_empty() ||
    callable_result is Some(_) ||
    !scalar_parameters.is_empty() ||
    formal_parameters != parameter_types ||
    formal_result != result_type else {
    return None
  }
  let parameters = []
  for index, type_ in parameter_types {
    let mut scalar : ClosedAggregateContract? = None
    for projection in scalar_parameters {
      if projection.parameter_index == index {
        scalar = Some(projection.contract)
        break
      }
    }
    match scalar {
      Some(contract) =>
        for payload in contract.payload_types {
          let key = self.canonical_runtime_value_key(payload)
          if !(key is Unit) {
            parameters.push(key)
          }
        }
      None => {
        let family = match definition.function.parameters.get(index) {
          Some(parameter) =>
            self.representation_solution.data_family_at_port(
              [owner],
              Value(parameter),
            )
          None => None
        }
        let callable = match definition.function.parameters.get(index) {
          Some(parameter) =>
            self.representation_solution.worker_callable_at_port(
              [owner],
              Value(parameter),
            )
          None => None
        }
        let key = self.canonical_runtime_type_key_for_representation(
          type_, family, callable,
        )
        if !(key is Unit) {
          parameters.push(key)
        }
      }
    }
  }
  let result = self.canonical_runtime_type_key_for_representation(
    result_type,
    self.representation_solution.data_family_at_result([owner]),
    callable_result,
  )
  guard !data_ports.is_empty() ||
    data_capture ||
    !callable_ports.is_empty() ||
    callable_result is Some(_) ||
    !scalar_parameters.is_empty() ||
    self.runtime_abi_changed(
      formal_parameters, formal_result, parameters, result,
    ) else {
    return None
  }
  Some({
    key: {
      source_function: definition.function.id,
      specialized_evidence,
      data_ports,
      callable_ports,
      callable_allocations,
      callable_arguments: self.representation_solution.callable_argument_assignments(
        owner,
      ),
      callable_result,
      captures: [],
      parameters,
      scalar_parameters: scalar_parameters.map(parameter => {
        (
          parameter.parameter_index,
          parameter.contract.data_constructor,
          parameter.contract.payload_types.map(type_ => {
            self.canonical_runtime_value_key(type_)
          }),
        )
      }),
      result,
    },
    substitutions,
    specialized_parameters,
    residual_parameters,
    parameter_types,
    scalar_parameters,
    result_type,
  })
}

///|
fn ImageLowerer::representation_capture_shapes(
  self : ImageLowerer,
  representation_target : CallableRepresentationTarget,
  instance : CallableInstance,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  sccs : RepresentationDemandSccs,
  states : Array[RepresentationDemandCompletion],
) -> Array[PhysicalCallableCaptureProjection] raise LoisvmLoweringError {
  let owner = CallableRepresentationOwner::Callable(representation_target)
  let captures : Array[PhysicalCallableCaptureProjection] = []
  for capture in instance.definition.captures {
    let binding = match capture {
      Value(value) => @anf.AnfBindingId::Value(value)
      Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    guard !captures.any(existing => existing.binding == binding) else {
      continue
    }
    guard self.callable_catalog.capture_type(capture, self.metadata)
      is Some(type_) else {
      raise RepresentationSpecializationInvariant(
        detail="representation worker capture lacks Runtime ANF type metadata",
      )
    }
    let type_ = instance.substitution.apply_type(self.runtime_types, type_)
    let callable = self.representation_solution.callable_instance_at_port(
      [owner],
      binding,
    )
    let worker = match callable {
      Some(callable) =>
        demand.key.callable_ports.any(entry => {
          entry.0 == binding && entry.1 == callable
        })
      None => false
    }
    let shape = match callable {
      Some(_) => {
        guard self.representation_port_callable_abi(
            owner, binding, demand, demands, sccs, states,
          )
          is Some(abi) else {
          raise RepresentationSpecializationInvariant(
            detail="callable capture demand has no planned invocation",
          )
        }
        CanonicalRuntimeTypeKey::Callable(abi)
      }
      None =>
        self.canonical_runtime_value_key_for_family(
          type_,
          self.representation_solution.data_family_at_capture([owner], binding),
        )
    }
    captures.push({ binding, shape, callable, worker, })
  }
  captures
}

///|
fn ImageLowerer::generic_callable_instance_implementation(
  self : ImageLowerer,
  instance : Int,
) -> CallableInstanceImplementation? {
  guard self.callable_instances.instances.get(instance) is Some(planned) else {
    return None
  }
  if planned.definition.function.source is Some(value) &&
    self.find_global(value) is Some(Function(function, type_)) {
    return Some({ function, type_, })
  }
  self
  .lifted_function(instance)
  .map(function => {
    function: function.lowered_function,
    type_: function.type_,
  })
}

///|
fn ImageLowerer::callable_representation_implementation(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  selected : Bool,
) -> CallableInstanceImplementation? raise LoisvmLoweringError {
  if selected &&
    self.representation_specialization_for_callable(callable) is Some(plan) {
    return Some({ function: plan.worker, type_: plan.callable_type(), })
  }
  let generic = self.generic_callable_representation_target(callable)
  guard generic is Semantic(instance) else { return None }
  self.generic_callable_instance_implementation(instance)
}

///|
/// Returns the semantic type proved by the callable-instance plan. This is
/// deliberately distinct from the generic implementation type, which only
/// describes the first-class wrapper selected for the value's physical ABI.
fn ImageLowerer::callable_representation_semantic_type(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  guard callable.instance(self.callable_instances) is Some(instance) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation names no semantic instance",
    )
  }
  instance.substitution.apply_type(
    self.runtime_types,
    instance.definition.type_,
  )
}

///|
fn ImageLowerer::representation_demand_invocation(
  _self : ImageLowerer,
  demand : RepresentationDemand,
) -> CanonicalCallableAbi {
  {
    witnesses: demand.residual_parameters.map(parameter => {
      let metadata = runtime_evidence_metadata(parameter)
      {
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      }
    }),
    parameters: demand.key.parameters,
    result: demand.key.result,
  }
}

///|
fn PhysicalCallableParameterProjection::append_keys(
  self : PhysicalCallableParameterProjection,
  keys : Array[CanonicalRuntimeTypeKey],
) -> Unit {
  match self {
    Unit => ()
    Slot(key) => keys.push(key)
    Product(fields) =>
      for field in fields {
        field.append_keys(keys)
      }
  }
}

///|
fn PhysicalCallableInterface::verify(
  self : PhysicalCallableInterface,
) -> Unit raise LoisvmLoweringError {
  if self.parameter_types.length() != self.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical callable semantic parameters disagree with its logical parameter projection",
    )
  }
  if self.evidence_parameters.length() != self.invocation.witnesses.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical callable evidence parameters disagree with its invocation ABI",
    )
  }
  if self.parameter_callables.length() != self.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical callable parameter interfaces disagree with its logical parameter projection",
    )
  }
  let parameters = []
  for projection in self.parameters {
    projection.append_keys(parameters)
  }
  if parameters != self.invocation.parameters {
    raise RepresentationSpecializationInvariant(
      detail="physical callable parameter projection does not flatten to its invocation ABI",
    )
  }
  for index, projection in self.parameters {
    match (projection, self.parameter_callables[index]) {
      (Slot(Callable(expected)), Some(parameter)) if parameter.invocation ==
        expected => ()
      (Slot(Callable(_)), _)
      | (Slot(_), Some(_))
      | (Unit, Some(_))
      | (Product(_), Some(_)) =>
        raise RepresentationSpecializationInvariant(
          detail="physical callable parameter interface disagrees with its invocation ABI",
        )
      (_, None) => ()
    }
  }
  match (self.invocation.result, self.result_callable) {
    (Callable(expected), Some(result)) if result.invocation == expected => ()
    (Callable(_), _) | (_, Some(_)) =>
      raise RepresentationSpecializationInvariant(
        detail="physical callable result projection disagrees with its invocation ABI in \{Repr(self)}",
      )
    (_, None) => ()
  }
}

///|
fn PhysicalCallableInterface::representation_equal(
  self : PhysicalCallableInterface,
  other : PhysicalCallableInterface,
) -> Bool {
  if self.invocation != other.invocation {
    return false
  }
  match (self.result_callable, other.result_callable) {
    (Some(left), Some(right)) if !left.representation_equal(right) =>
      return false
    (Some(_), None) | (None, Some(_)) => return false
    _ => ()
  }
  fn physical_parameters(
    interface : PhysicalCallableInterface,
  ) -> Array[PhysicalCallableInterface?] {
    let result = []
    for index, projection in interface.parameters {
      match projection {
        Unit => ()
        Slot(_) => result.push(interface.parameter_callables[index])
        Product(fields) =>
          for field in fields {
            let keys = []
            field.append_keys(keys)
            result.append(Array::make(keys.length(), None))
          }
      }
    }
    result
  }
  let left = physical_parameters(self)
  let right = physical_parameters(other)
  if left.length() != right.length() {
    return false
  }
  for index, left_parameter in left {
    match (left_parameter, right[index]) {
      (Some(left), Some(right)) if !left.representation_equal(right) =>
        return false
      (Some(_), None) | (None, Some(_)) => return false
      _ => ()
    }
  }
  true
}

///|
fn ImageLowerer::callable_interface_semantic_view(
  self : ImageLowerer,
  interface : PhysicalCallableInterface,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  let (_, parameter_types, result_type) = function_type_parts(type_)
  if parameter_types.length() != interface.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="instantiated callable type disagrees with its physical parameter projection",
    )
  }
  let parameter_callables = interface.parameter_callables.mapi((index, nested) => {
    match nested {
      Some(nested) =>
        match
          self.runtime_type(
            substitutions.apply_type(self.runtime_types, parameter_types[index]),
          ) {
          Concrete(Callable(_, _) | Forall(_, _) as callable) =>
            Some(
              self.callable_interface_semantic_view(
                nested,
                callable,
                RuntimeSubstitution::new(),
              ),
            )
          _ => Some(nested)
        }
      None => None
    }
  })
  let result_callable = match interface.result_callable {
    Some(nested) =>
      match
        self.runtime_type(
          substitutions.apply_type(self.runtime_types, result_type),
        ) {
        Concrete(Callable(_, _) | Forall(_, _) as callable) =>
          Some(
            self.callable_interface_semantic_view(
              nested,
              callable,
              RuntimeSubstitution::new(),
            ),
          )
        _ => Some(nested)
      }
    None => None
  }
  let view = {
    ..interface,
    parameter_types,
    result_type,
    parameter_callables,
    result_callable,
  }
  view.verify()
  view
}

///|
fn ImageLowerer::callable_interface_for_type_with_invocation(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  invocation : CanonicalCallableAbi,
) -> PhysicalCallableInterface? raise LoisvmLoweringError {
  let resolved = substitutions.apply_type(self.runtime_types, type_)
  guard self.runtime_type(resolved)
    is Concrete(Callable(_, _) | Forall(_, _) as callable) else {
    return None
  }
  Some(
    self.callable_interface_under_with_invocation(
      callable,
      RuntimeSubstitution::new(),
      invocation,
    ),
  )
}

///|
fn ImageLowerer::callable_interface_under_with_invocation(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  invocation : CanonicalCallableAbi,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  let (evidence_parameters, parameters, result) = function_type_parts(type_)
  let projections = []
  let parameter_callables = []
  let mut physical_index = 0
  for parameter in parameters {
    match self.canonical_runtime_value_key_under(parameter, substitutions) {
      Unit => {
        projections.push(PhysicalCallableParameterProjection::Unit)
        parameter_callables.push(None)
      }
      _ => {
        guard invocation.parameters.get(physical_index) is Some(key) else {
          raise RepresentationSpecializationInvariant(
            detail="physical callable invocation omits a non-Unit semantic parameter",
          )
        }
        projections.push(PhysicalCallableParameterProjection::Slot(key))
        parameter_callables.push(
          match key {
            Callable(nested) =>
              self.callable_interface_for_type_with_invocation(
                parameter, substitutions, nested,
              )
            _ => None
          },
        )
        physical_index += 1
      }
    }
  }
  if physical_index != invocation.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical callable invocation has parameters outside its semantic projection",
    )
  }
  let result_callable = match invocation.result {
    Callable(nested) =>
      self.callable_interface_for_type_with_invocation(
        result, substitutions, nested,
      )
    _ => None
  }
  if invocation.result is Callable(_) && result_callable is None {
    raise RepresentationSpecializationInvariant(
      detail="semantic callable type \{Repr(type_)} under \{Repr(substitutions)} cannot describe invocation result \{Repr(invocation.result)}",
    )
  }
  let interface : PhysicalCallableInterface = {
    evidence_parameters,
    parameter_types: parameters,
    result_type: result,
    invocation,
    parameters: projections,
    parameter_callables,
    result_callable,
  }
  interface.verify()
  interface
}

///|
fn ImageLowerer::canonical_callable_interface_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  self.callable_interface_under_with_invocation(
    type_,
    substitutions,
    self.canonical_callable_abi_under(type_, substitutions),
  )
}

///|
fn ImageLowerer::representation_worker_interface(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  let invocation = self.representation_worker_invocation(plan)
  let parameters = []
  let parameter_callables = []
  let mut physical_index = 0
  for index, type_ in plan.parameter_types {
    let mut scalar : ClosedAggregateContract? = None
    for candidate in plan.scalar_parameters {
      if candidate.parameter_index == index {
        scalar = Some(candidate.contract)
        break
      }
    }
    match scalar {
      Some(contract) => {
        let fields = []
        for _ in contract.payload_types {
          guard invocation.parameters.get(physical_index) is Some(key) else {
            raise RepresentationSpecializationInvariant(
              detail="representation worker invocation omits a scalar-expanded parameter",
            )
          }
          fields.push(PhysicalCallableParameterProjection::Slot(key))
          physical_index += 1
        }
        parameters.push(PhysicalCallableParameterProjection::Product(fields))
        parameter_callables.push(None)
      }
      None =>
        match
          self.canonical_runtime_value_key_under(type_, plan.substitutions) {
          Unit => {
            parameters.push(PhysicalCallableParameterProjection::Unit)
            parameter_callables.push(None)
          }
          _ => {
            guard invocation.parameters.get(physical_index) is Some(key) else {
              raise RepresentationSpecializationInvariant(
                detail="representation worker invocation omits a non-Unit parameter",
              )
            }
            parameters.push(PhysicalCallableParameterProjection::Slot(key))
            guard plan.function.parameters.get(index) is Some(parameter) else {
              parameter_callables.push(
                match key {
                  Callable(abi) =>
                    self.callable_interface_for_type_with_invocation(
                      type_,
                      plan.substitutions,
                      abi,
                    )
                  _ => None
                },
              )
              physical_index += 1
              continue
            }
            let mut nested : CallableRepresentationTarget? = None
            for entry in plan.key.callable_ports {
              if entry.0 == Value(parameter) && key is Callable(_) {
                nested = Some(entry.1)
                break
              }
            }
            parameter_callables.push(
              match nested {
                Some(callable) =>
                  Some(
                    self.callable_representation_interface(
                      callable,
                      worker=true,
                    ),
                  )
                None =>
                  match key {
                    Callable(abi) =>
                      self.callable_interface_for_type_with_invocation(
                        type_,
                        plan.substitutions,
                        abi,
                      )
                    _ => None
                  }
              },
            )
            physical_index += 1
          }
        }
    }
  }
  if physical_index != invocation.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation worker invocation has parameters outside its semantic projection",
    )
  }
  let result_callable = match invocation.result {
    Callable(abi) =>
      match plan.key.callable_result {
        Some(callable) =>
          Some(self.callable_representation_interface(callable, worker=true))
        None =>
          self.callable_interface_for_type_with_invocation(
            plan.result_type,
            plan.substitutions,
            abi,
          )
      }
    _ => None
  }
  let interface : PhysicalCallableInterface = {
    evidence_parameters: plan.residual_parameters,
    parameter_types: plan.parameter_types,
    result_type: plan.result_type,
    invocation,
    parameters,
    parameter_callables,
    result_callable,
  }
  interface.verify()
  interface
}

///|
fn ImageLowerer::callable_representation_interface(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  worker~ : Bool,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  if worker &&
    self.representation_specialization_for_callable(callable) is Some(plan) {
    return self.representation_worker_interface(plan)
  }
  guard self.callable_representation_implementation(callable, false)
    is Some(implementation) else {
    raise RepresentationSpecializationInvariant(
      detail="callable interface has no generic implementation",
    )
  }
  guard self.generic_callable_representation_target(callable)
    is Semantic(instance) else {
    raise RepresentationSpecializationInvariant(
      detail="generic callable interface has no canonical fallback instance",
    )
  }
  self.generic_function_interface(instance, implementation.function)
}

///|
fn physical_parameter_types(
  logical : Array[@anf.RuntimeType],
  scalar : Array[ScalarParameterPlan],
) -> Array[@anf.RuntimeType] {
  let physical = []
  for index, type_ in logical {
    let mut projected : ClosedAggregateContract? = None
    for parameter in scalar {
      if parameter.parameter_index == index {
        projected = Some(parameter.contract)
        break
      }
    }
    match projected {
      Some(contract) => physical.append(contract.payload_types)
      None => physical.push(type_)
    }
  }
  physical
}

///|
fn ImageLowerer::refine_callable_representation_substitution(
  self : ImageLowerer,
  source : @anf.RuntimeType,
  target : @anf.RuntimeType,
  base : RuntimeSubstitution,
  refinable : Array[@anf.RuntimeEvidenceId],
) -> RuntimeSubstitution? raise LoisvmLoweringError {
  let refinements = RuntimeSubstitution::new()
  self.collect_callable_representation_refinements(
    source,
    target,
    base,
    refinements,
    refinable,
    [],
  )
  let substitutions = base.overlay(refinements)
  if !self.types_representation_equivalent(
      substitutions.apply_type(self.runtime_types, source),
      target,
    ) {
    return None
  }
  Some(substitutions)
}

///|
fn ImageLowerer::collect_callable_representation_refinements(
  self : ImageLowerer,
  source : @anf.RuntimeType,
  target : @anf.RuntimeType,
  base : RuntimeSubstitution,
  refinements : RuntimeSubstitution,
  refinable : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Unit raise LoisvmLoweringError {
  let substitutions = base.overlay(refinements)
  if source is Erased(expression, _) &&
    self.runtime_types.type_expression(expression) is Some(Parameter(parameter)) &&
    refinable.contains(parameter) &&
    !bound.contains(parameter) {
    let resolved = substitutions.apply_type(self.runtime_types, source)
    if self.types_representation_equivalent(resolved, target) {
      return
    }
    if resolved is Erased(_, _) {
      refinements.insert(parameter, {
        type_expression: self.runtime_types.intern(Static(target)),
        evidence: runtime_type_evidence(target),
      })
      return
    }
  }
  match (source, target) {
    (
      Callable(source_parameters, source_result),
      Callable(target_parameters, target_result),
    ) => {
      guard source_parameters.length() == target_parameters.length() else {
        return
      }
      for index, source_parameter in source_parameters {
        self.collect_callable_representation_refinements(
          source_parameter,
          target_parameters[index],
          base,
          refinements,
          refinable,
          bound,
        )
      }
      self.collect_callable_representation_refinements(
        source_result, target_result, base, refinements, refinable, bound,
      )
    }
    (
      Forall(source_parameters, source_body),
      Forall(target_parameters, target_body),
    ) => {
      guard source_parameters.length() == target_parameters.length() else {
        return
      }
      self.collect_callable_representation_refinements(
        source_body,
        target_body,
        base,
        refinements,
        refinable,
        bound + source_parameters.map(parameter => parameter.id),
      )
    }
    _ => ()
  }
}

///|
fn ImageLowerer::canonical_specialized_evidence_key(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
  argument : @anf.RuntimeArgument,
  substitutions : RuntimeSubstitution,
) -> CanonicalSpecializedEvidenceKey raise LoisvmLoweringError {
  if parameter.arity == 0 {
    guard substitutions.argument_type(self.runtime_types, argument)
      is Some(argument_type) else {
      raise RepresentationSpecializationInvariant(
        detail="closed first-order evidence has no runtime type",
      )
    }
    FirstOrder(self.canonical_runtime_type_key(argument_type))
  } else {
    HigherKinded(
      canonical_runtime_evidence_key(
        substitutions.apply_evidence(argument.evidence),
      ),
    )
  }
}

///|
fn canonical_runtime_evidence_key(
  evidence : @anf.RuntimeEvidence,
) -> CanonicalRuntimeEvidenceKey raise LoisvmLoweringError {
  canonical_runtime_evidence_key_with(evidence, [])
}

///|
fn canonical_runtime_evidence_key_with(
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
) -> CanonicalRuntimeEvidenceKey raise LoisvmLoweringError {
  match evidence {
    Static(layout) => Static(layout)
    Parameter(parameter) => {
      for offset in 0..<bound.length() {
        if bound[bound.length() - offset - 1] == parameter {
          return Bound(offset)
        }
      }
      raise RepresentationSpecializationInvariant(
        detail="closed runtime evidence contains a free parameter",
      )
    }
    Apply(callee, arguments) =>
      Apply(
        canonical_runtime_evidence_key_with(callee, bound),
        arguments.map(argument => {
          canonical_runtime_evidence_key_with(argument, bound)
        }),
      )
    Lambda(parameters, body) =>
      Lambda(
        parameters.map(parameter => parameter.arity),
        canonical_runtime_evidence_key_with(
          body,
          bound + parameters.map(parameter => parameter.id),
        ),
      )
  }
}

///|
fn ImageLowerer::runtime_abi_changed(
  self : ImageLowerer,
  source_parameters : Array[@anf.RuntimeType],
  source_result : @anf.RuntimeType,
  target_parameters : Array[CanonicalRuntimeTypeKey],
  target_result : CanonicalRuntimeTypeKey,
) -> Bool raise LoisvmLoweringError {
  let source = source_parameters.map(type_ => {
    self.canonical_runtime_type_key(type_)
  })
  source != target_parameters ||
  self.canonical_runtime_type_key(source_result) != target_result
}

///|
fn ImageLowerer::representation_specialization_for_instance(
  self : ImageLowerer,
  instance : Int,
) -> RepresentationSpecializationPlan? {
  self.representation_specialization_for_callable(Semantic(instance))
}

///|
fn ImageLowerer::representation_specialization_for_callable(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> RepresentationSpecializationPlan? {
  for planned in self.plans.entries {
    if planned.entry is RepresentationWorker(plan) &&
      plan.aliases.contains(callable) {
      return Some(plan)
    }
  }
  None
}

///|
fn ImageLowerer::representation_call_target(
  self : ImageLowerer,
  callers : Array[Int],
  site : @anf.AnfBindingId,
) -> (CallableInstance, RepresentationSpecializationPlan)? {
  guard !callers.is_empty() else { return None }
  let mut selected : (CallableInstance, RepresentationSpecializationPlan)? = None
  for caller in callers {
    guard self.callable_instances.exact_call_target(caller, site)
      is Some(target) else {
      return None
    }
    guard self.representation_specialization_for_instance(target.id)
      is Some(plan) else {
      return None
    }
    match selected {
      None => selected = Some((target, plan))
      Some((_, selected_plan)) if selected_plan.key == plan.key => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn RepresentationSpecializationPlan::callable_type(
  self : RepresentationSpecializationPlan,
) -> @anf.RuntimeType {
  let callable = @anf.RuntimeType::Callable(
    physical_parameter_types(self.parameter_types, self.scalar_parameters),
    self.result_type,
  )
  if self.residual_parameters.is_empty() {
    callable
  } else {
    Forall(self.residual_parameters, callable)
  }
}

///|
fn ImageLowerer::representation_worker_invocation(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> CanonicalCallableAbi {
  self.representation_demand_invocation({
    key: plan.key,
    substitutions: plan.substitutions,
    specialized_parameters: plan.specialized_parameters,
    residual_parameters: plan.residual_parameters,
    parameter_types: plan.parameter_types,
    scalar_parameters: plan.scalar_parameters,
    result_type: plan.result_type,
  })
}

///|
fn ImageLowerer::callable_representation_physical_abi(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  worker~ : Bool,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  if worker &&
    self.representation_specialization_for_callable(callable) is Some(plan) {
    return self.representation_worker_invocation(plan)
  }
  self.generic_callable_representation_physical_abi(callable)
}

///|
fn ImageLowerer::generic_callable_representation_physical_abi(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self.ensure_generic_callable_invocation(callable)
}

///|
fn ImageLowerer::canonical_runtime_type_key_for_family(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  family : DataRepresentationFamilyKey?,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match (type_, family) {
    (Data(owner, _), Some(family)) if family.owner() == owner =>
      self.canonical_data_family_key(family)
    _ => self.canonical_runtime_type_key(type_)
  }
}

///|
fn ImageLowerer::canonical_runtime_type_key_for_representation(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  family : DataRepresentationFamilyKey?,
  callable : CallableRepresentationTarget?,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match callable {
    Some(callable) =>
      Callable(self.callable_representation_physical_abi(callable, worker=true))
    None => self.canonical_runtime_type_key_for_family(type_, family)
  }
}

///|
fn ImageLowerer::canonical_runtime_value_key_for_family(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  family : DataRepresentationFamilyKey?,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match type_ {
    Callable(_, _) | Forall(_, _) => self.canonical_runtime_value_key(type_)
    _ => self.canonical_runtime_type_key_for_family(type_, family)
  }
}

///|
fn ImageLowerer::canonical_runtime_type_key(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  self.canonical_runtime_type_key_under(type_, RuntimeSubstitution::new())
}

///|
fn ImageLowerer::canonical_runtime_value_key(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  self.canonical_runtime_value_key_under(type_, RuntimeSubstitution::new())
}

///|
fn ImageLowerer::canonical_runtime_value_key_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Concrete(Callable(_, _) | Forall(_, _) as callable, _) =>
      Callable(self.canonical_callable_value_abi(callable, substitutions))
    _ => self.canonical_runtime_type_key_under(type_, substitutions)
  }
}

///|
fn ImageLowerer::canonical_runtime_type_key_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    RuntimeUnit => Unit
    RuntimeErased =>
      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, })
    Concrete(Callable(_, _) | Forall(_, _) as type_, _) =>
      Callable(self.canonical_callable_abi_under(type_, substitutions))
    Concrete(type_, _) => {
      let type_ = substitutions.apply_type(self.runtime_types, type_)
      match self.elaborate_runtime_representation(type_) {
        RuntimeUnit => Unit
        RuntimeErased =>
          Value({
            representation: I64,
            cleanup: OwnedErased,
            kind: ErasedValue,
          })
        Concrete(type_, metadata) =>
          if metadata.kind is CallableValue {
            Callable(
              self.canonical_callable_abi_under(
                type_,
                RuntimeSubstitution::new(),
              ),
            )
          } else {
            Value({
              representation: metadata.representation,
              cleanup: metadata.cleanup,
              kind: metadata.kind,
            })
          }
      }
    }
  }
}

///|
/// Produces the canonical generic ABI for a first-class callable value.
/// Physical planning may select a concrete worker ABI for an acyclic value
/// port; recursive representation-demand SCCs retain this generic contract.
fn ImageLowerer::canonical_callable_value_abi(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self.canonical_callable_abi_under(type_, substitutions)
}

///|
fn ImageLowerer::canonical_callable_abi_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  let (type_parameters, parameters, result) = function_type_parts(type_)
  let witnesses : Array[@bytecode.ValueAbi] = []
  for parameter in type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = runtime_evidence_metadata(parameter)
      witnesses.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      })
    }
  }
  let parameter_abis : Array[CanonicalRuntimeTypeKey] = []
  for parameter in parameters {
    let key = self.canonical_runtime_value_key_under(parameter, substitutions)
    if !(key is Unit) {
      parameter_abis.push(key)
    }
  }
  {
    witnesses,
    parameters: parameter_abis,
    result: self.canonical_runtime_value_key_under(result, substitutions),
  }
}

///|
fn ImageLowerer::generic_argument_is_closed(
  self : ImageLowerer,
  argument : @anf.RuntimeArgument,
) -> Bool {
  let free = []
  collect_free_runtime_type_expression(self, argument.type_expression, [], free)
  collect_free_runtime_evidence(self, argument.evidence, [], free)
  free.is_empty()
}

///|
