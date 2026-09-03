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
    [{ source_id: "file:///List.lane", text: "module Basic.Data.List", }],
  )
  debug_inspect(
    parsed.sources.map(ParsedSource::diagnostics),
    content="[[], []]",
  )
  debug_inspect(
    parsed.sources.filter_map(ParsedSource::module_header),
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

///|
test "module input headers contain each directly imported module once" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module App.Main
        #|import Basic.Data.Bool.{ Bool }
        #|import Basic.Data.Bool.{ not }
        #|import Basic.Data.Bool as BoolModule
      ),
    },
    [],
  )
  debug_inspect(parsed.sources.map(ParsedSource::diagnostics), content="[[]]")
  debug_inspect(
    parsed.sources.filter_map(ParsedSource::module_header),
    content=(
      #|[
      #|  {
      #|    source_id: "file:///Main.lane",
      #|    module_path_text: "App.Main",
      #|    imports: ["Basic.Data.Bool"],
      #|  },
      #|]
    ),
  )
}

///|
test "language sugar does not synthesize module dependencies" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|pub let derived : Capability[Target] = derive[Capability, Target]()
        #|pub let operated : I64 = (1 + 2) * 3
      ),
    },
    [],
  )
  debug_inspect(parsed.sources.map(ParsedSource::diagnostics), content="[[]]")
  debug_inspect(
    parsed.sources.filter_map(ParsedSource::module_header),
    content=(
      #|[
      #|  {
      #|    source_id: "file:///Main.lane",
      #|    module_path_text: "Main",
      #|    imports: [],
      #|  },
      #|]
    ),
  )
}

///|
test "signed numeric literals do not require a module dependency" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: "module Main\npub let value : I64 = -1",
    },
    [],
  )
  debug_inspect(
    parsed.sources.filter_map(ParsedSource::module_header),
    content=(
      #|[
      #|  {
      #|    source_id: "file:///Main.lane",
      #|    module_path_text: "Main",
      #|    imports: [],
      #|  },
      #|]
    ),
  )
}
