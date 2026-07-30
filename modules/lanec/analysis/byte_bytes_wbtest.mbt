///|
test "semantic hover preserves Byte and Bytes primitive names" {
  let workspace = SemanticWorkspace::new()
  let source =
    #|module Main
    #|
    #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
    #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
    #|pub fn use() -> Unit {
    #|  let byte = i64_to_byte(255)
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
        text: "module Main\n\npub let value : I64 = 0",
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
      ("F32", Type, Some("primitive type F32")),
      ("F64", Type, Some("primitive type F64")),
      ("I32", Type, Some("primitive type I32")),
      ("I64", Type, Some("primitive type I64")),
      ("Bool", Type, Some("primitive type Bool")),
      ("Byte", Type, Some("primitive type Byte")),
      ("Char", Type, Some("primitive type Char")),
      ("Unit", Type, Some("primitive type Unit")),
      ("Bytes", Type, Some("primitive type Bytes")),
      ("String", Type, Some("primitive type String")),
    ],
  )
}

///|
test "semantic analysis preserves I32 and Char identity" {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      {
        source_id: "file:///Main.lane",
        text: (
          #|module Main
          #|
          #|pub fn convert(value : I32) -> Char {
          #|  match value {
          #|    _ => '你'
          #|  }
          #|}
        ),
      },
    ])
    is Some(snapshot) else {
    fail("expected semantic snapshot")
  }
  debug_inspect(
    snapshot.analysis(),
    content=(
      #|{
      #|  diagnostics: [],
      #|  definitions: [
      #|    {
      #|      symbol: Value({ index: 0 }),
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 20,
      #|          end_offset: 27,
      #|          start_line: 3,
      #|          start_column: 8,
      #|          end_line: 3,
      #|          end_column: 15,
      #|        },
      #|      },
      #|      label: "convert",
      #|      detail: "convert : (I32) -> Char",
      #|    },
      #|    {
      #|      symbol: Value({ index: 1 }),
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 28,
      #|          end_offset: 33,
      #|          start_line: 3,
      #|          start_column: 16,
      #|          end_line: 3,
      #|          end_column: 21,
      #|        },
      #|      },
      #|      label: "value",
      #|      detail: "value : I32",
      #|    },
      #|  ],
      #|  references: [
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 59,
      #|          end_offset: 64,
      #|          start_line: 4,
      #|          start_column: 9,
      #|          end_line: 4,
      #|          end_column: 14,
      #|        },
      #|      },
      #|      symbol: Value({ index: 1 }),
      #|      hover: Some("value : I32"),
      #|    },
      #|  ],
      #|  hovers: [
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 20,
      #|          end_offset: 27,
      #|          start_line: 3,
      #|          start_column: 8,
      #|          end_line: 3,
      #|          end_column: 15,
      #|        },
      #|      },
      #|      contents: "convert : (I32) -> Char",
      #|    },
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 28,
      #|          end_offset: 33,
      #|          start_line: 3,
      #|          start_column: 16,
      #|          end_line: 3,
      #|          end_column: 21,
      #|        },
      #|      },
      #|      contents: "value : I32",
      #|    },
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 59,
      #|          end_offset: 64,
      #|          start_line: 4,
      #|          start_column: 9,
      #|          end_line: 4,
      #|          end_column: 14,
      #|        },
      #|      },
      #|      contents: "value : I32",
      #|    },
      #|  ],
      #|  semantic_tokens: [
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 28,
      #|          end_offset: 33,
      #|          start_line: 3,
      #|          start_column: 16,
      #|          end_line: 3,
      #|          end_column: 21,
      #|        },
      #|      },
      #|      kind: ParameterToken,
      #|    },
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 59,
      #|          end_offset: 64,
      #|          start_line: 4,
      #|          start_column: 9,
      #|          end_line: 4,
      #|          end_column: 14,
      #|        },
      #|      },
      #|      kind: ParameterToken,
      #|    },
      #|  ],
      #|  inlay_hints: [],
      #|}
    ),
  )
}
