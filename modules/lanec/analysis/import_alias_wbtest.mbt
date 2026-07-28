///|
fn import_alias_snapshot(
  root : String,
  libraries : Array[(String, String)],
) -> SemanticSnapshot {
  let workspace = SemanticWorkspace::new()
  let sources : Array[@module_frontend.SourceInput] = [
    { source_id: "file:///Main.lane", text: root },
  ]
  for library in libraries {
    let (source_id, text) = library
    sources.push({ source_id, text })
  }
  guard workspace.replace_sources(sources) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot
}

///|
fn import_alias_library() -> String {
  (
    #|module Basic.Long.Library
    #|
    #|pub struct Item {
    #|  value : Int
    #|}
    #|
    #|pub enum Choice {
    #|  choose()
    #|}
    #|
    #|pub effect Read {
    #|  read() -> Int
    #|}
    #|
    #|pub fn answer() -> Int { 42 }
  )
}

///|
test "module alias qualifiers navigate to their source binder" {
  let root =
    #|module Main
    #|import Basic.Long.Library as Lib
    #|
    #|pub fn answer() -> Int { Lib.answer() }
    #|pub fn keep(value : Lib.Item) -> Lib.Item { value }
    #|pub fn choose() -> Lib.Choice { Lib.Choice::choose() }
    #|pub fn read() -> Unit ! Lib.Read { () }
    #|pub fn inspect(value : Lib.Choice) -> Unit {
    #|  match value {
    #|    Lib.Choice::choose() => ()
    #|  }
    #|}
  let snapshot = import_alias_snapshot(root, [
    ("file:///Library.lane", import_alias_library()),
  ])
  let alias_definition : AnalysisLocation = {
    source_id: "file:///Main.lane",
    span: {
      start_offset: 41,
      end_offset: 44,
      start_line: 2,
      start_column: 30,
      end_line: 2,
      end_column: 33,
    },
  }
  assert_eq(
    snapshot.definition_at("file:///Main.lane", 4, 26),
    Some(alias_definition),
  )
  assert_eq(
    snapshot.definition_at("file:///Main.lane", 5, 23),
    Some(alias_definition),
  )
  assert_eq(
    snapshot.definition_at("file:///Main.lane", 6, 34),
    Some(alias_definition),
  )
  assert_eq(
    snapshot.definition_at("file:///Main.lane", 7, 25),
    Some(alias_definition),
  )
  assert_eq(
    snapshot.definition_at("file:///Main.lane", 10, 6),
    Some(alias_definition),
  )
  guard snapshot.hover_at("file:///Main.lane", 4, 26) is Some(hover) else {
    abort("expected alias hover")
  }
  assert_eq(hover.contents, "module Lib = Basic.Long.Library")
}

///|
test "qualified members keep their original definitions through an alias" {
  let root =
    #|module Main
    #|import Basic.Long.Library as Lib
    #|
    #|pub fn answer() -> Int { Lib.answer() }
    #|pub fn keep(value : Lib.Item) -> Lib.Item { value }
    #|pub fn choose() -> Lib.Choice { Lib.Choice::choose() }
  let snapshot = import_alias_snapshot(root, [
    ("file:///Library.lane", import_alias_library()),
  ])
  guard snapshot.definition_at("file:///Main.lane", 4, 32) is Some(answer) else {
    abort("expected answer definition")
  }
  assert_eq(answer.source_id, "file:///Library.lane")
  assert_eq((answer.span.start_line, answer.span.start_column), (15, 8))
  guard snapshot.definition_at("file:///Main.lane", 5, 27) is Some(item) else {
    abort("expected Item definition")
  }
  assert_eq(item.source_id, "file:///Library.lane")
  assert_eq((item.span.start_line, item.span.start_column), (3, 12))
  guard snapshot.definition_at("file:///Main.lane", 6, 46) is Some(choose) else {
    abort("expected choose definition")
  }
  assert_eq(choose.source_id, "file:///Library.lane")
  assert_eq((choose.span.start_line, choose.span.start_column), (8, 3))
}

