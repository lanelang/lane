///|
fn raw_substitute_specialized_type(
  type_ : @buslane.Type,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Type {
  type_.substitute(effect_specialization_substitution(bindings))
}

///|
fn raw_substitute_specialized_argument(
  argument : @buslane.GenericArgument,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) =>
      TypeArgument(raw_substitute_specialized_type(type_, bindings))
    EffectArgument(effect) =>
      EffectArgument(raw_substitute_specialized_effect(effect, bindings))
  }
}

///|
fn raw_substitute_specialized_effect(
  effect : @buslane.Effect,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Effect {
  effect.substitute(effect_specialization_substitution(bindings))
}

///|
fn effect_specialization_substitution(
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.TypeSubstitution {
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for binding in bindings {
    substitution.insert_argument(binding.parameter, binding.argument)
  }
  substitution
}

///|
fn effect_contains_parameter(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty | Builtin(_) => false
    Parameter(_) => true
    Singleton(_, arguments) =>
      arguments.any(generic_argument_contains_effect_parameter)
    Union(effects) => effects.any(effect_contains_parameter)
  }
}

///|
fn generic_argument_contains_effect_parameter(
  argument : @buslane.GenericArgument,
) -> Bool {
  match argument {
    TypeArgument(type_) => type_contains_effect_parameter(type_)
    EffectArgument(effect) => effect_contains_parameter(effect)
  }
}

///|
fn type_contains_effect_parameter(type_ : @buslane.Type) -> Bool {
  match type_ {
    Primitive(_) | BuiltinConstructor(_) | Parameter(_) | Constructor(_) =>
      false
    Apply(callee, arguments) =>
      type_contains_effect_parameter(callee) ||
      arguments.any(generic_argument_contains_effect_parameter)
    TypeLambda(_, body) | Forall(_, body) =>
      type_contains_effect_parameter(body)
    Function(parameters, result, effect) =>
      parameters.any(type_contains_effect_parameter) ||
      type_contains_effect_parameter(result) ||
      effect_contains_parameter(effect)
  }
}

///|
fn abstract_effect_type_arguments(
  effect : @buslane.Effect,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.Effect raise SpecializationError {
  match effect {
    Empty | Builtin(_) | Parameter(_) => effect
    Singleton(id, effect_arguments) =>
      Singleton(
        id,
        effect_arguments.map(argument => {
          abstract_generic_type_argument(
            argument, parameters, arguments, metadata,
          )
        }),
      )
    Union(effects) =>
      canonicalize_specialization_input_effect(
        metadata,
        Union(
          effects.map(effect => {
            abstract_effect_type_arguments(
              effect, parameters, arguments, metadata,
            )
          }),
        ),
      )
  }
}

///|
fn abstract_generic_type_argument(
  argument : @buslane.GenericArgument,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.GenericArgument raise SpecializationError {
  match argument {
    TypeArgument(type_) =>
      TypeArgument(
        abstract_specialized_type(type_, parameters, arguments, metadata),
      )
    EffectArgument(effect) =>
      EffectArgument(
        abstract_effect_type_arguments(effect, parameters, arguments, metadata),
      )
  }
}

///|
fn abstract_specialized_type(
  type_ : @buslane.Type,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.Type raise SpecializationError {
  for index in 0..<parameters.length() {
    if !type_parameter_is_effect(metadata, parameters[index]) &&
      arguments[index] is TypeArgument(actual) &&
      specialization_types_definitionally_equal(metadata, type_, actual) {
      return Parameter(parameters[index])
    }
  }
  match type_ {
    Primitive(_) | BuiltinConstructor(_) | Parameter(_) | Constructor(_) =>
      type_
    Apply(callee, nested) =>
      Apply(
        abstract_specialized_type(callee, parameters, arguments, metadata),
        nested.map(argument => {
          abstract_generic_type_argument(
            argument, parameters, arguments, metadata,
          )
        }),
      )
    TypeLambda(bound, body) =>
      TypeLambda(
        bound,
        abstract_specialized_type(body, parameters, arguments, metadata),
      )
    Function(inputs, result, effect) =>
      Function(
        inputs.map(input => {
          abstract_specialized_type(input, parameters, arguments, metadata)
        }),
        abstract_specialized_type(result, parameters, arguments, metadata),
        abstract_effect_type_arguments(effect, parameters, arguments, metadata),
      )
    Forall(bound, body) =>
      Forall(
        bound,
        abstract_specialized_type(body, parameters, arguments, metadata),
      )
  }
}
