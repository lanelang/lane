///|
fn workspace_dependency_codes(
  sources : Array[@module_frontend.SourceInput],
) -> Array[(String?, String?)] {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot
  .diagnostics()
  .map(fn(diagnostic) { (diagnostic.source_id, diagnostic.code) })
}

///|
test "semantic workspace records unavailable parsed modules" {
  let broken : @module_frontend.SourceInput = {
    source_id: "file:///Broken.lane",
    text: "module Broken\npub let value : =",
  }
  assert_eq(
    workspace_dependency_codes([
      broken,
      {
        source_id: "file:///Main.lane",
        text: "module Main\nimport Broken\npub let answer : I64 = 42",
      },
    ]),
    [(Some("file:///Broken.lane"), Some("E1100"))],
  )
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      broken,
      {
        source_id: "file:///Healthy.lane",
        text: "module Healthy\npub let answer : I64 = 42",
      },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  guard snapshot.definition_at("file:///Healthy.lane", 2, 9) is Some(_) else {
    fail("an unrelated invalid source must not hide the healthy module")
  }
}

///|
test "semantic workspace shares module dependency classifications" {
  assert_eq(
    workspace_dependency_codes([
      {
        source_id: "file:///Missing.lane",
        text: "module MissingRoot\nimport Absent\npub let answer : I64 = 42",
      },
    ]),
    [(Some("file:///Missing.lane"), Some("E4002"))],
  )
  assert_eq(
    workspace_dependency_codes([
      {
        source_id: "file:///A.lane",
        text: "module A\nimport B\npub let a : I64 = 1",
      },
      {
        source_id: "file:///B.lane",
        text: "module B\nimport A\npub let b : I64 = 2",
      },
    ]),
    [(Some("file:///B.lane"), Some("E4003"))],
  )
  assert_eq(
    workspace_dependency_codes([
      {
        source_id: "file:///First.lane",
        text: "module Duplicate\npub let first : I64 = 1",
      },
      {
        source_id: "file:///Second.lane",
        text: "module Duplicate\npub let second : I64 = 2",
      },
    ]),
    [(Some("file:///Second.lane"), Some("E4001"))],
  )
}
