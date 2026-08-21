///|
fn FunctionLowerer::lower_data_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @anf.RuntimeType,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  owner : @buslane.TypeId,
  type_arguments : Array[@anf.RuntimeArgument],
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  let type_arguments = type_arguments.map(argument => {
    self.substitutions.apply_argument(self.image.runtime_types, argument)
  })
  let owner_info = match self.image.metadata.type_info(owner) {
    Some(info) => info
    None =>
      raise UnsupportedExpression(detail="data match owner metadata is missing")
  }
  let substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    type_arguments,
  )
  if owner_info.constructors.is_empty() {
    return self.lower_unreachable_match_result(match_.result_type, result_shape)
  }
  if owner_info.constructors is [data_constructor] {
    let alternative = match
      find_data_alternative(match_.alternatives, data_constructor) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(
          detail="data match lacks a constructor or default alternative",
        )
    }
    return self.lower_irrefutable_data_alternative(
      site,
      match_.binder,
      scrutinee,
      scrutinee_type,
      scrutinee_shape,
      data_constructor,
      alternative,
      substitutions,
    )
  }
  let tag_type = @anf.RuntimeType::Scalar(Bool)
  let tag = self.fresh_slot(tag_type)
  self.emit(LoadTag(tag, scrutinee))
  let join_value = self.fresh_block_value_parameter(
    match_.result_type,
    result_shape,
  )
  let join_block = self.new_block(join_value.0)
  let cases : Array[@vmcfg.Edge] = []
  let alternatives : Array[
    (
      @bytecode.BlockId,
      @vmcfg.ValueId,
      @vmcfg.ValueId?,
      @anf.AnfAlternative,
      @buslane.DataConId,
    ),
  ] = []
  for data_constructor in owner_info.constructors {
    let alternative = match
      find_data_alternative(match_.alternatives, data_constructor) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(
          detail="data match lacks a constructor or default alternative",
        )
    }
    let branch_scrutinee = self.fresh_metadata(
      scrutinee_shape.value_metadata(None),
    )
    let branch_environment = self.branch_environment_parameter()
    let parameters = [branch_scrutinee]
    if branch_environment is Some(environment) {
      parameters.push(environment)
    }
    let block = self.new_block(parameters)
    let arguments = [scrutinee]
    if self.environment is Some(environment) {
      arguments.push(environment)
    }
    cases.push({ target: block, arguments })
    alternatives.push(
      (
        block, branch_scrutinee, branch_environment, alternative, data_constructor,
      ),
    )
  }
  let default_block = self.new_block([])
  self.terminate(
    SwitchTag(tag, cases, { target: default_block, arguments: [] }),
  )
  for item in alternatives {
    let (
      block,
      branch_scrutinee,
      branch_environment,
      alternative,
      data_constructor,
    ) = item
    self.lower_data_alternative(
      site,
      block,
      join_block,
      match_.binder,
      branch_scrutinee,
      scrutinee_type,
      scrutinee_shape,
      data_constructor,
      alternative,
      branch_environment,
      substitutions,
    )
  }
  self.enter_block(default_block)
  self.terminate(Unreachable)
  self.enter_block(join_block)
  join_value.1
}

///|
fn FunctionLowerer::lower_unreachable_match_result(
  self : FunctionLowerer,
  result_type : @anf.RuntimeType,
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  self.terminate(Unreachable)
  let result = self.fresh_block_value_parameter(result_type, result_shape)
  self.enter_block(self.new_block(result.0))
  result.1
}

///|
fn FunctionLowerer::lower_irrefutable_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @anf.RuntimeType,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : RuntimeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  let original_substitutions = self.substitutions
  self.bind_data_alternative(
    site, binder, scrutinee, scrutinee_type, scrutinee_shape, data_constructor, alternative,
    substitutions,
  )
  let result = self.materialize_planned_match_alternative(
    site,
    alternative,
    self.materialize_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.substitutions = original_substitutions
  result
}

///|
fn FunctionLowerer::lower_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @anf.RuntimeType,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
  substitutions : RuntimeSubstitution,
) -> Unit raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  let original_substitutions = self.substitutions
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bind_data_alternative(
    site, binder, scrutinee, scrutinee_type, scrutinee_shape, data_constructor, alternative,
    substitutions,
  )
  let result = self.materialize_planned_match_alternative(
    site,
    alternative,
    self.materialize_local(self.lower_expr(alternative.body)),
  )
  let arguments = self.block_value_arguments(result)
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.substitutions = original_substitutions
  self.environment = original_environment
}

