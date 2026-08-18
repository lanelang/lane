///|
priv struct CallableCaptureInput {
  definition : @anf.AnfCallableDefinition
  function_type : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  data_families : Array[DataRepresentationFamilyPlan]
}

///|
fn ImageLowerer::plan_callable_capture(
  self : ImageLowerer,
  definition : @anf.AnfCallableDefinition,
  function_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  specialized_parameters : Array[@anf.RuntimeEvidenceId],
  data_families : Array[DataRepresentationFamilyPlan],
) -> CallableCaptureContract raise LoisvmLoweringError {
  self.plan_callable_captures([
    {
      definition,
      function_type,
      substitutions,
      specialized_parameters,
      data_families,
    },
  ])
}

///|
fn ImageLowerer::plan_callable_captures(
  self : ImageLowerer,
  inputs : Array[CallableCaptureInput],
) -> CallableCaptureContract raise LoisvmLoweringError {
  let capture_types = []
  let bindings = []
  let function_types = []
  let specialized_parameters = []
  let data_families : Array[DataRepresentationFamilyPlan] = []
  for input in inputs {
    function_types.push(input.function_type)
    for parameter in input.specialized_parameters {
      if !specialized_parameters.contains(parameter) {
        specialized_parameters.push(parameter)
      }
    }
    for family in input.data_families {
      if !data_families.any(candidate => candidate.identity == family.identity) {
        data_families.push(family)
      }
    }
    for capture in input.definition.captures {
      let binding = match capture {
        Value(value) => CaptureBinding::Value(value)
        Temp(temp) => Temp(temp)
      }
      guard !bindings.contains(binding) else { continue }
      guard self.callable_catalog.capture_type(capture, self.metadata)
        is Some(type_) else {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF callable capture lacks type metadata",
        )
      }
      capture_types.push(
        input.substitutions.apply_type(self.runtime_types, type_),
      )
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
    match
      self.elaborate_runtime_representation_with_data_families(
        type_, data_families,
      ) {
      RuntimeUnit => captures.push({ binding, type_, member_index: None })
      _ => {
        let (metadata, witness_ordinal) = if self.runtime_type(type_)
          is Erased(_) {
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
          (self.slot_metadata_with_data_families(type_, data_families), None)
        }
        let member_index = members.length()
        members.push({
          representation: metadata.representation,
          cleanup: metadata.cleanup,
          kind: metadata.kind,
          witness_ordinal,
        })
        captures.push({ binding, type_, member_index: Some(member_index) })
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
fn FunctionLowerer::capture_environment(
  self : FunctionLowerer,
  contract : CallableCaptureContract,
) -> @vmcfg.ValueId? raise LoisvmLoweringError {
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
      guard self.image.metadata.parameter_type_expression(evidence.source)
        is Some(type_expression) else {
        raise RepresentationSpecializationInvariant(
          detail="captured layout constructor lacks a type expression",
        )
      }
      values.push(
        self.runtime_evidence(evidence.target, {
          type_expression,
          evidence: Parameter(evidence.source),
        }),
      )
    }
  }
  for capture in contract.captures {
    guard capture.member_index is Some(_) else { continue }
    let captured = self.capture_value(capture.binding)
    guard self.materialize_local(captured) is Slot(slot, type_) else {
      raise RepresentationSpecializationInvariant(
        detail="planned callable capture is not materialized",
      )
    }
    if self.image.runtime_type(type_) is Erased(_) {
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
