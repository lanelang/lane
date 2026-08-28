///|
test "semantic tools present the builtin Array constructor" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|let array_empty : [Element]() -> Array[Element] = builtin("%array_empty")
    #|pub fn use() -> Array[I64] {
    #|  let values = array_empty[I64]()
    #|  values
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source, },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(snapshot.diagnostics(), [])
  assert_eq(
    snapshot.hover_at("file:///Main.lane", 5, 7).map(hover => hover.contents),
    Some("values : Array[I64]"),
  )
  assert_eq(snapshot.inlay_hints_in_range("file:///Main.lane", 1, 0, 8, 0), [
    {
      position: { source_id: "file:///Main.lane", line: 5, column: 13, },
      kind: TypeHint,
      label: ": Array[I64]",
    },
  ])
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: "module Main\n\npub let value : Arr",
    })
    is Some(completion_snapshot) else {
    fail("expected completion snapshot")
  }
  assert_eq(
    completion_snapshot
    .complete("file:///Main.lane", 3, 19, Manual)
    .filter(entry => entry.label == "Array"),
    [
      {
        label: "Array",
        kind: Type,
        is_offered: false,
        detail: Some("builtin type constructor Array : [Type] -> Type"),
        documentation: None,
        insert_text: None,
        replace: Some({
          source_id: "file:///Main.lane",
          span: {
            start_offset: 29,
            end_offset: 31,
            start_line: 3,
            start_column: 17,
            end_line: 3,
            end_column: 19,
          },
        }),
        sort_text: Some("30:Array"),
      },
    ],
  )
}