///|
fn FunctionLowerer::bind_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @anf.RuntimeType,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : RuntimeSubstitution,
) -> Unit raise LoisvmLoweringError {
  let info = match self.image.metadata.data_constructor_info(data_constructor) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  let binds_payloads = alternative.alt_constructor is DataCon(_)
  if binds_payloads {
    if alternative.evidence_binders.length() !=
      info.hidden_evidence_parameters.length() {
      raise InvalidTypeApplication(
        detail="data alternative expects \{info.hidden_evidence_parameters.length()} hidden evidence binders, got \{alternative.evidence_binders.length()}",
      )
    }
  } else if !alternative.evidence_binders.is_empty() {
    raise InvalidTypeApplication(
      detail="default data alternative cannot bind hidden types",
    )
  }
  let expected_binders = if binds_payloads {
    info.payload_types.length()
  } else {
    0
  }
  if alternative.value_binders.length() != expected_binders {
    raise InvalidDataPayloadCount(
      data_constructor~,
      expected=expected_binders,
      actual=alternative.value_binders.length(),
    )
  }
  self.bindings.push({
    value: binder,
    lowered: LocalValue::Slot(scrutinee, scrutinee_type, scrutinee_shape),
  })
  let hidden_substitutions = RuntimeSubstitution::new()
  if binds_payloads {
    guard self.values[scrutinee.value].kind is DataValue(family_id) else {
      raise RepresentationSpecializationInvariant(
        detail="data match scrutinee lacks a representation family",
      )
    }
    let family = self.image.data_family_by_bytecode_id(family_id)
    guard family.constructor_plan(data_constructor) is Some(constructor_plan) else {
      raise RepresentationSpecializationInvariant(
        detail="data match family lacks its constructor contract",
      )
    }
    let storage_types = constructor_plan.storage_types
    let storage_shapes = constructor_plan.storage_shapes
    let shape = self.image.materialize_data_shape(
      family, constructor_plan, info,
    )
    let mut evidence_member_index = 0
    match constructor_plan.storage_hidden_arguments {
      Some(arguments) =>
        for index, hidden_parameter in info.hidden_evidence_parameters {
          let binder = alternative.evidence_binders[index]
          guard arguments.get(index) is Some(argument) else {
            raise RepresentationSpecializationInvariant(
              detail="specialized data match lacks its hidden runtime argument",
            )
          }
          hidden_substitutions.insert(hidden_parameter.id, argument)
          hidden_substitutions.insert(binder.id, argument)
        }
      None =>
        for index, hidden_parameter in info.hidden_evidence_parameters {
          let binder = alternative.evidence_binders[index]
          guard self.image.metadata.parameter_type_expression(binder.id)
            is Some(type_expression) else {
            raise InvalidTypeApplication(
              detail="hidden evidence binder has no runtime type expression",
            )
          }
          hidden_substitutions.insert(hidden_parameter.id, {
            type_expression,
            evidence: Parameter(binder.id),
          })
          let metadata = runtime_evidence_metadata(hidden_parameter)
          let evidence = self.fresh_metadata(
            borrowed_evidence_metadata(metadata),
          )
          self.emit(
            BorrowField(shape, scrutinee, evidence_member_index, {
              value_destination: evidence,
              witness_destination: None,
            }),
          )
          self.witnesses.push({ parameter: binder.id, value: evidence })
          evidence_member_index += 1
        }
    }
    let branch_substitutions = substitutions.overlay(hidden_substitutions)
    for index, value_binder in alternative.value_binders {
      let storage_type = storage_types[index]
      let storage_shape = storage_shapes[index]
      let stored = if storage_shape is Value({ cleanup: OwnedErased, .. }) {
        let witness = self.fresh_metadata(layout_witness_metadata())
        let erased = self.fresh_metadata(
          storage_shape.borrowed_value_metadata(Some(witness)),
        )
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            evidence_member_index + runtime_member_index(storage_shapes, index),
            { value_destination: erased, witness_destination: Some(witness) },
          ),
        )
        LocalValue::Slot(erased, storage_type, storage_shape)
      } else if storage_shape is Unit {
        Unit
      } else {
        let destination = self.fresh_metadata(
          storage_shape.borrowed_value_metadata(None),
        )
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            evidence_member_index + runtime_member_index(storage_shapes, index),
            { value_destination: destination, witness_destination: None },
          ),
        )
        LocalValue::Slot(destination, storage_type, storage_shape)
      }
      let payload = self.planned_match_payload(
        site,
        alternative.alt_constructor,
        index,
      )
      let source_shape = self.physical_shape(payload.flow.source)
      if self.local_physical_shape(stored) != source_shape {
        raise RepresentationSpecializationInvariant(
          detail="data-match payload \{index} at \{Repr(site)} produced \{Repr(self.local_physical_shape(stored))}, but its physical flow owns \{Repr(source_shape)}",
        )
      }
      let lowered = self.materialize_planned_value_flow(
        "Runtime ANF data-match payload at \{Repr(site)}",
        stored,
        payload.type_,
        self.physical_shape(payload.flow.target),
        payload.flow.bridge,
      )
      self.bindings.push({ value: value_binder, lowered })
    }
    self.substitutions = self.substitutions.overlay(branch_substitutions)
  } else {
    self.substitutions = self.substitutions.overlay(substitutions)
  }
}

