///|
fn FunctionLowerer::lower_call(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.AnfAtom],
) -> LocalValue raise LoisvmLoweringError {
  let callee = self.lower_atom(callee)
  let lowered_arguments = arguments.map(argument => {
    self.materialize_local(self.lower_atom(argument))
  })
  if self.image.representation_call_target(self.caller_instances, site)
    is Some((target, plan)) {
    let (_, _, formal_result) = function_type_parts(target.definition.type_)
    let actual_result = target.substitution.apply_type(
      self.image.runtime_types,
      formal_result,
    )
    let deferred = match callee {
      NestedCallable(callable) | EvidenceAppliedNestedCallable(callable, _) =>
        Some(callable)
      _ => None
    }
    if deferred is Some(callable) &&
      callable.function.id == target.definition.function.id {
      guard self.materialize_representation_worker(plan, callable.environment)
        is Slot(worker, _) else {
        abort("representation worker was not materialized")
      }
      return self.lower_representation_specialized_call(
        plan,
        target.substitution,
        actual_result,
        lowered_arguments,
        callable=Some(worker),
      )
    }
    if target.definition.captures.is_empty() {
      return self.lower_representation_specialized_call(
        plan,
        target.substitution,
        actual_result,
        lowered_arguments,
        callable=None,
      )
    }
  }
  match callee {
    Global(Intrinsic(contract)) =>
      self.lower_intrinsic(contract, lowered_arguments)
    Global(Function(function, type_)) =>
      self.lower_direct_call(function, type_, lowered_arguments, None)
    RecursiveFunction(function, type_, environment) =>
      self.lower_direct_call(function, type_, lowered_arguments, environment)
    EvidenceApplied(Function(function, type_), type_arguments) =>
      self.lower_generic_direct_call(
        function, type_, type_arguments, lowered_arguments,
      )
    EvidenceAppliedCallable(callable, type_, type_arguments) =>
      self.lower_generic_value_call(
        callable, type_, type_arguments, lowered_arguments,
      )
    NestedCallable(callable) => {
      guard self.materialize_nested_callable(callable) is Slot(slot, type_) else {
        abort("nested callable was not materialized")
      }
      self.lower_value_call(slot, type_, lowered_arguments)
    }
    EvidenceAppliedNestedCallable(callable, type_arguments) => {
      guard self.materialize_nested_callable(callable) is Slot(slot, type_) else {
        abort("nested callable was not materialized")
      }
      self.lower_generic_value_call(
        slot, type_, type_arguments, lowered_arguments,
      )
    }
    AdaptedCallable(adaptation) =>
      self.lower_adapted_callable_call(adaptation, [], lowered_arguments)
    EvidenceAppliedAdaptedCallable(adaptation, type_arguments) =>
      self.lower_adapted_callable_call(
        adaptation, type_arguments, lowered_arguments,
      )
    EvidenceApplied(_, _) =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic function",
      )
    Slot(callable, type_) =>
      self.lower_value_call(callable, type_, lowered_arguments)
    _ => raise UnsupportedExpression(detail="value is not callable")
  }
}

///|
fn FunctionLowerer::materialize_local(
  self : FunctionLowerer,
  value : LocalValue,
) -> LocalValue raise LoisvmLoweringError {
  match value {
    Global(Function(function, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstFunction(destination, function))
      Slot(destination, type_)
    }
    Global(Intrinsic(contract)) => {
      let type_ = contract.type_()
      let destination = self.fresh_slot(type_)
      self.emit(
        ConstFunction(destination, self.image.intrinsic_wrapper(contract)),
      )
      Slot(destination, type_)
    }
    Global(DoubleConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstF64(destination, bits))
      Slot(destination, type_)
    }
    Global(FloatConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstF32(destination, bits))
      Slot(destination, type_)
    }
    RecursiveFunction(function, type_, environment) => {
      let destination = self.fresh_slot(type_)
      match environment {
        Some(environment) =>
          self.emit(MakeClosure(destination, function, environment))
        None => self.emit(ConstFunction(destination, function))
      }
      Slot(destination, type_)
    }
    NestedCallable(callable) => self.materialize_nested_callable(callable)
    AdaptedCallable(adaptation) => self.materialize_callable_adapter(adaptation)
    EvidenceApplied(_, _)
    | EvidenceAppliedCallable(_, _, _)
    | EvidenceAppliedNestedCallable(_, _) =>
      raise InvalidTypeApplication(
        detail="a type-applied callable must be called before materialization",
      )
    EvidenceAppliedAdaptedCallable(_, _) =>
      raise InvalidTypeApplication(
        detail="a type-applied callable must be called before materialization",
      )
    _ => value
  }
}

