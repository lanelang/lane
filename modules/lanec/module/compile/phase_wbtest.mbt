///|
fn module_phase_test_graph() -> @module_frontend.ModuleGraph {
  let root : @module_frontend.SourceInput = {
    source_id: "main.lane",
    text: (
      #|module Main
      #|import Lib.{ Wrapper }
      #|pub fn keep(value : Wrapper) -> Wrapper {
      #|  value
      #|}
    ),
  }
  let library : @module_frontend.SourceInput = {
    source_id: "lib.lane",
    text: (
      #|module Lib
      #|import Dependency.{ Token }
      #|pub struct Wrapper {
      #|  value : Token
      #|}
    ),
  }
  let dependency : @module_frontend.SourceInput = {
    source_id: "dependency.lane",
    text: (
      #|module Dependency
      #|pub struct Token {
      #|  value : I64
      #|}
    ),
  }
  let inputs = match
    @module_frontend.parse_module_input_set_from_inputs(root, [
      library, dependency,
    ]) {
    Ok(inputs) => inputs
    Err(diagnostics) =>
      abort("unexpected parse diagnostics: \{Repr(diagnostics)}")
  }
  match @module_frontend.build_module_graph(inputs) {
    Ok(graph) => graph
    Err(diagnostics) =>
      abort("unexpected graph diagnostics: \{Repr(diagnostics)}")
  }
}

///|
test "checked modules lower into complete compiled modules" {
  let checked = match
    check_module_graph(module_phase_test_graph(), (_, _) => ()) {
    Ok(checked) => checked
    Err(diagnostics) =>
      fail("unexpected check diagnostics: \{Repr(diagnostics)}")
  }
  let compiled = match lower_checked_modules(checked.modules, (_, _) => ()) {
    Ok(compiled) => compiled
    Err(diagnostic) =>
      fail("unexpected lowering diagnostic: \{Repr(diagnostic)}")
  }
  debug_inspect(
    compiled.map(fn(module_) {
      (
        module_.object.module_path_text,
        module_.object.metadata.types.length(),
        module_.object.terms.length(),
        module_.object.exports.length(),
      )
    }),
    content=(
      #|[("Dependency", 1, 1, 3), ("Lib", 2, 1, 3), ("Main", 2, 1, 1)]
    ),
  )
}

///|
test "lowering failure exposes no partial compiled module" {
  let checked = match
    check_module_graph(module_phase_test_graph(), (_, _) => ()) {
    Ok(checked) => checked
    Err(diagnostics) =>
      fail("unexpected check diagnostics: \{Repr(diagnostics)}")
  }
  guard find_checked_module(checked.modules, "Main") is Some(main) else {
    fail("expected checked Main module")
  }
  guard find_checked_module(checked.modules, "Lib") is Some(library) else {
    fail("expected checked Lib module")
  }
  let result = lower_checked_modules([main, library], (_, _) => ())
  guard result is Err(diagnostic) else {
    fail("expected lowering to reject the missing imported phase input")
  }
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: None,
      #|  message: "missing Buslane interface dependency",
      #|  span: None,
      #|  severity: Error,
      #|  code: Some("E4501"),
      #|  labels: [],
      #|  notes: ["a public imported signature references an unavailable interface dependency"],
      #|  helps: ["provide the complete transitive interface closure and report this if all source dependencies are present"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
    ),
  )
}
