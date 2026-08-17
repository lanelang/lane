///|
/// Owns the verified, effect-aware CPS Core input to runtime ANF lowering.
///
/// Initializer bodies and order remain in `program.terms`; `initializer_roots`
/// contains only the semantic values that must survive until planning. `entry`
/// belongs to the linked program from which this value was elaborated.
/// Runtime ANF lowering is the sole boundary that projects away effect syntax.
pub(all) struct ExecutableProgram {
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entry : @buslane_lowering.BuslaneEntry
  initializer_roots : Array[@buslane.ValueId]
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