///|
fn FunctionLowerer::lower_adapted_callable_call(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
  type_arguments : Array[@anf.RuntimeArgument],
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let witness_count = self.witnesses.length()
  self.witnesses.append(adaptation.captured_witnesses)
  let contract = adaptation.contract
  let (source_type_parameters, source_parameter_types, source_result_type) = function_type_parts(
    contract.source_type,
  )
  let (target_type_parameters, target_parameter_types, target_result_type) = function_type_parts(
    contract.target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() ||
    type_arguments.length() != target_type_parameters.length() ||
    arguments.length() != target_parameter_types.length() ||
    contract.source_parameter_targets.length() !=
    source_parameter_types.length() {
    raise InvalidTypeApplication(
      detail="adapted callable invocation does not match its function type",
    )
  }
  let substituted_arguments = type_arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  let target_substitutions = RuntimeSubstitution::from_arguments(
    target_type_parameters, substituted_arguments,
  )
  let source_substitutions = RuntimeSubstitution::from_arguments(
    source_type_parameters, substituted_arguments,
  )
  let substitutions = contract.substitutions
    .overlay(target_substitutions)
    .overlay(source_substitutions)
  let source_arguments = []
  for index, source_parameter_type in source_parameter_types {
    let target_index = contract.source_parameter_targets[index]
    let target_parameter_type = target_parameter_types[target_index]
    let adapted = self.adapt_local_value_with_substitutions(
      arguments[target_index],
      substitutions.apply_type(self.image.runtime_types, target_parameter_type),
      source_parameter_type,
      substitutions,
    )
    match self.materialize_local(adapted) {
      Unit => ()
      Slot(slot, _) => source_arguments.push(slot)
      _ =>
        raise UnsupportedExpression(
          detail="adapted callable argument is not materialized",
        )
    }
  }
  let witnesses = []
  for parameter in source_type_parameters {
    if self.image.requires_runtime_evidence(parameter) {
      witnesses.push(
        self.runtime_evidence(
          parameter,
          required_runtime_argument(substitutions, parameter.id),
        ),
      )
    }
  }
  let actual_source_result = substitutions.apply_type(
    self.image.runtime_types,
    source_result_type,
  )
  let source_result = if self.image.runtime_type(source_result_type)
    is Erased(_) {
    let witness = self.layout_witness(
      runtime_type_evidence(actual_source_result),
    )
    let slot = self.fresh_erased_slot(witness, Owned)
    (Some(slot), LocalValue::Slot(slot, source_result_type))
  } else {
    self.fresh_optional_slot(source_result_type)
  }
  self.emit(
    CallValue(adaptation.source, witnesses, source_arguments, source_result.0),
  )
  let result = self.adapt_local_value_with_substitutions(
    source_result.1,
    source_result_type,
    substitutions.apply_type(self.image.runtime_types, target_result_type),
    substitutions,
  )
  self.restore_witnesses(witness_count)
  result
}

///|
fn FunctionLowerer::lower_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @anf.RuntimeType,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, parameter_types, result_type) = function_type_parts(type_)
  if !parameters.is_empty() || parameter_types.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="value call arguments do not match its function type",
    )
  }
  let argument_slots = self.adapt_call_arguments(
    arguments,
    parameter_types,
    self.substitutions,
  )
  let destination = self.fresh_optional_slot(result_type)
  self.emit(CallValue(callable, [], argument_slots, destination.0))
  self.adapt_local_value_with_substitutions(
    destination.1,
    result_type,
    self.substitutions.apply_type(self.image.runtime_types, result_type),
    self.substitutions,
  )
}

