///|
fn FunctionLowerer::lower_data_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  owner : @buslane.TypeId,
  type_arguments : Array[@buslane.GenericArgument],
) -> LocalValue raise LoisvmLoweringError {
  let owner_info = match self.image.metadata.type_info(owner) {
    Some(info) => info
    None =>
      raise UnsupportedExpression(detail="data match owner metadata is missing")
  }
  let substitutions = self.data_type_substitutions(
    owner_info.parameters,
    type_arguments,
  )
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
      match_.binder,
      scrutinee,
      scrutinee_type,
      data_constructor,
      alternative,
      substitutions,
    )
  }
  let tag_type = @buslane.Type::Primitive(Bool)
  let tag = self.fresh_slot(tag_type)
  self.emit(LoadTag(tag, scrutinee))
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
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
    let branch_scrutinee = self.fresh_slot(scrutinee_type)
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
      block,
      join_block,
      match_.binder,
      branch_scrutinee,
      scrutinee_type,
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
fn FunctionLowerer::lower_irrefutable_data_alternative(
  self : FunctionLowerer,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  let substitution_count = self.substitutions.length()
  self.bind_data_alternative(
    binder, scrutinee, scrutinee_type, data_constructor, alternative, substitutions,
  )
  let result = self.materialize_local(self.lower_expr(alternative.body))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.restore_substitutions(substitution_count)
  result
}

///|
fn FunctionLowerer::lower_data_alternative(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
  substitutions : Array[TypeArgumentBinding],
) -> Unit raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  let substitution_count = self.substitutions.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bind_data_alternative(
    binder, scrutinee, scrutinee_type, data_constructor, alternative, substitutions,
  )
  let result = self.materialize_local(self.lower_expr(alternative.body))
  let arguments = match result {
    Unit => []
    Slot(slot, _) => [slot]
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(
        detail="match alternative returns an unapplied callable",
      )
  }
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.restore_substitutions(substitution_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::bind_data_alternative(
  self : FunctionLowerer,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : Array[TypeArgumentBinding],
) -> Unit raise LoisvmLoweringError {
  let info = match self.image.metadata.data_constructor_info(data_constructor) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  let binds_payloads = alternative.alt_constructor is DataCon(_)
  if binds_payloads {
    if alternative.type_binders.length() != info.hidden_type_parameters.length() {
      raise InvalidTypeApplication(
        detail="data alternative expects \{info.hidden_type_parameters.length()} hidden type binders, got \{alternative.type_binders.length()}",
      )
    }
  } else if !alternative.type_binders.is_empty() {
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
  self.bindings.push({ value: binder, lowered: Slot(scrutinee, scrutinee_type) })
  let branch_substitutions = substitutions.copy()
  if binds_payloads {
    let shape = self.image.data_shape(data_constructor, info)
    let owner_info = match self.image.metadata.type_info(info.owner) {
      Some(info) => info
      None => raise MissingDataConstructorMetadata(data_constructor~)
    }
    let mut witness_ordinal = owner_info.parameters
      .filter(parameter => self.image.requires_layout_witness(parameter))
      .length()
    for index, hidden_parameter in info.hidden_type_parameters {
      let binder = alternative.type_binders[index]
      let argument = match
        self.image.metadata.type_parameter_info(hidden_parameter) {
        Some({ kind: Effect, .. }) =>
          @buslane.GenericArgument::EffectArgument(Parameter(binder))
        Some(_) => TypeArgument(Parameter(binder))
        None =>
          raise InvalidTypeApplication(
            detail="hidden data parameter metadata is missing",
          )
      }
      branch_substitutions.push({ parameter: hidden_parameter, argument })
      if self.image.requires_layout_witness(hidden_parameter) {
        let witness = self.fresh_metadata(layout_witness_metadata())
        self.emit(LoadObjectWitness(witness, shape, scrutinee, witness_ordinal))
        self.witnesses.push({ parameter: binder, value: witness })
        witness_ordinal += 1
      }
    }
    for index, value_binder in alternative.value_binders {
      let formal_type = info.payload_types[index]
      let payload_type = substitute_type(formal_type, branch_substitutions)
      let stored = if formal_type is Parameter(_) {
        let witness = self.fresh_metadata(layout_witness_metadata())
        let erased = self.fresh_erased_slot(witness, Borrowed)
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            runtime_member_index(info.payload_types, index),
            { value_destination: erased, witness_destination: Some(witness) },
          ),
        )
        Slot(erased, formal_type)
      } else if formal_type == Primitive(Unit) {
        Unit
      } else {
        let destination = self.fresh_borrowed_slot(formal_type)
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            runtime_member_index(info.payload_types, index),
            { value_destination: destination, witness_destination: None },
          ),
        )
        Slot(destination, formal_type)
      }
      let lowered = self.adapt_local_value_with_substitutions(
        stored, formal_type, payload_type, branch_substitutions,
      )
      self.bindings.push({ value: value_binder, lowered })
    }
  }
  self.substitutions.append(branch_substitutions)
}

///|
fn FunctionLowerer::lower_bool_alternative(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
) -> Unit raise LoisvmLoweringError {
  if !alternative.type_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(detail="Bool alternatives cannot bind payloads")
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bindings.push({ value: binder, lowered: scrutinee })
  let result = self.materialize_local(self.lower_expr(alternative.body))
  let arguments = match result {
    Unit => []
    Slot(slot, _) => [slot]
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(
        detail="match alternative returns an unapplied callable",
      )
  }
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::branch_environment_parameter(
  self : FunctionLowerer,
) -> @vmcfg.ValueId? {
  self.environment.map(_ => self.fresh_metadata(environment_metadata()))
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
fn FunctionLowerer::restore_substitutions(
  self : FunctionLowerer,
  substitution_count : Int,
) -> Unit {
  while self.substitutions.length() > substitution_count {
    ignore(self.substitutions.pop())
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
  payload_types : Array[@buslane.Type],
  source_index : Int,
) -> Int {
  let mut runtime_index = 0
  for index in 0..<source_index {
    if payload_types[index] != Primitive(Unit) {
      runtime_index += 1
    }
  }
  runtime_index
}

///|