///|
fn FunctionLowerer::lower_bool_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
) -> Unit raise LoisvmLoweringError {
  if !alternative.evidence_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(detail="Bool alternatives cannot bind payloads")
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bindings.push({ value: binder, lowered: scrutinee })
  let result = self.materialize_planned_match_alternative(
    site,
    alternative,
    self.materialize_local(self.lower_expr(alternative.body)),
  )
  let arguments = self.block_value_arguments(result)
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::branch_environment_parameter(
  self : FunctionLowerer,
) -> @vmcfg.ValueId? {
  self.environment.map(environment => {
    self.fresh_metadata(self.values[environment.value])
  })
}

///|
fn FunctionLowerer::enter_branch_environment(
  self : FunctionLowerer,
  original : @vmcfg.ValueId?,
  branch : @vmcfg.ValueId?,
) -> Unit {
  self.environment = branch
  guard original is Some(original) && branch is Some(branch) else { return }
  let shadows : Array[ValueBinding] = []
  for binding in self.bindings {
    if binding.lowered is RecursiveFunction(function, type_, Some(environment)) &&
      environment == original {
      shadows.push({
        value: binding.value,
        lowered: RecursiveFunction(function, type_, Some(branch)),
      })
    }
  }
  self.bindings.append(shadows)
}

///|
fn FunctionLowerer::restore_bindings(
  self : FunctionLowerer,
  value_count : Int,
  temp_count : Int,
) -> Unit {
  while self.bindings.length() > value_count {
    ignore(self.bindings.pop())
  }
  while self.temps.length() > temp_count {
    ignore(self.temps.pop())
  }
}

///|
fn FunctionLowerer::restore_witnesses(
  self : FunctionLowerer,
  witness_count : Int,
) -> Unit {
  while self.witnesses.length() > witness_count {
    ignore(self.witnesses.pop())
  }
}

///|
fn find_bool_alternative(
  alternatives : Array[@anf.AnfAlternative],
  value : Bool,
) -> @anf.AnfAlternative? {
  let mut default = None
  for alternative in alternatives {
    match alternative.alt_constructor {
      Literal(Bool(actual)) if actual == value => return Some(alternative)
      Default => default = Some(alternative)
      _ => ()
    }
  }
  default
}

///|
fn find_unit_alternative(
  alternatives : Array[@anf.AnfAlternative],
) -> @anf.AnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Literal(Unit) {
      return Some(alternative)
    }
  }
  find_default_alternative(alternatives)
}

///|
fn find_default_alternative(
  alternatives : Array[@anf.AnfAlternative],
) -> @anf.AnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Default {
      return Some(alternative)
    }
  }
  None
}

///|
fn find_data_alternative(
  alternatives : Array[@anf.AnfAlternative],
  data_constructor : @buslane.DataConId,
) -> @anf.AnfAlternative? {
  let mut default = None
  for alternative in alternatives {
    match alternative.alt_constructor {
      DataCon(actual) if actual == data_constructor => return Some(alternative)
      Default => default = Some(alternative)
      _ => ()
    }
  }
  default
}

///|
fn runtime_member_index(
  payload_shapes : Array[CanonicalRuntimeTypeKey],
  source_index : Int,
) -> Int {
  let mut runtime_index = 0
  for index in 0..<source_index {
    if !(payload_shapes[index] is Unit) {
      runtime_index += 1
    }
  }
  runtime_index
}

///|
