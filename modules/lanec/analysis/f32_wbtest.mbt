///|
test "semantic hover preserves F32 identity" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|let f32_add : (F32, F32) -> F32 = builtin("%f32_add")
    #|pub fn use() -> F32 {
    #|  let value : F32 = f32_add(1.25f32, 2.5f32)
    #|  value
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(
    snapshot.hover_at("file:///Main.lane", 5, 7).map(hover => hover.contents),
    Some("value : F32"),
  )
}
