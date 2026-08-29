///|
priv struct PhysicalEvidenceBinding {
  parameter : @anf.RuntimeEvidenceId
  contract : PhysicalEvidenceContract
} derive(Eq)

///|
fn PhysicalCallableContractCatalog::reserve(
  self : PhysicalCallableContractCatalog,
  request : PhysicalCallableContractRequest,
) -> (PhysicalCallableContractId, Bool) {
  for index, existing in self.requests {
    if existing == request {
      return ({ value: index, }, false)
    }
  }
  let id : PhysicalCallableContractId = { value: self.requests.length(), }
  self.requests.push(request)
  self.entries.push(None)
  (id, true)
}

///|
fn PhysicalCallableContractCatalog::complete(
  self : PhysicalCallableContractCatalog,
  id : PhysicalCallableContractId,
  contract : PhysicalCallableContract,
) -> Unit {
  self.entries[id.value] = Some(contract)
}

///|
fn PhysicalCallableContractCatalog::get(
  self : PhysicalCallableContractCatalog,
  id : PhysicalCallableContractId,
) -> PhysicalCallableContract {
  self.entries[id.value].unwrap()
}

///|
fn ImageLowerer::intern_callable_adapter_worker_contract(
  self : ImageLowerer,
  contract : CallableAdapterWorkerContract,
) -> CallableAdapterWorkerContractId {
  for index, existing in self.callable_adapter_worker_contracts.entries {
    if existing.source_parameter_targets == contract.source_parameter_targets &&
      self.physical_callable_contracts_equivalent(
        existing.source,
        contract.source,
      ) &&
      self.physical_callable_contracts_equivalent(
        existing.target,
        contract.target,
      ) {
      return { value: index, }
    }
  }
  let id : CallableAdapterWorkerContractId = {
    value: self.callable_adapter_worker_contracts.entries.length(),
  }
  self.callable_adapter_worker_contracts.entries.push(contract)
  id
}

///|
priv enum PhysicalContractComparison {
  Invocation
  Complete
} derive(Eq)

///|
priv struct PhysicalContractVisit {
  left : PhysicalCallableContractId
  right : PhysicalCallableContractId
  comparison : PhysicalContractComparison
} derive(Eq)

///|
fn ImageLowerer::physical_callable_contracts_equivalent(
  self : ImageLowerer,
  left : PhysicalCallableContractId,
  right : PhysicalCallableContractId,
) -> Bool {
  self.physical_callable_contracts_equivalent_under(left, right, [], Complete)
}

///|
fn ImageLowerer::physical_callable_invocations_equivalent(
  self : ImageLowerer,
  left : PhysicalCallableContractId,
  right : PhysicalCallableContractId,
) -> Bool {
  self.physical_callable_contracts_equivalent_under(left, right, [], Invocation)
}

///|
fn ImageLowerer::physical_callable_contracts_equivalent_under(
  self : ImageLowerer,
  left : PhysicalCallableContractId,
  right : PhysicalCallableContractId,
  visited : Array[PhysicalContractVisit],
  comparison : PhysicalContractComparison,
) -> Bool {
  let visit : PhysicalContractVisit = { left, right, comparison, }
  if left == right || visited.contains(visit) {
    return true
  }
  visited.push(visit)
  let left_contract = self.physical_callable_contracts.get(left)
  let right_contract = self.physical_callable_contracts.get(right)
  if left_contract.witnesses != right_contract.witnesses ||
    (
      comparison is Complete &&
      left_contract.evidence_arguments != right_contract.evidence_arguments
    ) ||
    left_contract.parameters.length() != right_contract.parameters.length() {
    return false
  }
  for index, left_parameter in left_contract.parameters {
    if !self.physical_value_boundaries_equivalent_under(
        left_parameter,
        right_contract.parameters[index],
        visited,
        comparison,
      ) {
      return false
    }
  }
  self.physical_value_boundaries_equivalent_under(
    left_contract.result,
    right_contract.result,
    visited,
    comparison,
  )
}

///|
fn ImageLowerer::physical_value_boundaries_equivalent_under(
  self : ImageLowerer,
  left : PhysicalValueBoundary,
  right : PhysicalValueBoundary,
  visited : Array[PhysicalContractVisit],
  comparison : PhysicalContractComparison,
) -> Bool {
  if !self.physical_value_contracts_equivalent_under(
      left.abi,
      right.abi,
      visited,
      Invocation,
    ) {
    return false
  }
  comparison is Invocation ||
  self.physical_value_contracts_equivalent_under(
    left.shape,
    right.shape,
    visited,
    Complete,
  )
}

