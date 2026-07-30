///|
test "semantic hover preserves Byte and Bytes primitive names" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|let int_to_byte : (Int) -> Byte = builtin("%int_to_byte")
    #|let bytes_make : (Int, Byte) -> Bytes = builtin("%bytes_make")
    #|pub fn use() -> Unit {
    #|  let byte = int_to_byte(255)
    #|  let bytes = bytes_make(2, byte)
    #|  let _ = bytes
    #|  ()
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: source },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  assert_eq(
    snapshot.hover_at("file:///Main.lane", 6, 7).map(hover => hover.contents),
    Some("byte : Byte"),
  )
  assert_eq(
    snapshot.hover_at("file:///Main.lane", 7, 7).map(hover => hover.contents),
    Some("bytes : Bytes"),
  )
}

///|
test "type-space completion includes every primitive type" {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      {
        source_id: "file:///Main.lane",
        text: "module Main\n\npub let value : Int = 0",
      },
    ])
    is Some(_) else {
    fail("expected initial semantic snapshot")
  }
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: "module Main\n\npub let value :",
    })
    is Some(snapshot) else {
    fail("expected edited semantic snapshot")
  }
  assert_eq(
    snapshot
    .complete("file:///Main.lane", 3, 16, Manual)
    .filter(entry => {
      entry.detail.map_or(false, detail => detail.has_prefix("primitive type "))
    })
    .map(entry => (entry.label, entry.kind, entry.detail)),
    [
      ("Int", Type, Some("primitive type Int")),
      ("S32", Type, Some("primitive type S32")),
      ("Bool", Type, Some("primitive type Bool")),
      ("Byte", Type, Some("primitive type Byte")),
      ("Char", Type, Some("primitive type Char")),
      ("Unit", Type, Some("primitive type Unit")),
      ("Bytes", Type, Some("primitive type Bytes")),
      ("Double", Type, Some("primitive type Double")),
      ("String", Type, Some("primitive type String")),
    ],
  )
}
