///|
fn print_diagnostics(diagnostics : Array[@compile.CompileDiagnostic]) -> Unit {
  for diagnostic in diagnostics {
    println(@prettyprinter.render(diagnostic, width=100))
  }
}

///|
fn denied_diagnostics(
  diagnostics : Array[@compile.CompileDiagnostic],
  deny : Bool,
) -> Array[@compile.CompileDiagnostic] {
  diagnostics.filter(fn(diagnostic) { deny || diagnostic.severity is Error })
}
