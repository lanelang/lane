///|
fn test_compilation_request(
  root_source : String,
  library_sources : Array[String],
) -> CompilationRequest {
  {
    root: { source_id: "<root>", text: root_source, },
    libraries: library_sources.mapi((index, source) => {
      source_id: "<library:\{index}>",
      text: source,
    }),
  }
}

///|
fn successful_check_diagnostics(
  source : String,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  match check_source(source) {
    Succeeded(_, warnings) => warnings.diagnostics()
    Failed(failure) =>
      abort("expected checking to succeed: \{Repr(failure.diagnostics())}")
  }
}

///|
fn successful_check_sources_diagnostics(
  root_source : String,
  library_sources : Array[String],
) -> Array[@compiler_diag.CompilerDiagnostic] {
  match check(test_compilation_request(root_source, library_sources)) {
    Succeeded(_, warnings) => warnings.diagnostics()
    Failed(failure) =>
      abort("expected checking to succeed: \{Repr(failure.diagnostics())}")
  }
}

///|
fn successful_compile_modules_diagnostics(
  root_source : String,
  library_sources : Array[String],
) -> Array[@compiler_diag.CompilerDiagnostic] {
  match
    compile_modules(test_compilation_request(root_source, library_sources)) {
    Succeeded(_, warnings) => warnings.diagnostics()
    Failed(failure) =>
      abort("expected compilation to succeed: \{Repr(failure.diagnostics())}")
  }
}