///|
fn ImageLowerer::physical_value_contracts_equivalent_under(
  self : ImageLowerer,
  left : PhysicalValueContract,
  right : PhysicalValueContract,
  visited : Array[PhysicalContractVisit],
  comparison : PhysicalContractComparison,
) -> Bool {
  match (left, right) {
    (Callable(left), Callable(right)) =>
      self.physical_callable_contracts_equivalent_under(
        left, right, visited, comparison,
      )
    _ => left == right
  }
}

///|
fn ImageLowerer::callable_adapter_reason(
  self : ImageLowerer,
  source : PhysicalCallableContractId,
  target : PhysicalCallableContractId,
) -> CallableAdapterReason raise PhysicalLoweringError {
  let source_contract = self.physical_callable_contracts.get(source)
  let target_contract = self.physical_callable_contracts.get(target)
  let differences : Array[CallableContractDifference] = []
  if !self.physical_callable_invocations_equivalent(source, target) {
    differences.push(Invocation)
  }
  if source_contract.evidence_arguments != target_contract.evidence_arguments {
    differences.push(Evidence)
  }
  let parameter_count = source_contract.parameters
    .length()
    .max(target_contract.parameters.length())
  for index = 0; index < parameter_count; index = index + 1 {
    let different = match
      (
        source_contract.parameters.get(index),
        target_contract.parameters.get(index),
      ) {
      (Some(source), Some(target)) =>
        !self.physical_value_boundaries_equivalent_under(
          source,
          target,
          [],
          Complete,
        )
      _ => true
    }
    if different {
      differences.push(Parameter(index))
    }
  }
  if !self.physical_value_boundaries_equivalent_under(
      source_contract.result,
      target_contract.result,
      [],
      Complete,
    ) {
    differences.push(Result)
  }
  if differences.is_empty() {
    raise InvalidTypeApplication(
      detail="an identity callable adaptation reached worker materialization",
    )
  }
  { source, target, differences, }
}

///|
fn ImageLowerer::callable_adapter_worker_contract(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> (CallableAdapterWorkerContractId, CallableAdapterReason) raise PhysicalLoweringError {
  let (source, target) = self.callable_adapter_contract_boundaries(contract)
  let worker_contract = self.intern_callable_adapter_worker_contract({
    source,
    target,
    source_parameter_targets: contract.source_parameter_targets,
  })
  let canonical = self.callable_adapter_worker_contracts.entries[worker_contract.value]
  let reason = self.callable_adapter_reason(canonical.source, canonical.target)
  (worker_contract, reason)
}

///|
fn ImageLowerer::callable_adapter_contract_boundaries(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> (PhysicalCallableContractId, PhysicalCallableContractId) raise PhysicalLoweringError {
  let (source_type_parameters, _, _) = function_type_parts(contract.source_type)
  let (target_type_parameters, _, _) = function_type_parts(contract.target_type)
  let evidence : Array[PhysicalEvidenceBinding] = []
  let mut input_index = 0
  for parameter in target_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      bind_physical_evidence(evidence, parameter.id, Input(input_index))
      input_index += 1
    }
  }
  for index, parameter in contract.captured_parameters {
    bind_physical_evidence(evidence, parameter.id, Capture(index))
  }
  for index, source_parameter in source_type_parameters {
    let source = match contract.substitutions.argument(source_parameter.id) {
      Some(argument) =>
        self.physical_evidence_contract(
          contract.substitutions.apply_evidence(argument.evidence),
          evidence,
        )
      None => {
        guard target_type_parameters.get(index) is Some(target_parameter) else {
          raise InvalidTypeApplication(
            detail="callable adapter has no evidence source for a generic source parameter",
          )
        }
        find_physical_evidence(evidence, target_parameter.id)
      }
    }
    bind_physical_evidence(evidence, source_parameter.id, source)
  }
  let source = self.physical_callable_contract(
    contract.source_type,
    contract.substitutions,
    evidence,
  )
  let target = self.physical_callable_contract(
    contract.target_type,
    contract.substitutions,
    evidence,
  )
  (source, target)
}

