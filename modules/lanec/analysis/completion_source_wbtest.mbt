///|
fn complete_test_source_inputs(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([root_source] + library_sources)
    is Some(snapshot) else {
    return []
  }
  snapshot.complete(source_id, line, column, trigger)
}

///|
test "completion source indexes parser tokens and line positions" {
  let text = "module Main\r\nimport Lib\r\n\r\npub fn answer(seed : I64) -> I64 {\r\n  ans\r\n}"
  let parsed = @module_frontend.parse_module_inputs(
    { source_id: "file:///Main.lane", text },
    [],
  )
  guard parsed.modules.get(0) is Some(input) else {
    abort("expected parsed completion source")
  }
  let source = CompletionSource::from_input(input)
  let cursor = source.offset(5, 6)
  assert_eq(cursor, 68)
  assert_eq(source.span(65, cursor), {
    start_offset: 65,
    end_offset: 68,
    start_line: 5,
    start_column: 3,
    end_line: 5,
    end_column: 6,
  })
  let import_cursor = source.offset(2, 11)
  assert_true(
    source.line_starts_with_import(2, source.token_count_before(import_cursor)),
  )
  assert_false(
    source.line_starts_with_import(
      3,
      source.token_count_before(source.offset(3, 1)),
    ),
  )
}
