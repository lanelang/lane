///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  source_parameter_targets : Array[Int],
  substitutions : @buslane.TypeSubstitution,
) -> CallableAdapterPlan raise LoisvmLoweringError {
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
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in captured_parameters {
    let metadata = self.runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  members.push({
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    witness_ordinal: None,
  })
  let environment_shape = self.intern_object_shape(
    Environment({ stored_witness_count: 0, members }),
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
        (parameter.index < 0 || image.requires_runtime_evidence(parameter)) {
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
) -> @buslane.Type raise LoisvmLoweringError {
  if self.image.runtime_type(type_) is Concrete(Primitive(Unit)) {
    return type_
  }
  if self.image.runtime_type(type_) is Erased(Parameter(parameter)) &&
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
    return self.runtime_evidence(parameter, type_)
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
  if self.image.types_definitionally_equal(source_type, target_type) {
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
  let environment = self.fresh_metadata(
    environment_metadata(plan.environment_shape),
  )
  let environment_layout = self.image.intern_layout(
    Environment(plan.environment_shape),
  )
  self.emit(
    MakeEnv(
      environment,
      plan.environment_shape,
      Immediate(environment_layout),
      [],
      witnesses + [source],
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
          self.types_definitionally_equal(actual_source, actual_target) {
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
    if !self.types_definitionally_equal(actual_source, actual_target) {
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
  if value is Never {
    return Never
  }
  let source_value_type = match local_value_type(value) {
    Some(type_) => type_
    None => source_type
  }
  let source_shape = apply_type_substitution(source_value_type, substitutions)
  let target_shape = apply_type_substitution(target_type, substitutions)
  let source_runtime = self.image.runtime_type(source_type)
  let target_runtime = self.image.runtime_type(target_type)
  let source_is_erased = match value {
    Slot(slot, _) => self.values[slot.value].erased_companion is Some(_)
    _ => source_runtime is Erased(_)
  }
  match (source_is_erased, target_runtime is Erased(_)) {
    (true, true) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return Slot(slot, target_type)
    }
    (false, true) => {
      let witness = self.layout_witness(source_shape)
      return Slot(self.erase_value(value, source_shape, witness), target_type)
    }
    (true, false) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return self.unerase_value(slot, target_shape)
    }
    _ => ()
  }
  if self.image.runtime_type(source_shape) is Concrete(Primitive(Unit)) &&
    self.image.runtime_type(target_shape) is Concrete(Primitive(Unit)) {
    return Unit
  }
  guard self.image.runtime_type(source_shape) is Concrete(source_runtime_type) &&
    self.image.runtime_type(target_shape) is Concrete(target_runtime_type) else {
    raise InvalidTypeApplication(
      detail="value adaptation reached an unresolved erased representation",
    )
  }
  match (source_runtime_type, target_runtime_type) {
    (Function(_, _, _) | Forall(_, _), Function(_, _, _) | Forall(_, _)) => {
      let source_callable_type = match
        self.image.runtime_type(source_value_type) {
        Concrete(Function(_, _, _) | Forall(_, _) as type_) => type_
        _ => source_runtime_type
      }
      let target_callable_type = match self.image.runtime_type(target_type) {
        Concrete(Function(_, _, _) | Forall(_, _) as type_) => type_
        _ => target_runtime_type
      }
      if self.image.types_definitionally_equal(source_shape, target_shape) &&
        self.image.callable_types_share_runtime_abi(
          source_callable_type, target_callable_type, substitutions,
        ) {
        return match value {
          Slot(slot, _) => Slot(slot, target_shape)
          _ => value
        }
      }
      guard self.materialize_local(value) is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="callable value is not materialized",
        )
      }
      guard self.make_callable_adapter(
          source, source_callable_type, target_callable_type, substitutions,
        )
        is Slot(adapter, _) else {
        raise InvalidTypeApplication(
          detail="callable adapter is not materialized",
        )
      }
      Slot(adapter, target_callable_type)
    }
    _ => {
      if self.image.types_definitionally_equal(source_shape, target_shape) {
        return match value {
          Unit => Unit
          Slot(slot, _) => Slot(slot, target_shape)
          _ => value
        }
      }
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="adapted value is not materialized")
      }
      let source_metadata = self.image.slot_metadata(source_runtime_type)
      let target_metadata = self.image.slot_metadata(target_runtime_type)
      if source_metadata.representation != target_metadata.representation ||
        source_metadata.cleanup != target_metadata.cleanup {
        raise InvalidTypeApplication(
          detail="callable adapter cannot bridge incompatible value representations",
        )
      }
      Slot(slot, target_runtime_type)
    }
  }
}

///|
priv struct RuntimeValueAbi {
  representation : @bytecode.Representation
  cleanup : @bytecode.Cleanup
} derive(Eq)

///|
fn ImageLowerer::runtime_value_abi(
  self : ImageLowerer,
  type_ : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> RuntimeValueAbi? raise LoisvmLoweringError {
  match self.runtime_type(type_) {
    Erased(_) => Some({ representation: I64, cleanup: OwnedErased })
    Concrete(_) => {
      let type_ = apply_type_substitution(type_, substitutions)
      match self.runtime_type(type_) {
        Erased(_) => Some({ representation: I64, cleanup: OwnedErased })
        Concrete(Primitive(Unit)) => None
        Concrete(type_) => {
          let metadata = self.slot_metadata(type_)
          Some({
            representation: metadata.representation,
            cleanup: metadata.cleanup,
          })
        }
      }
    }
  }
}

///|
fn ImageLowerer::callable_types_share_runtime_abi(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> Bool raise LoisvmLoweringError {
  let (source_type_parameters, source_parameters, source_result) = function_type_parts(
    source_type,
  )
  let (target_type_parameters, target_parameters, target_result) = function_type_parts(
    target_type,
  )
  let source_witnesses : Array[@bytecode.ValueAbi] = []
  for parameter in source_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = self.runtime_evidence_metadata(parameter)
      source_witnesses.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      })
    }
  }
  let target_witnesses : Array[@bytecode.ValueAbi] = []
  for parameter in target_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = self.runtime_evidence_metadata(parameter)
      target_witnesses.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      })
    }
  }
  if source_witnesses != target_witnesses ||
    source_parameters.length() != target_parameters.length() {
    return false
  }
  for index in 0..<source_parameters.length() {
    if !self.runtime_values_share_abi(
        source_parameters[index],
        target_parameters[index],
        substitutions,
      ) {
      return false
    }
  }
  self.runtime_values_share_abi(source_result, target_result, substitutions)
}

