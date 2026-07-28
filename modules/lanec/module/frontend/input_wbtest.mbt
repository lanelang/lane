///|
test "fallback module header uses lexical module path tokens" {
  debug_inspect(
    source_module_header({
      source_id: "file:///Main.lane",
      text: "// leading comment\nmodule App.Main // trailing comment\npub fn broken(",
    }),
    content=(
      #|Some(
      #|  {
      #|    source_id: "file:///Main.lane",
      #|    module_path_text: "App.Main",
      #|    imports: [],
      #|  },
      #|)
    ),
  )
}

///|
test "fallback module header rejects incomplete module paths" {
  debug_inspect(
    source_module_header({
      source_id: "file:///Main.lane",
      text: "module App.\npub fn broken(",
    }),
    content="None",
  )
}

///|
test "module input headers keep aliased imports canonical" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: "module App.Main\nimport Basic.Data.List as List",
    },
    [{ source_id: "file:///List.lane", text: "module Basic.Data.List" }],
  )
  debug_inspect(parsed.diagnostics, content="[]")
  debug_inspect(
    parsed.headers,
    content=(
      #|[
      #|  {
      #|    source_id: "file:///Main.lane",
      #|    module_path_text: "App.Main",
      #|    imports: ["Basic.Data.List"],
      #|  },
      #|  {
      #|    source_id: "file:///List.lane",
      #|    module_path_text: "Basic.Data.List",
      #|    imports: [],
      #|  },
      #|]
    ),
  )
}
