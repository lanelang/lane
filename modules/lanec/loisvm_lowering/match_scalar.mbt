///|
fn FunctionLowerer::lower_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
) -> LocalValue raise LoisvmLoweringError {
  let scrutinee = self.materialize_local(self.lower_atom(match_.scrutinee))
  match scrutinee {
    Unit => {
      let alternative = match find_unit_alternative(match_.alternatives) {
        Some(alternative) => alternative
        None =>
          raise UnsupportedExpression(
            detail="Unit match has no matching alternative",
          )
      }
      self.lower_irrefutable_match(match_, scrutinee, alternative)
    }
    Slot(condition, scrutinee_type) =>
      match scrutinee_type {
        Primitive(Bool) => self.lower_bool_match(match_, condition, scrutinee)
        Primitive(Int) | Primitive(Double) | Primitive(String) =>
          self.lower_literal_match(match_, condition, scrutinee_type, scrutinee)
        Function(_, _, _) | Forall(_, _) => {
          let alternative = match
            find_default_alternative(match_.alternatives) {
            Some(alternative) => alternative
            None =>
              raise UnsupportedExpression(
                detail="callable match requires a default alternative",
              )
          }
          self.lower_irrefutable_match(match_, scrutinee, alternative)
        }
        Constructor(owner) =>
          self.lower_data_match(match_, condition, scrutinee_type, owner, [])
        Apply(Constructor(owner), arguments) =>
          self.lower_data_match(
            match_, condition, scrutinee_type, owner, arguments,
          )
        _ =>
          raise UnsupportedExpression(detail="unsupported match scrutinee type")
      }
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(detail="match scrutinee is not materialized")
  }
}

///|
fn FunctionLowerer::lower_literal_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  initial_scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  initial_value : LocalValue,
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
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
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
      BranchBool(condition, { target: branch_block, arguments }, {
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
      block,
      join_block,
      match_.binder,
      Slot(branch_scrutinee, scrutinee_type),
      alternative,
      branch_environment,
    )
  }
  self.lower_bool_alternative(
    { value: default_block },
    join_block,
    match_.binder,
    Slot(default_scrutinee, scrutinee_type),
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
  scrutinee_type : @buslane.Type,
  literal : @buslane.Literal,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let lowered = self.lower_literal(literal)
  guard lowered is Slot(expected, literal_type) &&
    literal_type == scrutinee_type else {
    raise UnsupportedExpression(
      detail="literal pattern type does not match its scrutinee",
    )
  }
  let condition = self.fresh_slot(Primitive(Bool))
  let instruction : @vmcfg.Instruction = match scrutinee_type {
    Primitive(Int) => IntEq(condition, scrutinee, expected)
    Primitive(Double) => DoubleEq(condition, scrutinee, expected)
    Primitive(String) => StringEq(condition, scrutinee, expected)
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
  match_ : @anf.AnfMatch,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
) -> LocalValue raise LoisvmLoweringError {
  if !alternative.type_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(
      detail="irrefutable alternative cannot bind payloads",
    )
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.bindings.push({ value: match_.binder, lowered: scrutinee })
  let result = self.materialize_local(self.lower_expr(alternative.body))
  self.restore_bindings(value_count, temp_count)
  result
}

///|
fn FunctionLowerer::lower_bool_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  condition : @vmcfg.ValueId,
  scrutinee : LocalValue,
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
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
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
    true_block,
    join_block,
    match_.binder,
    scrutinee,
    if_true,
    true_environment,
  )
  self.lower_bool_alternative(
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
