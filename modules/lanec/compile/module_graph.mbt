///|
priv struct ModuleGraph {
  root_path : String
  modules : Array[ParsedModuleInput]
}

///|
fn build_module_graph(
  inputs : ModuleInputSet,
) -> Result[ModuleGraph, Array[CompileDiagnostic]] {
  let graph_diagnostics = validate_module_inputs(inputs.modules)
  if !graph_diagnostics.is_empty() {
    return Err(graph_diagnostics)
  }
  let reachable = reachable_modules(inputs.modules, inputs.root_path)
  if !reachable.diagnostics.is_empty() {
    return Err(reachable.diagnostics)
  }
  Ok({ root_path: inputs.root_path, modules: reachable.modules })
}

///|
fn validate_module_inputs(
  modules : Array[ParsedModuleInput],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for index in 0..<modules.length() {
    for other_index in (index + 1)..<modules.length() {
      if modules[index].path == modules[other_index].path {
        diagnostics.push(
          make_error(
            "duplicate module input " + modules[index].path,
            span=Some(modules[other_index].source.module_path.loc),
          ),
        )
      }
    }
  }
  for module_ in modules {
    for import_ in module_import_paths(module_.source) {
      if find_module(modules, import_.path) is None {
        diagnostics.push(
          make_error("missing import " + import_.path, span=Some(import_.loc)),
        )
      }
    }
  }
  diagnostics
}

///|
priv struct ImportPath {
  path : String
  loc : @basic.SourceSpan
}

///|
fn module_import_paths(source : @syntax.SourceFile) -> Array[ImportPath] {
  source.imports.map(fn(import_) {
    let path = match import_ {
      Qualified(module_path~, ..)
      | Open(module_path~, ..)
      | Selective(module_path~, ..) => module_path
    }
    { path: module_path_text(path), loc: import_.loc() }
  })
}

///|
priv struct ReachableModulesResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[CompileDiagnostic]
}

///|
fn reachable_modules(
  modules : Array[ParsedModuleInput],
  root_path : String,
) -> ReachableModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  visit_module(modules, root_path, visiting, visited, ordered, diagnostics)
  { modules: ordered, diagnostics }
}

///|
fn visit_module(
  modules : Array[ParsedModuleInput],
  path : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[ParsedModuleInput],
  diagnostics : Array[CompileDiagnostic],
) -> Unit {
  if visited.contains(path) {
    return
  }
  if visiting.contains(path) {
    diagnostics.push(make_error("import cycle " + path, span=None))
    return
  }
  guard find_module(modules, path) is Some(module_) else {
    diagnostics.push(make_error("missing import " + path, span=None))
    return
  }
  visiting.push(path)
  for import_ in module_import_paths(module_.source) {
    visit_module(modules, import_.path, visiting, visited, ordered, diagnostics)
  }
  ignore(visiting.pop())
  visited.push(path)
  ordered.push(module_)
}

///|
fn find_module(
  modules : Array[ParsedModuleInput],
  path : String,
) -> ParsedModuleInput? {
  for module_ in modules {
    if module_.path == path {
      return Some(module_)
    }
  }
  None
}
