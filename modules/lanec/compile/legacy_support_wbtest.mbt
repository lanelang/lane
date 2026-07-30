///|
priv struct TestCheckResult {
  source : @checked.CheckedSourceFile?
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct TestCompileModulesResult {
  modules : @module_compile.CompiledModuleSet?
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct TestCompileResult {
  program : @buslane.Program?
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn check_source_for_test(source : String) -> TestCheckResult {
  test_check_result(check_source(source))
}

///|
fn check_sources_for_test(
  root_source : String,
  library_sources : Array[String],
) -> TestCheckResult {
  test_check_result(check(test_compilation_request(root_source, library_sources)))
}

///|
fn check_source_with_interfaces_for_test(
  root_source : String,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> TestCheckResult {
  test_check_result(
    check_with_interfaces({
      root: { source_id: "<root>", text: root_source },
      interfaces,
    }),
  )
}

///|
fn test_check_result(
  outcome : CompilationOutcome[CheckedModule],
) -> TestCheckResult {
  match outcome {
    Succeeded(module_, warnings) =>
      { source: Some(module_.source), diagnostics: warnings.diagnostics() }
    Failed(failure) =>
      { source: None, diagnostics: failure.diagnostics() }
  }
}

///|
fn compile_modules_for_test(
  root_source : String,
  library_sources : Array[String],
) -> TestCompileModulesResult {
  test_compile_modules_result(
    compile_modules(test_compilation_request(root_source, library_sources)),
  )
}

///|
fn compile_module_with_interfaces_for_test(
  root_source : String,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> TestCompileModulesResult {
  test_compile_modules_result(
    compile_module_with_interfaces({
      root: { source_id: "<root>", text: root_source },
      interfaces,
    }),
  )
}

///|
fn test_compile_modules_result(
  outcome : CompilationOutcome[CompiledModules],
) -> TestCompileModulesResult {
  match outcome {
    Succeeded(modules, warnings) =>
      { modules: Some(modules.modules), diagnostics: warnings.diagnostics() }
    Failed(failure) =>
      { modules: None, diagnostics: failure.diagnostics() }
  }
}

///|
fn compile_source_for_test(source : String) -> TestCompileResult {
  test_compile_result(compile_source(source))
}

///|
fn compile_sources_for_test(
  root_source : String,
  library_sources : Array[String],
) -> TestCompileResult {
  test_compile_result(
    compile(test_compilation_request(root_source, library_sources)),
  )
}

///|
fn test_compile_result(
  outcome : CompilationOutcome[CompiledProgram],
) -> TestCompileResult {
  match outcome {
    Succeeded(program, warnings) =>
      {
        program: Some(program.linked.program),
        externals: program.linked.externals,
        entries: program.linked.entries,
        diagnostics: warnings.diagnostics(),
      }
    Failed(failure) =>
      {
        program: None,
        externals: { builtins: [], runtime_imports: [] },
        entries: [],
        diagnostics: failure.diagnostics(),
      }
  }
}

///|
fn link_modules_for_test(
  modules : @module_compile.CompiledModuleSet,
) -> @module_link.LinkResult {
  @module_compile.link_compiled_module_set(modules)
}

///|
fn test_compilation_request(
  root_source : String,
  library_sources : Array[String],
) -> CompilationRequest {
  {
    root: { source_id: "<root>", text: root_source },
    libraries: library_sources.mapi((index, source) => {
      { source_id: "<library:\{index}>", text: source }
    }),
  }
}
