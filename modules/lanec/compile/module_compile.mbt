///|
pub(all) struct CompilationFingerprint {
  value : String
} derive(Debug, Eq)

///|
pub(all) struct ImportedInterfaceFingerprint {
  module_path_text : String
  fingerprint : CompilationFingerprint
} derive(Debug, Eq)

///|
pub(all) struct ModuleImportedReference {
  module_path_text : String
  kind : @elaborate.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
} derive(Debug, Eq)

///|
pub(all) struct ModuleObject {
  module_path_text : String
  checked : @checked.CheckedSourceFile
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  exports : Array[@elaborate.BuslaneModuleExport]
  imports : Array[ModuleImportedReference]
  fingerprint : CompilationFingerprint
  object_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModule {
  module_path_text : String
  interface : @module_interface.ModuleInterface
  object : ModuleObject
  fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleSet {
  root_module_path_text : String
  modules : Array[CompiledModule]
  reachable_module_path_texts : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  runtime_effect_operations : Array[LinkedRuntimeEffectOperation]
} derive(Debug, Eq)

///|
pub(all) struct LinkResult {
  program : LinkedProgram?
  diagnostics : Array[CompilerDiagnostic]
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
pub(all) struct LinkedRuntimeEffectOperation {
  module_path_text : String
  effect_name : String
  operation_name : String
  payload : Array[@types.Type]
  result : @types.Type
  operation : @buslane.OperationId
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
  find_runtime_effect_operation(self.runtime_effect_operations, signature)
}

///|
pub fn LinkedProgram::validate_runtime_effect_operation(
  self : LinkedProgram,
  signature : RuntimeEffectOperationSignature,
) -> Result[@buslane.OperationId, RuntimeEffectOperationValidationError] {
  validate_runtime_effect_operation(self.runtime_effect_operations, signature)
}

///|
pub fn LinkedProgramArtifact::find_runtime_effect_operation(
  self : LinkedProgramArtifact,
  signature : RuntimeEffectOperationSignature,
) -> @buslane.OperationId? {
  find_runtime_effect_operation(self.runtime_effect_operations, signature)
}

///|
pub fn LinkedProgramArtifact::validate_runtime_effect_operation(
  self : LinkedProgramArtifact,
  signature : RuntimeEffectOperationSignature,
) -> Result[@buslane.OperationId, RuntimeEffectOperationValidationError] {
  validate_runtime_effect_operation(self.runtime_effect_operations, signature)
}

///|
fn find_runtime_effect_operation(
  operations : Array[LinkedRuntimeEffectOperation],
  signature : RuntimeEffectOperationSignature,
) -> @buslane.OperationId? {
  for operation in operations {
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
fn validate_runtime_effect_operation(
  operations : Array[LinkedRuntimeEffectOperation],
  signature : RuntimeEffectOperationSignature,
) -> Result[@buslane.OperationId, RuntimeEffectOperationValidationError] {
  match find_runtime_effect_operation(operations, signature) {
    Some(operation) => Ok(operation)
    None => Err(MissingRuntimeEffectOperation(signature))
  }
}

///|
fn compile_module_graph(
  graph : ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let modules : Array[CompiledModule] = []
  for input in graph.modules {
    let imported = imported_interfaces(input.header, modules)
    match compile_one_module(input, registry, imported) {
      Ok(module_) => modules.push(module_)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  if find_compiled_module(modules, graph.root_module_path_text) is None {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  Ok({
    root_module_path_text: graph.root_module_path_text,
    modules: lower_compiled_module_objects(modules),
    reachable_module_path_texts: graph.reachable_module_path_texts,
  })
}

///|
fn compile_module_from_interface_artifacts(
  root_source : SourceInput,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let parsed = parse_module_inputs(root_source, [])
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(input) else {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  let ordered_interfaces = reachable_interface_artifacts(
    input.header,
    interfaces,
  )
  let import_diagnostics = ordered_interfaces.diagnostics
  if !import_diagnostics.is_empty() {
    return Err(
      import_diagnostics.map(fn(diagnostic) {
        diagnostic.with_source_id(root_source.source_id)
      }),
    )
  }
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let imported = freshen_module_interface_artifacts(
    registry,
    ordered_interfaces.interfaces,
  )
  match compile_one_module(input, registry, imported) {
    Err(diagnostics) => Err(diagnostics)
    Ok(module_) => {
      let imported_fingerprints = imported_interface_fingerprints_from_artifacts(
        input.header,
        ordered_interfaces.interfaces,
      )
      let module_ = module_.with_imported_interface_fingerprints(
        imported_fingerprints,
      )
      let lowered = @elaborate.lower_checked_source_file_to_buslane_object_with_imports(
        module_.object.checked,
        imported,
      )
      let compiled = attach_lowered_object_from_interfaces(
        module_,
        lowered,
        ordered_interfaces.interfaces,
      )
      Ok({
        root_module_path_text: compiled.module_path_text,
        modules: [compiled],
        reachable_module_path_texts: [compiled.module_path_text],
      })
    }
  }
}
