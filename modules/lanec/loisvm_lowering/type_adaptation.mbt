///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.source_type == source_type && adapter.target_type == target_type {
      return adapter
    }
  }
  let captured_parameters = free_runtime_type_parameters(
    self, source_type, target_type,
  )
  let environment_shape = self.intern_object_shape(
    Environment({
      stored_witness_count: captured_parameters.length(),
      members: [
        { representation: I64, cleanup: OwnedCallable, witness_ordinal: None },
      ],
    }),
  )
  let adapter : CallableAdapterPlan = {
    function: { value: self.plans.length() + 1 },
    source_type,
    target_type,
    captured_parameters,
    environment_shape,
  }
  self.callable_adapters.push(adapter)
  self.plans.push(CallableAdapter(adapter))
  adapter
}

///|
fn free_runtime_type_parameters(
  image : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> Array[@buslane.TypeParameterId] {
  free_runtime_type_parameters_in_types(image, [source_type, target_type])
}

///|
fn free_runtime_type_parameters_in_types(
  image : ImageLowerer,
  types : Array[@buslane.Type],
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  for type_ in types {
    collect_free_runtime_type_parameters(image, type_, [], parameters)
  }
  parameters
}

///|
fn collect_free_runtime_type_parameters(
  image : ImageLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  parameters : Array[@buslane.TypeParameterId],
) -> Unit {
  match type_ {
    Parameter(parameter) =>
      if !bound.contains(parameter) &&
        !parameters.contains(parameter) &&
        (parameter.index < 0 || image.requires_layout_witness(parameter)) {
        parameters.push(parameter)
      }
    Apply(applied_type, arguments) => {
      collect_free_runtime_type_parameters(
        image, applied_type, bound, parameters,
      )
      for argument in arguments {
        if argument is TypeArgument(type_) {
          collect_free_runtime_type_parameters(image, type_, bound, parameters)
        }
      }
    }
    TypeLambda(type_parameters, body) | Forall(type_parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(type_parameters)
      collect_free_runtime_type_parameters(
        image, body, nested_bound, parameters,
      )
    }
    Function(arguments, result, _) => {
      for argument in arguments {
        collect_free_runtime_type_parameters(image, argument, bound, parameters)
      }
      collect_free_runtime_type_parameters(image, result, bound, parameters)
    }
    Primitive(_) | Constructor(_) => ()
  }
}

///|
fn FunctionLowerer::canonical_callable_type(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> (@buslane.Type, Array[TypeArgumentBinding]) raise LoisvmLoweringError {
  let bindings = []
  let canonical = self.canonical_callable_type_with_bound(type_, [], bindings)
  (canonical, bindings)
}

///|
fn FunctionLowerer::canonical_callable_type_with_bound(
  self : FunctionLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  bindings : Array[TypeArgumentBinding],
) -> @buslane.Type raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(parameters)
      Forall(
        parameters,
        self.canonical_callable_type_with_bound(body, nested_bound, bindings),
      )
    }
    Function(parameters, result, effect) =>
      Function(
        parameters.map(type_ => {
          self.canonical_callable_value_type(type_, bound, bindings)
        }),
        self.canonical_callable_value_type(result, bound, bindings),
        effect,
      )
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn FunctionLowerer::canonical_callable_value_type(
  self : FunctionLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  bindings : Array[TypeArgumentBinding],
) -> @buslane.Type {
  if type_ == Primitive(Unit) {
    return type_
  }
  if type_ is Parameter(parameter) && bound.contains(parameter) {
    return type_
  }
  let parameter = self.image.fresh_synthetic_parameter()
  bindings.push({ parameter, argument: TypeArgument(type_) })
  Parameter(parameter)
}

///|
fn FunctionLowerer::adapter_witness(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
  substitutions : Array[TypeArgumentBinding],
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  for substitution in substitutions.rev_iter() {
    if substitution.parameter == parameter {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="callable adapter witness requires a type argument",
        )
      }
      return self.layout_witness(type_)
    }
  }
  if self.image.effect_source(parameter) is Some(source) {
    for substitution in substitutions.rev_iter() {
      if substitution.parameter == source &&
        substitution.argument is EffectArgument(effect) {
        return self.effect_context_witness(effect)
      }
    }
  }
  self.find_witness(parameter)
}

///|
fn FunctionLowerer::make_callable_adapter(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  if source_type == target_type {
    return Slot(source, target_type)
  }
  let plan = self.image.callable_adapter(source_type, target_type)
  let witnesses = plan.captured_parameters.map(parameter => {
    self.adapter_witness(parameter, substitutions)
  })
  let environment = self.fresh_metadata(environment_metadata())
  let environment_layout = self.image.intern_layout(
    Environment(plan.environment_shape),
  )
  self.emit(
    MakeEnv(
      environment,
      plan.environment_shape,
      Immediate(environment_layout),
      witnesses,
      [source],
    ),
  )
  let callable = self.fresh_slot(target_type)
  self.emit(MakeClosure(callable, plan.function, environment))
  Slot(callable, target_type)
}

