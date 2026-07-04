///|
fn print_diagnostics_with_sources(
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  sources : CompilerDiagnosticSources,
) -> Unit {
  for diagnostic in diagnostics {
    println(render_compile_diagnostic(diagnostic, sources))
  }
}

///|
fn render_compile_diagnostic(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> String {
  @diag_render.render_diagnostic(
    diagnostic.to_diagnostic(sources),
    sources.source_database(),
    config=@terminal.diagnostic_render_config(),
  )
}

///|
fn denied_diagnostics(
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  deny : Bool,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  diagnostics.filter(fn(diagnostic) { deny || diagnostic.severity is Error })
}
