///|
pub fn link_modules(modules : Array[LinkModuleObject]) -> LinkResult {
  match LinkModuleIndex::from_modules(modules) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(index) => link_index(index, AllModules, QualifiedEntries)
  }
}

///|
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
  let remapped_objects = remapper.remap_module_objects(modules)
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
  {
    program: Some({
      module_path_texts,
      program: { metadata: remapper.metadata, terms },
      externals: { builtins, runtime_imports },
      entries,
    }),
    diagnostics: [],
  }
}

///|
fn BuslaneLinker::remap_module_objects(
  self : BuslaneLinker,
  objects : Array[ValidatedLinkModuleObject],
) -> Array[RemappedModuleObject] {
  let remapped_objects = []
  let exports : Array[LinkedModuleExport] = []
  for validated in objects {
    let object = validated.object
    self.seed_imports(object, exports)
    let remapped = self.remap_module_object(object)
    remapped_objects.push(remapped)
    for item in remapped.exports {
      exports.push({
        module_path_text: remapped.module_path_text,
        name: item.name,
        fingerprint: remapped.fingerprint,
        reference: item.reference,
      })
    }
  }
  remapped_objects
}

///|
fn BuslaneLinker::seed_imports(
  self : BuslaneLinker,
  object : LinkModuleObject,
  exports : Array[LinkedModuleExport],
) -> Unit {
  for imported in object.imports {
    guard find_linked_export(exports, imported) is Some(item) else { continue }
    match (imported.reference, item.reference) {
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
fn find_linked_export(
  exports : Array[LinkedModuleExport],
  imported : @artifact_model.ModuleImportedReference,
) -> LinkedModuleExport? {
  for item in exports {
    if item.module_path_text == imported.module_path_text &&
      module_references_have_same_kind(item.reference, imported.reference) &&
      item.name == imported.name &&
      item.fingerprint == imported.fingerprint {
      return Some(item)
    }
  }
  None
}

///|
fn module_references_have_same_kind(
  left : @buslane_lowering.BuslaneModuleReference,
  right : @buslane_lowering.BuslaneModuleReference,
) -> Bool {
  match (left, right) {
    (Type(_), Type(_))
    | (DataConstructor(_), DataConstructor(_))
    | (Effect(_), Effect(_))
    | (Operation(_), Operation(_))
    | (FieldSelector(_), FieldSelector(_))
    | (Value(_), Value(_)) => true
    _ => false
  }
}

///|
fn LinkModuleIndex::from_modules(
  modules : Array[LinkModuleObject],
) -> Result[LinkModuleIndex, Array[CompilerDiagnostic]] {
  let diagnostics = []
  for index in 0..<modules.length() {
    for other_index in (index + 1)..<modules.length() {
      if modules[index].module_path_text ==
        modules[other_index].module_path_text {
        diagnostics.push(
          link_diagnostic(
            DuplicateModuleArtifact(modules[index].module_path_text),
            None,
          ),
        )
      }
    }
  }
  if diagnostics.is_empty() {
    Ok({ modules, })
  } else {
    Err(diagnostics)
  }
}

///|
fn LinkModuleIndex::all(self : LinkModuleIndex) -> OrderedLinkModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
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
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  self.visit(root_module_path_text, visiting, visited, ordered, diagnostics)
  { modules: ordered, diagnostics }
}

///|
fn LinkModuleIndex::visit(
  self : LinkModuleIndex,
  module_path_text : String,
  visiting : Array[String],
  visited : Array[String],
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
  visiting.push(module_path_text)
  for import_ in module_.imported_interface_fingerprints {
    self.visit(
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

///|
fn LinkModuleIndex::find(
  self : LinkModuleIndex,
  path : String,
) -> LinkModuleObject? {
  for module_ in self.modules {
    if module_.module_path_text == path {
      return Some(module_)
    }
  }
  None
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
