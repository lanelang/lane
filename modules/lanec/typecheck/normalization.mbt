///|
fn type_computation_failure_label(
  context : String,
  error : @types.TypeComputationError,
) -> String {
  match error {
    TypeNormalizationFuelExhausted =>
      "type-level computation did not terminate while normalizing " + context
    EffectNormalizationFuelExhausted =>
      "type-level computation did not terminate while normalizing " + context
  }
}

///|
fn report_type_computation_failure(
  diagnostics : Array[TypeCheckDiagnostic],
  context : String,
  loc : SourceSpan,
  error : @types.TypeComputationError,
) -> Unit {
  diagnostics.push({
    kind: InternalTypecheckFailure(
      label=type_computation_failure_label(context, error),
    ),
    loc,
  })
}

///|
fn normalize_type_or_error(
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @types.Type,
  loc : SourceSpan,
  context~ : String,
) -> @types.Type {
  type_.try_normalize() catch {
    error => {
      report_type_computation_failure(diagnostics, context, loc, error)
      Error
    }
  }
}

///|
fn normalize_effect_or_empty(
  diagnostics : Array[TypeCheckDiagnostic],
  effect : @types.Effect,
  loc : SourceSpan,
  context~ : String,
) -> @types.Effect {
  effect.try_normalize() catch {
    error => {
      report_type_computation_failure(diagnostics, context, loc, error)
      Empty
    }
  }
}
