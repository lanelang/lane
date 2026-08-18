///|
fn ImageLowerer::plan_representation_specializations(
  self : ImageLowerer,
  instances : CallableInstancePlan,
) -> Unit raise LoisvmLoweringError {
  for instance in instances.instances {
    guard !instance.generic_fallback else { continue }
    if instance.definition.recursive_group is Some(group) &&
      instances.rejected_recursive_groups.contains(group) {
      continue
    }
    guard self.representation_demand(instance) is Some(demand) else { continue }
    let mut existing = false
    for plan in self.representation_specializations {
      if plan.key == demand.key {
        plan.instances.push(instance.id)
        existing = true
        break
      }
    }
    guard !existing else { continue }
    let physical_parameters = physical_parameter_types(
      demand.parameter_types,
      demand.scalar_parameters,
    )
    let function_type = if demand.retained_parameters.is_empty() {
      @anf.RuntimeType::Callable(physical_parameters, demand.result_type)
    } else {
      Forall(
        demand.retained_parameters,
        Callable(physical_parameters, demand.result_type),
      )
    }
    let (capture, recursive_functions) = match instance.definition.owner {
      Some(_) => {
        guard instances.generic_instance(instance.definition.function.id)
          is Some(generic) &&
          self.lifted_function(generic) is Some(fallback) else {
          raise RepresentationSpecializationInvariant(
            detail="nested specialization has no planned generic closure",
          )
        }
        (fallback.capture, fallback.recursive_functions)
      }
      _ =>
        (
          self.plan_callable_capture(
            instance.definition,
            function_type,
            demand.substitutions,
            demand.specialized_parameters,
          ),
          [],
        )
    }
    let (_, plan) = self.plans.append_with_result(
      RepresentationSpecialization(
        function=instance.definition.function.id,
        source=instance.definition.function.source,
      ),
      fn(worker) {
        let plan : RepresentationSpecializationPlan = {
          worker,
          instances: [instance.id],
          key: demand.key,
          function: instance.definition.function,
          substitutions: demand.substitutions,
          retained_parameters: demand.retained_parameters,
          specialized_parameters: demand.specialized_parameters,
          parameter_types: demand.parameter_types,
          scalar_parameters: demand.scalar_parameters,
          result_type: demand.result_type,
          capture,
          recursive_functions,
        }
        (RepresentationWorker(plan), plan)
      },
    )
    self.representation_specializations.push(plan)
  }
}

///|
priv struct RepresentationDemand {
  key : RepresentationSpecializationKey
  substitutions : RuntimeSubstitution
  retained_parameters : Array[@anf.RuntimeEvidenceParameter]
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  parameter_types : Array[@anf.RuntimeType]
  scalar_parameters : Array[ScalarParameterPlan]
  result_type : @anf.RuntimeType
}

