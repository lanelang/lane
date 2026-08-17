///|
test "dependency failure provenance does not own diagnostic policy" {
  let source = ModuleDependencyFailure::missing_import(
    "Missing",
    source_modules=["Main"],
    interface_modules=[],
    provenance=SourceInput(source_id="file:///Main.lane", span=None),
  )
  let interface = ModuleDependencyFailure::missing_import(
    "Missing",
    source_modules=["Main"],
    interface_modules=[],
    provenance=InterfaceArtifact(
      source_id="file:///Main.lane",
      importer_module_path_text="Dependency",
      span=None,
    ),
  )
  assert_false(source == interface)
  assert_eq(source.kind, interface.kind)
  assert_eq(source.diagnostic(), interface.diagnostic())
}

///|
test "validated module graph dependency facts are mutation isolated" {
  guard parse_import_reachable_module_graph_from_inputs(
      {
        source_id: "file:///Main.lane",
        text: "module Main\nimport Dependency\npub let answer : I64 = 42",
      },
      [
        {
          source_id: "file:///Dependency.lane",
          text: "module Dependency\npub let value : I64 = 1",
        },
      ],
    )
    is Ok(graph) else {
    fail("expected a validated module graph")
  }
  let detached = graph.modules()
  detached[1].header.imports.push(detached[1].header.imports[0])
  ignore(detached.pop())
  assert_eq(
    graph
    .modules()
    .map(fn(module_) {
      (
        module_.header.module_path_text,
        module_.header.imports.map(fn(import_) { import_.module_path_text }),
      )
    }),
    [("Dependency", []), ("Main", ["Dependency"])],
  )
}
