///|
test "outcome construction detaches nested diagnostic arrays" {
  let diagnostics : Array[CompilerDiagnostic] = [
    {
      source_id: None,
      message: "original",
      span: None,
      severity: Error,
      code: Some("E0000"),
      labels: [],
      notes: ["original note"],
      helps: [],
      facts: [],
      suggestions: [],
    },
  ]
  let outcome : CompilationOutcome[Unit] = compilation_failed(diagnostics)
  diagnostics[0].notes.push("mutated note")
  guard outcome is Failed(failure) && failure.diagnostics() is [diagnostic] else {
    abort("expected one failed diagnostic")
  }
  assert_eq(diagnostic.notes, ["original note"])
}