///|
test "completion exposes an alias and completes its canonical interface" {
  let root =
    #|module Main
    #|import Basic.Long.Library as Lib
    #|
    #|pub fn use() -> Int { Lib.answer() }
  let libraries : Array[@module_frontend.SourceInput] = [
    { source_id: "file:///Library.lane", text: import_alias_library() },
  ]
  let module_entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    libraries,
    "file:///Main.lane",
    4,
    26,
    Manual,
  ).filter(fn(entry) { entry.kind is Module })
  debug_inspect(
    module_entries.map(fn(entry) { (entry.label, entry.detail) }),
    content=(
      #|[("Lib", Some("module Lib = Basic.Long.Library"))]
    ),
  )
  let surface_entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    libraries,
    "file:///Main.lane",
    4,
    27,
    TriggerCharacter("."),
  )
  assert_true(
    surface_entries.any(fn(entry) {
      entry.label == "answer" && entry.kind is Function
    }),
  )
  assert_true(
    surface_entries.any(fn(entry) {
      entry.label == "Item" && entry.kind is Type
    }),
  )
  assert_true(
    surface_entries.any(fn(entry) {
      entry.label == "Read" && entry.kind is Effect
    }),
  )
}

///|
test "completion consumes open and selective module exposures" {
  let root =
    #|module Main
    #|import Basic.Long.Library.*
    #|import Basic.Other.{ value }
    #|
    #|pub fn use() -> Int {
    #|  Bas
    #|}
  let other =
    #|module Basic.Other
    #|
    #|pub let value : Int = 1
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    [
      { source_id: "file:///Library.lane", text: import_alias_library() },
      { source_id: "file:///Other.lane", text: other },
    ],
    "file:///Main.lane",
    6,
    6,
    Manual,
  ).filter(fn(entry) { entry.kind is Module })
  debug_inspect(
    entries,
    content=(
      #|[
      #|  {
      #|    label: "Basic.Other",
      #|    kind: Module,
      #|    is_offered: false,
      #|    detail: Some("module Basic.Other"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 94,
      #|          end_offset: 97,
      #|          start_line: 6,
      #|          start_column: 3,
      #|          end_line: 6,
      #|          end_column: 6,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("40:Basic.Other"),
      #|  },
      #|  {
      #|    label: "Basic.Long.Library",
      #|    kind: Module,
      #|    is_offered: false,
      #|    detail: Some("module Basic.Long.Library"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 94,
      #|          end_offset: 97,
      #|          start_line: 6,
      #|          start_column: 3,
      #|          end_line: 6,
      #|          end_column: 6,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("40:Basic.Long.Library"),
      #|  },
      #|]
    ),
  )
}

///|
test "canonical tuple sugar marks every provider alias as used" {
  let root =
    #|module Main
    #|import Basic.Data.Tuple as First
    #|import Basic.Data.Tuple as Second
    #|
    #|pub fn pair() -> (Int, Bool) { (1, true) }
  let tuple =
    #|module Basic.Data.Tuple
    #|pub enum Tuple[A, B] {
    #|  tuple(A, B)
    #|}
  let snapshot = import_alias_snapshot(root, [("file:///Tuple.lane", tuple)])
  assert_eq(
    snapshot.analysis().diagnostics.filter(fn(diagnostic) {
      diagnostic.code == Some("W2004")
    }),
    [],
  )
}

///|
test "unused import diagnostics name the local module alias" {
  let root =
    #|module Main
    #|import Basic.Long.Library as Lib
    #|pub let answer : Int = 42
  let snapshot = import_alias_snapshot(root, [
    ("file:///Library.lane", import_alias_library()),
  ])
  let warnings = snapshot.analysis().diagnostics.filter(fn(diagnostic) {
    diagnostic.code == Some("W2004")
  })
  debug_inspect(
    warnings.map(fn(diagnostic) {
      (diagnostic.message, diagnostic.labels.map(fn(label) { label.message }))
    }),
    content=(
      #|[("unused import", ["imported module binding `Lib` is never used"])]
    ),
  )
}
