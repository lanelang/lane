///|
pub struct ExecutionProfile {
  priv builtin_effects : Array[@buslane.BuiltinEffect]
  priv supports_external_effects : Bool
} derive(Debug, Eq)

///|
pub fn ExecutionProfile::new(
  builtin_effects~ : Array[@buslane.BuiltinEffect],
  supports_external_effects~ : Bool,
) -> ExecutionProfile {
  { builtin_effects: builtin_effects.copy(), supports_external_effects }
}

///|
pub fn ExecutionProfile::lane_cli() -> ExecutionProfile {
  ExecutionProfile::new(
    builtin_effects=[Io, Panic],
    supports_external_effects=true,
  )
}

///|
fn validate_executable_entry(
  metadata : @buslane.MetadataRegistry,
  entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
) -> Unit raise ExecutableElaborationError {
  guard entry.type_ is Function(parameters, Primitive(Unit), effect) &&
    parameters.is_empty() else {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
  let unsupported = unsupported_entry_effects(metadata, effect, profile) catch {
    error => raise EntryTypeNormalizationCompilerDefect(error)
  }
  if !unsupported.is_empty() {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
}

///|
pub fn entry_effect_is_executable(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  profile : ExecutionProfile,
) -> Bool raise @buslane.TypeNormalizationError {
  unsupported_entry_effects(metadata, effect, profile).is_empty()
}

///|
pub fn unsupported_entry_effects(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  profile : ExecutionProfile,
) -> Array[@buslane.Effect] raise @buslane.TypeNormalizationError {
  if !entry_effect_is_closed(effect) {
    return [effect]
  }
  match metadata.canonicalize_effect(effect) {
    Empty => []
    Builtin(effect) as item =>
      if profile.builtin_effects.contains(effect) {
        []
      } else {
        [item]
      }
    Singleton(effect_id, _) as item =>
      if profile.supports_external_effects &&
        metadata
        .effect_info(effect_id)
        .map_or(false, info => info.flavor is External) {
        []
      } else {
        [item]
      }
    Union(effects) => {
      let unsupported = []
      for effect in effects {
        unsupported.append(unsupported_entry_effects(metadata, effect, profile))
      }
      unsupported
    }
    Parameter(_) as item => [item]
  }
}

///|
fn entry_effect_is_closed(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty | Builtin(_) => true
    Parameter(_) => false
    Singleton(_, arguments) => arguments.all(entry_argument_is_closed)
    Union(effects) => effects.all(entry_effect_is_closed)
  }
}

///|
fn entry_argument_is_closed(argument : @buslane.GenericArgument) -> Bool {
  match argument {
    TypeArgument(type_) => entry_type_is_closed(type_)
    EffectArgument(effect) => entry_effect_is_closed(effect)
  }
}

///|
fn entry_type_is_closed(type_ : @buslane.Type) -> Bool {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => true
    Apply(callee, arguments) =>
      entry_type_is_closed(callee) && arguments.all(entry_argument_is_closed)
    TypeLambda(_, body) | Forall(_, body) => entry_type_is_closed(body)
    Function(parameters, result, effect) =>
      parameters.all(entry_type_is_closed) &&
      entry_type_is_closed(result) &&
      entry_effect_is_closed(effect)
  }
}
