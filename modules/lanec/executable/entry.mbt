///|
/// Residual-effect admission selected by an embedding execution target. Export
/// ABI admission is a separate compiler-owned check. The compiler deliberately
/// provides no default profile.
pub struct ExecutionProfile {
  priv builtin_effects : Array[@buslane.BuiltinEffect]
  priv supports_external_effects : Bool
} derive(Debug, Eq)

///|
pub fn ExecutionProfile::new(
  builtin_effects~ : Array[@buslane.BuiltinEffect],
  supports_external_effects~ : Bool,
) -> ExecutionProfile {
  { builtin_effects: builtin_effects.copy(), supports_external_effects, }
}

///|
fn validate_executable_entry(
  metadata : @buslane.MetadataRegistry,
  request : ExportRequest,
  profile : ExecutionProfile,
) -> ExecutableExport raise ExecutableElaborationError {
  let entry = request.entry
  let entry_type = @buslane_lowering.source_value_type(metadata, entry.value) catch {
    MissingValueMetadata(_) => raise EntryNotLinked(entry.value)
  }
  let normalized = entry_type.normalize() catch {
    error => raise EntryTypeNormalizationCompilerDefect(error)
  }
  guard normalized is Function(parameters, result, effect) else {
    raise EntryAdmissionRejected(
      value=entry.value,
      type_=entry_type,
      reason=NotFunction,
    )
  }
  let export_parameters = []
  for index, parameter in parameters {
    match export_parameter(parameter) {
      Some(parameter) => export_parameters.push(parameter)
      None =>
        raise EntryAdmissionRejected(
          value=entry.value,
          type_=entry_type,
          reason=UnsupportedParameter(index~, type_=parameter),
        )
    }
  }
  let export_result = match export_result(result) {
    Some(result) => result
    None =>
      raise EntryAdmissionRejected(
        value=entry.value,
        type_=entry_type,
        reason=UnsupportedResult(result~),
      )
  }
  let unsupported = unsupported_entry_effects(metadata, effect, profile) catch {
    error => raise EntryTypeNormalizationCompilerDefect(error)
  }
  if !unsupported.is_empty() {
    raise EntryAdmissionRejected(
      value=entry.value,
      type_=entry_type,
      reason=HasUnsupportedEffects(effects=unsupported),
    )
  }
  executable_export(
    entry~,
    name=request.name,
    parameters=export_parameters,
    result=export_result,
  )
}

///|
fn export_parameter(type_ : @buslane.Type) -> @lane_wasm_abi.ExportParameter? {
  match type_ {
    Primitive(Unit) => Some(ErasedUnit)
    Primitive(I32) => Some(Direct(I32))
    Primitive(I64) => Some(Direct(I64))
    Primitive(F32) => Some(Direct(F32))
    Primitive(F64) => Some(Direct(F64))
    _ => None
  }
}

///|
fn export_result(type_ : @buslane.Type) -> @lane_wasm_abi.ExportResult? {
  match type_ {
    Primitive(Unit) => Some(Unit)
    Primitive(I32) => Some(Direct(I32))
    Primitive(I64) => Some(Direct(I64))
    Primitive(F32) => Some(Direct(F32))
    Primitive(F64) => Some(Direct(F64))
    _ => None
  }
}

///|
fn unsupported_entry_effects(
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