///|
fn ImageLowerer::physical_callable_contract(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  evidence : Array[PhysicalEvidenceBinding],
) -> PhysicalCallableContractId raise PhysicalLoweringError {
  let (id, reserved) = self.physical_callable_contracts.reserve({
    type_,
    substitutions,
    evidence: evidence.copy(),
  })
  if !reserved {
    return id
  }
  let (type_parameters, parameters, result) = function_type_parts(type_)
  let nested_evidence = evidence.copy()
  let mut bound_index = 0
  for parameter in type_parameters {
    if !nested_evidence.any(binding => binding.parameter == parameter.id) {
      bind_physical_evidence(nested_evidence, parameter.id, Bound(bound_index))
      bound_index += 1
    }
  }
  let evidence_arguments = []
  for parameter in type_parameters {
    if self.requires_runtime_evidence(parameter) {
      evidence_arguments.push(
        find_physical_evidence(nested_evidence, parameter.id),
      )
    }
  }
  self.physical_callable_contracts.complete(id, {
    witnesses: type_parameters.filter_map(parameter => {
      if self.requires_runtime_evidence(parameter) {
        Some(value_metadata_abi(runtime_evidence_metadata(parameter)))
      } else {
        None
      }
    }),
    evidence_arguments,
    parameters: parameters.filter_map(parameter => {
      let boundary = self.physical_value_boundary(
        parameter, substitutions, nested_evidence,
      )
      if boundary.abi is Unit {
        None
      } else {
        Some(boundary)
      }
    }),
    result: self.physical_value_boundary(result, substitutions, nested_evidence),
  })
  id
}

///|
fn ImageLowerer::physical_value_boundary(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  evidence : Array[PhysicalEvidenceBinding],
) -> PhysicalValueBoundary raise PhysicalLoweringError {
  {
    abi: self.physical_value_contract(type_, substitutions, evidence, false),
    shape: self.physical_value_contract(
      substitutions.apply_type(self.runtime_types, type_),
      substitutions,
      evidence,
      true,
    ),
  }
}

///|
fn ImageLowerer::physical_value_contract(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  evidence : Array[PhysicalEvidenceBinding],
  include_evidence : Bool,
) -> PhysicalValueContract raise PhysicalLoweringError {
  match self.elaborate_runtime_representation(type_) {
    RuntimeUnit => Unit
    RuntimeErased(runtime_evidence) =>
      if include_evidence {
        Open(self.physical_evidence_contract(runtime_evidence, evidence))
      } else {
        Erased
      }
    Concrete(Callable(_, _) | Forall(_, _) as callable, _) => {
      let contract = self.physical_callable_contract(
        callable, substitutions, evidence,
      )
      Callable(contract)
    }
    Concrete(concrete, metadata) =>
      Concrete(value_metadata_abi(metadata), concrete_layout_recipe(concrete))
  }
}

///|
fn ImageLowerer::physical_evidence_contract(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
  bindings : Array[PhysicalEvidenceBinding],
) -> PhysicalEvidenceContract raise PhysicalLoweringError {
  match evidence {
    Static(layout) => Static(runtime_layout_recipe(layout))
    Parameter(parameter) => find_physical_evidence(bindings, parameter)
    Apply(callee, arguments) =>
      Apply(
        self.physical_evidence_contract(callee, bindings),
        arguments.map(argument => {
          self.physical_evidence_contract(argument, bindings)
        }),
      )
    Lambda(parameters, body) => {
      let nested = bindings.copy()
      for index, parameter in parameters {
        bind_physical_evidence(nested, parameter.id, Bound(index))
      }
      Lambda(
        parameters.map(parameter => parameter.arity),
        self.physical_evidence_contract(body, nested),
      )
    }
  }
}

///|
fn bind_physical_evidence(
  bindings : Array[PhysicalEvidenceBinding],
  parameter : @anf.RuntimeEvidenceId,
  contract : PhysicalEvidenceContract,
) -> Unit raise PhysicalLoweringError {
  for binding in bindings {
    if binding.parameter == parameter {
      if binding.contract != contract {
        raise InvalidTypeApplication(
          detail="callable adapter evidence parameter has two physical sources",
        )
      }
      return
    }
  }
  bindings.push({ parameter, contract, })
}

///|
fn find_physical_evidence(
  bindings : Array[PhysicalEvidenceBinding],
  parameter : @anf.RuntimeEvidenceId,
) -> PhysicalEvidenceContract raise PhysicalLoweringError {
  for binding in bindings {
    if binding.parameter == parameter {
      return binding.contract
    }
  }
  raise InvalidTypeApplication(
    detail="missing physical evidence source for \{Repr(parameter)}",
  )
}

///|
fn value_metadata_abi(metadata : @vmcfg.ValueMetadata) -> @physical.ValueAbi {
  {
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
  }
}

///|
