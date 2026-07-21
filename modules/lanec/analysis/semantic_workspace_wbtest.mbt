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
test "semantic workspace reuses module topology for body-only edits" {
  let workspace = SemanticWorkspace::new()
  let main_source =
    #|module Main
    #|
    #|pub let value : Int = 1
  let library_source =
    #|module Library
    #|
    #|pub let value : Int = 2
  guard workspace.replace_sources([
      { source_id: "file:///0-Main.lane", text: main_source },
      { source_id: "file:///1-Library.lane", text: library_source },
    ])
    is Some(_) else {
    abort("expected initial semantic snapshot")
  }
  guard workspace.graph_cache is Some(initial_graph_cache) else {
    abort("expected initial module graph cache")
  }
  let changed_body =
    #|module Main
    #|
    #|pub let value : Int = 3
  guard workspace.upsert_source({
      source_id: "file:///0-Main.lane",
      text: changed_body,
    })
    is Some(_) else {
    abort("expected snapshot after body edit")
  }
  guard workspace.graph_cache is Some(reused_graph_cache) else {
    abort("expected reused module graph cache")
  }
  let changed_imports =
    #|module Main
    #|
    #|import Library
    #|
    #|pub let value : Int = Library.value
  guard workspace.upsert_source({
      source_id: "file:///0-Main.lane",
      text: changed_imports,
    })
    is Some(_) else {
    abort("expected snapshot after import edit")
  }
  guard workspace.graph_cache is Some(rebuilt_graph_cache) else {
    abort("expected rebuilt module graph cache")
  }
  debug_inspect(
    [
      physical_equal(initial_graph_cache, reused_graph_cache),
      physical_equal(reused_graph_cache, rebuilt_graph_cache),
    ],
    content="[true, false]",
  )
}

///|
test "semantic workspace persistently replaces only dirty snapshot branches" {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      { source_id: "file:///A.lane", text: "module A\n\npub let a : Int = 1" },
      { source_id: "file:///B.lane", text: "module B\n\npub let b : Int = 2" },
      { source_id: "file:///C.lane", text: "module C\n\npub let c : Int = 3" },
      { source_id: "file:///D.lane", text: "module D\n\npub let d : Int = 4" },
    ])
    is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  guard initial.parsed_sources is Branch(left=initial_parsed_left, ..) &&
    initial.modules is Branch(left=initial_modules_left, ..) else {
    abort("expected branched semantic snapshot")
  }
  guard workspace.upsert_source({
      source_id: "file:///D.lane",
      text: "module D\n\npub let d : Int = 5",
    })
    is Some(updated) else {
    abort("expected updated semantic snapshot")
  }
  guard updated.parsed_sources is Branch(left=updated_parsed_left, ..) &&
    updated.modules is Branch(left=updated_modules_left, ..) else {
    abort("expected updated branched semantic snapshot")
  }
  debug_inspect(
    [
      physical_equal(initial_parsed_left, updated_parsed_left),
      physical_equal(initial_modules_left, updated_modules_left),
      updated.changed_source_ids == ["file:///D.lane"],
    ],
    content="[true, true, true]",
  )
}

///|
test "semantic workspace reuses unchanged invalid module topology" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|import Missing
    #|
    #|pub let value : Int = 1
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source },
    ])
    is Some(initial_snapshot) else {
    abort("expected initial semantic snapshot")
  }
  assert_false(initial_snapshot.diagnostics().is_empty())
  guard workspace.graph_cache is Some(initial_graph_cache) else {
    abort("expected invalid module graph cache")
  }
  let changed_body =
    #|module Main
    #|
    #|import Missing
    #|
    #|pub let value : Int = 2
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: changed_body,
    })
    is Some(updated_snapshot) else {
    abort("expected semantic snapshot after body edit")
  }
  assert_false(updated_snapshot.diagnostics().is_empty())
  guard workspace.graph_cache is Some(reused_graph_cache) else {
    abort("expected reused invalid module graph cache")
  }
  debug_inspect(
    physical_equal(initial_graph_cache, reused_graph_cache),
    content="true",
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