///|
fn FunctionLowerer::adapt_call_arguments(
  self : FunctionLowerer,
  arguments : Array[LocalValue],
  parameter_types : Array[@anf.RuntimeType],
  substitutions : RuntimeSubstitution,
) -> Array[@vmcfg.ValueId] raise LoisvmLoweringError {
  if parameter_types.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="call arguments do not match its function type",
    )
  }
  let argument_slots = []
  for index, argument in arguments {
    let source_type = local_value_type(argument).unwrap_or(
      parameter_types[index],
    )
    let adapted = self.materialize_local(
      self.adapt_local_value_with_substitutions(
        argument,
        source_type,
        parameter_types[index],
        substitutions,
      ),
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  argument_slots
}

///|
fn FunctionLowerer::lower_generic_direct_call(
  self : FunctionLowerer,
  function : @bytecode.FunctionId,
  type_ : @anf.RuntimeType,
  arguments : Array[@anf.RuntimeArgument],
  values : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, formal_parameters, formal_result) = function_type_parts(
    type_,
  )
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let arguments = arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  let substitutions = self.image.call_type_substitution(parameters, arguments)
  let witnesses = []
  for parameter in parameters {
    if self.image.requires_runtime_evidence(parameter) {
      let argument = required_runtime_argument(substitutions, parameter.id)
      witnesses.push(self.runtime_evidence(parameter, argument))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitutions.apply_type(self.image.runtime_types, formal)
    let adapted = self.materialize_local(
      self.adapt_local_value_with_substitutions(
        values[index],
        actual,
        formal,
        substitutions,
      ),
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = substitutions.apply_type(
    self.image.runtime_types,
    formal_result,
  )
  if self.image.runtime_type(formal_result) is Erased(_) {
    let witness = self.layout_witness(runtime_type_evidence(actual_result))
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallDirect(function, None, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result, substitutions)
  } else {
    let destination = self.fresh_optional_slot(formal_result)
    self.emit(
      CallDirect(function, None, witnesses, argument_slots, destination.0),
    )
    self.adapt_local_value_with_substitutions(
      destination.1,
      formal_result,
      actual_result,
      substitutions,
    )
  }
}

///|
fn FunctionLowerer::lower_representation_specialized_call(
  self : FunctionLowerer,
  plan : RepresentationSpecializationPlan,
  substitutions : RuntimeSubstitution,
  actual_result : @anf.RuntimeType,
  values : Array[LocalValue],
  callable~ : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  if values.length() != plan.parameter_types.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized call arguments do not match its worker",
    )
  }
  let witnesses = []
  for parameter in plan.retained_parameters {
    if self.image.requires_runtime_evidence(parameter) {
      guard self.image.metadata.parameter_type_expression(parameter.id)
        is Some(type_expression) else {
        raise RepresentationSpecializationInvariant(
          detail="retained worker parameter lacks a type expression",
        )
      }
      witnesses.push(
        self.runtime_evidence(parameter, {
          type_expression,
          evidence: Parameter(parameter.id),
        }),
      )
    }
  }
  let arguments = []
  for index, formal in plan.parameter_types {
    let actual = substitutions.apply_type(self.image.runtime_types, formal)
    let adapted = self.materialize_local(
      self.adapt_local_value_with_substitutions(
        values[index],
        actual,
        formal,
        substitutions,
      ),
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => arguments.push(slot)
      _ =>
        raise RepresentationSpecializationInvariant(
          detail="representation-specialized argument is not materialized",
        )
    }
  }
  let worker_result = self.fresh_optional_slot(plan.result_type)
  match callable {
    Some(callable) =>
      self.emit(CallValue(callable, witnesses, arguments, worker_result.0))
    None =>
      self.emit(
        CallDirect(plan.worker, None, witnesses, arguments, worker_result.0),
      )
  }
  self.adapt_local_value_with_substitutions(
    worker_result.1,
    plan.result_type,
    actual_result,
    substitutions,
  )
}

///|
fn FunctionLowerer::lower_generic_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @anf.RuntimeType,
  arguments : Array[@anf.RuntimeArgument],
  values : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, formal_parameters, formal_result) = function_type_parts(
    type_,
  )
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let substitutions = self.call_type_substitution(parameters, arguments)
  let witnesses = []
  for parameter in parameters {
    if self.image.requires_runtime_evidence(parameter) {
      let argument = required_runtime_argument(substitutions, parameter.id)
      witnesses.push(self.runtime_evidence(parameter, argument))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitutions.apply_type(self.image.runtime_types, formal)
    let adapted = self.materialize_local(
      self.adapt_local_value_with_substitutions(
        values[index],
        actual,
        formal,
        substitutions,
      ),
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = substitutions.apply_type(
    self.image.runtime_types,
    formal_result,
  )
  if self.image.runtime_type(formal_result) is Erased(_) {
    let witness = self.layout_witness(runtime_type_evidence(actual_result))
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallValue(callable, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result, substitutions)
  } else {
    let destination = self.fresh_optional_slot(formal_result)
    self.emit(CallValue(callable, witnesses, argument_slots, destination.0))
    self.adapt_local_value_with_substitutions(
      destination.1,
      formal_result,
      actual_result,
      substitutions,
    )
  }
}

///|

///|
fn FunctionLowerer::call_type_substitution(
  self : FunctionLowerer,
  parameters : Array[@anf.RuntimeEvidenceParameter],
  arguments : Array[@anf.RuntimeArgument],
) -> RuntimeSubstitution raise LoisvmLoweringError {
  let arguments = arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  self.substitutions.overlay(
    RuntimeSubstitution::from_arguments(parameters, arguments),
  )
}

///|
fn ImageLowerer::call_type_substitution(
  _self : ImageLowerer,
  parameters : Array[@anf.RuntimeEvidenceParameter],
  arguments : Array[@anf.RuntimeArgument],
) -> RuntimeSubstitution raise LoisvmLoweringError {
  RuntimeSubstitution::from_arguments(parameters, arguments)
}

///|
fn FunctionLowerer::substitute_generic_argument(
  self : FunctionLowerer,
  argument : @anf.RuntimeArgument,
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  self.substitutions.apply_argument(self.image.runtime_types, argument)
}

///|
fn required_runtime_argument(
  substitution : RuntimeSubstitution,
  parameter : @anf.RuntimeEvidenceId,
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  match substitution.argument(parameter) {
    Some(argument) => argument
    None =>
      raise InvalidTypeApplication(
        detail="type substitution does not bind \{Repr(parameter)}",
      )
  }
}

///|
fn FunctionLowerer::lower_direct_call(
  self : FunctionLowerer,
  function : @bytecode.FunctionId,
  type_ : @anf.RuntimeType,
  arguments : Array[LocalValue],
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, parameter_types, result_type) = function_type_parts(type_)
  if !parameters.is_empty() {
    raise InvalidTypeApplication(
      detail="direct call requires explicit generic arguments",
    )
  }
  let argument_slots = self.adapt_call_arguments(
    arguments,
    parameter_types,
    self.substitutions,
  )
  let destination = self.fresh_optional_slot(result_type)
  self.emit(
    CallDirect(function, environment, [], argument_slots, destination.0),
  )
  self.adapt_local_value_with_substitutions(
    destination.1,
    result_type,
    self.substitutions.apply_type(self.image.runtime_types, result_type),
    self.substitutions,
  )
}

///|
fn FunctionLowerer::lower_intrinsic(
  self : FunctionLowerer,
  contract : RuntimeIntrinsicFunctionContract,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let intrinsic = contract.intrinsic
  let result_type = contract.result
  match (intrinsic, arguments) {
    (CharToI32 | I32ToChar | StringToBytes | BytesToString, [Slot(source, _)]) =>
      return Slot(source, result_type)
    _ => ()
  }
  match intrinsic {
    BytesMake
    | BytesLength
    | BytesGet
    | BytesSet
    | BytesEqual
    | BytesConcat
    | BytesSlice
    | BytesIsValidUtf8
    | F32ToString
    | F64ToString => ignore(self.image.intern_layout(ByteSequence))
    _ => ()
  }
  let slots = arguments.map(fn(argument) {
    match argument {
      Slot(slot, _) => slot
      _ => abort("intrinsic argument is not represented by a slot")
    }
  })
  let destination = self.fresh_slot(result_type)
  let instruction : @vmcfg.Instruction = match (intrinsic, slots) {
    (I64Add, [left, right]) => I64Add(destination, left, right)
    (I64Sub, [left, right]) => I64Sub(destination, left, right)
    (I64Mul, [left, right]) => I64Mul(destination, left, right)
    (I64Div, [left, right]) => I64Div(destination, left, right)
    (I64Rem, [left, right]) => I64Rem(destination, left, right)
    (I64Neg, [source]) => I64Neg(destination, source)
    (I64Equal, [left, right]) => I64Eq(destination, left, right)
    (I64Less, [left, right]) => I64Lt(destination, left, right)
    (I32Add, [left, right]) => I32Add(destination, left, right)
    (I32Sub, [left, right]) => I32Sub(destination, left, right)
    (I32Mul, [left, right]) => I32Mul(destination, left, right)
    (I32Div, [left, right]) => I32Div(destination, left, right)
    (I32Rem, [left, right]) => I32Rem(destination, left, right)
    (I32Neg, [source]) => I32Neg(destination, source)
    (I32Equal, [left, right]) => I32Eq(destination, left, right)
    (I32Less, [left, right]) => I32Lt(destination, left, right)
    (I32ToI64, [source]) => I32ToI64(destination, source)
    (I64ToI32, [source]) => I64ToI32(destination, source)
    (F32Add, [left, right]) => F32Add(destination, left, right)
    (F32Sub, [left, right]) => F32Sub(destination, left, right)
    (F32Mul, [left, right]) => F32Mul(destination, left, right)
    (F32Div, [left, right]) => F32Div(destination, left, right)
    (F32Neg, [source]) => F32Neg(destination, source)
    (F32Equal, [left, right]) => F32Eq(destination, left, right)
    (F32Less, [left, right]) => F32Lt(destination, left, right)
    (I64ToF32, [source]) => I64ToF32(destination, source)
    (F32ToI64, [source]) => F32ToI64(destination, source)
    (F32ToF64, [source]) => F32ToF64(destination, source)
    (F64ToF32, [source]) => F64ToF32(destination, source)
    (F32ToString, [source]) => F32ToString(destination, source)
    (F64ToString, [source]) => F64ToString(destination, source)
    (I64ToF64, [source]) => I64ToF64(destination, source)
    (F64ToI64, [source]) => F64ToI64(destination, source)
    (F64Add, [left, right]) => F64Add(destination, left, right)
    (F64Sub, [left, right]) => F64Sub(destination, left, right)
    (F64Mul, [left, right]) => F64Mul(destination, left, right)
    (F64Div, [left, right]) => F64Div(destination, left, right)
    (F64Neg, [source]) => F64Neg(destination, source)
    (F64Equal, [left, right]) => F64Eq(destination, left, right)
    (F64Less, [left, right]) => F64Lt(destination, left, right)
    (ByteToI64, [source]) => ByteToI64(destination, source)
    (I64ToByte, [source]) => I64ToByte(destination, source)
    (BytesMake, [length, fill]) => ByteSequenceMake(destination, length, fill)
    (BytesLength, [source]) => ByteSequenceLength(destination, source)
    (BytesGet, [source, index]) => ByteSequenceGet(destination, source, index)
    (BytesSet, [source, index, value]) =>
      ByteSequenceSet(destination, source, index, value)
    (BytesEqual, [left, right]) => ByteSequenceEqual(destination, left, right)
    (BytesConcat, [left, right]) => ByteSequenceConcat(destination, left, right)
    (BytesSlice, [source, start, length]) =>
      ByteSequenceSlice(destination, source, start, length)
    (BytesIsValidUtf8, [source]) => ByteSequenceIsValidUtf8(destination, source)
    _ => raise UnsupportedIntrinsic(name=intrinsic.name())
  }
  self.emit(instruction)
  Slot(destination, result_type)
}

///|
