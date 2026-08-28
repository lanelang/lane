///|
/// A verified seam in the effect-lowering pipeline. Only the input and CPS Core
/// output are public IRs; the middle variants identify private snapshot points.
pub(all) enum EffectLoweringVerificationStage {
  HandlerElaboration
  MonadicTransformation
  SelectiveCpsRewrite
  OpenContextResolution
  CpsCore
} derive(Debug, Eq)

///|
/// A private transformation point that may be observed after verification.
pub(all) enum EffectLoweringSnapshotStage {
  HandlersElaborated
  MonadicTransformed
  SelectiveCpsRewritten
  OpenContextsResolved
} derive(Debug, Eq)

///|
/// Stable aggregate facts owned by the private transitional representation.
pub(all) struct EffectLoweringScale {
  top_terms : Int
  functions : Int
  nodes : Int
  calls : Int
} derive(Debug, Eq)

///|
/// Verified CPS Core together with transformation-owned function provenance.
pub(all) struct EffectLoweringResult {
  program : @buslane.VerifiedProgram
  function_origins : @function_origin.FunctionOriginCatalog
} derive(Debug, Eq)

///|
/// A read-only observation of a verified private stage. It deliberately carries
/// no constructible transitional AST.
pub(all) struct EffectLoweringSnapshot {
  stage : EffectLoweringSnapshotStage
  text : String
  scale : EffectLoweringScale
} derive(Debug, Eq)

///|
/// Lowers verified effect-aware Buslane into verified effect-aware CPS Core.
/// Every private stage is checked before its snapshot is reported.
pub fn lower_effects(
  program : @buslane.VerifiedProgram,
) -> Result[EffectLoweringResult, SynthesisError] {
  Ok(lower_effects_or_raise(program, None)) catch {
    error => Err(error)
  }
}

///|
/// Lowers effects while reporting verified private transformation points.
pub fn lower_effects_observed(
  program : @buslane.VerifiedProgram,
  observe : (EffectLoweringSnapshot) -> Unit,
) -> Result[EffectLoweringResult, SynthesisError] {
  Ok(lower_effects_or_raise(program, Some(observe))) catch {
    error => Err(error)
  }
}

///|
fn lower_effects_or_raise(
  verified : @buslane.VerifiedProgram,
  observe : ((EffectLoweringSnapshot) -> Unit)?,
) -> EffectLoweringResult raise SynthesisError {
  let program = verified.program()
  let elaborated = elaborate_handlers(program)
  require_transitional_program(HandlerElaboration, elaborated)
  observe_effect_lowering_stage(observe, HandlersElaborated, elaborated)
  let bound = introduce_monadic_binds_or_raise(elaborated)
  require_transitional_program(MonadicTransformation, bound)
  observe_effect_lowering_stage(observe, MonadicTransformed, bound)
  let transformed = rewrite_selective_cps_abis_or_raise(bound)
  require_transitional_program(SelectiveCpsRewrite, transformed)
  observe_effect_lowering_stage(observe, SelectiveCpsRewritten, transformed)
  let resolved = resolve_open_contexts_or_raise(transformed)
  require_transitional_program(OpenContextResolution, resolved)
  observe_effect_lowering_stage(observe, OpenContextsResolved, resolved)
  let (lifted, function_origins) = lift_monadic_continuations_or_raise(resolved)
  let certified = match lifted.certify() {
    Ok(program) => program
    Err(result) => raise InvalidProgram(stage=CpsCore, result~)
  }
  { program: certified, function_origins, }
}

///|
fn observe_effect_lowering_stage(
  observe : ((EffectLoweringSnapshot) -> Unit)?,
  stage : EffectLoweringSnapshotStage,
  program : Program,
) -> Unit {
  if observe is Some(emit) {
    emit(effect_lowering_snapshot(stage, program))
  }
}

///|
fn require_transitional_program(
  stage : EffectLoweringVerificationStage,
  program : Program,
) -> Unit raise SynthesisError {
  let result = verify_program_or_raise(program)
  if !result.is_ok() {
    raise InvalidProgram(stage~, result~)
  }
}

///|
