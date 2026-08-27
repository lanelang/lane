///|
priv struct LocalJoinPointPlan {
  function : @anf.AnfFunction
  block : @physical.BlockId
  parameters : Array[LocalValue]
}

///|
fn FunctionLowerer::lower_join_group(
  self : FunctionLowerer,
  bindings : Array[@anf.AnfRecursiveBinding],
  body : @anf.AnfExpr,
) -> LocalValue raise PhysicalLoweringError {
  guard !bindings.is_empty() else {
    raise invalid_runtime_anf_callable_disposition(
      detail="an empty join-point group reached physical lowering",
    )
  }
  guard bindings[0].rhs is JoinPoint(first) else {
    raise invalid_runtime_anf_callable_disposition(
      detail="a join-point group contains a non-join callable",
    )
  }
  let result_type = self.substitutions.apply_type(
    self.image.runtime_types,
    first.result_type,
  )
  let result = self.fresh_optional_slot(result_type)
  let result_parameters = result.0.map(value => [value]).unwrap_or([])
  let result_block = self.new_block(result_parameters)
  let plans : Array[LocalJoinPointPlan] = []
  for binding in bindings {
    guard binding.rhs is JoinPoint(function) else {
      raise invalid_runtime_anf_callable_disposition(
        detail="a join-point group contains mixed callable dispositions",
      )
    }
    let actual_result = self.substitutions.apply_type(
      self.image.runtime_types,
      function.result_type,
    )
    if actual_result != result_type {
      raise invalid_runtime_anf_callable_disposition(
        detail="join points in one group have different result types",
      )
    }
    let parameters : Array[LocalValue] = []
    let block_parameters : Array[@vmcfg.ValueId] = []
    for parameter in function.parameters {
      let type_ = match self.image.metadata.value_info(parameter) {
        Some(info) =>
          self.substitutions.apply_type(self.image.runtime_types, info.type_)
        None => raise MissingValueMetadata(value=parameter)
      }
      if self.image.runtime_type(type_) is Concrete(Unit) {
        parameters.push(Unit)
      } else {
        let slot = self.fresh_slot(type_)
        parameters.push(Slot(slot, type_))
        block_parameters.push(slot)
      }
    }
    plans.push({
      function,
      block: self.new_block(block_parameters),
      parameters,
    })
  }
  let binding_count = self.bindings.length()
  let temp_count = self.temps.length()
  for index, binding in bindings {
    let function_type = match self.image.metadata.value_info(binding.id) {
      Some(info) =>
        self.substitutions.apply_type(self.image.runtime_types, info.type_)
      None => raise MissingValueMetadata(value=binding.id)
    }
    self.bindings.push({
      value: binding.id,
      lowered: JoinTarget(plans[index].block, function_type),
    })
  }
  self.route_join_result(self.lower_expr(body), result_block, result_type)
  for plan in plans {
    self.enter_block(plan.block)
    let parameter_binding_count = self.bindings.length()
    let parameter_temp_count = self.temps.length()
    for index, parameter in plan.function.parameters {
      self.bindings.push({ value: parameter, lowered: plan.parameters[index], })
    }
    self.route_join_result(
      self.lower_expr(plan.function.body),
      result_block,
      result_type,
    )
    self.restore_bindings(parameter_binding_count, parameter_temp_count)
  }
  self.restore_bindings(binding_count, temp_count)
  self.enter_block(result_block)
  result.1
}

///|
fn FunctionLowerer::route_join_result(
  self : FunctionLowerer,
  value : LocalValue,
  result_block : @physical.BlockId,
  result_type : @anf.RuntimeType,
) -> Unit raise PhysicalLoweringError {
  if value is ControlTransferred {
    return
  }
  let source_type = local_value_type(value).unwrap_or(result_type)
  let value = self.materialize_local(
    self.adapt_local_value_with_substitutions(
      value,
      source_type,
      result_type,
      self.substitutions,
    ),
  )
  let arguments = match value {
    Unit => []
    Slot(slot, _) => [slot]
    _ =>
      raise invalid_runtime_anf_callable_disposition(
        detail="a join-point branch returned an unapplied callable",
      )
  }
  self.terminate(Jump({ target: result_block, arguments, }))
}

///|
fn FunctionLowerer::lower_join_call(
  self : FunctionLowerer,
  block : @physical.BlockId,
  type_ : @anf.RuntimeType,
  arguments : Array[LocalValue],
) -> LocalValue raise PhysicalLoweringError {
  let (parameters, parameter_types, _) = function_type_parts(type_)
  if !parameters.is_empty() {
    raise invalid_runtime_anf_callable_disposition(
      detail="a generic callable was classified as a join point",
    )
  }
  let arguments = self.adapt_call_arguments(
    arguments,
    parameter_types,
    self.substitutions,
  )
  self.terminate(Jump({ target: block, arguments, }))
  ControlTransferred
}
