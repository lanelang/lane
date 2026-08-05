///|
fn FunctionLowerer::lower_call(
  self : FunctionLowerer,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.AnfAtom],
) -> LocalValue raise LoisvmLoweringError {
  let callee = self.lower_atom(callee)
  let lowered_arguments = arguments.map(argument => {
    self.materialize_local(self.lower_atom(argument))
  })
  match callee {
    Global(Intrinsic(intrinsic, type_)) =>
      self.lower_intrinsic(intrinsic, type_, lowered_arguments)
    Global(Function(function, type_)) =>
      self.lower_direct_call(function, type_, lowered_arguments, None)
    RecursiveFunction(function, type_, environment) =>
      self.lower_direct_call(function, type_, lowered_arguments, environment)
    TypeApplied(Function(function, type_), type_arguments) =>
      self.lower_generic_direct_call(
        function, type_, type_arguments, lowered_arguments,
      )
    TypeAppliedCallable(callable, type_, type_arguments) =>
      self.lower_generic_value_call(
        callable, type_, type_arguments, lowered_arguments,
      )
    TypeApplied(_, _) =>
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
    Global(Intrinsic(intrinsic, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(
        ConstFunction(
          destination,
          self.image.intrinsic_wrapper(intrinsic, type_),
        ),
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
    TypeApplied(_, _) | TypeAppliedCallable(_, _, _) =>
      raise InvalidTypeApplication(
        detail="a type-applied callable must be called before materialization",
      )
    _ => value
  }
}

///|
fn FunctionLowerer::lower_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @buslane.Type,
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
    apply_type_substitution(result_type, self.substitutions),
    self.substitutions,
  )
}

///|
fn FunctionLowerer::adapt_call_arguments(
  self : FunctionLowerer,
  arguments : Array[LocalValue],
  parameter_types : Array[@buslane.Type],
  substitutions : @buslane.TypeSubstitution,
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
    let adapted = self.adapt_local_value_with_substitutions(
      argument,
      source_type,
      parameter_types[index],
      substitutions,
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
  type_ : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
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
      let type_ = required_type_substitution_argument(substitutions, parameter)
      witnesses.push(self.runtime_evidence(parameter, type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = apply_type_substitution(formal, substitutions)
    let adapted = self.adapt_local_value_with_substitutions(
      values[index],
      actual,
      formal,
      substitutions,
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = apply_type_substitution(formal_result, substitutions)
  if self.image.runtime_type(formal_result) is Erased(_) {
    let witness = self.layout_witness(actual_result)
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallDirect(function, None, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result)
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
fn FunctionLowerer::lower_generic_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
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
      let type_ = required_type_substitution_argument(substitutions, parameter)
      witnesses.push(self.runtime_evidence(parameter, type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = apply_type_substitution(formal, substitutions)
    let adapted = self.adapt_local_value_with_substitutions(
      values[index],
      actual,
      formal,
      substitutions,
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = apply_type_substitution(formal_result, substitutions)
  if self.image.runtime_type(formal_result) is Erased(_) {
    let witness = self.layout_witness(actual_result)
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallValue(callable, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result)
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
fn apply_type_substitution(
  type_ : @buslane.Type,
  substitution : @buslane.TypeSubstitution,
) -> @buslane.Type raise LoisvmLoweringError {
  type_.try_substitute(substitution) catch {
    error => raise type_substitution_error(error)
  }
}

///|
fn apply_generic_argument_substitution(
  argument : @buslane.GenericArgument,
  substitution : @buslane.TypeSubstitution,
) -> @buslane.GenericArgument raise LoisvmLoweringError {
  argument.try_substitute(substitution) catch {
    error => raise type_substitution_error(error)
  }
}

///|
fn ImageLowerer::data_type_substitutions(
  self : ImageLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.TypeSubstitution raise LoisvmLoweringError {
  let substitutions = self.type_substitution(parameters, arguments)
  let companion_substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  for index, parameter in parameters {
    let argument = arguments[index]
    if argument is EffectArgument(Parameter(actual)) &&
      self.effect_companion(parameter) is Some(formal_companion) &&
      self.effect_companion(actual) is Some(actual_companion) {
      companion_substitutions.insert(
        formal_companion,
        Parameter(actual_companion),
      )
    }
  }
  substitutions.overlay(companion_substitutions)
}

///|
fn FunctionLowerer::data_type_substitutions(
  self : FunctionLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.TypeSubstitution raise LoisvmLoweringError {
  self.image.data_type_substitutions(
    parameters,
    arguments.map(argument => self.substitute_generic_argument(argument)),
  )
}

///|
fn FunctionLowerer::call_type_substitution(
  self : FunctionLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.TypeSubstitution raise LoisvmLoweringError {
  let arguments = arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  let substitutions = self.image.type_substitution(parameters, arguments)
  let companion_substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  for index, parameter in parameters {
    let argument = arguments[index]
    if argument is TypeArgument(Parameter(actual_companion)) &&
      self.image.effect_source(parameter) is Some(formal_source) &&
      self.image.effect_source(actual_companion) is Some(actual_source) {
      companion_substitutions.insert_effect(
        formal_source,
        Parameter(actual_source),
      )
    }
  }
  substitutions.overlay(companion_substitutions)
}

///|
fn FunctionLowerer::substitute_generic_argument(
  self : FunctionLowerer,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise LoisvmLoweringError {
  apply_generic_argument_substitution(argument, self.substitutions)
}

///|
fn ImageLowerer::type_substitution(
  self : ImageLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.TypeSubstitution raise LoisvmLoweringError {
  @buslane.TypeSubstitution::from_arguments(
    self.metadata,
    parameters,
    arguments,
  ) catch {
    error => raise type_substitution_error(error)
  }
}

///|
fn required_type_substitution_argument(
  substitution : @buslane.TypeSubstitution,
  parameter : @buslane.TypeParameterId,
) -> @buslane.Type raise LoisvmLoweringError {
  match type_substitution_type_argument(substitution, parameter) {
    Some(type_) => type_
    None =>
      raise InvalidTypeApplication(
        detail="type substitution does not bind \{Repr(parameter)}",
      )
  }
}

///|
fn type_substitution_type_argument(
  substitution : @buslane.TypeSubstitution,
  parameter : @buslane.TypeParameterId,
) -> @buslane.Type? raise LoisvmLoweringError {
  substitution.type_argument(parameter) catch {
    error => raise type_substitution_error(error)
  }
}

///|
fn type_substitution_error(
  error : @buslane.TypeSubstitutionError,
) -> LoisvmLoweringError {
  let detail = match error {
    ArgumentCountMismatch(expected~, actual~) =>
      "expected \{expected} generic arguments, got \{actual}"
    MissingParameterMetadata(parameter~) =>
      "type substitution metadata is missing for \{Repr(parameter)}"
    ExpectedTypeArgument(parameter~) =>
      "type substitution for \{Repr(parameter)} requires a type argument"
    ExpectedEffectArgument(parameter~) =>
      "type substitution for \{Repr(parameter)} requires an effect argument"
    CapturedTypeParameter(parameter~, binder~) =>
      "type substitution for \{Repr(parameter)} would be captured by \{Repr(binder)}"
  }
  InvalidTypeApplication(detail~)
}

///|
fn ImageLowerer::effect_companion(
  self : ImageLowerer,
  parameter : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId? {
  for binding in self.effect_companions {
    if binding.source == parameter {
      return Some(binding.companion)
    }
  }
  None
}

///|
fn ImageLowerer::effect_source(
  self : ImageLowerer,
  companion : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId? {
  for binding in self.effect_companions {
    if binding.companion == companion {
      return Some(binding.source)
    }
  }
  None
}

///|
fn FunctionLowerer::lower_direct_call(
  self : FunctionLowerer,
  function : @bytecode.FunctionId,
  type_ : @buslane.Type,
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
    apply_type_substitution(result_type, self.substitutions),
    self.substitutions,
  )
}

///|
fn FunctionLowerer::lower_intrinsic(
  self : FunctionLowerer,
  intrinsic : @abi.Intrinsic,
  type_ : @buslane.Type,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let result_type = callable_result_type(type_)
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
fn callable_result_type(
  type_ : @buslane.Type,
) -> @buslane.Type raise LoisvmLoweringError {
  match strip_forall(type_) {
    Function(_, result, _) => result
    _ => raise UnsupportedType(type_~)
  }
}

///|
