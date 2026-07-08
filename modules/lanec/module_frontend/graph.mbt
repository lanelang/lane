///|
pub(all) struct ModuleGraph {
  root_module_path_text : String
  modules : Array[ParsedModuleInput]
  reachable_module_path_texts : Array[String]
}

///|
pub fn build_module_graph(
  inputs : ModuleInputSet,
) -> Result[ModuleGraph, Array[@compiler_diag.CompilerDiagnostic]] {
  let graph_diagnostics = validate_module_inputs(inputs.modules)
  if !graph_diagnostics.is_empty() {
    return Err(graph_diagnostics)
  }
  let ordered = topological_modules(inputs.modules)
  if !ordered.diagnostics.is_empty() {
    return Err(ordered.diagnostics)
  }
  let reachable = reachable_modules(
    inputs.modules,
    inputs.root_module_path_text,
  )
  if !reachable.diagnostics.is_empty() {
    return Err(reachable.diagnostics)
  }
  Ok({
    root_module_path_text: inputs.root_module_path_text,
    modules: ordered.modules,
    reachable_module_path_texts: reachable.modules.map(fn(module_) {
      module_.header.module_path_text
    }),
  })
}

///|
fn validate_module_inputs(
  modules : Array[ParsedModuleInput],
) -> Array[@compiler_diag.CompilerDiagnostic] {
  let diagnostics = []
  for index in 0..<modules.length() {
    for other_index in (index + 1)..<modules.length() {
      if modules[index].header.module_path_text ==
        modules[other_index].header.module_path_text {
        let diagnostic = module_frontend_diagnostic(
          DuplicateModuleInput(modules[index].header.module_path_text),
          Some(modules[other_index].header.module_span),
        ).with_source_id(modules[other_index].source_id)
        diagnostics.push(diagnostic)
      }
    }
  }
  for module_ in modules {
    for import_ in module_.header.imports {
      if find_module(modules, import_.module_path_text) is None {
        let diagnostic = module_frontend_diagnostic(
          MissingImportWithCandidates(
            module_=import_.module_path_text,
            source_modules=module_candidates(modules),
            interface_modules=[],
          ),
          Some(import_.import_span),
        ).with_source_id(module_.source_id)
        diagnostics.push(diagnostic)
      }
    }
  }
  diagnostics
}

///|
priv struct ReachableModulesResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
}

///|
priv struct OrderedModulesResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
}

///|
fn topological_modules(
  modules : Array[ParsedModuleInput],
) -> OrderedModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  for module_ in modules {
    visit_module(
      modules,
      module_.header.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  { modules: ordered, diagnostics }
}

///|
fn reachable_modules(
  modules : Array[ParsedModuleInput],
  root_module_path_text : String,
) -> ReachableModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  visit_module(
    modules, root_module_path_text, visiting, visited, ordered, diagnostics,
  )
  { modules: ordered, diagnostics }
}

///|
fn visit_module(
  modules : Array[ParsedModuleInput],
  path : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[ParsedModuleInput],
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> Unit {
  if visited.contains(path) {
    return
  }
  guard find_module(modules, path) is Some(module_) else {
    diagnostics.push(
      module_frontend_diagnostic(
        MissingImportWithCandidates(
          module_=path,
          source_modules=module_candidates(modules),
          interface_modules=[],
        ),
        None,
      ),
    )
    return
  }
  if visiting.contains(path) {
    let diagnostic = module_frontend_diagnostic(ImportCycle(path), None).with_source_id(
      module_.source_id,
    )
    diagnostics.push(diagnostic)
    return
  }
  visiting.push(path)
  for import_ in module_.header.imports {
    visit_module(
      modules,
      import_.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
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
    if module_.header.module_path_text == path {
      return Some(module_)
    }
  }
  None
}

///|
fn module_candidates(modules : Array[ParsedModuleInput]) -> Array[String] {
  modules.map(fn(module_) { module_.header.module_path_text })
}