///|
fn ImageLowerer::representation_demand(
  self : ImageLowerer,
  instance : CallableInstance,
) -> RepresentationDemand? raise LoisvmLoweringError {
  let definition = instance.definition
  guard instance.own_arguments.length() == definition.parameters.length() else {
    return None
  }
  let (_, formal_parameters, formal_result) = function_type_parts(
    definition.type_,
  )
  let substitutions = instance.substitution
  let retained_parameters = []
  let specialized_parameters = []
  let specialized_evidence = []
  for index, parameter in definition.lexical_parameters {
    let argument = instance.key.arguments[index]
    if is_closed_generic_argument(argument) {
      specialized_parameters.push(parameter.id)
      specialized_evidence.push(
        (
          index,
          self.canonical_specialized_evidence_key(
            parameter, argument, substitutions,
          ),
        ),
      )
    } else if parameter.arity == 0 {
      return None
    }
  }
  for index, parameter in definition.parameters {
    let argument = instance.own_arguments[index].argument
    if is_closed_generic_argument(argument) {
      specialized_parameters.push(parameter.id)
      specialized_evidence.push(
        (
          definition.lexical_parameters.length() + index,
          self.canonical_specialized_evidence_key(
            parameter, argument, substitutions,
          ),
        ),
      )
    } else {
      guard argument.evidence is Parameter(retained) &&
        self.evidence_parameter(retained) is Some(retained_parameter) &&
        retained_parameter.arity == parameter.arity else {
        return None
      }
      retained_parameters.push(retained_parameter)
    }
  }
  let parameter_types = formal_parameters.map(type_ => {
    substitutions.apply_type(self.runtime_types, type_)
  })
  let result_type = substitutions.apply_type(self.runtime_types, formal_result)
  let scalar_parameters = []
  for index in 0..<parameter_types.length() {
    if self.callable_instances.scalar_parameter_contract(instance.id, index)
      is Some(contract) {
      scalar_parameters.push({
        instance: instance.id,
        parameter_index: index,
        contract,
      })
    }
  }
  guard !scalar_parameters.is_empty() ||
    self.runtime_abi_changed(
      formal_parameters, formal_result, parameter_types, result_type,
    ) else {
    return None
  }
  let physical_parameters = physical_parameter_types(
    parameter_types, scalar_parameters,
  )
  let parameters = []
  for type_ in physical_parameters {
    let key = self.canonical_runtime_type_key(type_)
    if !(key is Unit) {
      parameters.push(key)
    }
  }
  Some({
    key: {
      source_function: definition.function.id,
      specialized_evidence,
      retained_arities: retained_parameters.map(parameter => parameter.arity),
      parameters,
      scalar_parameters: scalar_parameters.map(parameter => {
        (
          parameter.parameter_index,
          parameter.contract.data_constructor,
          parameter.contract.payload_types.map(type_ => {
            self.canonical_runtime_type_key(type_)
          }),
        )
      }),
      result: self.canonical_runtime_type_key(result_type),
    },
    substitutions,
    retained_parameters,
    specialized_parameters,
    parameter_types,
    scalar_parameters,
    result_type,
  })
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
  target_parameters : Array[@anf.RuntimeType],
  target_result : @anf.RuntimeType,
) -> Bool raise LoisvmLoweringError {
  let source = source_parameters.map(type_ => {
    self.canonical_runtime_type_key(type_)
  })
  let target = target_parameters.map(type_ => {
    self.canonical_runtime_type_key(type_)
  })
  source != target ||
  self.canonical_runtime_type_key(source_result) !=
  self.canonical_runtime_type_key(target_result)
}

///|
fn ImageLowerer::representation_specialization_for_instance(
  self : ImageLowerer,
  instance : Int,
) -> RepresentationSpecializationPlan? {
  for plan in self.representation_specializations {
    if plan.instances.contains(instance) {
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
  if self.retained_parameters.is_empty() {
    callable
  } else {
    Forall(self.retained_parameters, callable)
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
fn ImageLowerer::canonical_runtime_type_key_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    RuntimeUnit => Unit
    RuntimeErased(_) =>
      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
    Concrete(Callable(_, _) | Forall(_, _) as type_, _) =>
      Callable(self.canonical_callable_abi_under(type_, substitutions))
    Concrete(type_, _) => {
      let type_ = substitutions.apply_type(self.runtime_types, type_)
      match self.elaborate_runtime_representation(type_) {
        RuntimeUnit => Unit
        RuntimeErased(_) =>
          Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
        Concrete(type_, metadata) =>
          if metadata.kind is CallableValue {
            Callable(self.canonical_callable_abi(type_))
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
fn ImageLowerer::canonical_callable_abi(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self.canonical_callable_abi_under(type_, RuntimeSubstitution::new())
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
    let key = self.canonical_runtime_type_key_under(parameter, substitutions)
    if !(key is Unit) {
      parameter_abis.push(key)
    }
  }
  {
    witnesses,
    parameters: parameter_abis,
    result: self.canonical_runtime_type_key_under(result, substitutions),
  }
}

///|
fn is_closed_generic_argument(argument : @anf.RuntimeArgument) -> Bool {
  is_closed_evidence(argument.evidence, [])
}

///|
fn is_closed_evidence(
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match evidence {
    Static(_) => true
    Parameter(parameter) => bound.contains(parameter)
    Apply(callee, arguments) =>
      is_closed_evidence(callee, bound) &&
      arguments.all(argument => is_closed_evidence(argument, bound))
    Lambda(parameters, body) => {
      let nested = bound + parameters.map(parameter => parameter.id)
      is_closed_evidence(body, nested)
    }
  }
}

///|
fn ImageLowerer::lower_representation_worker(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  self.lower_function_body(
    plan.function,
    plan.instances,
    plan.retained_parameters,
    plan.parameter_types,
    plan.result_type,
    plan.capture.captured_evidence.map(evidence => evidence.target),
    plan.capture.captures,
    plan.capture.environment_shape,
    plan.recursive_functions,
    plan.substitutions,
    plan.specialized_parameters,
    scalar_parameters=plan.scalar_parameters,
  )
}
