///|
priv struct CallableCaptureInput {
  instances : Array[Int]
  definition : @anf.AnfCallableDefinition
  function_type : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
}

///|
fn CallableCaptureContract::empty() -> CallableCaptureContract {
  { captured_evidence: [], captures: [], environment_shape: None }
}

///|
fn ImageLowerer::plan_callable_capture(
  self : ImageLowerer,
  instances : Array[Int],
  definition : @anf.AnfCallableDefinition,
  function_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  specialized_parameters : Array[@anf.RuntimeEvidenceId],
  excluded_data_components : Array[Int],
  excluded_callable_components : Array[Int],
  physical_captures? : Array[(@anf.AnfBindingId, CanonicalRuntimeTypeKey)]? = None,
) -> CallableCaptureContract raise LoisvmLoweringError {
  self.plan_callable_captures(
    [
      {
        instances,
        definition,
        function_type,
        substitutions,
        specialized_parameters,
      },
    ],
    excluded_data_components,
    excluded_callable_components,
    physical_captures~,
  )
}

///|
fn ImageLowerer::plan_callable_captures(
  self : ImageLowerer,
  inputs : Array[CallableCaptureInput],
  excluded_data_components : Array[Int],
  excluded_callable_components : Array[Int],
  physical_captures? : Array[(@anf.AnfBindingId, CanonicalRuntimeTypeKey)]? = None,
) -> CallableCaptureContract raise LoisvmLoweringError {
  let capture_types = []
  let capture_shapes : Array[CanonicalRuntimeTypeKey] = []
  let bindings = []
  let function_types = []
  let specialized_parameters = []
  for input in inputs {
    function_types.push(input.function_type)
    for parameter in input.specialized_parameters {
      if !specialized_parameters.contains(parameter) {
        specialized_parameters.push(parameter)
      }
    }
    for capture in input.definition.captures {
      let binding = match capture {
        Value(value) => CaptureBinding::Value(value)
        Temp(temp) => Temp(temp)
      }
      guard self.callable_catalog.capture_type(capture, self.metadata)
        is Some(type_) else {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF callable capture lacks type metadata",
        )
      }
      let type_ = input.substitutions.apply_type(self.runtime_types, type_)
      let binding_id = match binding {
        CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
        CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
      }
      let shape = self.planned_callable_capture_shape(
        input.instances,
        binding_id,
        type_,
        excluded_data_components,
        excluded_callable_components,
      )
      let mut existing_index = -1
      for index, existing in bindings {
        if existing == binding {
          existing_index = index
          break
        }
      }
      if existing_index >= 0 {
        let index = existing_index
        if capture_shapes[index] != shape {
          raise RepresentationSpecializationInvariant(
            detail="one recursive callable group assigned two physical shapes to the same capture",
          )
        }
        continue
      }
      capture_types.push(type_)
      capture_shapes.push(shape)
      bindings.push(binding)
    }
  }
  let types = function_types + capture_types
  let captured_parameters = free_runtime_type_parameters_in_types(self, types)
  for input in inputs {
    let (bound, _, _) = function_type_parts(input.function_type)
    collect_free_runtime_evidence_in_expr(
      self,
      input.definition.function.body,
      bound.map(parameter => parameter.id) + input.substitutions.parameters(),
      captured_parameters,
    )
  }
  let captured_parameters = captured_parameters.filter(parameter => {
    !specialized_parameters.contains(parameter.id)
  })
  let captured_evidence = captured_parameters.map(target => {
    let mut source = target.id
    for input in inputs {
      for candidate in input.substitutions.parameters() {
        if input.substitutions.apply_evidence(Parameter(candidate)) ==
          Parameter(target.id) {
          source = candidate
        }
      }
    }
    { source, target }
  })
  let members : Array[@bytecode.MemberSchema] = []
  for evidence in captured_evidence {
    let metadata = runtime_evidence_metadata(evidence.target)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let captures = []
  let mut stored_witness_count = 0
  for index, binding in bindings {
    let type_ = capture_types[index]
    let shape = match physical_captures {
      Some(assignments) => {
        let capture_binding = match binding {
          CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
          CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
        }
        let mut selected : CanonicalRuntimeTypeKey? = None
        for assignment in assignments {
          if assignment.0 == capture_binding {
            selected = Some(assignment.1)
            break
          }
        }
        guard selected is Some(shape) else {
          raise RepresentationSpecializationInvariant(
            detail="representation worker lacks a planned physical capture port",
          )
        }
        shape
      }
      None => capture_shapes[index]
    }
    match shape {
      Unit => captures.push({ binding, type_, shape: None, member_index: None })
      shape => {
        let (metadata, witness_ordinal) = if shape
          is Value({ cleanup: OwnedErased, .. }) {
          let ordinal = stored_witness_count
          stored_witness_count = stored_witness_count + 1
          (
            @vmcfg.ValueMetadata::{
              representation: I64,
              cleanup: OwnedErased,
              kind: ErasedValue,
              ownership: Owned,
              erased_companion: None,
            },
            Some(ordinal),
          )
        } else {
          (shape.value_metadata(None), None)
        }
        let member_index = members.length()
        members.push({
          representation: metadata.representation,
          cleanup: metadata.cleanup,
          kind: metadata.kind,
          witness_ordinal,
        })
        captures.push({
          binding,
          type_,
          shape: Some(shape),
          member_index: Some(member_index),
        })
      }
    }
  }
  {
    captured_evidence,
    captures,
    environment_shape: self.environment_shape(stored_witness_count, members),
  }
}

