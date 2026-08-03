///|
/// Internal model and mechanical rewrite for the effect-specialization phase.
priv struct EffectGenericDefinition {
  id : @buslane.ValueId
  parameters : Array[@buslane.TypeParameterId]
  rhs : @buslane.Expr
}

///|
pub(all) struct EffectSpecializationBinding {
  parameter : @buslane.TypeParameterId
  argument : @buslane.GenericArgument
} derive(Debug, Eq)

///|
/// The source-level demand made by one fully substituted generic use.
///
/// This classification deliberately contains no CPS or runtime-layout facts.
/// A symbolic effect remains a request for the generic definition; concrete
/// bindings form the canonical identity of a specialized callable instance.
priv enum EffectGenericUseMode {
  Incomplete
  Symbolic
  Concrete(Array[EffectSpecializationBinding])
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct ClassifiedEffectGenericUse {
  arguments : Array[@buslane.GenericArgument]
  retained_arguments : Array[@buslane.GenericArgument]
  mode : EffectGenericUseMode
} derive(Debug, Eq)

///|
fn classify_effect_generic_use(
  metadata : @buslane.MetadataRegistry,
  parameters : Array[@buslane.TypeParameterId],
  substituted_arguments : Array[@buslane.GenericArgument],
) -> ClassifiedEffectGenericUse raise SpecializationError {
  if substituted_arguments.length() < parameters.length() {
    return {
      arguments: substituted_arguments,
      retained_arguments: [],
      mode: Incomplete,
    }
  }
  let bindings = []
  let retained_arguments = []
  let mut symbolic = false
  for index in 0..<parameters.length() {
    let parameter = parameters[index]
    let argument = substituted_arguments[index]
    if type_parameter_is_effect(metadata, parameter) {
      guard argument is EffectArgument(effect) else {
        raise InvalidInputMetadata(
          specialization_error_context(
            "an effect parameter requires an effect argument",
            source=TypeParameter(parameter),
          ),
        )
      }
      let canonical = metadata.canonicalize_effect(effect)
      let abstracted = abstract_effect_type_arguments(
        canonical, parameters, substituted_arguments, metadata,
      )
      if effect_contains_parameter(abstracted) {
        symbolic = true
      } else {
        bindings.push({ parameter, argument: EffectArgument(abstracted) })
      }
    } else {
      retained_arguments.push(argument)
    }
  }
  for index in parameters.length()..<substituted_arguments.length() {
    retained_arguments.push(substituted_arguments[index])
  }
  {
    arguments: substituted_arguments,
    retained_arguments,
    mode: if symbolic {
      Symbolic
    } else {
      Concrete(bindings)
    },
  }
}

///|
fn specialization_bindings_equal(
  metadata : @buslane.MetadataRegistry,
  left : Array[EffectSpecializationBinding],
  right : Array[EffectSpecializationBinding],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index].parameter != right[index].parameter ||
      !generic_arguments_definitionally_equal(
        metadata,
        left[index].argument,
        right[index].argument,
      ) {
      return false
    }
  }
  true
}

///|
fn generic_arguments_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.GenericArgument,
  right : @buslane.GenericArgument,
) -> Bool {
  match (left, right) {
    (TypeArgument(left), TypeArgument(right)) =>
      metadata.types_definitionally_equal(left, right)
    (EffectArgument(left), EffectArgument(right)) =>
      metadata.effects_definitionally_equal(left, right)
    _ => false
  }
}
