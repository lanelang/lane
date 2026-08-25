///|
fn FunctionLowerer::lower_match(
  self : FunctionLowerer,
  match_ : PhysicalAnfMatch,
) -> LocalValue raise LoisvmLoweringError {
  let site = match_.plan.site
  let result_shape = self.physical_shape(match_.plan.result)
  let scrutinee = self.materialize_physical_local(
    self.lower_physical_atom(match_.scrutinee),
  )
  match match_.plan.representation {
    Product => {
      guard scrutinee.value is ClosedAggregate(contract, payloads) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF product match produced a non-product value",
        )
      }
      self.lower_closed_aggregate_match(match_, contract, payloads)
    }
    Unit => {
      guard scrutinee.value is Unit else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF Unit match produced a non-Unit value",
        )
      }
      let alternative = match find_unit_alternative(match_.alternatives) {
        Some(alternative) => alternative
        None =>
          raise UnsupportedExpression(
            detail="Unit match has no matching alternative",
          )
      }
      self.lower_irrefutable_match(match_, scrutinee.value, alternative)
    }
    Bool => {
      guard scrutinee.value is Slot(condition, shape) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF Bool match produced a non-slot value",
        )
      }
      self.lower_bool_match(
        site,
        match_,
        condition,
        LocalValue::Slot(condition, shape),
        result_shape,
      )
    }
    Literal(comparison) => {
      guard scrutinee.value is Slot(condition, shape) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF literal match produced a non-slot value",
        )
      }
      self.lower_literal_match(
        site,
        match_,
        condition,
        shape,
        comparison,
        LocalValue::Slot(condition, shape),
        result_shape,
      )
    }
    Callable => {
      guard scrutinee.value is Slot(_, _) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF callable match produced a non-slot value",
        )
      }
      let alternative = match find_default_alternative(match_.alternatives) {
        Some(alternative) => alternative
        None =>
          raise UnsupportedExpression(
            detail="callable match requires a default alternative",
          )
      }
      self.lower_irrefutable_match(match_, scrutinee.value, alternative)
    }
    Data(data) => {
      guard scrutinee.value is Slot(condition, shape) else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF data match produced a non-slot value",
        )
      }
      self.lower_data_match(site, match_, condition, shape, data, result_shape)
    }
  }
}

///|
fn FunctionLowerer::lower_closed_aggregate_match(
  self : FunctionLowerer,
  match_ : PhysicalAnfMatch,
  contract : ClosedAggregateContract,
  payloads : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let mut selected : PhysicalAnfAlternative? = None
  let mut default : PhysicalAnfAlternative? = None
  for alternative in match_.alternatives {
    match alternative.alt_constructor {
      DataCon(data_constructor) if data_constructor == contract.data_constructor => {
        selected = Some(alternative)
        break
      }
      Default => default = Some(alternative)
      _ => ()
    }
  }
  if selected is None {
    selected = default
  }
  guard selected is Some(alternative) && alternative.evidence_binders.is_empty() else {
    raise RepresentationSpecializationInvariant(
      detail="closed aggregate match lacks its certified alternative",
    )
  }
  match alternative.alt_constructor {
    DataCon(_) =>
      if alternative.value_binders.length() != payloads.length() {
        raise RepresentationSpecializationInvariant(
          detail="closed aggregate payload binders do not match its contract",
        )
      }
    Default =>
      if !alternative.value_binders.is_empty() {
        raise RepresentationSpecializationInvariant(
          detail="closed aggregate default alternative binds payloads",
        )
      }
    Literal(_) =>
      raise RepresentationSpecializationInvariant(
        detail="closed aggregate selected a literal alternative",
      )
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.bindings.push({
    value: match_.binder,
    lowered: ClosedAggregate(contract, payloads),
  })
  if alternative.alt_constructor is DataCon(_) {
    for index, binder in alternative.value_binders {
      self.bindings.push({ value: binder, lowered: payloads[index], })
    }
  }
  let result = self.materialize_physical_match_alternative(
    match_,
    alternative,
    self.materialize_physical_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  result.value
}

///|
fn FunctionLowerer::lower_literal_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : PhysicalAnfMatch,
  initial_scrutinee : @vmcfg.ValueId,
  scrutinee_shape : CanonicalRuntimeTypeKey,
  comparison : PhysicalLiteralComparison,
  initial_value : LocalValue,
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  let literal_alternatives = match_.alternatives.filter(alternative => {
    alternative.alt_constructor is Literal(_)
  })
  if literal_alternatives.is_empty() {
    let alternative = match find_default_alternative(match_.alternatives) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(detail="literal match has no alternatives")
    }
    return self.lower_irrefutable_match(match_, initial_value, alternative)
  }
  let default_alternative = match
    find_default_alternative(match_.alternatives) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(
        detail="literal match requires a default alternative",
      )
  }
  let join_value = self.fresh_block_value_parameter(result_shape)
  let join_block = self.new_block(join_value.0)
  let branches : Array[
    (@bytecode.BlockId, @vmcfg.ValueId, @vmcfg.ValueId?, PhysicalAnfAlternative),
  ] = []
  let mut scrutinee = initial_scrutinee
  let mut environment = self.environment
  for alternative in literal_alternatives {
    guard alternative.alt_constructor is Literal(literal) else {
      abort("filtered literal alternative")
    }
    let condition = self.emit_literal_equality(scrutinee, comparison, literal)
    let branch_scrutinee = self.fresh_metadata(
      scrutinee_shape.value_metadata(None),
    )
    let branch_environment = self.branch_environment_parameter()
    let branch_parameters = [branch_scrutinee]
    if branch_environment is Some(value) {
      branch_parameters.push(value)
    }
    let branch_block = self.new_block(branch_parameters)
    branches.push(
      (branch_block, branch_scrutinee, branch_environment, alternative),
    )
    let next_scrutinee = self.fresh_metadata(
      scrutinee_shape.value_metadata(None),
    )
    let next_environment = self.branch_environment_parameter()
    let next_parameters = [next_scrutinee]
    if next_environment is Some(value) {
      next_parameters.push(value)
    }
    let next_block = self.new_block(next_parameters)
    let arguments = [scrutinee]
    if environment is Some(value) {
      arguments.push(value)
    }
    self.terminate(
      BranchBool(condition, { target: branch_block, arguments, }, {
        target: next_block,
        arguments,
      }),
    )
    self.enter_block(next_block)
    scrutinee = next_scrutinee
    environment = next_environment
  }
  let default_block = self.current_block
  let default_scrutinee = scrutinee
  let default_environment = environment
  for branch in branches {
    let (block, branch_scrutinee, branch_environment, alternative) = branch
    self.lower_bool_alternative(
      site,
      block,
      join_block,
      match_.binder,
      LocalValue::Slot(branch_scrutinee, scrutinee_shape),
      alternative,
      branch_environment,
    )
  }
  self.lower_bool_alternative(
    site,
    { value: default_block, },
    join_block,
    match_.binder,
    LocalValue::Slot(default_scrutinee, scrutinee_shape),
    default_alternative,
    default_environment,
  )
  self.enter_block(join_block)
  join_value.1
}

