///|
/// Validates and links every supplied module, exporting entries with qualified
/// module identity. Semantic order is dependency-derived rather than input
/// order; any diagnostic yields no partial program.
pub fn link_modules(modules : Array[LinkModuleObject]) -> LinkResult {
  match LinkModuleIndex::from_modules(modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(index) => link_index(index, AllModules, QualifiedEntries)
  }
}

///|
/// Validates the module pool and links only the import closure reachable from
/// `root_module_path_text`. Only root-module entries remain executable; missing
/// roots, cycles, and integrity failures return diagnostics and no program.
pub fn link_reachable_modules(
  modules : Array[LinkModuleObject],
  root_module_path_text : String,
) -> LinkResult {
  match LinkModuleIndex::from_modules(modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(index) =>
      link_index(
        index,
        Reachable(root_module_path_text),
        RootEntries(root_module_path_text),
      )
  }
}

///|
fn link_index(
  index : LinkModuleIndex,
  selection : LinkModuleSelection,
  entry_mode : LinkedEntryMode,
) -> LinkResult {
  let ordered = match selection {
    AllModules => index.all()
    Reachable(root) => index.reachable(root)
  }
  let diagnostics = ordered.diagnostics +
    validate_module_exports_for_link_order(ordered.modules, index)
  if !diagnostics.is_empty() {
    return { program: None, diagnostics }
  }
  match index.validate_order(ordered.modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(modules) => link_ordered_modules(modules, entry_mode)
  }
}

///|
fn link_ordered_modules(
  modules : Array[ValidatedLinkModuleObject],
  entry_mode : LinkedEntryMode,
) -> LinkResult {
  let remapper = BuslaneLinker::BuslaneLinker()
  link_ordered_modules_with_remapper(remapper, modules, entry_mode)
}

///|
fn link_ordered_modules_with_remapper(
  remapper : BuslaneLinker,
  modules : Array[ValidatedLinkModuleObject],
  entry_mode : LinkedEntryMode,
) -> LinkResult {
  let remapped_objects = remapper.remap_module_objects(modules) catch {
    error =>
      return {
        program: None,
        diagnostics: [
          link_diagnostic(LinkMetadataAllocationCompilerDefect(error), None),
        ],
      }
  }
  let module_path_texts = []
  let terms = []
  let builtins = []
  let runtime_imports = []
  let entries : Array[@buslane_lowering.BuslaneEntry] = []
  for object in remapped_objects {
    module_path_texts.push(object.module_path_text)
    terms.append(object.terms)
    builtins.append(object.externals.builtins)
    runtime_imports.append(object.externals.runtime_imports)
    match entry_mode {
      RootEntries(root) =>
        if object.module_path_text == root {
          entries.append(object.entries)
        }
      QualifiedEntries => entries.append(object.entries)
    }
  }
  let complete_program : @buslane.Program = {
    metadata: remapper.metadata,
    terms,
  }
  let retained_program = @occurrence.retain_reachable_top_terms(
    complete_program,
    linked_top_term_roots(remapped_objects, entries),
  )
  {
    program: Some({
      module_path_texts,
      program: retained_program,
      externals: { builtins, runtime_imports },
      entries,
    }),
    diagnostics: [],
  }
}

///|
fn linked_top_term_roots(
  objects : Array[RemappedModuleObject],
  entries : Array[@buslane_lowering.BuslaneEntry],
) -> Array[@buslane.ValueId] {
  let roots = entries.map(entry => entry.value)
  for object in objects {
    for export_ in object.exports {
      match export_.reference {
        Value(value) | FieldSelector(value) => roots.push(value)
        Type(_) | DataConstructor(_) | Effect(_) | Operation(_) => ()
      }
    }
    for builtin in object.externals.builtins {
      roots.push(builtin.value())
    }
    for runtime_import in object.externals.runtime_imports {
      roots.push(runtime_import.value)
    }
  }
  roots
}

///|
fn BuslaneLinker::remap_module_objects(
  self : BuslaneLinker,
  objects : Array[ValidatedLinkModuleObject],
) -> Array[RemappedModuleObject] raise @buslane.MetadataAllocationError {
  let remapped_objects = []
  let exports : Map[String, LinkedModuleExports] = Map([])
  for validated in objects {
    let object = validated.object
    self.seed_imports(object, exports)
    let remapped = self.remap_module_object(object)
    remapped_objects.push(remapped)
    exports[remapped.module_path_text] = {
      fingerprint: remapped.fingerprint,
      index: LinkExportIndex::from_exports(remapped.exports),
    }
  }
  remapped_objects
}