///|
fn FunctionLowerer::adapt_local_value(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> LocalValue raise LoisvmLoweringError {
  self.adapt_local_value_with_substitutions(value, source_type, target_type, [])
}

///|
fn FunctionLowerer::adapt_local_value_with_substitutions(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  let source_type = local_value_type(value).unwrap_or(source_type)
  if source_type == target_type {
    return match value {
      Unit => Unit
      Slot(slot, _) => Slot(slot, target_type)
      _ => value
    }
  }
  match (source_type, target_type) {
    (Primitive(Unit), Primitive(Unit)) => Unit
    (Parameter(_), Parameter(_)) =>
      match value {
        Slot(slot, _) => Slot(slot, target_type)
        _ =>
          raise InvalidTypeApplication(
            detail="erased value is not materialized",
          )
      }
    (_, Parameter(parameter)) => {
      let witness = if source_type is Parameter(_) {
        self.adapter_witness(parameter, substitutions)
      } else {
        self.layout_witness(source_type)
      }
      Slot(self.erase_value(value, source_type, witness), target_type)
    }
    (Parameter(_), _) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      self.unerase_value(slot, target_type)
    }
    (Function(_, _, _) | Forall(_, _), Function(_, _, _) | Forall(_, _)) => {
      guard self.materialize_local(value) is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="callable value is not materialized",
        )
      }
      self.make_callable_adapter(
        source, source_type, target_type, substitutions,
      )
    }
    _ => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="adapted value is not materialized")
      }
      let source_metadata = slot_metadata(source_type)
      let target_metadata = slot_metadata(target_type)
      if source_metadata.representation != target_metadata.representation ||
        source_metadata.cleanup != target_metadata.cleanup {
        raise InvalidTypeApplication(
          detail="callable adapter cannot bridge incompatible value representations",
        )
      }
      Slot(slot, target_type)
    }
  }
}

///|
fn local_value_type(value : LocalValue) -> @buslane.Type? {
  match value {
    Slot(_, type_) => Some(type_)
    Global(Function(_, type_))
    | Global(Intrinsic(_, type_))
    | Global(DoubleConstant(_, type_))
    | Global(ScalarExternal(_, type_))
    | Global(InstanceGlobal(_, type_)) => Some(type_)
    RecursiveFunction(_, type_, _) | TypeAppliedCallable(_, type_, _) =>
      Some(type_)
    Global(UnitValue) | Unit | TypeApplied(_, _) => None
  }
}

///|
fn ImageLowerer::lower_callable_adapter(
  self : ImageLowerer,
  plan : CallableAdapterPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (source_type_parameters, source_parameter_types, source_result_type) = function_type_parts(
    plan.source_type,
  )
  let (target_type_parameters, target_parameter_types, target_result_type) = function_type_parts(
    plan.target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() ||
    source_parameter_types.length() != target_parameter_types.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target arities differ",
    )
  }
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: [],
  }
  let input_witnesses = []
  for index, parameter in target_type_parameters {
    if self.requires_layout_witness(parameter) {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter, value: witness })
      let source_parameter = source_type_parameters[index]
      if source_parameter != parameter {
        lowerer.witnesses.push({ parameter: source_parameter, value: witness })
      }
    }
  }
  let environment = lowerer.fresh_metadata(environment_metadata())
  lowerer.environment = Some(environment)
  for index, parameter in plan.captured_parameters {
    let witness = lowerer.fresh_metadata(layout_witness_metadata())
    lowerer.emit(
      LoadObjectWitness(witness, plan.environment_shape, environment, index),
    )
    lowerer.witnesses.push({ parameter, value: witness })
  }
  let source_callable = lowerer.fresh_borrowed_slot(plan.source_type)
  lowerer.emit(
    BorrowCapture(plan.environment_shape, environment, 0, {
      value_destination: source_callable,
      witness_destination: None,
    }),
  )
  let target_parameters : Array[LocalValue] = []
  let user_parameter_slots = []
  for type_ in target_parameter_types {
    if type_ == Primitive(Unit) {
      target_parameters.push(Unit)
    } else {
      let slot = lowerer.fresh_slot(type_)
      user_parameter_slots.push(slot)
      target_parameters.push(Slot(slot, type_))
    }
  }
  let source_arguments = []
  for index, source_parameter_type in source_parameter_types {
    let adapted = lowerer.adapt_local_value(
      target_parameters[index],
      target_parameter_types[index],
      source_parameter_type,
    )
    if adapted is Slot(slot, _) {
      source_arguments.push(slot)
    }
  }
  let call_witnesses = []
  for parameter in source_type_parameters {
    if self.requires_layout_witness(parameter) {
      call_witnesses.push(lowerer.find_witness(parameter))
    }
  }
  if source_result_type == target_result_type {
    lowerer.terminate(
      TailCallValue(source_callable, call_witnesses, source_arguments),
    )
  } else {
    let source_result = lowerer.fresh_optional_slot(source_result_type)
    lowerer.emit(
      CallValue(
        source_callable,
        call_witnesses,
        source_arguments,
        source_result.0,
      ),
    )
    let result = lowerer.adapt_local_value(
      source_result.1,
      source_result_type,
      target_result_type,
    )
    lowerer.terminate(
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        _ =>
          raise InvalidTypeApplication(
            detail="callable adapter result is not materialized",
          )
      },
    )
  }
  {
    values: lowerer.values,
    inputs: {
      environment: Some(environment),
      witnesses: input_witnesses,
      user_parameters: user_parameter_slots,
    },
    result: result_representation(target_result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}

///|