///|
fn FunctionLowerer::emit_literal_equality(
  self : FunctionLowerer,
  scrutinee : @vmcfg.ValueId,
  comparison : PhysicalLiteralComparison,
  literal : PhysicalLiteral,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let lowered = self.lower_literal_with_shape(literal, literal.physical_shape())
  guard lowered is Slot(expected, _) else {
    raise UnsupportedExpression(
      detail="literal pattern type does not match its scrutinee",
    )
  }
  let condition = self.fresh_metadata(
    canonical_scalar_key(I32).value_metadata(None),
  )
  let instruction : @vmcfg.Instruction = match comparison {
    I64 => I64Eq(condition, scrutinee, expected)
    I32 => I32Eq(condition, scrutinee, expected)
    F32 => F32Eq(condition, scrutinee, expected)
    F64 => F64Eq(condition, scrutinee, expected)
    ByteSequence => ByteSequenceEqual(condition, scrutinee, expected)
  }
  self.emit(instruction)
  condition
}

///|
fn FunctionLowerer::lower_irrefutable_match(
  self : FunctionLowerer,
  match_ : PhysicalAnfMatch,
  scrutinee : LocalValue,
  alternative : PhysicalAnfAlternative,
) -> LocalValue raise LoisvmLoweringError {
  if !alternative.evidence_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(
      detail="irrefutable alternative cannot bind payloads",
    )
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.bindings.push({ value: match_.binder, lowered: scrutinee, })
  let result = self.materialize_physical_match_alternative(
    match_,
    alternative,
    self.materialize_physical_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  result.value
}

///|
fn FunctionLowerer::lower_bool_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : PhysicalAnfMatch,
  condition : @vmcfg.ValueId,
  scrutinee : LocalValue,
  result_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  let if_true = match find_bool_alternative(match_.alternatives, true) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(detail="Bool match lacks a true alternative")
  }
  let if_false = match find_bool_alternative(match_.alternatives, false) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(detail="Bool match lacks a false alternative")
  }
  let true_environment = self.branch_environment_parameter()
  let false_environment = self.branch_environment_parameter()
  let true_block = self.new_block(
    true_environment.map(value => [value]).unwrap_or([]),
  )
  let false_block = self.new_block(
    false_environment.map(value => [value]).unwrap_or([]),
  )
  let join_value = self.fresh_block_value_parameter(result_shape)
  let join_block = self.new_block(join_value.0)
  self.terminate(
    BranchBool(
      condition,
      {
        target: true_block,
        arguments: self.environment.map(value => [value]).unwrap_or([]),
      },
      {
        target: false_block,
        arguments: self.environment.map(value => [value]).unwrap_or([]),
      },
    ),
  )
  self.lower_bool_alternative(
    site,
    true_block,
    join_block,
    match_.binder,
    scrutinee,
    if_true,
    true_environment,
  )
  self.lower_bool_alternative(
    site,
    false_block,
    join_block,
    match_.binder,
    scrutinee,
    if_false,
    false_environment,
  )
  self.enter_block(join_block)
  join_value.1
}

///|
