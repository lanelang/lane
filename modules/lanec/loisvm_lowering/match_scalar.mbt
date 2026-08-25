///|
fn FunctionLowerer::lower_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
) -> LocalValue raise LoisvmLoweringError {
  let result_shape = self.planned_match_result(site)
  let scrutinee = self.materialize_local(self.lower_atom(match_.scrutinee))
  let scrutinee_shape = self.planned_match_scrutinee(site)
  if self.local_physical_shape(scrutinee) != scrutinee_shape {
    raise RepresentationSpecializationInvariant(
      detail="match scrutinee at \{Repr(site)} produced \{Repr(self.local_physical_shape(scrutinee))}, but its physical port owns \{Repr(scrutinee_shape)}",
    )
  }
  match scrutinee {
    ClosedAggregate(contract, payloads) =>
      self.lower_closed_aggregate_match(site, match_, contract, payloads)
    Unit => {
      let alternative = match find_unit_alternative(match_.alternatives) {
        Some(alternative) => alternative
        None =>
          raise UnsupportedExpression(
            detail="Unit match has no matching alternative",
          )
      }
      self.lower_irrefutable_match(site, match_, scrutinee, alternative)
    }
    Slot(condition, scrutinee_type, shape) => {
      let scrutinee = LocalValue::Slot(condition, scrutinee_type, shape)
      match scrutinee_type {
        Scalar(Bool) =>
          self.lower_bool_match(
            site, match_, condition, scrutinee, result_shape,
          )
        Scalar(I64 | I32 | Char | F32 | F64) | ByteSequence =>
          self.lower_literal_match(
            site, match_, condition, scrutinee_type, scrutinee, result_shape,
          )
        Callable(_, _) | Forall(_, _) => {
          let alternative = match
            find_default_alternative(match_.alternatives) {
            Some(alternative) => alternative
            None =>
              raise UnsupportedExpression(
                detail="callable match requires a default alternative",
              )
          }
          self.lower_irrefutable_match(site, match_, scrutinee, alternative)
        }
        Data(owner, arguments) =>
          self.lower_data_match(
            site, match_, condition, scrutinee_type, shape, owner, arguments, result_shape,
          )
        _ =>
          raise UnsupportedExpression(detail="unsupported match scrutinee type")
      }
    }
    Global(_)
    | NestedCallable(_)
    | RecursiveFunction(_, _, _)
    | EvidenceApplied(_, _)
    | EvidenceAppliedCallable(_, _, _, _)
    | EvidenceAppliedNestedCallable(_, _) =>
      raise UnsupportedExpression(detail="match scrutinee is not materialized")
  }
}

///|
fn FunctionLowerer::lower_closed_aggregate_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
  contract : ClosedAggregateContract,
  payloads : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let mut selected : @anf.AnfAlternative? = None
  let mut default : @anf.AnfAlternative? = None
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
  let result = self.materialize_planned_match_alternative(
    site,
    alternative,
    self.materialize_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  result
}

///|
fn FunctionLowerer::lower_literal_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
  initial_scrutinee : @vmcfg.ValueId,
  scrutinee_type : @anf.RuntimeType,
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
    return self.lower_irrefutable_match(
      site, match_, initial_value, alternative,
    )
  }
  let default_alternative = match
    find_default_alternative(match_.alternatives) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(
        detail="literal match requires a default alternative",
      )
  }
  let join_value = self.fresh_block_value_parameter(
    match_.result_type,
    result_shape,
  )
  let join_block = self.new_block(join_value.0)
  let branches : Array[
    (@bytecode.BlockId, @vmcfg.ValueId, @vmcfg.ValueId?, @anf.AnfAlternative),
  ] = []
  let mut scrutinee = initial_scrutinee
  let mut environment = self.environment
  for alternative in literal_alternatives {
    guard alternative.alt_constructor is Literal(literal) else {
      abort("filtered literal alternative")
    }
    let condition = self.emit_literal_equality(
      scrutinee, scrutinee_type, literal,
    )
    let branch_scrutinee = self.fresh_slot(scrutinee_type)
    let branch_environment = self.branch_environment_parameter()
    let branch_parameters = [branch_scrutinee]
    if branch_environment is Some(value) {
      branch_parameters.push(value)
    }
    let branch_block = self.new_block(branch_parameters)
    branches.push(
      (branch_block, branch_scrutinee, branch_environment, alternative),
    )
    let next_scrutinee = self.fresh_slot(scrutinee_type)
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
      self.slot_value(branch_scrutinee, scrutinee_type),
      alternative,
      branch_environment,
    )
  }
  self.lower_bool_alternative(
    site,
    { value: default_block, },
    join_block,
    match_.binder,
    self.slot_value(default_scrutinee, scrutinee_type),
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
  scrutinee_type : @anf.RuntimeType,
  literal : @buslane.Literal,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let lowered = self.lower_literal(literal)
  guard lowered is Slot(expected, literal_type, _) &&
    literal_type == scrutinee_type else {
    raise UnsupportedExpression(
      detail="literal pattern type does not match its scrutinee",
    )
  }
  let condition = self.fresh_slot(Scalar(Bool))
  let instruction : @vmcfg.Instruction = match scrutinee_type {
    Scalar(I64) => I64Eq(condition, scrutinee, expected)
    Scalar(I32 | Char) => I32Eq(condition, scrutinee, expected)
    Scalar(F32) => F32Eq(condition, scrutinee, expected)
    Scalar(F64) => F64Eq(condition, scrutinee, expected)
    ByteSequence => ByteSequenceEqual(condition, scrutinee, expected)
    _ =>
      raise UnsupportedExpression(
        detail="unsupported literal pattern representation",
      )
  }
  self.emit(instruction)
  condition
}

///|
fn FunctionLowerer::lower_irrefutable_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
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
  let result = self.materialize_planned_match_alternative(
    site,
    alternative,
    self.materialize_local(self.lower_expr(alternative.body)),
  )
  self.restore_bindings(value_count, temp_count)
  result
}

///|
fn FunctionLowerer::lower_bool_match(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
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
  let join_value = self.fresh_block_value_parameter(
    match_.result_type,
    result_shape,
  )
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