///|
fn ImageLowerer::planned_callable_capture_shape(
  self : ImageLowerer,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
  type_ : @anf.RuntimeType,
  excluded_data_components : Array[Int],
  excluded_callable_components : Array[Int],
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  if self.representation_demands.callable_instance_at_port_excluding(
      instances, binding, excluded_callable_components,
    )
    is Some(callable) {
    if self.representation_demands.callable_port_uses_worker(
        instances, binding, excluded_callable_components,
      ) &&
      self.representation_specialization_for_callable(callable) is Some(plan) {
      return Callable(self.representation_worker_invocation(plan))
    }
    return Callable(self.generic_callable_representation_physical_abi(callable))
  }
  self.canonical_runtime_type_key_for_family(
    type_,
    self.representation_demands.data_family_at_capture_excluding(
      instances, binding, excluded_data_components,
    ),
  )
}

///|
fn FunctionLowerer::capture_environment(
  self : FunctionLowerer,
  contract : CallableCaptureContract,
  allocation : PhysicalCallableAllocationPlan,
) -> @vmcfg.ValueId? raise LoisvmLoweringError {
  if allocation.captures.length() != contract.captures.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable allocation flows disagree with its capture contract",
    )
  }
  let stored_layouts = []
  let values = []
  for evidence in contract.captured_evidence {
    let target = self.substitutions.apply_evidence(Parameter(evidence.source))
    if evidence.target.arity == 0 {
      values.push(
        self
        .equivalent_witness(target)
        .unwrap_or_else(() => {
          self.materialize_runtime_evidence(
            self.image.plan_layout_witness(target),
          )
        }),
      )
    } else {
      values.push(
        self.materialize_runtime_evidence(
          self.image.plan_layout_constructor_evidence(target),
        ),
      )
    }
  }
  for index, capture in contract.captures {
    guard capture.member_index is Some(_) else { continue }
    let flow = allocation.captures[index]
    let source = self.materialize_local(self.capture_value(capture.binding))
    let source_shape = self.physical_shape(flow.source)
    if self.local_physical_shape(source) != source_shape {
      raise RepresentationSpecializationInvariant(
        detail="callable capture \{Repr(capture.binding)} produced \{Repr(self.local_physical_shape(source))}, but its physical flow owns \{Repr(source_shape)}",
      )
    }
    let target_shape = self.physical_shape(flow.target)
    let captured = self.materialize_planned_value_flow(
      "callable capture",
      source,
      capture.type_,
      target_shape,
      flow.bridge,
    )
    guard captured is Slot(slot, _, actual_shape) &&
      capture.shape is Some(expected_shape) else {
      raise RepresentationSpecializationInvariant(
        detail="planned callable capture does not materialize as a physical slot",
      )
    }
    if actual_shape != expected_shape {
      raise RepresentationSpecializationInvariant(
        detail="capture \{Repr(capture.binding)} produced \{Repr(actual_shape)}, expected \{Repr(expected_shape)}",
      )
    }
    if expected_shape is Value({ cleanup: OwnedErased, .. }) {
      guard self.values[slot.value].erased_companion is Some(witness) else {
        raise InvalidTypeApplication(
          detail="erased capture is missing its layout evidence",
        )
      }
      stored_layouts.push(witness)
    }
    values.push(slot)
  }
  self.make_capture_environment(
    contract.environment_shape,
    stored_layouts,
    values,
  )
}
