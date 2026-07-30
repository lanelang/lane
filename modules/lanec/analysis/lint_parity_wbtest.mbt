///|
test "compiler and semantic workspace share lint diagnostics" {
  let root : @module_frontend.SourceInput = {
    source_id: "main.lane",
    text: (
      #|module Main
      #|import Lib.*
      #|
      #|fn[A] hidden(value : I64) -> I64 {
      #|  let local = 1
      #|  value
      #|}
      #|
      #|pub fn answer() -> I64 {
      #|  42
      #|}
    ),
  }
  let library : @module_frontend.SourceInput = {
    source_id: "lib.lane",
    text: (
      #|module Lib
      #|pub let value : I64 = 1
    ),
  }
  let input_set = match
    @module_frontend.parse_module_input_set_from_inputs(root, [library]) {
    Ok(input_set) => input_set
    Err(diagnostics) =>
      abort("unexpected parse diagnostics: \{Repr(diagnostics)}")
  }
  let graph = match @module_frontend.build_module_graph(input_set) {
    Ok(graph) => graph
    Err(diagnostics) =>
      abort("unexpected module graph diagnostics: \{Repr(diagnostics)}")
  }
  let compiled = match @module_compile.compile_module_graph(graph) {
    Ok(compiled) => compiled
    Err(diagnostics) =>
      abort("unexpected compile diagnostics: \{Repr(diagnostics)}")
  }
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([root, library]) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  assert_eq(compiled.diagnostics.map(fn(diagnostic) { diagnostic.code }), [
    Some("W2001"),
    Some("W2002"),
    Some("W2003"),
    Some("W2004"),
  ])
  assert_eq(snapshot.analysis().diagnostics, compiled.diagnostics)
}
