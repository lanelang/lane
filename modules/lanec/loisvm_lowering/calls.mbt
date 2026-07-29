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
      self.emit(ConstDouble(destination, bits))
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
  let result_type = callable_result_type(type_)
  let argument_slots = []
  for argument in arguments {
    match argument {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let destination = self.fresh_optional_slot(result_type)
  self.emit(CallValue(callable, [], argument_slots, destination.0))
  destination.1
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
    if self.image.requires_layout_witness(parameter) {
      let type_ = required_type_substitution_argument(substitutions, parameter)
      witnesses.push(self.layout_witness(type_))
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
  if formal_result is Parameter(parameter) {
    let witness = self.adapter_witness(parameter, substitutions)
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
    if self.image.requires_layout_witness(parameter) {
      let type_ = required_type_substitution_argument(substitutions, parameter)
      witnesses.push(self.layout_witness(type_))
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
  if formal_result is Parameter(parameter) {
    let witness = self.adapter_witness(parameter, substitutions)
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
fn type_substitution_effect_argument(
  substitution : @buslane.TypeSubstitution,
  parameter : @buslane.TypeParameterId,
) -> @buslane.Effect? raise LoisvmLoweringError {
  substitution.effect_argument(parameter) catch {
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
  let result_type = callable_result_type(type_)
  let argument_slots = []
  for argument in arguments {
    match argument {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let destination = self.fresh_optional_slot(result_type)
  self.emit(
    CallDirect(function, environment, [], argument_slots, destination.0),
  )
  destination.1
}

///|
fn FunctionLowerer::lower_intrinsic(
  self : FunctionLowerer,
  intrinsic : @abi.Intrinsic,
  type_ : @buslane.Type,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let result_type = callable_result_type(type_)
  let slots = arguments.map(fn(argument) {
    match argument {
      Slot(slot, _) => slot
      _ => abort("intrinsic argument is not represented by a slot")
    }
  })
  let destination = self.fresh_slot(result_type)
  let instruction : @vmcfg.Instruction = match (intrinsic, slots) {
    (I64Add, [left, right]) => IntAdd(destination, left, right)
    (I64Sub, [left, right]) => IntSub(destination, left, right)
    (I64Mul, [left, right]) => IntMul(destination, left, right)
    (I64Div, [left, right]) => IntDiv(destination, left, right)
    (I64Rem, [left, right]) => IntRem(destination, left, right)
    (I64Neg, [source]) => IntNeg(destination, source)
    (I64Equal, [left, right]) => IntEq(destination, left, right)
    (I64Less, [left, right]) => IntLt(destination, left, right)
    (F64Add, [left, right]) => DoubleAdd(destination, left, right)
    (F64Sub, [left, right]) => DoubleSub(destination, left, right)
    (F64Mul, [left, right]) => DoubleMul(destination, left, right)
    (F64Div, [left, right]) => DoubleDiv(destination, left, right)
    (F64Neg, [source]) => DoubleNeg(destination, source)
    (F64Equal, [left, right]) => DoubleEq(destination, left, right)
    (F64Less, [left, right]) => DoubleLt(destination, left, right)
    (StringEqual, [left, right]) => StringEq(destination, left, right)
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
