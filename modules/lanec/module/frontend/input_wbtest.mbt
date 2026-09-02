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
test "derive module header includes every canonical compiler dependency" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: "module Main\npub let value : Capability[Target] = derive[Capability, Target]()",
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
      #|    imports: ["Basic.Trait.Derive", "Basic.Trait.Iso", "Basic.Data.Void"],
      #|  },
      #|]
    ),
  )
}

///|
test "operator syntax adds the canonical Basic Ops dependency once" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Main.lane",
      text: "module Main\npub let value : I64 = (1 + 2) * 3",
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
      #|    imports: ["Basic.Ops"],
      #|  },
      #|]
    ),
  )
}

///|
test "signed numeric literals do not add an operator dependency" {
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

///|
test "canonical Basic Ops does not depend on itself" {
  let parsed = parse_module_inputs(
    {
      source_id: "file:///Ops.lane",
      text: "module Basic.Ops\npub fn op_not(value : Bool) -> Bool { !value }",
    },
    [],
  )
  debug_inspect(
    parsed.sources.filter_map(ParsedSource::module_header),
    content=(
      #|[
      #|  {
      #|    source_id: "file:///Ops.lane",
      #|    module_path_text: "Basic.Ops",
      #|    imports: [],
      #|  },
      #|]
    ),
  )
}
