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
    Global(Intrinsic(name, type_)) =>
      self.lower_intrinsic(name, type_, lowered_arguments)
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
    Global(Intrinsic(name, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(
        ConstFunction(destination, self.image.intrinsic_wrapper(name, type_)),
      )
      Slot(destination, type_)
    }
    Global(DoubleConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstDouble(destination, bits))
      Slot(destination, type_)
    }
    Global(ScalarExternal(function, type_)) => {
      let destination = self.fresh_optional_slot(type_)
      self.emit(CallDirect(function, None, [], [], destination.0))
      destination.1
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
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="expected \{parameters.length()} generic arguments, got \{arguments.length()}",
    )
  }
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let substitutions : Array[TypeArgumentBinding] = []
  for index, parameter in parameters {
    let argument = self.substitute_generic_argument(arguments[index])
    self.append_type_application_substitution(
      substitutions, parameter, argument,
    )
  }
  let witnesses = []
  for substitution in substitutions {
    if self.image.requires_layout_witness(substitution.parameter) {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="runtime layout witnesses require type arguments",
        )
      }
      witnesses.push(self.layout_witness(type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitute_type(formal, substitutions)
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
  let actual_result = substitute_type(formal_result, substitutions)
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
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="expected \{parameters.length()} generic arguments, got \{arguments.length()}",
    )
  }
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let substitutions : Array[TypeArgumentBinding] = []
  for index, parameter in parameters {
    let argument = self.substitute_generic_argument(arguments[index])
    self.append_type_application_substitution(
      substitutions, parameter, argument,
    )
  }
  let witnesses = []
  for substitution in substitutions {
    if self.image.requires_layout_witness(substitution.parameter) {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="runtime layout witnesses require type arguments",
        )
      }
      witnesses.push(self.layout_witness(type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitute_type(formal, substitutions)
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
  let actual_result = substitute_type(formal_result, substitutions)
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
fn substitute_type(
  type_ : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> @buslane.Type raise LoisvmLoweringError {
  match type_ {
    Parameter(parameter) => {
      for substitution in substitutions.rev_iter() {
        if substitution.parameter == parameter {
          guard substitution.argument is TypeArgument(type_) else {
            raise InvalidTypeApplication(
              detail="an effect argument cannot substitute a value type",
            )
          }
          return substitute_type(
            type_,
            substitutions.filter(binding => binding.parameter != parameter),
          )
        }
      }
      type_
    }
    Apply(applied_constructor, arguments) =>
      Apply(
        substitute_type(applied_constructor, substitutions),
        arguments.map(argument => {
          match argument {
            TypeArgument(type_) =>
              TypeArgument(substitute_type(type_, substitutions))
            EffectArgument(effect) =>
              EffectArgument(substitute_effect(effect, substitutions))
          }
        }),
      )
    Function(parameters, result, effect) =>
      Function(
        parameters.map(type_ => substitute_type(type_, substitutions)),
        substitute_type(result, substitutions),
        effect,
      )
    TypeLambda(parameters, body) => {
      let nested_substitutions = substitutions.filter(substitution => {
        !parameters.contains(substitution.parameter)
      })
      TypeLambda(parameters, substitute_type(body, nested_substitutions))
    }
    Forall(parameters, body) => {
      let nested_substitutions = substitutions.filter(substitution => {
        !parameters.contains(substitution.parameter)
      })
      Forall(parameters, substitute_type(body, nested_substitutions))
    }
    _ => type_
  }
}

///|
fn substitute_effect(
  effect : @buslane.Effect,
  substitutions : Array[TypeArgumentBinding],
) -> @buslane.Effect raise LoisvmLoweringError {
  match effect {
    Io => Io
    Parameter(parameter) => {
      for substitution in substitutions.rev_iter() {
        if substitution.parameter == parameter {
          guard substitution.argument is EffectArgument(effect) else {
            raise InvalidTypeApplication(
              detail="a type argument cannot substitute an effect",
            )
          }
          return effect
        }
      }
      effect
    }
    Singleton(effect_id, arguments) =>
      Singleton(
        effect_id,
        arguments.map(argument => {
          match argument {
            TypeArgument(type_) =>
              TypeArgument(substitute_type(type_, substitutions))
            EffectArgument(effect) =>
              EffectArgument(substitute_effect(effect, substitutions))
          }
        }),
      )
    Union(effects) =>
      Union(effects.map(effect => substitute_effect(effect, substitutions)))
    Empty => Empty
  }
}

///|
fn ImageLowerer::data_type_substitutions(
  self : ImageLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[TypeArgumentBinding] raise LoisvmLoweringError {
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="data type expects \{parameters.length()} arguments, got \{arguments.length()}",
    )
  }
  let substitutions = []
  for index, parameter in parameters {
    let argument = arguments[index]
    substitutions.push({ parameter, argument })
    if argument is EffectArgument(Parameter(actual)) &&
      self.effect_companion(parameter) is Some(formal_companion) &&
      self.effect_companion(actual) is Some(actual_companion) {
      substitutions.push({
        parameter: formal_companion,
        argument: TypeArgument(Parameter(actual_companion)),
      })
    }
  }
  substitutions
}

///|
fn FunctionLowerer::data_type_substitutions(
  self : FunctionLowerer,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[TypeArgumentBinding] raise LoisvmLoweringError {
  self.image.data_type_substitutions(
    parameters,
    arguments.map(argument => self.substitute_generic_argument(argument)),
  )
}

///|
fn FunctionLowerer::append_type_application_substitution(
  self : FunctionLowerer,
  substitutions : Array[TypeArgumentBinding],
  parameter : @buslane.TypeParameterId,
  argument : @buslane.GenericArgument,
) -> Unit {
  substitutions.push({ parameter, argument })
  if argument is TypeArgument(Parameter(actual_companion)) &&
    self.image.effect_source(parameter) is Some(formal_source) &&
    self.image.effect_source(actual_companion) is Some(actual_source) {
    substitutions.push({
      parameter: formal_source,
      argument: EffectArgument(Parameter(actual_source)),
    })
  }
}

///|
fn FunctionLowerer::substitute_generic_argument(
  self : FunctionLowerer,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise LoisvmLoweringError {
  match argument {
    TypeArgument(type_) =>
      TypeArgument(substitute_type(type_, self.substitutions))
    EffectArgument(effect) =>
      EffectArgument(substitute_effect(effect, self.substitutions))
  }
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
  name : String,
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
  let instruction : @vmcfg.Instruction = match (name, slots) {
    ("%i64_add", [left, right]) => IntAdd(destination, left, right)
    ("%i64_sub", [left, right]) => IntSub(destination, left, right)
    ("%i64_mul", [left, right]) => IntMul(destination, left, right)
    ("%i64_div", [left, right]) => IntDiv(destination, left, right)
    ("%i64_rem", [left, right]) => IntRem(destination, left, right)
    ("%i64_neg", [source]) => IntNeg(destination, source)
    ("%i64_equal", [left, right]) => IntEq(destination, left, right)
    ("%i64_less", [left, right]) => IntLt(destination, left, right)
    ("%f64_add", [left, right]) => DoubleAdd(destination, left, right)
    ("%f64_sub", [left, right]) => DoubleSub(destination, left, right)
    ("%f64_mul", [left, right]) => DoubleMul(destination, left, right)
    ("%f64_div", [left, right]) => DoubleDiv(destination, left, right)
    ("%f64_neg", [source]) => DoubleNeg(destination, source)
    ("%f64_equal", [left, right]) => DoubleEq(destination, left, right)
    ("%f64_less", [left, right]) => DoubleLt(destination, left, right)
    ("%string_equal", [left, right]) => StringEq(destination, left, right)
    _ => raise UnsupportedIntrinsic(name~)
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
