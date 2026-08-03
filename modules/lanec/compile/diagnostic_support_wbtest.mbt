///|
fn single_check_sources_diagnostic(
  root_source : String,
  library_sources : Array[String],
) -> CompilerDiagnostic {
  let result = check_sources_for_test(root_source, library_sources)
  guard result.diagnostics is [diagnostic] else {
    abort("\{Repr(result.diagnostics)}")
  }
  diagnostic
}

///|
fn assert_diagnostic_headline(
  diagnostic : CompilerDiagnostic,
  code : String,
  message : String,
) -> Unit {
  guard diagnostic.code == Some(code) else {
    abort("unexpected diagnostic: \{Repr(diagnostic)}")
  }
  guard diagnostic.message == message else {
    abort("unexpected diagnostic: \{Repr(diagnostic)}")
  }
}

///|
fn assert_single_help(diagnostic : CompilerDiagnostic, help : String) -> Unit {
  guard diagnostic.helps.length() == 1 else {
    abort("expected one diagnostic help")
  }
  guard diagnostic.helps[0] == help else { abort("unexpected diagnostic help") }
}
