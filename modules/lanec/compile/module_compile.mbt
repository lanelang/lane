///|
priv struct ModuleObject {
  module_path_text : String
  interface : @module_interface.ModuleInterface
  checked : @checked.CheckedSourceFile
}

///|
priv struct CompiledModuleSet {
  root : ModuleObject
  linked_libraries : Array[ModuleObject]
}

///|
fn compile_module_graph(
  graph : ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompileDiagnostic]] {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let objects : Array[ModuleObject] = []
  for input in graph.modules {
    let imported = imported_objects(input.header, objects)
    match compile_one_module(input, registry, imported) {
      Ok(object) => objects.push(object)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  guard find_module_object(objects, graph.root_module_path_text) is Some(root) else {
    return Err([make_error("no root source module", span=None)])
  }
  let linked_libraries = []
  for module_path_text in graph.reachable_module_path_texts {
    if module_path_text != graph.root_module_path_text {
      match find_module_object(objects, module_path_text) {
        Some(object) => linked_libraries.push(object)
        None =>
          return Err([
            make_error("missing import " + module_path_text, span=None),
          ])
      }
    }
  }
  Ok({ root, linked_libraries })
}

///|
fn imported_objects(
  header : ModuleHeader,
  objects : Array[ModuleObject],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if find_module_object(objects, import_.module_path_text) is Some(object) {
      imported.push(object.interface)
    }
  }
  { modules: imported }
}

///|
fn compile_one_module(
  input : ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imported : @module_interface.ImportedEnvironment,
) -> Result[ModuleObject, Array[CompileDiagnostic]] {
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported,
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
  let checked = @typecheck.typecheck_checked_source_file_with_imported_environment(
    resolved.source,
    imported,
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
  match (checked.source, checked.module_interface) {
    (Some(checked), Some(interface)) =>
      Ok({ module_path_text: input.header.module_path_text, interface, checked })
    _ => Err([make_error("checked source construction failed", span=None)])
  }
}

///|
fn find_module_object(
  objects : Array[ModuleObject],
  path : String,
) -> ModuleObject? {
  for object in objects {
    if object.module_path_text == path {
      return Some(object)
    }
  }
  None
}
