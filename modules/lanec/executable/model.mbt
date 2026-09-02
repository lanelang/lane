///|
/// Owns the verified, effect-aware CPS Core input to runtime ANF lowering.
///
/// Initializer bodies and order remain in `program.terms`; `retained_values`
/// is the single occurrence result consumed by runtime projection. `exports`
/// is the complete external root set selected by the embedding target.
/// Runtime ANF lowering is the sole boundary that projects away effect syntax.
pub(all) struct ExecutableProgram {
  cps_core : @effect_lowering.CpsCoreProgram
  externals : @buslane_lowering.BuslaneExternalMap
  exports : Array[ExecutableExport]
  retained_values : Array[@buslane.ValueId]
} derive(Debug, Eq)

///|
pub(all) struct ExportRequest {
  entry : @buslane_lowering.BuslaneEntry
  name : String
} derive(Debug, Eq)

///|
pub struct ExecutableExport {
  entry : @buslane_lowering.BuslaneEntry
  name : String
  parameters : Array[@lane_wasm_abi.ExportParameter]
  result : @lane_wasm_abi.ExportResult
} derive(Debug, Eq)

///|
pub fn ExecutableExport::entry(
  self : ExecutableExport,
) -> @buslane_lowering.BuslaneEntry {
  self.entry
}

///|
pub fn executable_export(
  entry~ : @buslane_lowering.BuslaneEntry,
  name~ : String,
  parameters~ : Array[@lane_wasm_abi.ExportParameter],
  result~ : @lane_wasm_abi.ExportResult,
) -> ExecutableExport {
  { entry, name, parameters: parameters.copy(), result, }
}

///|
pub fn ExecutableExport::name(self : ExecutableExport) -> String {
  self.name
}

///|
pub fn ExecutableExport::parameters(
  self : ExecutableExport,
) -> Array[@lane_wasm_abi.ExportParameter] {
  self.parameters.copy()
}

///|
pub fn ExecutableExport::result(
  self : ExecutableExport,
) -> @lane_wasm_abi.ExportResult {
  self.result
}

///|
pub fn ExecutableExport::contract(
  self : ExecutableExport,
) -> @lane_wasm_abi.ExportContract {
  { name: self.name(), parameters: self.parameters(), result: self.result(), }
}

///|
/// A semantic reason why the selected linked entry cannot be admitted by an
/// execution profile.
pub(all) enum EntryAdmissionFailure {
  NotFunction
  UnsupportedParameter(index~ : Int, type_~ : @buslane.Type)
  UnsupportedResult(result~ : @buslane.Type)
  HasUnsupportedEffects(effects~ : Array[@buslane.Effect])
} derive(Debug, Eq)

///|
/// Structured whole-program elaboration failures. Unsupported source programs
/// are distinguished from compiler invariant and verification failures.
pub(all) suberror ExecutableElaborationError {
  NoExports
  DuplicateExportName(String)
  ReservedExportName(String)
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
} derive(Debug, Eq)
