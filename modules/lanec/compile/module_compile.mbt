///|
priv struct ModuleObject {
  path : String
  resolved : @resolve.ResolvedSourceFile
  checked : @checked.CheckedSourceFile
}

///|
priv struct CompiledModuleSet {
  root : ModuleObject
  libraries : Array[ModuleObject]
}

///|
fn compile_module_graph(
  graph : ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompileDiagnostic]] {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let objects : Array[ModuleObject] = []
  for input in graph.modules {
    let imported = imported_objects(input.source, objects)
    match compile_one_module(input, registry, imported) {
      Ok(object) => objects.push(object)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  guard find_module_object(objects, graph.root_path) is Some(root) else {
    return Err([make_error("no root source module", span=None)])
  }
  let libraries = []
  for object in objects {
    if object.path != graph.root_path {
      libraries.push(object)
    }
  }
  Ok({ root, libraries })
}

///|
fn imported_objects(
  source : @syntax.SourceFile,
  objects : Array[ModuleObject],
) -> Array[ModuleObject] {
  let imported = []
  for import_ in module_import_paths(source) {
    if find_module_object(objects, import_.path) is Some(object) {
      imported.push(object)
    }
  }
  imported
}

///|
fn compile_one_module(
  input : ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imported : Array[ModuleObject],
) -> Result[ModuleObject, Array[CompileDiagnostic]] {
  let imported_sources = imported.map(fn(object) { object.resolved })
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported_sources,
  )
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  let checked = @typecheck.typecheck_checked_source_file_with_imports(
    resolved.source,
    imported_sources,
  )
  let typecheck_diagnostics = checked.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !typecheck_diagnostics.is_empty() {
    return Err(typecheck_diagnostics)
  }
  match checked.source {
    Some(checked) =>
      Ok({ path: input.path, resolved: resolved.source, checked })
    None => Err([make_error("checked source construction failed", span=None)])
  }
}

///|
fn find_module_object(
  objects : Array[ModuleObject],
  path : String,
) -> ModuleObject? {
  for object in objects {
    if object.path == path {
      return Some(object)
    }
  }
  None
}
