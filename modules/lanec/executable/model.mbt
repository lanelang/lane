///|
/// Owns the verified, effect-aware CPS Core input to runtime ANF lowering.
///
/// Initializers and execution roots are in deterministic dependency order;
/// `entry` belongs to the linked program from which this value was elaborated.
/// Runtime ANF lowering is the sole boundary that projects away effect syntax.
pub(all) struct ExecutableProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entry : @buslane_lowering.BuslaneEntry
  initializers : Array[TopLevelInitializer]
  execution_roots : Array[ExecutionRoot]
} derive(Debug, Eq)

///|
/// One eager top-level initialization action. Array order is execution order;
/// recursive groups initialize atomically as one action.
pub(all) enum TopLevelInitializer {
  Value(@buslane.ValueId, @buslane.Expr)
  Recursive(Array[@buslane.RecursiveBinding])
} derive(Debug, Eq)

///|
/// A root retained for execution. Initializer indices refer to the owning
/// `ExecutableProgram.initializers` array and precede its selected entry root.
pub(all) enum ExecutionRoot {
  Initializer(Int)
  Entry(@buslane.ValueId)
} derive(Debug, Eq)

///|
/// Structured whole-program elaboration failures. Unsupported source programs
/// are distinguished from compiler invariant and verification failures.
pub(all) suberror ExecutableElaborationError {
  EntryNotLinked(@buslane.ValueId)
  InvalidEntryFunction(value~ : @buslane.ValueId, type_~ : @buslane.Type)
  EntryTypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  UnsupportedEffectSpecialization(detail~ : String)
  EffectSpecializationCompilerDefect(@effect_specialization.SpecializationError)
  CoreOptimizationError(@core_opt.CoreOptimizeError)
  EffectLoweringError(@effect_lowering_core.SynthesisError)
  UnverifiedProgram(stage~ : String, result~ : @buslane.VerifyResult)
} derive(Debug, Eq)
