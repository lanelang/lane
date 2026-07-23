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
priv enum NominalDecomposition {
  Nominal(TypeSymbolId, Array[@types.GenericArgument])
  NotNominal
  ComputationFailed
}

///|
fn decompose_nominal_or_report(
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @types.Type,
  loc : SourceSpan,
  context~ : String,
) -> NominalDecomposition {
  let decomposition = type_.decompose_nominal() catch {
    error => {
      report_type_computation_failure(diagnostics, context, loc, error)
      return ComputationFailed
    }
  }
  match decomposition {
    Some((symbol, arguments)) => Nominal(symbol, arguments)
    None => NotNominal
  }
}

///|
fn normalize_type_or_error(
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @types.Type,
  loc : SourceSpan,
  context~ : String,
) -> @types.Type {
  normalize_type_or_report(diagnostics, type_, loc, context~).unwrap_or(Error)
}

///|
fn normalize_type_or_report(
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @types.Type,
  loc : SourceSpan,
  context~ : String,
) -> @types.Type? {
  Some(type_.try_normalize()) catch {
    error => {
      report_type_computation_failure(diagnostics, context, loc, error)
      None
    }
  }
}

///|
fn normalize_effect_or_report(
  diagnostics : Array[TypeCheckDiagnostic],
  effect : @types.Effect,
  loc : SourceSpan,
  context~ : String,
) -> @types.Effect? {
  Some(effect.try_normalize()) catch {
    error => {
      report_type_computation_failure(diagnostics, context, loc, error)
      None
    }
  }
}
