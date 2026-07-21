///|
fn definition_symbol(
  snapshot : SemanticSnapshot,
  source_id : String,
  label : String,
) -> AnalysisSymbol {
  for definition in snapshot.analysis().definitions {
    if definition.location.source_id == source_id && definition.label == label {
      return definition.symbol
    }
  }
  abort("missing definition \{label} in \{source_id}")
}

///|
test "semantic workspace invalidates only reverse dependencies" {
  let workspace = SemanticWorkspace::new()
  let source_a =
    #|module A
    #|
    #|pub let value : Int = 1
  let source_b =
    #|module B
    #|
    #|import A
    #|
    #|pub let dependent : Int = A.value
  let source_c =
    #|module C
    #|
    #|pub let separate : Int = 3
  let sources : Array[@module_frontend.SourceInput] = [
    { source_id: "file:///A.lane", text: source_a },
    { source_id: "file:///B.lane", text: source_b },
    { source_id: "file:///C.lane", text: source_c },
  ]
  guard workspace.replace_sources(sources) is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  let initial_a = definition_symbol(initial, "file:///A.lane", "value")
  let initial_b = definition_symbol(initial, "file:///B.lane", "dependent")
  let initial_c = definition_symbol(initial, "file:///C.lane", "separate")
  let changed_a =
    #|module A
    #|
    #|pub let value : Int = 2
  guard workspace.upsert_source({ source_id: "file:///A.lane", text: changed_a })
    is Some(after_a) else {
    abort("expected semantic snapshot after changing A")
  }
  let after_a_symbol = definition_symbol(after_a, "file:///A.lane", "value")
  let after_a_b = definition_symbol(after_a, "file:///B.lane", "dependent")
  let after_a_c = definition_symbol(after_a, "file:///C.lane", "separate")
  assert_false(after_a_symbol == initial_a)
  assert_false(after_a_b == initial_b)
  assert_eq(after_a_c, initial_c)
  let changed_c =
    #|module C
    #|
    #|pub let separate : Int = 4
  guard workspace.upsert_source({ source_id: "file:///C.lane", text: changed_c })
    is Some(after_c) else {
    abort("expected semantic snapshot after changing C")
  }
  assert_eq(
    definition_symbol(after_c, "file:///A.lane", "value"),
    after_a_symbol,
  )
  assert_eq(
    definition_symbol(after_c, "file:///B.lane", "dependent"),
    after_a_b,
  )
  assert_false(
    definition_symbol(after_c, "file:///C.lane", "separate") == after_a_c,
  )
}

///|
test "semantic workspace reuses snapshot for identical sources" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|pub let answer : Int = 42
  let sources : Array[@module_frontend.SourceInput] = [
    { source_id: "file:///Main.lane", text: source },
  ]
  guard workspace.replace_sources(sources) is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  guard workspace.replace_sources(sources.copy()) is Some(reused) else {
    abort("expected reused semantic snapshot")
  }
  assert_eq(reused.revision(), initial.revision())
  assert_eq(
    definition_symbol(reused, "file:///Main.lane", "answer"),
    definition_symbol(initial, "file:///Main.lane", "answer"),
  )
}

///|
test "semantic workspace keeps healthy modules when another source cannot parse" {
  let workspace = SemanticWorkspace::new()
  let healthy =
    #|module Healthy
    #|
    #|pub let answer : Int = 42
  let broken =
    #|module Broken
    #|
    #|pub let missing =
  guard workspace.replace_sources([
      { source_id: "file:///Healthy.lane", text: healthy },
      { source_id: "file:///Broken.lane", text: broken },
    ])
    is Some(snapshot) else {
    abort("expected tolerant semantic snapshot")
  }
  ignore(definition_symbol(snapshot, "file:///Healthy.lane", "answer"))
  assert_true(
    snapshot.analysis().diagnostics.any(fn(diagnostic) {
      diagnostic.source_id == Some("file:///Broken.lane")
    }),
  )
}

///|
test "semantic workspace uses the last successful interface during parse recovery" {
  let workspace = SemanticWorkspace::new()
  let source_a =
    #|module A
    #|
    #|pub let value : Int = 1
  let source_b =
    #|module B
    #|
    #|import A
    #|
    #|pub let dependent : Int = A.value
  guard workspace.replace_sources([
      { source_id: "file:///A.lane", text: source_a },
      { source_id: "file:///B.lane", text: source_b },
    ])
    is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  let initial_dependent = definition_symbol(
    initial, "file:///B.lane", "dependent",
  )
  let broken_a =
    #|module A
    #|
    #|pub let value =
  guard workspace.upsert_source({ source_id: "file:///A.lane", text: broken_a })
    is Some(recovering) else {
    abort("expected recovery semantic snapshot")
  }
  assert_eq(
    definition_symbol(recovering, "file:///B.lane", "dependent"),
    initial_dependent,
  )
  debug_inspect(
    recovering.diagnostics().map(fn(diagnostic) { diagnostic.source_id }),
    content="[Some(\"file:///A.lane\")]",
  )
  let recovered_a =
    #|module A
    #|
    #|pub let value : Int = 2
  guard workspace.upsert_source({
      source_id: "file:///A.lane",
      text: recovered_a,
    })
    is Some(recovered) else {
    abort("expected recovered semantic snapshot")
  }
  assert_false(
    definition_symbol(recovered, "file:///B.lane", "dependent") ==
    initial_dependent,
  )
}

///|
test "semantic workspace uses the last successful interface during type recovery" {
  let workspace = SemanticWorkspace::new()
  let source_a =
    #|module A
    #|
    #|pub let value : Int = 1
  let source_b =
    #|module B
    #|
    #|import A
    #|
    #|pub let dependent : Int = A.value
  guard workspace.replace_sources([
      { source_id: "file:///A.lane", text: source_a },
      { source_id: "file:///B.lane", text: source_b },
    ])
    is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  let initial_dependent = definition_symbol(
    initial, "file:///B.lane", "dependent",
  )
  let broken_a =
    #|module A
    #|
    #|pub let value : Int = true
  guard workspace.upsert_source({ source_id: "file:///A.lane", text: broken_a })
    is Some(recovering) else {
    abort("expected type recovery semantic snapshot")
  }
  assert_eq(
    definition_symbol(recovering, "file:///B.lane", "dependent"),
    initial_dependent,
  )
  assert_false(recovering.diagnostics().is_empty())
  assert_true(
    recovering
    .diagnostics()
    .all(fn(diagnostic) { diagnostic.source_id == Some("file:///A.lane") }),
  )
}
