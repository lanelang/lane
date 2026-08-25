///|
fn FunctionLowerer::lower_data_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : PhysicalAnfMatch,
  scrutinee : @vmcfg.ValueId,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  data : PhysicalDataMatchPlan,
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  let constructors = data.family.constructors
  if constructors.is_empty() {
    return self.lower_unreachable_match_result(result_shape)
  }
  if constructors is [constructor_plan] {
    let data_constructor = constructor_plan.data_constructor
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
      scrutinee_shape,
      constructor_plan,
      alternative,
    )
  }
  let tag = self.fresh_metadata(canonical_scalar_key(I32).value_metadata(None))
  self.emit(LoadTag(tag, scrutinee))
  let join_value = self.fresh_block_value_parameter(result_shape)
  let join_block = self.new_block(join_value.0)
  let cases : Array[@vmcfg.Edge] = []
  let alternatives : Array[
    (
      @bytecode.BlockId,
      @vmcfg.ValueId,
      @vmcfg.ValueId?,
      PhysicalAnfAlternative,
      PhysicalDataConstructorContract,
    ),
  ] = []
  for constructor_plan in constructors {
    let data_constructor = constructor_plan.data_constructor
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
    cases.push({ target: block, arguments, })
    alternatives.push(
      (
        block, branch_scrutinee, branch_environment, alternative, constructor_plan,
      ),
    )
  }
  let default_block = self.new_block([])
  self.terminate(
    SwitchTag(tag, cases, { target: default_block, arguments: [], }),
  )
  for item in alternatives {
    let (
      block,
      branch_scrutinee,
      branch_environment,
      alternative,
      constructor_plan,
    ) = item
    self.lower_data_alternative(
      site,
      block,
      join_block,
      match_.binder,
      branch_scrutinee,
      scrutinee_shape,
      constructor_plan,
      alternative,
      branch_environment,
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
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  self.terminate(Unreachable)
  let result = self.fresh_block_value_parameter(result_shape)
  self.enter_block(self.new_block(result.0))
  result.1
}

///|
fn FunctionLowerer::lower_irrefutable_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  constructor_plan : PhysicalDataConstructorContract,
  alternative : PhysicalAnfAlternative,
) -> LocalValue raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  self.bind_data_alternative(
    site, binder, scrutinee, scrutinee_shape, constructor_plan, alternative,
  )
  let result = self.materialize_physical_match_alternative_plan(
    alternative.plan,
    site,
    alternative,
    self.materialize_physical_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  result.value
}

///|
fn FunctionLowerer::lower_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  constructor_plan : PhysicalDataConstructorContract,
  alternative : PhysicalAnfAlternative,
  branch_environment : @vmcfg.ValueId?,
) -> Unit raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bind_data_alternative(
    site, binder, scrutinee, scrutinee_shape, constructor_plan, alternative,
  )
  let result = self.materialize_physical_match_alternative_plan(
    alternative.plan,
    site,
    alternative,
    self.materialize_physical_local(self.lower_expr(alternative.body)),
  )
  let arguments = self.block_value_arguments(result.value)
  self.terminate(Jump({ target: join, arguments, }))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::bind_data_alternative(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  constructor_plan : PhysicalDataConstructorContract,
  alternative : PhysicalAnfAlternative,
) -> Unit raise LoisvmLoweringError {
  let data_constructor = constructor_plan.data_constructor
  let binds_payloads = alternative.alt_constructor is DataCon(_)
  let expected_evidence_binders = if binds_payloads {
    constructor_plan.source_evidence_binder_count
  } else {
    0
  }
  if binds_payloads {
    if alternative.evidence_binders.length() != expected_evidence_binders {
      raise InvalidTypeApplication(
        detail="data alternative expects \{expected_evidence_binders} hidden evidence binders, got \{alternative.evidence_binders.length()}",
      )
    }
  } else if !alternative.evidence_binders.is_empty() {
    raise InvalidTypeApplication(
      detail="default data alternative cannot bind hidden types",
    )
  }
  let expected_binders = if binds_payloads {
    constructor_plan.storage_types.length()
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
    lowered: LocalValue::Slot(scrutinee, scrutinee_shape),
  })
  if binds_payloads {
    guard self.values[scrutinee.value].kind is DataValue(_) else {
      raise RepresentationSpecializationInvariant(
        detail="data match scrutinee lacks a representation family",
      )
    }
    let shape = constructor_plan.shape
    let storage_shapes = constructor_plan.storage_shapes
    let mut evidence_member_index = 0
    for index, hidden_parameter in constructor_plan.stored_evidence_parameters {
      let binder = alternative.evidence_binders[index]
      let metadata = runtime_evidence_metadata(hidden_parameter)
      let evidence = self.fresh_metadata(borrowed_evidence_metadata(metadata))
      self.emit(
        BorrowField(shape, scrutinee, evidence_member_index, {
          value_destination: evidence,
          witness_destination: None,
        }),
      )
      self.witnesses.push({ parameter: binder.id, value: evidence, })
      evidence_member_index += 1
    }
    for index, value_binder in alternative.value_binders {
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
            { value_destination: erased, witness_destination: Some(witness), },
          ),
        )
        LocalValue::Slot(erased, storage_shape)
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
            { value_destination: destination, witness_destination: None, },
          ),
        )
        LocalValue::Slot(destination, storage_shape)
      }
      guard alternative.plan.payloads.get(index) is Some(payload) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF data alternative has no payload contract",
        )
      }
      let lowered = self.materialize_planned_value_flow(
        "Runtime ANF data-match payload at \{Repr(site)}",
        { value: stored, contract: payload.flow.source, },
        payload.flow.target,
        payload.flow.bridge,
      )
      self.bindings.push({ value: value_binder, lowered: lowered.value, })
    }
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
  alternative : PhysicalAnfAlternative,
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
  self.bindings.push({ value: binder, lowered: scrutinee, })
  let result = self.materialize_physical_match_alternative_plan(
    alternative.plan,
    site,
    alternative,
    self.materialize_physical_local(self.lower_expr(alternative.body)),
  )
  let arguments = self.block_value_arguments(result.value)
  self.terminate(Jump({ target: join, arguments, }))
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
    if binding.lowered is RecursiveFunction(function, Some(environment)) &&
      environment == original {
      shadows.push({
        value: binding.value,
        lowered: RecursiveFunction(function, Some(branch)),
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
  alternatives : Array[PhysicalAnfAlternative],
  value : Bool,
) -> PhysicalAnfAlternative? {
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
  alternatives : Array[PhysicalAnfAlternative],
) -> PhysicalAnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Literal(Unit) {
      return Some(alternative)
    }
  }
  find_default_alternative(alternatives)
}

///|
fn find_default_alternative(
  alternatives : Array[PhysicalAnfAlternative],
) -> PhysicalAnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Default {
      return Some(alternative)
    }
  }
  None
}

///|
fn find_data_alternative(
  alternatives : Array[PhysicalAnfAlternative],
  data_constructor : @buslane.DataConId,
) -> PhysicalAnfAlternative? {
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
