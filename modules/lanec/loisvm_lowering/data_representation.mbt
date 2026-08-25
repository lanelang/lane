///|
fn ImageLowerer::plan_declaration_data_families(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for item in self.metadata.data_types() {
    let (owner, info) = item
    guard info.kind is Data else { continue }
    self.data_families.push({
      identity: { index: self.data_families.length(), },
      key: Declaration(owner),
      bytecode_family: None,
      owner,
      constructors: [],
    })
  }
  for family in self.data_families {
    guard family.key is Declaration(_) else { continue }
    guard self.metadata.type_info(family.owner) is Some(owner_info) else {
      raise RepresentationSpecializationInvariant(
        detail="declaration data family lacks runtime metadata",
      )
    }
    for data_constructor in owner_info.constructors {
      guard self.metadata.data_constructor_info(data_constructor) is Some(info) else {
        raise MissingDataConstructorMetadata(data_constructor~)
      }
      family.constructors.push({
        data_constructor,
        shape: None,
        storage_hidden_arguments: None,
        storage_evidence_parameters: info.hidden_evidence_parameters,
        storage_types: info.payload_types,
        storage_data_families: Array::makei(info.payload_types.length(), _ => {
          None
        }),
        storage_callable_demands: Array::makei(info.payload_types.length(), _ => {
          []
        }),
        storage_callable_interfaces: [],
        storage_shapes: [],
      })
    }
  }
}

///|
fn ImageLowerer::materialize_data_family(
  self : ImageLowerer,
  plan : DataRepresentationFamilyPlan,
) -> @bytecode.DataFamilyId {
  if plan.bytecode_family is Some(family) {
    return family
  }
  let family : @bytecode.DataFamilyId = {
    value: self.materialized_data_families.length(),
  }
  plan.bytecode_family = Some(family)
  self.materialized_data_families.push(plan)
  family
}

///|
fn ImageLowerer::materialized_data_family_count(self : ImageLowerer) -> Int {
  self.materialized_data_families.length()
}

///|
fn DataRepresentationFamilyKey::owner(
  self : DataRepresentationFamilyKey,
) -> @buslane.TypeId {
  match self {
    Declaration(owner) | Specialized(owner, _, _) => owner
  }
}

///|
fn DataRepresentationFamilyCandidateKey::finalize(
  self : DataRepresentationFamilyCandidateKey,
  component : Int,
) -> DataRepresentationFamilyKey {
  Specialized(self.owner, self.arguments, component)
}

///|
fn ImageLowerer::canonical_data_family_key(
  self : ImageLowerer,
  family : DataRepresentationFamilyKey,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  Value({
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue(self.materialize_data_family(self.data_family(family))),
  })
}

///|
fn DataRepresentationFamilyPlan::physical_contract(
  self : DataRepresentationFamilyPlan,
) -> PhysicalDataFamilyContract raise LoisvmLoweringError {
  guard self.bytecode_family is Some(family) else {
    raise RepresentationSpecializationInvariant(
      detail="physical data-family contract has no materialized identity",
    )
  }
  let constructors = self.constructors.map(constructor_plan => {
    guard constructor_plan.shape is Some(shape) else {
      raise RepresentationSpecializationInvariant(
        detail="physical data-family constructor has no finalized object shape",
      )
    }
    {
      data_constructor: constructor_plan.data_constructor,
      shape,
      source_evidence_binder_count: match
        constructor_plan.storage_hidden_arguments {
        Some(arguments) => arguments.length()
        None => constructor_plan.storage_evidence_parameters.length()
      },
      stored_evidence_parameters: constructor_plan.storage_evidence_parameters.copy(),
      storage_types: constructor_plan.storage_types.copy(),
      storage_shapes: constructor_plan.storage_shapes.copy(),
    }
  })
  { family, constructors, }
}

///|
fn PhysicalDataFamilyContract::constructor_contract(
  self : PhysicalDataFamilyContract,
  data_constructor : @buslane.DataConId,
) -> PhysicalDataConstructorContract? {
  for contract in self.constructors {
    if contract.data_constructor == data_constructor {
      return Some(contract)
    }
  }
  None
}

