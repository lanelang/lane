///|
/// Owns the verified, effect-aware CPS Core input to runtime ANF lowering.
///
/// Initializer bodies and order remain in `program.terms`; `retained_values`
/// is the single occurrence result consumed by runtime projection. `entry`
/// belongs to the linked program from which this value was elaborated.
/// Runtime ANF lowering is the sole boundary that projects away effect syntax.
pub(all) struct ExecutableProgram {
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entry : @buslane_lowering.BuslaneEntry
  retained_values : Array[@buslane.ValueId]
  function_origins : @function_origin.FunctionOriginCatalog
} derive(Debug, Eq)

///|
/// A semantic reason why the selected linked entry cannot be admitted by an
/// execution profile.
pub(all) enum EntryAdmissionFailure {
  NotFunction
  HasParameters(count~ : Int)
  ReturnsNonUnit(result~ : @buslane.Type)
  HasUnsupportedEffects(effects~ : Array[@buslane.Effect])
} derive(Debug, Eq)

///|
/// Structured whole-program elaboration failures. Unsupported source programs
/// are distinguished from compiler invariant and verification failures.
pub(all) suberror ExecutableElaborationError {
  EntryNotLinked(@buslane.ValueId)
  EntryAdmissionRejected(
    value~ : @buslane.ValueId,
    type_~ : @buslane.Type,
    reason~ : EntryAdmissionFailure
  )
  EntryTypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  UnsupportedEffectSpecialization(detail~ : String)
  EffectSpecializationCompilerDefect(@effect_specialization.SpecializationError)
  CoreOptimizationError(@core_opt.CoreOptimizeError)
  EffectLoweringError(@effect_lowering.SynthesisError)
  UnverifiedProgram(stage~ : String, result~ : @buslane.VerifyResult)
} derive(Debug, Eq)
