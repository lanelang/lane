///|
fn ImageLowerer::plan_representation_specializations(
  self : ImageLowerer,
  physical : PhysicalRepresentationPlan,
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
    let forced_callable_type = self.representation_demands.callable_representation_target_type(
      callable,
    )
    let closed_call_target = instances.is_closed_call_target(instance.id)
    let physical_value = self.representation_demands.demands_callable_instance(
      callable,
    )
    guard forced_callable_type is Some(_) ||
      closed_call_target ||
      physical_value else {
      continue
    }
    guard self.representation_demand(instance, forced_callable_type)
      is Some(demand) else {
      continue
    }
    demands.push((callable, instance, demand))
  }
  let refined_targets = self.complete_refined_callable_targets(
    self.representation_demands.refined_callable_targets(),
    instances,
  )
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
    guard self.representation_demand(instance, Some(forced_callable_type))
      is Some(demand) else {
      continue
    }
    demands.push((callable, instance, demand))
  }
  let completed = self.complete_representation_demands(demands)
  for draft in completed {
    let callable = draft.0
    let instance = draft.1
    let demand = draft.2
    let mut existing = false
    for plan in physical.representation_workers {
      if plan.key == demand.key {
        if !plan.callables.contains(callable) {
          plan.callables.push(callable)
        }
        if !plan.analysis_instances.contains(instance.id) {
          plan.analysis_instances.push(instance.id)
        }
        for
          component in self.representation_demands.data_components_for_instance(
            instance.id,
          ) {
          if !plan.data_components.contains(component) {
            plan.data_components.push(component)
          }
        }
        for
          component in self.representation_demands.callable_components_for_target(
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
          callables: [callable],
          analysis_instances: [instance.id],
          data_components: self.representation_demands.data_components_for_instance(
            instance.id,
          ),
          callable_components: self.representation_demands.callable_components_for_target(
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
    physical.representation_workers.push(plan)
  }
}

///|
fn ImageLowerer::complete_representation_demands(
  self : ImageLowerer,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
) -> Array[
  (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
] raise LoisvmLoweringError {
  let states = Array::make(
    demands.length(),
    RepresentationDemandCompletion::Unvisited,
  )
  Array::makei(demands.length(), index => {
    let draft = demands[index]
    (
      draft.0,
      draft.1,
      self.complete_representation_demand(index, demands, states),
    )
  })
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
  states : Array[RepresentationDemandCompletion],
) -> RepresentationDemand raise LoisvmLoweringError {
  match states[index] {
    Completed(demand) => return demand
    Visiting =>
      raise RepresentationSpecializationInvariant(
        detail="recursive physical callable ABI demand has no finite structural contract",
      )
    Unvisited => ()
  }
  states[index] = Visiting
  let draft = demands[index]
  let instance = draft.1
  let demand = {
    ..draft.2,
    key: {
      ..draft.2.key,
      parameters: self.representation_parameter_shapes(
        instance,
        draft.2,
        demands,
        states,
      ),
      result: self.representation_result_shape(
        instance,
        draft.2,
        demands,
        states,
      ),
      captures: self.representation_capture_shapes(
        instance,
        draft.2,
        demands,
        states,
      ),
    },
  }
  states[index] = Completed(demand)
  demand
}

///|
fn ImageLowerer::representation_callable_abi(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  for index, draft in demands {
    if draft.0 == callable {
      let demand = self.complete_representation_demand(index, demands, states)
      return self.representation_demand_invocation(demand)
    }
  }
  let generic = self.generic_callable_representation_target(callable)
  guard generic is Semantic(instance) &&
    self.generic_callable_instance_implementation(instance)
    is Some(implementation) else {
    raise RepresentationSpecializationInvariant(
      detail="physical callable demand has no generic implementation contract",
    )
  }
  self.canonical_callable_value_abi(
    implementation.type_,
    RuntimeSubstitution::new(),
  )
}

///|
fn ImageLowerer::representation_result_shape(
  self : ImageLowerer,
  instance : CallableInstance,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match
    self.representation_result_callable_abi(
      instance.id,
      demand,
      demands,
      states,
    ) {
    Some(abi) => CanonicalRuntimeTypeKey::Callable(abi)
    None =>
      self.canonical_runtime_value_key_for_family(
        demand.result_type,
        self.representation_demands.data_family_at_result([instance.id]),
      )
  }
}

///|
fn ImageLowerer::representation_result_callable_abi(
  self : ImageLowerer,
  instance : Int,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi? raise LoisvmLoweringError {
  guard self.representation_demands.callable_instance_at_result([instance])
    is Some(callable) else {
    return None
  }
  if demand.key.callable_result == Some(callable) {
    return Some(self.representation_callable_abi(callable, demands, states))
  }
  Some(self.generic_callable_representation_physical_abi(callable))
}

///|
fn ImageLowerer::representation_port_callable_abi(
  self : ImageLowerer,
  instance : Int,
  binding : @anf.AnfBindingId,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> CanonicalCallableAbi? raise LoisvmLoweringError {
  guard self.representation_demands.callable_instance_at_port(
      [instance],
      binding,
    )
    is Some(callable) else {
    return None
  }
  if demand.key.callable_ports.any(entry => {
      entry.0 == binding && entry.1 == callable
    }) {
    return Some(self.representation_callable_abi(callable, demands, states))
  }
  Some(self.generic_callable_representation_physical_abi(callable))
}

///|
fn ImageLowerer::representation_parameter_shapes(
  self : ImageLowerer,
  instance : CallableInstance,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> Array[CanonicalRuntimeTypeKey] raise LoisvmLoweringError {
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
                instance.id,
                Value(parameter),
                demand,
                demands,
                states,
              ) {
              Some(abi) => CanonicalRuntimeTypeKey::Callable(abi)
              None =>
                self.canonical_runtime_value_key_for_family(
                  type_,
                  self.representation_demands.data_family_at_port(
                    [instance.id],
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
fn ImageLowerer::complete_refined_callable_targets(
  self : ImageLowerer,
  initial : Array[CallableRepresentationTarget],
  instances : CallableInstancePlan,
) -> Array[CallableRepresentationTarget] raise LoisvmLoweringError {
  let targets = initial.copy()
  let mut index = 0
  while index < targets.length() {
    let parent = targets[index]
    guard parent.instance(instances) is Some(parent_instance) else {
      raise RepresentationSpecializationInvariant(
        detail="refined callable target has no semantic source",
      )
    }
    for definition in self.callable_catalog.definitions() {
      guard definition.owner == Some(parent_instance.definition.function.id) else {
        continue
      }
      let nested = self.callable_representation_candidate(
        definition.function.id,
        parent_instance.substitution,
      )
      guard nested is Refined(..) && !targets.contains(nested) else { continue }
      guard nested.instance(instances) is Some(instance) else {
        raise RepresentationSpecializationInvariant(
          detail="refined nested callable target has no semantic source",
        )
      }
      let callable_type = instance.substitution.apply_type(
        self.runtime_types,
        instance.definition.type_,
      )
      if self.representation_demand(instance, Some(callable_type)) is Some(_) {
        targets.push(nested)
      }
    }
    index += 1
  }
  targets
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
  guard self.callable_catalog.find(function) is Some(definition) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation target is absent from the Runtime ANF catalog",
    )
  }
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    substitutions
    .argument(parameter.id)
    .map(argument => substitutions.apply_argument(self.runtime_types, argument))
    .unwrap_or_else(() => self.identity_runtime_argument(parameter))
  })
  let own_arguments = definition.parameters.map(parameter => {
    argument: self.identity_runtime_argument(parameter),
    transform: RuntimeArgumentTransform::Projection(parameter.id),
  })
  let arguments = lexical_arguments +
    own_arguments.map(argument => argument.argument)
  for instance in self.callable_instances.instances {
    if instance.key.function == function && instance.key.arguments == arguments {
      return Semantic(instance.id)
    }
  }
  guard self.callable_instances.generic_instance(function) is Some(source) else {
    raise RepresentationSpecializationInvariant(
      detail="refined callable target has no semantic generic source",
    )
  }
  Refined(source_instance=source, lexical_arguments~, own_arguments~)
}

///|
fn ImageLowerer::freeze_callable_representation_targets(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for index, demand in self.representation_demands.callable_ports {
    self.representation_demands.callable_ports[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for index, demand in self.representation_demands.callable_results {
    self.representation_demands.callable_results[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  for index, demand in self.representation_demands.callable_arguments {
    self.representation_demands.callable_arguments[index] = {
      ..demand,
      callable: self.frozen_callable_representation_target(demand.callable),
    }
  }
  let data = self.representation_demands.data_representations
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
  { type_expression, evidence: Parameter(parameter.id) }
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
  instance : CallableInstance,
  forced_callable_type : @anf.RuntimeType?,
) -> RepresentationDemand? raise LoisvmLoweringError {
  let definition = instance.definition
  guard instance.own_arguments.length() == definition.parameters.length() else {
    return None
  }
  let (_, formal_parameters, formal_result) = function_type_parts(
    definition.type_,
  )
  let instance_substitutions = match forced_callable_type {
    Some(target) =>
      self.refine_callable_representation_substitution(
        definition.type_,
        target,
        instance.substitution,
        (definition.lexical_parameters + definition.parameters).map(parameter => {
          parameter.id
        }),
      )
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
    if self.representation_demands.scalar_parameter_contract(instance.id, index)
      is Some(contract) {
      scalar_parameters.push({
        instance: instance.id,
        parameter_index: index,
        contract,
      })
    }
  }
  let data_ports = self.representation_demands.data_port_assignments(
    instance.id,
  )
  let data_capture = self.representation_demands.has_data_capture_assignment(
    instance.id,
  )
  let callable_ports = self.representation_demands.callable_port_assignments(
    instance.id,
  )
  let callable_result = self.representation_demands.worker_callable_at_result([
    instance.id,
  ])
  guard !data_ports.is_empty() ||
    data_capture ||
    !callable_ports.is_empty() ||
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
            self.representation_demands.data_family_at_port(
              [instance.id],
              Value(parameter),
            )
          None => None
        }
        let callable = match definition.function.parameters.get(index) {
          Some(parameter) =>
            self.representation_demands.worker_callable_at_port(
              [instance.id],
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
    self.representation_demands.data_family_at_result([instance.id]),
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
      callable_arguments: self.representation_demands.callable_argument_assignments(
        instance.id,
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
  instance : CallableInstance,
  demand : RepresentationDemand,
  demands : Array[
    (CallableRepresentationTarget, CallableInstance, RepresentationDemand),
  ],
  states : Array[RepresentationDemandCompletion],
) -> Array[(@anf.AnfBindingId, CanonicalRuntimeTypeKey)] raise LoisvmLoweringError {
  let captures : Array[(@anf.AnfBindingId, CanonicalRuntimeTypeKey)] = []
  for capture in instance.definition.captures {
    let binding = match capture {
      Value(value) => @anf.AnfBindingId::Value(value)
      Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    guard !captures.any(existing => existing.0 == binding) else { continue }
    guard self.callable_catalog.capture_type(capture, self.metadata)
      is Some(type_) else {
      raise RepresentationSpecializationInvariant(
        detail="representation worker capture lacks Runtime ANF type metadata",
      )
    }
    let type_ = instance.substitution.apply_type(self.runtime_types, type_)
    let shape = match
      self.representation_port_callable_abi(
        instance.id,
        binding,
        demand,
        demands,
        states,
      ) {
      Some(abi) => CanonicalRuntimeTypeKey::Callable(abi)
      None =>
        self.canonical_runtime_value_key_for_family(
          type_,
          self.representation_demands.data_family_at_capture(
            [instance.id],
            binding,
          ),
        )
    }
    captures.push((binding, shape))
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
    return Some({ function, type_ })
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
    return Some({ function: plan.worker, type_: plan.callable_type() })
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
) -> RuntimeSubstitution raise LoisvmLoweringError {
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
    raise RepresentationSpecializationInvariant(
      detail="planned callable source \{Repr(source)} with refinable evidence \{Repr(refinable)} does not determine target representation \{Repr(target)} under \{Repr(base)} and \{Repr(refinements)}",
    )
  }
  substitutions
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
  guard self.physical_representations is Some(physical) else { return None }
  for plan in physical.representation_workers {
    if plan.callables.contains(callable) {
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
      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
    Concrete(Callable(_, _) | Forall(_, _) as type_, _) =>
      Callable(self.canonical_callable_abi_under(type_, substitutions))
    Concrete(type_, _) => {
      let type_ = substitutions.apply_type(self.runtime_types, type_)
      match self.elaborate_runtime_representation(type_) {
        RuntimeUnit => Unit
        RuntimeErased =>
          Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
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
/// A first-class callable has one generic value ABI. Representation workers
/// may expose a more concrete direct-call ABI, but that ABI is never used for
/// a callable stored in a slot, aggregate, capture, parameter, or result.
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
fn ImageLowerer::lower_representation_worker(
  self : ImageLowerer,
  lowered_function : @bytecode.FunctionId,
  plan : RepresentationSpecializationPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  self.lower_function_body(
    lowered_function,
    plan.function,
    true,
    [],
    plan.parameter_types,
    plan.recursive_functions,
    plan.substitutions,
    plan.specialized_parameters,
  )
}
