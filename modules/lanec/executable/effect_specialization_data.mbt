///|
fn EffectSpecializer::specialize_type(
  self : EffectSpecializer,
  type_ : @buslane.Type,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Type raise ExecutableElaborationError {
  self.specialize_substituted_type(
    raw_substitute_specialized_type(type_, bindings),
  )
}

///|
fn EffectSpecializer::specialize_substituted_type(
  self : EffectSpecializer,
  type_ : @buslane.Type,
) -> @buslane.Type raise ExecutableElaborationError {
  match type_ {
    Primitive(_) | Parameter(_) => type_
    Constructor(id) => {
      guard self.program.metadata.type_info(id) is Some(info) else {
        return type_
      }
      if info.parameters.any(parameter => {
          type_parameter_is_effect(self.program.metadata, parameter)
        }) {
        raise UnsupportedEffectSpecialization(
          detail="an effect-parameterized data type is missing its arguments",
        )
      }
      type_
    }
    Apply(Constructor(source), arguments) => {
      let specialized_arguments = arguments.map(argument => {
        self.specialize_substituted_argument(argument)
      })
      self.specialize_nominal_application(source, specialized_arguments)
    }
    Apply(callee, arguments) =>
      Apply(
        self.specialize_substituted_type(callee),
        arguments.map(argument => self.specialize_substituted_argument(argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.specialize_substituted_type(body))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(parameter => self.specialize_substituted_type(parameter)),
        self.specialize_substituted_type(result),
        self.specialize_substituted_effect(effect),
      )
    Forall(parameters, body) =>
      Forall(parameters, self.specialize_substituted_type(body))
  }
}

///|
fn EffectSpecializer::specialize_argument(
  self : EffectSpecializer,
  argument : @buslane.GenericArgument,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.GenericArgument raise ExecutableElaborationError {
  self.specialize_substituted_argument(
    raw_substitute_specialized_argument(argument, bindings),
  )
}

///|
fn EffectSpecializer::specialize_substituted_argument(
  self : EffectSpecializer,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise ExecutableElaborationError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.specialize_substituted_type(type_))
    EffectArgument(effect) =>
      EffectArgument(self.specialize_substituted_effect(effect))
  }
}

///|
fn EffectSpecializer::specialize_effect(
  self : EffectSpecializer,
  effect : @buslane.Effect,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Effect raise ExecutableElaborationError {
  self.specialize_substituted_effect(
    raw_substitute_specialized_effect(effect, bindings),
  )
}

///|
fn EffectSpecializer::specialize_substituted_effect(
  self : EffectSpecializer,
  effect : @buslane.Effect,
) -> @buslane.Effect raise ExecutableElaborationError {
  match effect {
    Empty | Parameter(_) => effect
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(argument => self.specialize_substituted_argument(argument)),
      )
    Union(effects) =>
      @buslane.Effect::Union(
        effects.map(effect => self.specialize_substituted_effect(effect)),
      ).canonicalize()
  }
}

///|
fn EffectSpecializer::specialize_nominal_application(
  self : EffectSpecializer,
  source : @buslane.TypeId,
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.Type raise ExecutableElaborationError {
  guard self.program.metadata.type_info(source) is Some(info) else {
    return Apply(Constructor(source), arguments)
  }
  if !info.parameters.any(parameter => {
      type_parameter_is_effect(self.program.metadata, parameter)
    }) {
    return Apply(Constructor(source), arguments)
  }
  let instance = self.require_data_instance(source, arguments)
  let retained_arguments = []
  for index, parameter in info.parameters {
    if !type_parameter_is_effect(self.program.metadata, parameter) {
      retained_arguments.push(arguments[index])
    }
  }
  if retained_arguments.is_empty() {
    Constructor(instance.target)
  } else {
    Apply(Constructor(instance.target), retained_arguments)
  }
}

///|
fn EffectSpecializer::require_data_instance(
  self : EffectSpecializer,
  source : @buslane.TypeId,
  arguments : Array[@buslane.GenericArgument],
) -> EffectDataInstance raise ExecutableElaborationError {
  guard self.program.metadata.type_info(source) is Some(info) else {
    raise UnsupportedEffectSpecialization(
      detail="effect-parameterized data metadata is missing",
    )
  }
  if info.parameters.length() != arguments.length() {
    raise UnsupportedEffectSpecialization(
      detail="effect-parameterized data application has the wrong arity",
    )
  }
  let bindings = []
  for index, parameter in info.parameters {
    if type_parameter_is_effect(self.program.metadata, parameter) {
      guard arguments[index] is EffectArgument(effect) else {
        raise UnsupportedEffectSpecialization(
          detail="a data effect parameter requires an effect argument",
        )
      }
      let specialized = abstract_effect_type_arguments(
        effect.canonicalize(),
        info.parameters,
        arguments,
        self.program.metadata,
      )
      if effect_contains_parameter(specialized) {
        raise UnsupportedEffectSpecialization(
          detail="a reachable data specialization must have concrete effects",
        )
      }
      bindings.push({ parameter, argument: EffectArgument(specialized) })
    }
  }
  for instance in self.data_instances {
    if instance.source == source && instance.bindings == bindings {
      return instance
    }
  }
  let retained_parameters = info.parameters.filter(parameter => {
    !type_parameter_is_effect(self.program.metadata, parameter)
  })
  let target = self.program.metadata.define_type(
    "\{info.name.occurrence}%effect",
    retained_parameters,
  )
  let instance = EffectDataInstance::{
    source,
    bindings,
    target,
    constructors: [],
  }
  self.data_instances.push(instance)
  for data_constructor in info.constructors {
    guard self.program.metadata.data_constructor_info(data_constructor)
      is Some(constructor_info) else {
      raise UnsupportedEffectSpecialization(
        detail="an effect-parameterized data constructor is missing metadata",
      )
    }
    let specialized_constructor = self.program.metadata.define_data_constructor(
      "\{constructor_info.name.occurrence}%effect",
      target,
      constructor_info.hidden_type_parameters,
      constructor_info.payload_types.map(type_ => {
        self.specialize_type(type_, bindings)
      }),
    )
    instance.constructors.push({
      source: data_constructor,
      target: specialized_constructor,
    })
  }
  instance
}

///|
fn EffectSpecializer::specialize_constructor(
  self : EffectSpecializer,
  source : @buslane.DataConId,
  arguments : Array[@buslane.GenericArgument],
) -> (@buslane.DataConId, Array[@buslane.GenericArgument]) raise ExecutableElaborationError {
  guard self.program.metadata.data_constructor_info(source) is Some(info) &&
    self.program.metadata.type_info(info.owner) is Some(owner) else {
    return (source, arguments)
  }
  if !owner.parameters.any(parameter => {
      type_parameter_is_effect(self.program.metadata, parameter)
    }) {
    return (source, arguments)
  }
  let instance = self.require_data_instance(info.owner, arguments)
  guard find_specialized_data_constructor(instance.constructors, source)
    is Some(binding) else {
    raise UnsupportedEffectSpecialization(
      detail="a specialized data constructor mapping is missing",
    )
  }
  let retained_arguments = []
  for index, parameter in owner.parameters {
    if !type_parameter_is_effect(self.program.metadata, parameter) {
      retained_arguments.push(arguments[index])
    }
  }
  (binding.target, retained_arguments)
}

///|
fn find_specialized_data_constructor(
  bindings : Array[EffectDataConstructorBinding],
  source : @buslane.DataConId,
) -> EffectDataConstructorBinding? {
  for binding in bindings {
    if binding.source == source {
      return Some(binding)
    }
  }
  None
}

///|
fn EffectSpecializer::specialize_alt_constructor(
  self : EffectSpecializer,
  alternative : @buslane.AltCon,
  binder : @buslane.ValueId,
) -> @buslane.AltCon raise ExecutableElaborationError {
  guard alternative is DataCon(source) &&
    self.program.metadata.data_constructor_info(source) is Some(source_info) &&
    self.program.metadata.value_info(binder) is Some(binder_info) &&
    nominal_type_id(binder_info.type_) is Some(target_owner) else {
    return alternative
  }
  if source_info.owner == target_owner {
    return alternative
  }
  for instance in self.data_instances {
    if instance.source == source_info.owner && instance.target == target_owner {
      for binding in instance.constructors {
        if binding.source == source {
          return DataCon(binding.target)
        }
      }
    }
  }
  raise UnsupportedEffectSpecialization(
    detail="a specialized match constructor mapping is missing",
  )
}

///|
fn nominal_type_id(type_ : @buslane.Type) -> @buslane.TypeId? {
  match type_ {
    Constructor(id) | Apply(Constructor(id), _) => Some(id)
    _ => None
  }
}
