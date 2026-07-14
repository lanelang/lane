///|
pub(all) struct LinkModuleObject {
  module_path_text : String
  interface : @module_interface.ModuleInterface?
  interface_fingerprint : @artifact_core.CompilationFingerprint
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_core.ModuleImportedReference]
  runtime_effect_operations : Array[RuntimeEffectOperationSignature]
  fingerprint : @artifact_core.CompilationFingerprint
  object_fingerprint_valid : Bool
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  runtime_effect_operations : Array[@artifact_core.LinkedRuntimeEffectOperation]
} derive(Debug, Eq)

///|
pub(all) struct LinkResult {
  program : LinkedProgram?
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct RuntimeEffectOperationSignature {
  module_path_text : String
  effect_name : String
  operation_name : String
  payload : Array[@types.Type]
  result : @types.Type
} derive(Debug, Eq)

///|
pub(all) enum RuntimeEffectOperationValidationError {
  MissingRuntimeEffectOperation(RuntimeEffectOperationSignature)
} derive(Debug, Eq)

///|
pub fn LinkedProgram::find_runtime_effect_operation(
  self : LinkedProgram,
  signature : RuntimeEffectOperationSignature,
) -> @buslane.OperationId? {
  for operation in self.runtime_effect_operations {
    if operation.module_path_text == signature.module_path_text &&
      operation.effect_name == signature.effect_name &&
      operation.operation_name == signature.operation_name &&
      operation.payload == signature.payload &&
      operation.result == signature.result {
      return Some(operation.operation)
    }
  }
  None
}

///|
pub fn LinkedProgram::validate_runtime_effect_operation(
  self : LinkedProgram,
  signature : RuntimeEffectOperationSignature,
) -> Result[@buslane.OperationId, RuntimeEffectOperationValidationError] {
  match self.find_runtime_effect_operation(signature) {
    Some(operation) => Ok(operation)
    None => Err(MissingRuntimeEffectOperation(signature))
  }
}
