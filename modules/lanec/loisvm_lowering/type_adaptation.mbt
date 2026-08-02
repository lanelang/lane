///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  source_parameter_targets : Array[Int],
  substitutions : @buslane.TypeSubstitution,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.source_type == source_type &&
      adapter.target_type == target_type &&
      adapter.source_parameter_targets == source_parameter_targets &&
      adapter.substitutions == substitutions {
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
    source_parameter_targets,
    substitutions,
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
) -> (@buslane.Type, @buslane.TypeSubstitution) raise LoisvmLoweringError {
  let bindings = @buslane.TypeSubstitution::TypeSubstitution()
  let canonical = self.canonical_callable_type_with_bound(type_, [], bindings)
  (canonical, bindings)
}

///|
fn FunctionLowerer::canonical_callable_type_with_bound(
  self : FunctionLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  bindings : @buslane.TypeSubstitution,
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
  bindings : @buslane.TypeSubstitution,
) -> @buslane.Type {
  if self.image.runtime_type(type_) is Concrete(Primitive(Unit)) {
    return type_
  }
  if self.image.runtime_type(type_) is Erased(parameter) &&
    bound.contains(parameter) {
    return type_
  }
  let parameter = self.image.fresh_synthetic_parameter()
  bindings.insert(parameter, type_)
  Parameter(parameter)
}

///|
fn FunctionLowerer::adapter_witness(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
  substitutions : @buslane.TypeSubstitution,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if type_substitution_type_argument(substitutions, parameter) is Some(type_) {
    return self.layout_witness(type_)
  }
  self.find_witness(parameter)
}

///|
fn FunctionLowerer::make_callable_adapter(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  if self.image.metadata.types_definitionally_equal(source_type, target_type) {
    return Slot(source, target_type)
  }
  let (source_parameter_targets, adapter_substitutions) = self.image.align_callable_parameters(
    source_type, target_type, substitutions,
  )
  let plan = self.image.callable_adapter(
    source_type, target_type, source_parameter_targets, adapter_substitutions,
  )
  let witnesses = plan.captured_parameters.map(parameter => {
    self.adapter_witness(parameter, adapter_substitutions)
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
/// Align source parameters with target ABI parameters after substitution.
/// Only a target that classifies as Unit may be skipped; every other pair must
/// be definitionally equal. The returned substitution is final: alignment
/// creates it, the adapter plan takes ownership, and subsequent lowering only
/// reads it.
fn ImageLowerer::align_callable_parameters(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> (Array[Int], @buslane.TypeSubstitution) raise LoisvmLoweringError {
  let (source_type_parameters, source_parameters, _) = function_type_parts(
    source_type,
  )
  let (target_type_parameters, target_parameters, _) = function_type_parts(
    target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target type arities differ",
    )
  }
  let alignment = @buslane.TypeSubstitution::TypeSubstitution()
  for index, target_parameter in target_type_parameters {
    alignment.insert(target_parameter, Parameter(source_type_parameters[index]))
  }
  let alignment_substitutions = substitutions.overlay(alignment)
  let source_parameter_targets = []
  let mut source_index = 0
  for target_index, target_parameter in target_parameters {
    let actual_target = apply_type_substitution(
      target_parameter, alignment_substitutions,
    )
    if self.runtime_type(actual_target) is Concrete(Primitive(Unit)) {
      if source_index < source_parameters.length() {
        let actual_source = apply_type_substitution(
          source_parameters[source_index],
          substitutions,
        )
        if self.runtime_type(actual_source) is Concrete(Primitive(Unit)) &&
          self.metadata.types_definitionally_equal(actual_source, actual_target) {
          source_parameter_targets.push(target_index)
          source_index += 1
        }
      }
      continue
    }
    if source_index >= source_parameters.length() {
      raise InvalidTypeApplication(
        detail="callable adapter source parameter \{source_index}/\{source_parameters.length()} does not align with target parameter \{target_index}/\{target_parameters.length()}",
      )
    }
    let actual_source = apply_type_substitution(
      source_parameters[source_index],
      substitutions,
    )
    if !self.metadata.types_definitionally_equal(actual_source, actual_target) {
      raise InvalidTypeApplication(
        detail="callable adapter source parameter \{source_index}/\{source_parameters.length()} does not align with target parameter \{target_index}/\{target_parameters.length()}",
      )
    }
    source_parameter_targets.push(target_index)
    source_index += 1
  }
  if source_index != source_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target parameters cannot be aligned",
    )
  }
  (source_parameter_targets, alignment_substitutions)
}

///|
fn FunctionLowerer::adapt_local_value_with_substitutions(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  let source_type = local_value_type(value).unwrap_or(source_type)
  let source_runtime = self.image.runtime_type(source_type)
  let target_runtime = self.image.runtime_type(target_type)
  match (source_runtime, target_runtime) {
    (Concrete(Primitive(Unit)), Concrete(Primitive(Unit))) => return Unit
    (Erased(_), Erased(_)) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return Slot(slot, target_type)
    }
    (_, Erased(_)) => {
      let witness = self.layout_witness(source_type)
      return Slot(self.erase_value(value, source_type, witness), target_type)
    }
    (Erased(_), _) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return self.unerase_value(slot, target_type)
    }
    _ => ()
  }
  if self.image.metadata.types_definitionally_equal(source_type, target_type) {
    return match value {
      Unit => Unit
      Slot(slot, _) => Slot(slot, target_type)
      _ => value
    }
  }
  match (source_type, target_type) {
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
      let source_metadata = self.image.slot_metadata(source_type)
      let target_metadata = self.image.slot_metadata(target_type)
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
    | Global(FloatConstant(_, type_))
    | Global(DoubleConstant(_, type_))
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
    plan.source_parameter_targets.length() != source_parameter_types.length() {
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
    substitutions: plan.substitutions,
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
    if self.runtime_type(type_) is Concrete(Primitive(Unit)) {
      target_parameters.push(Unit)
    } else {
      let slot = lowerer.fresh_slot(type_)
      user_parameter_slots.push(slot)
      target_parameters.push(Slot(slot, type_))
    }
  }
  let source_arguments = []
  for index, source_parameter_type in source_parameter_types {
    let target_index = plan.source_parameter_targets[index]
    let adapted = lowerer.adapt_local_value_with_substitutions(
      target_parameters[target_index],
      target_parameter_types[target_index],
      source_parameter_type,
      plan.substitutions,
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
  if self.metadata.types_definitionally_equal(
      source_result_type, target_result_type,
    ) {
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
    let result = lowerer.adapt_local_value_with_substitutions(
      source_result.1,
      source_result_type,
      target_result_type,
      plan.substitutions,
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
    result: self.result_representation(target_result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}
