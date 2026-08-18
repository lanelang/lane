///|
fn ImageLowerer::plan_declaration_data_families(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for item in self.metadata.data_types() {
    let (owner, info) = item
    guard info.kind is Data else { continue }
    let identity : DataRepresentationFamilyId = {
      index: self.data_families.length(),
    }
    self.data_families.push({
      identity,
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
        storage_types: info.payload_types,
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
    value: self.data_families.fold(init=0, (count, candidate) => {
      if candidate.bytecode_family is Some(_) {
        count + 1
      } else {
        count
      }
    }),
  }
  plan.bytecode_family = Some(family)
  family
}

///|
fn ImageLowerer::materialized_data_family_count(self : ImageLowerer) -> Int {
  self.data_families.fold(init=0, (count, family) => {
    if family.bytecode_family is Some(_) {
      count + 1
    } else {
      count
    }
  })
}

///|
fn ImageLowerer::data_representation_family(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
  selected : Array[DataRepresentationFamilyPlan],
) -> DataRepresentationFamilyPlan raise LoisvmLoweringError {
  if self.specialized_data_family_key_or_none(owner, arguments) is Some(key) {
    for family in selected {
      if family.key == key {
        return family
      }
    }
  }
  self.data_family(Declaration(owner))
}

///|
fn ImageLowerer::data_family_by_bytecode_id(
  self : ImageLowerer,
  id : @bytecode.DataFamilyId,
) -> DataRepresentationFamilyPlan raise LoisvmLoweringError {
  for family in self.data_families {
    if family.bytecode_family == Some(id) {
      return family
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="runtime data value names an unknown representation family",
  )
}

///|
fn ImageLowerer::data_family_plans(
  self : ImageLowerer,
  keys : Array[DataRepresentationFamilyKey],
) -> Array[DataRepresentationFamilyPlan] raise LoisvmLoweringError {
  let selected : Array[DataRepresentationFamilyPlan] = []
  for key in keys {
    for family in self.data_families {
      if family.key == key &&
        !selected.any(item => item.identity == family.identity) {
        selected.push(family)
      }
    }
  }
  while true {
    let before = selected.length()
    for family in selected.copy() {
      for constructor_plan in family.constructors {
        for storage_type in constructor_plan.storage_types {
          collect_selected_nested_data_families(self, storage_type, selected)
        }
      }
    }
    if selected.length() == before {
      break
    }
  }
  selected
}

///|
fn collect_selected_nested_data_families(
  image : ImageLowerer,
  type_ : @anf.RuntimeType,
  selected : Array[DataRepresentationFamilyPlan],
) -> Unit raise LoisvmLoweringError {
  match type_ {
    Data(owner, arguments) =>
      if image.data_representation_changes(owner, arguments) &&
        image.specialized_data_family_key_or_none(owner, arguments) is Some(key) {
        for family in image.data_families {
          if family.key == key &&
            !selected.any(item => item.identity == family.identity) {
            selected.push(family)
          }
        }
      }
    Callable(parameters, result) => {
      for parameter in parameters {
        collect_selected_nested_data_families(image, parameter, selected)
      }
      collect_selected_nested_data_families(image, result, selected)
    }
    Forall(_, body) =>
      collect_selected_nested_data_families(image, body, selected)
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) | Erased(_, _) => ()
  }
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
    ignore(self.plan_specialized_data_family(owner, arguments))
  }
}

///|
fn ImageLowerer::plan_specialized_data_family(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> DataRepresentationFamilyPlan raise LoisvmLoweringError {
  let key = self.specialized_data_family_key(owner, arguments)
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
    identity: { index: self.data_families.length() },
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
    let storage_types = info.payload_types.map(type_ => {
      substitutions.apply_type(self.runtime_types, type_)
    })
    for storage_type in storage_types {
      self.plan_nested_data_families(storage_type)
    }
    family.constructors.push({ data_constructor, shape: None, storage_types })
  }
  family
}

///|
fn ImageLowerer::plan_nested_data_families(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> Unit raise LoisvmLoweringError {
  match type_ {
    Data(owner, arguments) => {
      if self.data_representation_changes(owner, arguments) &&
        self.specialized_data_family_key_or_none(owner, arguments) is Some(_) {
        ignore(self.plan_specialized_data_family(owner, arguments))
      }
      for argument in arguments {
        if self.runtime_types.type_expression(argument.type_expression)
          is Some(Static(nested)) {
          self.plan_nested_data_families(nested)
        }
      }
    }
    Callable(parameters, result) => {
      for parameter in parameters {
        self.plan_nested_data_families(parameter)
      }
      self.plan_nested_data_families(result)
    }
    Forall(_, body) => self.plan_nested_data_families(body)
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) | Erased(_, _) => ()
  }
}

///|
fn ImageLowerer::specialized_data_family_key(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> DataRepresentationFamilyKey raise LoisvmLoweringError {
  guard self.specialized_data_family_key_or_none(owner, arguments) is Some(key) else {
    raise RepresentationSpecializationInvariant(
      detail="specialized data family has open runtime arguments",
    )
  }
  key
}

///|
fn ImageLowerer::specialized_data_family_key_or_none(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> DataRepresentationFamilyKey? {
  try
    Specialized(
      owner,
      arguments.map(argument => {
        self.canonical_representation_argument_key(argument, [])
      }),
    )
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
fn ImageLowerer::data_representation_changes(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> Bool raise LoisvmLoweringError {
  guard self.metadata.type_info(owner) is Some(owner_info) &&
    owner_info.evidence_parameters.length() == arguments.length() else {
    return false
  }
  let substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    arguments,
  )
  for data_constructor in owner_info.constructors {
    guard self.metadata.data_constructor_info(data_constructor) is Some(info) else {
      raise MissingDataConstructorMetadata(data_constructor~)
    }
    for source_type in info.payload_types {
      let target_type = substitutions.apply_type(
        self.runtime_types,
        source_type,
      )
      if self.canonical_runtime_type_key(source_type) !=
        self.canonical_runtime_type_key(target_type) {
        return true
      }
    }
  }
  false
}

///|
fn ImageLowerer::nested_data_representations_are_closed(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> Bool raise LoisvmLoweringError {
  self.nested_data_representations_are_closed_with(type_, [])
}

///|
fn ImageLowerer::nested_data_representations_are_closed_with(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  visiting : Array[DataRepresentationFamilyKey],
) -> Bool raise LoisvmLoweringError {
  match type_ {
    Data(owner, arguments) => {
      guard self.metadata.type_info(owner) is Some(owner_info) &&
        owner_info.evidence_parameters.length() == arguments.length() else {
        return false
      }
      guard self.data_representation_changes(owner, arguments) else {
        return true
      }
      guard self.specialized_data_family_key_or_none(owner, arguments)
        is Some(key) else {
        return false
      }
      if visiting.contains(key) {
        return true
      }
      if visiting.any(active => {
          active is (Declaration(active_owner) | Specialized(active_owner, _)) &&
          active_owner == owner
        }) {
        return false
      }
      let substitutions = RuntimeSubstitution::from_arguments(
        owner_info.evidence_parameters,
        arguments,
      )
      for data_constructor in owner_info.constructors {
        guard self.metadata.data_constructor_info(data_constructor)
          is Some(info) else {
          return false
        }
        for payload_type in info.payload_types {
          if !self.nested_data_representations_are_closed_with(
              substitutions.apply_type(self.runtime_types, payload_type),
              visiting + [key],
            ) {
            return false
          }
        }
      }
      true
    }
    Callable(parameters, result) => {
      for parameter in parameters {
        if !self.nested_data_representations_are_closed_with(
            parameter, visiting,
          ) {
          return false
        }
      }
      self.nested_data_representations_are_closed_with(result, visiting)
    }
    Forall(_, body) =>
      self.nested_data_representations_are_closed_with(body, visiting)
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) | Erased(_, _) => true
  }
}

///|
fn ImageLowerer::intern_data_shape(
  self : ImageLowerer,
  family : @bytecode.DataFamilyId,
  constructor_tag : Int,
  hidden_parameters : Array[@anf.RuntimeEvidenceParameter],
  storage_types : Array[@anf.RuntimeType],
  selected_families : Array[DataRepresentationFamilyPlan],
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
  for storage_type in storage_types {
    if self.runtime_type(storage_type) is Erased(_) {
      members.push({
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        witness_ordinal: Some(witness_ordinal),
      })
      witness_ordinal += 1
    } else if self.runtime_type(storage_type) is Concrete(Unit) {
      ()
    } else {
      let metadata = self.slot_metadata_with_data_families(
        storage_type, selected_families,
      )
      members.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
        witness_ordinal: None,
      })
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

///|
fn ImageLowerer::materialize_data_shape(
  self : ImageLowerer,
  family : DataRepresentationFamilyPlan,
  constructor_plan : DataRepresentationConstructorPlan,
  info : @anf.RuntimeDataConstructorInfo,
  selected_families : Array[DataRepresentationFamilyPlan],
) -> @bytecode.ObjectShapeId raise LoisvmLoweringError {
  if constructor_plan.shape is Some(shape) {
    return shape
  }
  let shape = self.intern_data_shape(
    self.materialize_data_family(family),
    self.constructor_tag(constructor_plan.data_constructor, family.owner),
    info.hidden_evidence_parameters,
    constructor_plan.storage_types,
    selected_families,
  )
  constructor_plan.shape = Some(shape)
  shape
}
