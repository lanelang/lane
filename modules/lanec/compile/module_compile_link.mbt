///|
fn link_compiled_module_set(modules : CompiledModuleSet) -> LinkResult {
  match linked_module_objects(modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(objects) =>
      link_ordered_module_objects(
        objects,
        RootEntries(modules.root_module_path_text),
      )
  }
}

///|
fn link_compiled_modules(modules : Array[CompiledModule]) -> LinkResult {
  match linked_all_module_objects(modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(objects) => link_ordered_module_objects(objects, QualifiedEntries)
  }
}

///|
fn link_ordered_module_objects(
  objects : Array[ModuleObject],
  entry_mode : LinkedEntryMode,
) -> LinkResult {
  let remapper = BuslaneLinker::BuslaneLinker()
  let remapped_objects = remapper.remap_module_objects(objects)
  let module_path_texts = []
  let terms = []
  let builtins = []
  let entries : Array[@elaborate.BuslaneEntry] = []
  for object in remapped_objects {
    module_path_texts.push(object.module_path_text)
    terms.append(object.terms)
    builtins.append(object.externals.builtins)
    match entry_mode {
      RootEntries(root) =>
        if object.module_path_text == root {
          entries.append(object.entries)
        }
      QualifiedEntries =>
        entries.append(
          qualified_entries(object.module_path_text, object.entries),
        )
    }
  }
  {
    program: Some({
      module_path_texts,
      program: { metadata: remapper.metadata, terms },
      externals: { builtins, },
      entries,
    }),
    diagnostics: [],
  }
}

///|
fn qualified_entries(
  module_path_text : String,
  entries : Array[@elaborate.BuslaneEntry],
) -> Array[@elaborate.BuslaneEntry] {
  entries.map(fn(entry) {
    {
      name: "\{module_path_text}::\{entry.name}",
      value: entry.value,
      type_: entry.type_,
    }
  })
}

///|
fn BuslaneLinker::remap_module_objects(
  self : BuslaneLinker,
  objects : Array[ModuleObject],
) -> Array[RemappedModuleObject] {
  let remapped_objects = []
  let exports : Array[LinkedModuleExport] = []
  for object in objects {
    self.seed_imports(object, exports)
    let remapped = self.remap_module_object(object)
    remapped_objects.push(remapped)
    for item in remapped.exports {
      exports.push({
        module_path_text: remapped.module_path_text,
        kind: item.kind,
        name: item.name,
        fingerprint: remapped.fingerprint,
        type_id: item.type_id,
        data_constructor: item.data_constructor,
        effect_id: item.effect_id,
        operation: item.operation,
        value: item.value,
      })
    }
  }
  remapped_objects
}

///|
fn BuslaneLinker::seed_imports(
  self : BuslaneLinker,
  object : ModuleObject,
  exports : Array[LinkedModuleExport],
) -> Unit {
  for imported in object.imports {
    guard find_linked_export(exports, imported) is Some(item) else { continue }
    match (imported.type_id, item.type_id) {
      (Some(source), Some(target)) =>
        ignore(
          self.identities.bind_type(object.module_path_text, source, target),
        )
      _ => ()
    }
    match (imported.data_constructor, item.data_constructor) {
      (Some(source), Some(target)) =>
        ignore(
          self.identities.bind_data_constructor(
            object.module_path_text,
            source,
            target,
          ),
        )
      _ => ()
    }
    match (imported.value, item.value) {
      (Some(source), Some(target)) =>
        ignore(
          self.identities.bind_value(object.module_path_text, source, target),
        )
      _ => ()
    }
    match (imported.effect_id, item.effect_id) {
      (Some(source), Some(target)) =>
        ignore(
          self.identities.bind_effect(object.module_path_text, source, target),
        )
      _ => ()
    }
    match (imported.operation, item.operation) {
      (Some(source), Some(target)) =>
        ignore(
          self.identities.bind_operation(
            object.module_path_text,
            source,
            target,
          ),
        )
      _ => ()
    }
  }
}

///|
fn find_linked_export(
  exports : Array[LinkedModuleExport],
  imported : ModuleImportedReference,
) -> LinkedModuleExport? {
  for item in exports {
    if item.module_path_text == imported.module_path_text &&
      item.kind == imported.kind &&
      item.name == imported.name &&
      item.fingerprint == imported.fingerprint {
      return Some(item)
    }
  }
  None
}

///|
fn linked_module_objects(
  modules : CompiledModuleSet,
) -> Result[Array[ModuleObject], Array[CompileDiagnostic]] {
  let module_diagnostics = validate_compiled_modules(modules.modules)
  if !module_diagnostics.is_empty() {
    return Err(module_diagnostics)
  }
  let ordered = reachable_compiled_modules(
    modules.modules,
    modules.root_module_path_text,
  )
  if !ordered.diagnostics.is_empty() {
    return Err(ordered.diagnostics)
  }
  let objects = []
  for module_ in ordered.modules {
    let object = module_.object
    let diagnostics = validate_link_object(modules.modules, module_, object)
    if !diagnostics.is_empty() {
      return Err(diagnostics)
    }
    objects.push(object)
  }
  Ok(objects)
}

///|
fn linked_all_module_objects(
  modules : Array[CompiledModule],
) -> Result[Array[ModuleObject], Array[CompileDiagnostic]] {
  let module_diagnostics = validate_compiled_modules(modules)
  if !module_diagnostics.is_empty() {
    return Err(module_diagnostics)
  }
  let ordered = all_compiled_modules(modules)
  if !ordered.diagnostics.is_empty() {
    return Err(ordered.diagnostics)
  }
  let objects = []
  for module_ in ordered.modules {
    let object = module_.object
    let diagnostics = validate_link_object(modules, module_, object)
    if !diagnostics.is_empty() {
      return Err(diagnostics)
    }
    objects.push(object)
  }
  Ok(objects)
}

///|
fn validate_compiled_modules(
  modules : Array[CompiledModule],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for index in 0..<modules.length() {
    for other_index in (index + 1)..<modules.length() {
      if modules[index].module_path_text ==
        modules[other_index].module_path_text {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            DuplicateModuleArtifact(modules[index].module_path_text),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn all_compiled_modules(
  modules : Array[CompiledModule],
) -> OrderedCompiledModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  for module_ in modules {
    visit_compiled_module(
      modules,
      module_.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  { modules: ordered, diagnostics }
}

///|
fn reachable_compiled_modules(
  modules : Array[CompiledModule],
  root_module_path_text : String,
) -> OrderedCompiledModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  visit_compiled_module(
    modules, root_module_path_text, visiting, visited, ordered, diagnostics,
  )
  { modules: ordered, diagnostics }
}

///|
fn visit_compiled_module(
  modules : Array[CompiledModule],
  module_path_text : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[CompiledModule],
  diagnostics : Array[CompileDiagnostic],
) -> Unit {
  if visited.contains(module_path_text) {
    return
  }
  if visiting.contains(module_path_text) {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(ImportCycle(module_path_text), None),
    )
    return
  }
  guard find_compiled_module(modules, module_path_text) is Some(module_) else {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(MissingObject(module_path_text), None),
    )
    return
  }
  visiting.push(module_path_text)
  for import_ in module_.imported_interface_fingerprints {
    visit_compiled_module(
      modules,
      import_.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  ignore(visiting.pop())
  visited.push(module_path_text)
  ordered.push(module_)
}
