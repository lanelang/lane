///|
pub(all) struct CheckResult {
  source : @checked.CheckedSourceFile?
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CompileResult {
  program : @buslane.Program?
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CompileModulesResult {
  modules : CompiledModuleSet?
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
/// Checks one Lane source module.
pub fn check_source(source : String) -> CheckResult {
  check_sources(source, [])
}

///|
/// Checks a root Lane source module against explicitly supplied library modules.
pub fn check_sources(
  root_source : String,
  library_sources : Array[String],
) -> CheckResult {
  match compile_module_set_from_inputs(root_source, library_sources) {
    Ok(modules) =>
      match
        find_compiled_module(modules.modules, modules.root_module_path_text) {
        Some(root) => { source: Some(root.object.checked), diagnostics: [] }
        None =>
          {
            source: None,
            diagnostics: [
              CompileErrorKind::to_diagnostic(NoRootSourceModule, None),
            ],
          }
      }
    Err(diagnostics) => { source: None, diagnostics }
  }
}

///|
/// Checks one Lane source module against already compiled module interfaces.
pub fn check_source_with_interface_artifacts(
  root_source : String,
  interfaces : Array[ModuleInterfaceArtifact],
) -> CheckResult {
  match compile_module_from_interface_artifacts(root_source, interfaces) {
    Ok(modules) =>
      match
        find_compiled_module(modules.modules, modules.root_module_path_text) {
        Some(root) => { source: Some(root.object.checked), diagnostics: [] }
        None =>
          {
            source: None,
            diagnostics: [
              CompileErrorKind::to_diagnostic(NoRootSourceModule, None),
            ],
          }
      }
    Err(diagnostics) => { source: None, diagnostics }
  }
}

///|
/// Compiles source modules into separate module artifacts without linking them.
pub fn compile_modules(
  root_source : String,
  library_sources : Array[String],
) -> CompileModulesResult {
  match compile_module_set_from_inputs(root_source, library_sources) {
    Ok(modules) => { modules: Some(modules), diagnostics: [] }
    Err(diagnostics) => { modules: None, diagnostics }
  }
}

///|
/// Compiles one Lane source module against already compiled module interfaces.
pub fn compile_module_with_interface_artifacts(
  root_source : String,
  interfaces : Array[ModuleInterfaceArtifact],
) -> CompileModulesResult {
  match compile_module_from_interface_artifacts(root_source, interfaces) {
    Ok(modules) => { modules: Some(modules), diagnostics: [] }
    Err(diagnostics) => { modules: None, diagnostics }
  }
}

///|
/// Links a compiled module set into a Buslane program.
pub fn link_modules(modules : CompiledModuleSet) -> LinkResult {
  link_compiled_module_set(modules)
}

///|
/// Compiles one Lane source module into Buslane plus compiler-owned side tables
/// needed by tools and runtimes.
pub fn compile_source(source : String) -> CompileResult {
  compile_sources(source, [])
}

///|
/// Compiles a root Lane source module against explicitly supplied library
/// modules.
pub fn compile_sources(
  root_source : String,
  library_sources : Array[String],
) -> CompileResult {
  match compile_module_set_from_inputs(root_source, library_sources) {
    Ok(modules) => {
      let linked = link_compiled_module_set(modules)
      match linked.program {
        Some(program) =>
          {
            program: Some(program.program),
            externals: program.externals,
            entries: program.entries,
            diagnostics: linked.diagnostics,
          }
        None =>
          {
            program: None,
            externals: { builtins: [] },
            entries: [],
            diagnostics: linked.diagnostics,
          }
      }
    }
    Err(diagnostics) =>
      { program: None, externals: { builtins: [] }, entries: [], diagnostics }
  }
}

///|
fn compile_module_set_from_inputs(
  root_source : String,
  library_sources : Array[String],
) -> Result[CompiledModuleSet, Array[CompileDiagnostic]] {
  match parse_module_input_set(root_source, library_sources) {
    Err(diagnostics) => Err(diagnostics)
    Ok(inputs) =>
      match build_module_graph(inputs) {
        Err(diagnostics) => Err(diagnostics)
        Ok(graph) => compile_module_graph(graph)
      }
  }
}