///|
fn ImageLowerer::runtime_values_share_abi(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> Bool raise LoisvmLoweringError {
  match (self.runtime_type(source_type), self.runtime_type(target_type)) {
    (Erased(_), Erased(_)) => true
    (Erased(_), _) | (_, Erased(_)) => false
    (
      Concrete(Function(_, _, _) | Forall(_, _) as source_type),
      Concrete(Function(_, _, _) | Forall(_, _) as target_type),
    ) =>
      self.callable_types_share_runtime_abi(
        source_type, target_type, substitutions,
      )
    (Concrete(Function(_, _, _) | Forall(_, _)), Concrete(_))
    | (Concrete(_), Concrete(Function(_, _, _) | Forall(_, _))) => {
      let source_type = apply_type_substitution(source_type, substitutions)
      let target_type = apply_type_substitution(target_type, substitutions)
      guard self.runtime_type(source_type)
        is Concrete(Function(_, _, _) | Forall(_, _) as source_type) &&
        self.runtime_type(target_type)
        is Concrete(Function(_, _, _) | Forall(_, _) as target_type) else {
        return false
      }
      self.callable_types_share_runtime_abi(
        source_type, target_type, substitutions,
      )
    }
    (Concrete(_), Concrete(_)) =>
      self.runtime_value_abi(source_type, substitutions) ==
      self.runtime_value_abi(target_type, substitutions)
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
    Global(UnitValue) | Never | Unit | TypeApplied(_, _) => None
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
    if self.requires_runtime_evidence(parameter) {
      let witness = lowerer.fresh_metadata(
        self.runtime_evidence_metadata(parameter),
      )
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter, value: witness })
      let source_parameter = source_type_parameters[index]
      if source_parameter != parameter {
        lowerer.witnesses.push({ parameter: source_parameter, value: witness })
      }
    }
  }
  let environment = lowerer.fresh_metadata(
    environment_metadata(plan.environment_shape),
  )
  lowerer.environment = Some(environment)
  for index, parameter in plan.captured_parameters {
    let metadata = self.runtime_evidence_metadata(parameter)
    let witness = lowerer.fresh_metadata(borrowed_evidence_metadata(metadata))
    lowerer.emit(
      BorrowCapture(plan.environment_shape, environment, index, {
        value_destination: witness,
        witness_destination: None,
      }),
    )
    lowerer.witnesses.push({ parameter, value: witness })
  }
  let source_callable = lowerer.fresh_borrowed_slot(plan.source_type)
  lowerer.emit(
    BorrowCapture(
      plan.environment_shape,
      environment,
      plan.captured_parameters.length(),
      { value_destination: source_callable, witness_destination: None },
    ),
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
    if self.requires_runtime_evidence(parameter) {
      call_witnesses.push(lowerer.find_witness(parameter))
    }
  }
  if self.result_abi(source_result_type) is Never {
    lowerer.terminate(
      CallNeverValue(source_callable, call_witnesses, source_arguments),
    )
  } else if self.types_definitionally_equal(
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
        Never => abort("returning adapter call produced no result")
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
    result: self.result_abi(target_result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}
