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
