///|
fn compile_source_diagnostics(
  source : String,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  @compile.check_source(source).diagnostics()
}

///|
fn workspace_source_diagnostics(
  source : String,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  let workspace = @analysis.SemanticWorkspace::new()
  guard workspace.upsert_source({ source_id: "<root>", text: source })
    is Some(snapshot) else {
    abort("expected a semantic snapshot")
  }
  snapshot.diagnostics()
}

///|
test "batch and workspace source elaboration diagnostics agree" {
  for
    source in [
      "module Main\npub let answer : I64 = 42", "module Main\npub let answer : I64 = missing",
      "module Main\npub let answer : I64 = true", "module Main\npub fn answer() -> I64 { let unused = 1; 42 }",
    ] {
    assert_eq(
      workspace_source_diagnostics(source),
      compile_source_diagnostics(source),
    )
  }
}

///|
test "batch and workspace elaborate the same imported interface closure" {
  let root_text = "module Main\nimport Lib.{ value }\npub let answer : I64 = value"
  let library_text = "module Lib\npub let value : I64 = 42"
  let compiled = @compile.check({
    root: { source_id: "file:///Main.lane", text: root_text },
    libraries: [{ source_id: "file:///Lib.lane", text: library_text }],
  })
  guard compiled is Succeeded(_, warnings) else {
    fail("expected batch elaboration to succeed")
  }
  let workspace = @analysis.SemanticWorkspace::new()
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: root_text },
      { source_id: "file:///Lib.lane", text: library_text },
    ])
    is Some(snapshot) else {
    fail("expected a semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), warnings.diagnostics())
  assert_eq(
    snapshot.analysis().definitions.map(fn(definition) {
      (definition.location.source_id, definition.label)
    }),
    [("file:///Lib.lane", "value"), ("file:///Main.lane", "answer")],
  )
}

///|
test "workspace source elaboration reuses declaration identity" {
  let workspace = @analysis.SemanticWorkspace::new()
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: "module Main\npub let stable : I64 = 1",
    })
    is Some(initial) else {
    fail("expected an initial semantic snapshot")
  }
  guard initial.analysis().definitions is [first] else {
    fail("expected one initial definition")
  }
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: "module Main\n// edited\npub let stable : I64 = 2",
    })
    is Some(updated) else {
    fail("expected an updated semantic snapshot")
  }
  guard updated.analysis().definitions is [second] else {
    fail("expected one updated definition")
  }
  assert_eq(second.symbol, first.symbol)
}