///|
fn PhysicalDataFamilyContract::physical_shape(
  self : PhysicalDataFamilyContract,
) -> PhysicalValueShape {
  PhysicalValueShape::Slot(
    CanonicalRuntimeTypeKey::Value({
      representation: I32,
      cleanup: OwnedRef,
      kind: DataValue(self.family),
    }),
  )
}

///|
fn ImageLowerer::data_family_by_bytecode_id(
  self : ImageLowerer,
  id : @bytecode.DataFamilyId,
) -> DataRepresentationFamilyPlan raise LoisvmLoweringError {
  for family in self.materialized_data_families {
    if family.bytecode_family == Some(id) {
      return family
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="runtime data value names an unknown representation family",
  )
}

///|
fn DataRepresentationFamilyPlan::constructor_plan(
  self : DataRepresentationFamilyPlan,
  data_constructor : @buslane.DataConId,
) -> DataRepresentationConstructorPlan? {
  for constructor_plan in self.constructors {
    if constructor_plan.data_constructor == data_constructor {
      return Some(constructor_plan)
    }
  }
  None
}

///|
fn ImageLowerer::plan_specialized_data_families(
  self : ImageLowerer,
  demands : DataRepresentationDemandPlan,
) -> Unit raise LoisvmLoweringError {
  for demand in demands.allocations {
    guard demand.type_ is Data(owner, arguments) else {
      raise RepresentationSpecializationInvariant(
        detail="specialized data demand does not describe a data type",
      )
    }
    ignore(
      self.plan_specialized_data_family_with_key(
        demand.family,
        owner,
        arguments,
      ),
    )
  }
}

///|
fn ImageLowerer::finalize_data_family_contract(
  self : ImageLowerer,
  family : DataRepresentationFamilyPlan,
) -> Unit raise LoisvmLoweringError {
  if self.finalized_data_families.contains(family.identity) {
    return
  }
  let bytecode_family = self.materialize_data_family(family)
  let specialized = family.key is Specialized(_, _, _)
  for constructor_plan in family.constructors {
    if !constructor_plan.storage_shapes.is_empty() {
      raise RepresentationSpecializationInvariant(
        detail="data-family storage contract was finalized twice",
      )
    }
    if !constructor_plan.storage_callable_interfaces.is_empty() {
      raise RepresentationSpecializationInvariant(
        detail="data-family callable storage contract was finalized twice",
      )
    }
    for index, storage_type in constructor_plan.storage_types {
      let callable_interface = match storage_type {
        Callable(_, _) | Forall(_, _) =>
          if specialized &&
            !constructor_plan.storage_callable_demands[index].is_empty() {
            self.finalize_data_callable_storage_interface(
              constructor_plan.storage_callable_demands[index],
            )
          } else {
            Some(
              self.canonical_callable_interface_under(
                storage_type,
                RuntimeSubstitution::new(),
              ),
            )
          }
        _ => None
      }
      constructor_plan.storage_callable_interfaces.push(callable_interface)
      constructor_plan.storage_shapes.push(
        self.canonical_data_storage_key(
          storage_type,
          constructor_plan.storage_data_families[index],
          callable_interface,
        ),
      )
    }
  }
  for constructor_plan in family.constructors {
    if constructor_plan.shape is Some(_) {
      raise RepresentationSpecializationInvariant(
        detail="data-family object shape was finalized twice",
      )
    }
    constructor_plan.shape = Some(
      self.intern_data_shape(
        bytecode_family,
        self.constructor_tag(constructor_plan.data_constructor, family.owner),
        constructor_plan.storage_evidence_parameters,
        constructor_plan.storage_shapes,
      ),
    )
  }
  self.finalized_data_families.push(family.identity)
}

///|
fn ImageLowerer::verify_materialized_data_family_contracts(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for index, family in self.materialized_data_families {
    guard family.bytecode_family is Some(bytecode_family) else {
      raise RepresentationSpecializationInvariant(
        detail="materialized data-family catalog entry lacks a physical identity",
      )
    }
    if bytecode_family.value != index {
      raise RepresentationSpecializationInvariant(
        detail="data-family catalog identity is not dense and stable",
      )
    }
    if !self.finalized_data_families.contains(family.identity) {
      continue
    }
    for constructor_plan in family.constructors {
      guard constructor_plan.shape is Some(shape) &&
        self.object_shapes.get(shape.value) is Some(Data(data_shape)) else {
        raise RepresentationSpecializationInvariant(
          detail="finalized data constructor lacks its planned data object shape",
        )
      }
      if data_shape.family != bytecode_family {
        raise RepresentationSpecializationInvariant(
          detail="finalized data constructor shape belongs to a different physical family",
        )
      }
    }
  }
}

///|
fn ImageLowerer::canonical_data_storage_key(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  data_family : DataRepresentationFamilyKey?,
  callable_interface : PhysicalCallableInterface?,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match type_ {
    Data(owner, _) =>
      self.canonical_data_family_key(
        data_family.unwrap_or(DataRepresentationFamilyKey::Declaration(owner)),
      )
    Callable(_, _) | Forall(_, _) => {
      guard callable_interface is Some(interface) else {
        return self.canonical_runtime_value_key(type_)
      }
      CanonicalRuntimeTypeKey::Callable(interface.invocation)
    }
    _ => self.canonical_runtime_type_key(type_)
  }
}

///|
fn ImageLowerer::finalize_data_callable_storage_interface(
  self : ImageLowerer,
  demands : Array[DataRepresentationCallableStorageDemand],
) -> PhysicalCallableInterface? raise LoisvmLoweringError {
  let mut selected : PhysicalCallableInterface? = None
  for demand in demands {
    let generic = self.representation_solution.callable_component_requires_generic(
      demand.component,
    )
    let worker = demand.component >= 0 &&
      !generic &&
      self.representation_specialization_for_callable(demand.callable)
      is Some(_)
    let interface = self.callable_representation_interface(
      demand.callable,
      worker~,
    )
    match selected {
      None => selected = Some(interface)
      Some(existing) if existing == interface => ()
      Some(_) =>
        raise RepresentationSpecializationInvariant(
          detail="one specialized data member received incompatible callable interfaces",
        )
    }
  }
  selected
}

///|
fn ImageLowerer::plan_specialized_data_family_with_key(
  self : ImageLowerer,
  key : DataRepresentationFamilyKey,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> DataRepresentationFamilyPlan raise LoisvmLoweringError {
  for family in self.data_families {
    if family.key == key {
      return family
    }
  }
  guard self.metadata.type_info(owner) is Some(owner_info) else {
    raise RepresentationSpecializationInvariant(
      detail="specialized data family lacks owner metadata",
    )
  }
  let family : DataRepresentationFamilyPlan = {
    identity: { index: self.data_families.length(), },
    key,
    bytecode_family: None,
    owner,
    constructors: [],
  }
  self.data_families.push(family)
  let substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    arguments,
  )
  for data_constructor in owner_info.constructors {
    guard self.metadata.data_constructor_info(data_constructor) is Some(info) else {
      raise MissingDataConstructorMetadata(data_constructor~)
    }
    let generic_storage_types = info.payload_types.map(type_ => {
      substitutions.apply_type(self.runtime_types, type_)
    })
    let family_allocations = self.representation_solution.data_representations.allocations.filter(demand => {
        demand.family == key && demand.data_constructor == data_constructor
      },
    )
    let (storage_hidden_arguments, storage_evidence_parameters, storage_types) = match
      family_allocations {
      [] => (None, info.hidden_evidence_parameters, generic_storage_types)
      [first, .. rest] => {
        let mut closed_and_uniform = first.hidden_arguments.all(argument => {
          self.generic_argument_is_closed(argument)
        })
        for demand in rest {
          if demand.hidden_arguments != first.hidden_arguments ||
            demand.storage_types != first.storage_types {
            closed_and_uniform = false
          }
        }
        if closed_and_uniform {
          (Some(first.hidden_arguments), [], first.storage_types)
        } else {
          (None, info.hidden_evidence_parameters, generic_storage_types)
        }
      }
    }
    let data_families = Array::makei(storage_types.length(), _ => None)
    let callable_demands = Array::makei(storage_types.length(), _ => [])
    for
      demand in self.representation_solution.data_representations.data_payloads {
      let mut allocation : DataRepresentationAllocationDemand? = None
      for
        candidate in self.representation_solution.data_representations.allocations {
        if candidate.allocation == demand.allocation {
          allocation = Some(candidate)
          break
        }
      }
      guard demand.payload_index < data_families.length() &&
        allocation is Some(allocation) &&
        allocation.family == key &&
        allocation.data_constructor == data_constructor else {
        continue
      }
      match data_families[demand.payload_index] {
        None => data_families[demand.payload_index] = Some(demand.family)
        Some(existing) if existing == demand.family => ()
        Some(_) =>
          raise RepresentationSpecializationInvariant(
            detail="one specialized data member received incompatible nested data-family contracts",
          )
      }
    }
    for
      demand in self.representation_solution.data_representations.callable_payloads {
      let mut allocation : DataRepresentationAllocationDemand? = None
      for
        candidate in self.representation_solution.data_representations.allocations {
        if candidate.allocation == demand.allocation {
          allocation = Some(candidate)
          break
        }
      }
      guard demand.payload_index < callable_demands.length() &&
        allocation is Some(allocation) &&
        allocation.family == key &&
        allocation.data_constructor == data_constructor else {
        continue
      }
      let demands = callable_demands[demand.payload_index]
      let storage_demand : DataRepresentationCallableStorageDemand = {
        callable: demand.callable,
        component: demand.callable_component,
      }
      if !demands.contains(storage_demand) {
        demands.push(storage_demand)
      }
    }
    family.constructors.push({
      data_constructor,
      shape: None,
      storage_hidden_arguments,
      storage_evidence_parameters,
      storage_types,
      storage_data_families: data_families,
      storage_callable_demands: callable_demands,
      storage_callable_interfaces: [],
      storage_shapes: [],
    })
  }
  family
}

///|
fn ImageLowerer::specialized_data_family_key_or_none(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> DataRepresentationFamilyCandidateKey? {
  try
    {
      owner,
      arguments: arguments.map(argument => {
        self.canonical_representation_argument_key(argument, [])
      }),
    }
  catch {
    _ => None
  } noraise {
    key => Some(key)
  }
}

///|
fn ImageLowerer::canonical_representation_argument_key(
  self : ImageLowerer,
  argument : @anf.RuntimeArgument,
  bound : Array[@anf.RuntimeEvidenceId],
) -> CanonicalRepresentationArgumentKey raise LoisvmLoweringError {
  {
    type_expression: self.canonical_representation_type_expression_key(
      argument.type_expression,
      bound,
    ),
    evidence: canonical_runtime_evidence_key_with(argument.evidence, bound),
  }
}

///|
fn ImageLowerer::canonical_representation_type_expression_key(
  self : ImageLowerer,
  expression : @anf.RuntimeTypeExpressionId,
  bound : Array[@anf.RuntimeEvidenceId],
) -> CanonicalRepresentationTypeExpressionKey raise LoisvmLoweringError {
  guard self.runtime_types.type_expression(expression) is Some(node) else {
    raise RepresentationSpecializationInvariant(
      detail="data representation argument lacks a runtime type expression",
    )
  }
  match node {
    Static(type_) =>
      Static(self.canonical_representation_type_key(type_, bound))
    Parameter(parameter) => Bound(canonical_bound_offset(parameter, bound))
    Apply(callee, arguments) =>
      Apply(
        self.canonical_representation_type_expression_key(callee, bound),
        arguments.map(argument => {
          self.canonical_representation_type_expression_key(argument, bound)
        }),
      )
    Lambda(parameters, body) =>
      Lambda(
        parameters.map(parameter => parameter.arity),
        self.canonical_representation_type_expression_key(
          body,
          bound + parameters.map(parameter => parameter.id),
        ),
      )
  }
}

///|
fn ImageLowerer::canonical_representation_type_key(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
) -> CanonicalRepresentationTypeKey raise LoisvmLoweringError {
  match type_ {
    Unit => Unit
    Scalar(scalar) => Scalar(scalar)
    ByteSequence => ByteSequence
    OpaqueReference(owner) => OpaqueReference(owner)
    Data(owner, arguments) =>
      Data(
        owner,
        arguments.map(argument => {
          self.canonical_representation_argument_key(argument, bound)
        }),
      )
    Callable(parameters, result) =>
      Callable(
        parameters.map(parameter => {
          self.canonical_representation_type_key(parameter, bound)
        }),
        self.canonical_representation_type_key(result, bound),
      )
    Erased(expression, evidence) =>
      Erased(
        self.canonical_representation_type_expression_key(expression, bound),
        canonical_runtime_evidence_key_with(evidence, bound),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(parameter => parameter.arity),
        self.canonical_representation_type_key(
          body,
          bound + parameters.map(parameter => parameter.id),
        ),
      )
  }
}

///|
fn canonical_bound_offset(
  parameter : @anf.RuntimeEvidenceId,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Int raise LoisvmLoweringError {
  for offset in 0..<bound.length() {
    if bound[bound.length() - offset - 1] == parameter {
      return offset
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="closed representation type contains a free parameter",
  )
}

///|
fn ImageLowerer::runtime_type_may_change_physical_representation(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> Bool raise LoisvmLoweringError {
  self.runtime_type_may_change_physical_representation_with(type_, [])
}

///|
fn ImageLowerer::runtime_type_may_change_physical_representation_with(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  visiting : Array[@buslane.TypeId],
) -> Bool raise LoisvmLoweringError {
  match type_ {
    Callable(_, _) | Forall(_, _) | Erased(_, _) => true
    Data(owner, _) => {
      if visiting.contains(owner) {
        return false
      }
      guard self.metadata.type_info(owner) is Some(info) else {
        raise RepresentationSpecializationInvariant(
          detail="runtime data type lacks metadata while discovering physical representation candidates",
        )
      }
      for data_constructor in info.constructors {
        guard self.metadata.data_constructor_info(data_constructor)
          is Some(constructor_info) else {
          raise MissingDataConstructorMetadata(data_constructor~)
        }
        if constructor_info.payload_types.any(payload => {
            self.runtime_type_may_change_physical_representation_with(
              payload,
              visiting + [owner],
            )
          }) {
          return true
        }
      }
      false
    }
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => false
  }
}

///|
fn ImageLowerer::intern_data_shape(
  self : ImageLowerer,
  family : @bytecode.DataFamilyId,
  constructor_tag : Int,
  hidden_parameters : Array[@anf.RuntimeEvidenceParameter],
  storage_shapes : Array[CanonicalRuntimeTypeKey],
) -> @bytecode.ObjectShapeId raise LoisvmLoweringError {
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in hidden_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let mut witness_ordinal = 0
  for storage_shape in storage_shapes {
    match storage_shape {
      Unit => ()
      shape => {
        let metadata = shape.value_metadata(None)
        let erased = metadata.cleanup is OwnedErased
        members.push({
          representation: metadata.representation,
          cleanup: metadata.cleanup,
          kind: metadata.kind,
          witness_ordinal: if erased {
            Some(witness_ordinal)
          } else {
            None
          },
        })
        if erased {
          witness_ordinal += 1
        }
      }
    }
  }
  self.intern_object_shape(
    Data({
      family,
      constructor_tag,
      stored_witness_count: witness_ordinal,
      members,
    }),
  )
}
