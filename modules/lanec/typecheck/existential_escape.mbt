///|
fn SemanticChecker::check_hidden_type_escape(
  self : SemanticChecker,
  opened : Array[TypeParameterId],
  type_ : @types.Type,
  loc : SourceSpan,
) -> Bool {
  // Existential opening is scoped to the pattern arm/body. A synthesized result
  // type must not mention any hidden type parameter opened by that pattern.
  if type_.mentions_any_type_parameter(opened) {
    self.diagnostics.push({ kind: HiddenTypeEscape(type_~), loc })
    true
  } else {
    false
  }
}

///|
fn @checked.CheckedPattern::opened_type_parameters(
  self : @checked.CheckedPattern,
) -> Array[TypeParameterId] {
  let parameters : Array[TypeParameterId] = []
  self.collect_opened_type_parameters(parameters)
  parameters
}

///|
fn @checked.CheckedPattern::collect_opened_type_parameters(
  self : @checked.CheckedPattern,
  parameters : Array[TypeParameterId],
) -> Unit {
  match self {
    Wildcard(..) | Binding(..) | Literal(..) => ()
    Variant(generic_arguments~, arguments~, ..) => {
      for argument in generic_arguments {
        match argument {
          TypeArgument(Parameter(id)) | EffectArgument(Parameter(id)) =>
            parameters.push(id)
          _ => ()
        }
      }
      for argument in arguments {
        argument.collect_opened_type_parameters(parameters)
      }
    }
    Struct(type_binders~, fields~, ..) => {
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          parameters.push(parameter.id)
        }
      }
      for field in fields {
        field.pattern.collect_opened_type_parameters(parameters)
      }
    }
  }
}

///|
fn @types.Type::mentions_any_type_parameter(
  self : @types.Type,
  parameters : Array[TypeParameterId],
) -> Bool {
  self.mentions_any_type_parameter_with_bound(parameters, [])
}

///|
fn @types.Type::mentions_any_type_parameter_with_bound(
  self : @types.Type,
  parameters : Array[TypeParameterId],
  bound : Array[TypeParameterId],
) -> Bool {
  match self {
    Error | Primitive(_) | Constructor(_) => false
    Apply(callee, arguments) =>
      callee.mentions_any_type_parameter_with_bound(parameters, bound) ||
      arguments.any(fn(argument) {
        argument.mentions_any_type_parameter_with_bound(parameters, bound)
      })
    TypeLambda(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      body.mentions_any_type_parameter_with_bound(parameters, next_bound)
    }
    Parameter(id) => parameters.contains(id) && !bound.contains(id)
    Function(function_parameters, result, effect) =>
      function_parameters.any(fn(parameter) {
        parameter.mentions_any_type_parameter_with_bound(parameters, bound)
      }) ||
      result.mentions_any_type_parameter_with_bound(parameters, bound) ||
      effect.mentions_any_type_parameter_with_bound(parameters, bound)
    Forall(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      body.mentions_any_type_parameter_with_bound(parameters, next_bound)
    }
  }
}

///|
fn @types.GenericArgument::mentions_any_type_parameter_with_bound(
  self : @types.GenericArgument,
  parameters : Array[TypeParameterId],
  bound : Array[TypeParameterId],
) -> Bool {
  match self {
    TypeArgument(type_) =>
      type_.mentions_any_type_parameter_with_bound(parameters, bound)
    EffectArgument(effect) =>
      effect.mentions_any_type_parameter_with_bound(parameters, bound)
  }
}

///|
fn @types.Effect::mentions_any_type_parameter_with_bound(
  self : @types.Effect,
  parameters : Array[TypeParameterId],
  bound : Array[TypeParameterId],
) -> Bool {
  match self {
    Empty | Io => false
    Singleton(_, arguments) =>
      arguments.any(fn(argument) {
        argument.mentions_any_type_parameter_with_bound(parameters, bound)
      })
    Parameter(id) => parameters.contains(id) && !bound.contains(id)
    Union(effects) =>
      effects.any(fn(effect) {
        effect.mentions_any_type_parameter_with_bound(parameters, bound)
      })
  }
}
