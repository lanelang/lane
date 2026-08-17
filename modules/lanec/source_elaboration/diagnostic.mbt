///|
fn source_elaboration_compiler_defect_diagnostic(
  cause : SourceElaborationCompilerDefectCause,
) -> @compiler_diag.CompilerDiagnostic {
  match cause {
    InvalidTypecheckInput(error) =>
      @compiler_diag.compiler_error(
        "internal compiler error while checking resolved source",
        span=None,
        code=Some("E4599"),
        labels=[],
        notes=["the resolver/typechecker phase contract failed: \{Repr(error)}"],
        helps=["report this compiler defect with the input module sources"],
      )
    IncompleteTypecheckOutput =>
      @compiler_diag.compiler_error(
        "internal compiler error while constructing checked source",
        span=None,
        code=Some("E4599"),
        labels=[],
        notes=[
          "type checking completed without both a checked source and its certified module interface",
        ],
        helps=["report this compiler defect with the input module sources"],
      )
  }
}

///|
fn resolve_diagnostics(
  diagnostics : Array[@resolve.ResolveDiagnostic],
  source_id : String,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  diagnostics.map(fn(diagnostic) {
    diagnostic
    .to_compiler_diagnostic(DiagnosticContext())
    .with_source_id(source_id)
  })
}

///|
fn typecheck_diagnostics(
  diagnostics : Array[@typecheck.TypeCheckDiagnostic],
  display : @typecheck.TypeDisplayContext,
  source_id : String,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  diagnostics.map(fn(diagnostic) {
    diagnostic
    .with_display(display)
    .to_compiler_diagnostic(DiagnosticContext())
    .with_source_id(source_id)
  })
}