///|
fn BuslaneLinker::seed_imports(
  self : BuslaneLinker,
  object : LinkModuleObject,
  exports : Map[String, LinkedModuleExports],
) -> Unit {
  for imported in object.imports {
    guard exports.get(imported.module_path_text) is Some(provider) &&
      provider.fingerprint == imported.fingerprint &&
      provider.index.find(imported.reference, imported.name) is Some(target) else {
      continue
    }
    match (imported.reference, target) {
      (Type(source), Type(target)) =>
        ignore(
          self.identities.bind_type(object.module_path_text, source, target),
        )
      (DataConstructor(source), DataConstructor(target)) =>
        ignore(
          self.identities.bind_data_constructor(
            object.module_path_text,
            source,
            target,
          ),
        )
      (FieldSelector(source), FieldSelector(target))
      | (Value(source), Value(target)) =>
        ignore(
          self.identities.bind_value(object.module_path_text, source, target),
        )
      (Effect(source), Effect(target)) =>
        ignore(
          self.identities.bind_effect(object.module_path_text, source, target),
        )
      (Operation(source), Operation(target)) =>
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
fn LinkModuleIndex::from_modules(
  modules : Array[LinkModuleObject],
) -> Result[LinkModuleIndex, Array[CompilerDiagnostic]] {
  let diagnostics = []
  let module_slots_by_path : Map[String, Int] = Map([])
  let exports_by_path : Map[String, LinkExportIndex] = Map([])
  for slot, module_ in modules {
    let path = module_.module_path_text
    if module_slots_by_path.contains(path) {
      diagnostics.push(link_diagnostic(DuplicateModuleArtifact(path), None))
    } else {
      module_slots_by_path[path] = slot
      exports_by_path[path] = LinkExportIndex::from_exports(module_.exports)
    }
  }
  if diagnostics.is_empty() {
    Ok({ modules, module_slots_by_path, exports_by_path })
  } else {
    Err(diagnostics)
  }
}

///|
fn LinkModuleIndex::all(self : LinkModuleIndex) -> OrderedLinkModulesResult {
  let ordered = []
  let visiting : @hashset.HashSet[String] = HashSet([])
  let visited : @hashset.HashSet[String] = HashSet([])
  let diagnostics = []
  for module_ in self.modules {
    self.visit(
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
fn LinkModuleIndex::reachable(
  self : LinkModuleIndex,
  root_module_path_text : String,
) -> OrderedLinkModulesResult {
  let ordered = []
  let visiting : @hashset.HashSet[String] = HashSet([])
  let visited : @hashset.HashSet[String] = HashSet([])
  let diagnostics = []
  self.visit(root_module_path_text, visiting, visited, ordered, diagnostics)
  { modules: ordered, diagnostics }
}

///|
fn LinkModuleIndex::visit(
  self : LinkModuleIndex,
  module_path_text : String,
  visiting : @hashset.HashSet[String],
  visited : @hashset.HashSet[String],
  ordered : Array[LinkModuleObject],
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  if visited.contains(module_path_text) {
    return
  }
  if visiting.contains(module_path_text) {
    diagnostics.push(link_diagnostic(LinkImportCycle(module_path_text), None))
    return
  }
  guard self.find(module_path_text) is Some(module_) else {
    diagnostics.push(link_diagnostic(MissingObject(module_path_text), None))
    return
  }
  visiting.add(module_path_text)
  for import_ in module_.imported_interface_fingerprints {
    self.visit(
      import_.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  visiting.remove(module_path_text)
  visited.add(module_path_text)
  ordered.push(module_)
}

///|
fn LinkModuleIndex::find(
  self : LinkModuleIndex,
  path : String,
) -> LinkModuleObject? {
  guard self.module_slots_by_path.get(path) is Some(slot) else { return None }
  self.modules.get(slot)
}

///|
fn LinkModuleIndex::export_index(
  self : LinkModuleIndex,
  path : String,
) -> LinkExportIndex? {
  self.exports_by_path.get(path)
}

///|
fn LinkModuleIndex::validate_order(
  self : LinkModuleIndex,
  modules : Array[LinkModuleObject],
) -> Result[Array[ValidatedLinkModuleObject], Array[CompilerDiagnostic]] {
  let validated = []
  let diagnostics = []
  for module_ in modules {
    let module_diagnostics = validate_link_object(self, module_)
    if module_diagnostics.is_empty() {
      validated.push({ object: module_ })
    } else {
      diagnostics.append(module_diagnostics)
    }
  }
  if diagnostics.is_empty() {
    Ok(validated)
  } else {
    Err(diagnostics)
  }
}
