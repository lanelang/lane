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
    Ok(modules) => { source: Some(modules.root.checked), diagnostics: [] }
    Err(diagnostics) => { source: None, diagnostics }
  }
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
      let lowered = @elaborate.lower_checked_source_files_to_buslane_result(
        modules.root.checked,
        modules.linked_libraries.map(fn(module_) { module_.checked }),
      )
      {
        program: Some(lowered.program),
        externals: lowered.externals,
        entries: lowered.entries,
        diagnostics: [],
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
