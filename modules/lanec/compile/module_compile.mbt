///|
pub(all) struct CompilationFingerprint {
  value : String
} derive(Debug, Eq)

///|
pub(all) struct ImportedInterfaceFingerprint {
  module_path_text : String
  fingerprint : CompilationFingerprint
} derive(Debug, Eq)

///|
pub(all) struct ModuleImportedReference {
  module_path_text : String
  kind : @elaborate.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  value : @buslane.ValueId?
} derive(Debug, Eq)

///|
pub(all) struct ModuleObject {
  module_path_text : String
  checked : @checked.CheckedSourceFile
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  exports : Array[@elaborate.BuslaneModuleExport]
  imports : Array[ModuleImportedReference]
  fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModule {
  module_path_text : String
  interface : @module_interface.ModuleInterface
  object : ModuleObject
  fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleSet {
  root_module_path_text : String
  modules : Array[CompiledModule]
  reachable_module_path_texts : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
} derive(Debug, Eq)

///|
pub(all) struct LinkResult {
  program : LinkedProgram?
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
priv struct LinkTypeMapEntry {
  module_path_text : String
  source : @buslane.TypeId
  target : @buslane.TypeId
}

///|
priv struct LinkTypeParameterMapEntry {
  module_path_text : String
  source : @buslane.TypeParameterId
  target : @buslane.TypeParameterId
}

///|
priv struct LinkValueMapEntry {
  module_path_text : String
  source : @buslane.ValueId
  target : @buslane.ValueId
}

///|
priv struct LinkDataConMapEntry {
  module_path_text : String
  source : @buslane.DataConId
  target : @buslane.DataConId
}

///|
priv struct LinkEffectMapEntry {
  module_path_text : String
  source : @buslane.EffectId
  target : @buslane.EffectId
}

///|
priv struct LinkOperationMapEntry {
  module_path_text : String
  source : @buslane.OperationId
  target : @buslane.OperationId
}

///|
priv struct BuslaneLinker {
  metadata : @buslane.MetadataRegistry
  types : Array[LinkTypeMapEntry]
  type_parameters : Array[LinkTypeParameterMapEntry]
  values : Array[LinkValueMapEntry]
  data_constructors : Array[LinkDataConMapEntry]
  effects : Array[LinkEffectMapEntry]
  operations : Array[LinkOperationMapEntry]
}

///|
priv struct RemappedModuleObject {
  module_path_text : String
  terms : Array[@buslane.TopTerm]
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  exports : Array[@elaborate.BuslaneModuleExport]
  fingerprint : CompilationFingerprint
}

///|
priv struct LinkedModuleExport {
  module_path_text : String
  kind : @elaborate.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  value : @buslane.ValueId?
}

///|
priv struct OrderedCompiledModulesResult {
  modules : Array[CompiledModule]
  diagnostics : Array[CompileDiagnostic]
}

///|
priv enum LinkedEntryMode {
  RootEntries(String)
  QualifiedEntries
}

///|
priv struct OrderedInterfaceArtifactsResult {
  interfaces : Array[ModuleInterfaceArtifact]
  diagnostics : Array[CompileDiagnostic]
}

///|
priv struct FingerprintNominalTypeName {
  symbol : @symbol.TypeSymbolId
  name : String
}

///|
priv struct FingerprintTypeParameterName {
  symbol : @symbol.TypeParameterId
  name : String
  kind : @types.Kind
}

///|
priv struct FingerprintTypeContext {
  nominal_types : Array[FingerprintNominalTypeName]
  type_parameters : Array[FingerprintTypeParameterName]
}

///|
fn BuslaneLinker::BuslaneLinker() -> BuslaneLinker {
  {
    metadata: MetadataRegistry(),
    types: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
  }
}

///|
fn compile_module_graph(
  graph : ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompileDiagnostic]] {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let modules : Array[CompiledModule] = []
  for input in graph.modules {
    let imported = imported_interfaces(input.header, modules)
    match compile_one_module(input, registry, imported) {
      Ok(module_) => modules.push(module_)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  if find_compiled_module(modules, graph.root_module_path_text) is None {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  Ok({
    root_module_path_text: graph.root_module_path_text,
    modules: lower_compiled_module_objects(modules),
    reachable_module_path_texts: graph.reachable_module_path_texts,
  })
}

///|
fn compile_module_from_interface_artifacts(
  root_source : String,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Result[CompiledModuleSet, Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs({ source_id: "<root>", text: root_source }, [])
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(input) else {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  let ordered_interfaces = reachable_interface_artifacts(
    input.header,
    interfaces,
  )
  let import_diagnostics = ordered_interfaces.diagnostics
  if !import_diagnostics.is_empty() {
    return Err(import_diagnostics)
  }
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let imported = freshen_module_interface_artifacts(
    registry,
    ordered_interfaces.interfaces,
  )
  match compile_one_module(input, registry, imported) {
    Err(diagnostics) => Err(diagnostics)
    Ok(module_) => {
      let imported_fingerprints = imported_interface_fingerprints_from_artifacts(
        input.header,
        ordered_interfaces.interfaces,
      )
      let module_ = module_.with_imported_interface_fingerprints(
        imported_fingerprints,
      )
      let lowered = @elaborate.lower_checked_source_file_to_buslane_object_with_imports(
        module_.object.checked,
        imported,
      )
      let compiled = attach_lowered_object_from_interfaces(
        module_,
        lowered,
        ordered_interfaces.interfaces,
      )
      Ok({
        root_module_path_text: compiled.module_path_text,
        modules: [compiled],
        reachable_module_path_texts: [compiled.module_path_text],
      })
    }
  }
}

///|
fn reachable_interface_artifacts(
  header : ModuleHeader,
  interfaces : Array[ModuleInterfaceArtifact],
) -> OrderedInterfaceArtifactsResult {
  let diagnostics = validate_interface_artifacts(interfaces)
  if !diagnostics.is_empty() {
    return { interfaces: [], diagnostics }
  }
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  for import_ in header.imports {
    visit_interface_artifact(
      interfaces,
      import_.module_path_text,
      Some(import_.import_span),
      None,
      header.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  { interfaces: ordered, diagnostics }
}

///|
fn validate_interface_artifacts(
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for interface in interfaces {
    match interface.validate() {
      Some(diagnostic) => diagnostics.push(diagnostic)
      None => ()
    }
  }
  for index in 0..<interfaces.length() {
    for other_index in (index + 1)..<interfaces.length() {
      if interfaces[index].module_path_text ==
        interfaces[other_index].module_path_text {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            DuplicateModuleInterfaceArtifact(interfaces[index].module_path_text),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn ModuleInterfaceArtifact::validate(
  self : ModuleInterfaceArtifact,
) -> CompileDiagnostic? {
  if self.schema_version != 1 {
    return Some(
      CompileErrorKind::to_diagnostic(
        UnsupportedModuleInterfaceArtifactSchema(self.module_path_text),
        None,
      ),
    )
  }
  if self.interface.module_path != self.module_path_text {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="name mismatch",
        ),
        None,
      ),
    )
  }
  let fingerprint = module_fingerprint(
    self.interface,
    self.imported_interface_fingerprints,
  )
  if self.interface_fingerprint != interface_fingerprint(self.interface) {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if self.module_fingerprint != fingerprint {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  None
}

///|
fn visit_interface_artifact(
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
  span : @basic.SourceSpan?,
  expected_fingerprint : CompilationFingerprint?,
  importer_path_text : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[ModuleInterfaceArtifact],
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
  guard find_module_interface_artifact(interfaces, module_path_text)
    is Some(interface) else {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(MissingImport(module_path_text), span),
    )
    return
  }
  match expected_fingerprint {
    Some(fingerprint) if interface_fingerprint(interface.interface) !=
      fingerprint =>
      diagnostics.push(
        CompileErrorKind::to_diagnostic(
          ImportedInterfaceFingerprintMismatch(
            importer=importer_path_text,
            imported=module_path_text,
          ),
          None,
        ),
      )
    _ => ()
  }
  visiting.push(module_path_text)
  for imported in interface.imported_interface_fingerprints {
    visit_interface_artifact(
      interfaces,
      imported.module_path_text,
      None,
      Some(imported.fingerprint),
      module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  ignore(visiting.pop())
  visited.push(module_path_text)
  ordered.push(interface)
}

///|
fn find_module_interface_artifact(
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
) -> ModuleInterfaceArtifact? {
  for interface in interfaces {
    if interface.module_path_text == module_path_text {
      return Some(interface)
    }
  }
  None
}

///|
fn imported_interface_fingerprints_from_artifacts(
  header : ModuleHeader,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[ImportedInterfaceFingerprint] {
  let fingerprints = []
  for import_ in header.imports {
    if find_module_interface_artifact(interfaces, import_.module_path_text)
      is Some(interface) {
      fingerprints.push({
        module_path_text: interface.module_path_text,
        fingerprint: interface_fingerprint(interface.interface),
      })
    }
  }
  fingerprints
}

///|
fn CompiledModule::with_imported_interface_fingerprints(
  self : CompiledModule,
  imported : Array[ImportedInterfaceFingerprint],
) -> CompiledModule {
  let fingerprint = module_fingerprint(self.interface, imported)
  let object : ModuleObject = {
    module_path_text: self.object.module_path_text,
    checked: self.object.checked,
    metadata: self.object.metadata,
    terms: self.object.terms,
    externals: self.object.externals,
    entries: self.object.entries,
    exports: self.object.exports,
    imports: self.object.imports,
    fingerprint,
    imported_interface_fingerprints: imported,
  }
  {
    module_path_text: self.module_path_text,
    interface: self.interface,
    object,
    fingerprint,
    imported_interface_fingerprints: imported,
  }
}

///|
fn imported_interfaces(
  header : ModuleHeader,
  modules : Array[CompiledModule],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if find_compiled_module(modules, import_.module_path_text) is Some(module_) {
      imported.push(module_.interface)
    }
  }
  { modules: imported }
}

///|
fn compile_one_module(
  input : ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imported : @module_interface.ImportedEnvironment,
) -> Result[CompiledModule, Array[CompileDiagnostic]] {
  let display = TypeDisplayContext::from_registry(registry)
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported,
  )
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    resolve_diagnostic(diagnostic, display)
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  let checked = @typecheck.typecheck_checked_source_file_with_imported_environment(
    resolved.source,
    imported,
  )
  let typecheck_diagnostics = checked.diagnostics.map(fn(diagnostic) {
    typecheck_diagnostic(diagnostic, display)
  })
  if !typecheck_diagnostics.is_empty() {
    return Err(typecheck_diagnostics)
  }
  match (checked.source, checked.module_interface) {
    (Some(checked), Some(interface)) => {
      let imported_fingerprints = imported_environment_fingerprints(imported)
      let fingerprint = module_fingerprint(interface, imported_fingerprints)
      let object : ModuleObject = {
        module_path_text: input.header.module_path_text,
        checked,
        metadata: MetadataRegistry(),
        terms: [],
        externals: { builtins: [] },
        entries: [],
        exports: [],
        imports: [],
        fingerprint,
        imported_interface_fingerprints: imported_fingerprints,
      }
      Ok({
        module_path_text: input.header.module_path_text,
        interface,
        object,
        fingerprint,
        imported_interface_fingerprints: imported_fingerprints,
      })
    }
    _ =>
      Err([
        CompileErrorKind::to_diagnostic(CheckedSourceConstructionFailed, None),
      ])
  }
}

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
        self.types.push({
          module_path_text: object.module_path_text,
          source,
          target,
        })
      _ => ()
    }
    match (imported.data_constructor, item.data_constructor) {
      (Some(source), Some(target)) =>
        self.data_constructors.push({
          module_path_text: object.module_path_text,
          source,
          target,
        })
      _ => ()
    }
    match (imported.value, item.value) {
      (Some(source), Some(target)) =>
        self.values.push({
          module_path_text: object.module_path_text,
          source,
          target,
        })
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

///|
fn BuslaneLinker::remap_module_object(
  self : BuslaneLinker,
  object : ModuleObject,
) -> RemappedModuleObject {
  {
    module_path_text: object.module_path_text,
    terms: object.terms.map(fn(term) { self.remap_top_term(object, term) }),
    externals: {
      builtins: object.externals.builtins.map(fn(builtin) {
        {
          value: self.remap_value_id(object, builtin.value),
          name: builtin.name,
          type_: self.remap_type(object, builtin.type_),
        }
      }),
    },
    entries: object.entries.map(fn(entry) {
      {
        name: entry.name,
        value: self.remap_value_id(object, entry.value),
        type_: self.remap_type(object, entry.type_),
      }
    }),
    exports: object.exports.map(fn(item) {
      {
        kind: item.kind,
        name: item.name,
        type_id: item.type_id.map(fn(id) { self.remap_type_id(object, id) }),
        data_constructor: item.data_constructor.map(fn(id) {
          self.remap_data_constructor_id(object, id)
        }),
        value: item.value.map(fn(id) { self.remap_value_id(object, id) }),
      }
    }),
    fingerprint: object.fingerprint,
  }
}

///|
fn BuslaneLinker::remap_top_term(
  self : BuslaneLinker,
  object : ModuleObject,
  term : @buslane.TopTerm,
) -> @buslane.TopTerm {
  match term {
    Let(id, expr) =>
      Let(self.remap_value_id(object, id), self.remap_expr(object, expr))
    LetRec(bindings) =>
      LetRec(
        bindings.map(fn(binding) {
          {
            id: self.remap_value_id(object, binding.id),
            rhs: self.remap_expr(object, binding.rhs),
          }
        }),
      )
    External(id) => External(self.remap_value_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_expr(
  self : BuslaneLinker,
  object : ModuleObject,
  expr : @buslane.Expr,
) -> @buslane.Expr {
  match expr {
    Ref(id) => Ref(self.remap_value_id(object, id))
    Literal(literal) => Literal(literal)
    Function(function) =>
      Function({
        parameters: function.parameters.map(fn(id) {
          self.remap_value_id(object, id)
        }),
        result_type: self.remap_type(object, function.result_type),
        body: self.remap_expr(object, function.body),
      })
    Call(callee, arguments) =>
      Call(
        self.remap_expr(object, callee),
        arguments.map(fn(argument) { self.remap_expr(object, argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_expr(object, body),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        self.remap_expr(object, callee),
        arguments.map(fn(argument) { self.remap_type(object, argument) }),
      )
    Construct(construct) =>
      Construct({
        data_constructor: self.remap_data_constructor_id(
          object,
          construct.data_constructor,
        ),
        type_arguments: construct.type_arguments.map(fn(argument) {
          self.remap_type(object, argument)
        }),
        hidden_witnesses: construct.hidden_witnesses.map(fn(witness) {
          self.remap_type(object, witness)
        }),
        payloads: construct.payloads.map(fn(payload) {
          self.remap_expr(object, payload)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        self.remap_value_id(object, id),
        self.remap_expr(object, initializer),
        self.remap_expr(object, body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(fn(binding) {
          {
            id: self.remap_value_id(object, binding.id),
            rhs: self.remap_expr(object, binding.rhs),
          }
        }),
        self.remap_expr(object, body),
      )
    Match(match_) =>
      Match({
        scrutinee: self.remap_expr(object, match_.scrutinee),
        binder: self.remap_value_id(object, match_.binder),
        result_type: self.remap_type(object, match_.result_type),
        alternatives: match_.alternatives.map(fn(alternative) {
          {
            alt_constructor: self.remap_alt_constructor(
              object,
              alternative.alt_constructor,
            ),
            type_binders: alternative.type_binders.map(fn(id) {
              self.remap_type_parameter_id(object, id)
            }),
            value_binders: alternative.value_binders.map(fn(id) {
              self.remap_value_id(object, id)
            }),
            body: self.remap_expr(object, alternative.body),
          }
        }),
      })
    Perform(perform) =>
      Perform({
        operation: self.remap_operation_id(object, perform.operation),
        type_arguments: perform.type_arguments.map(fn(argument) {
          self.remap_type(object, argument)
        }),
        payloads: perform.payloads.map(fn(payload) {
          self.remap_expr(object, payload)
        }),
      })
    Handle(handle) =>
      Handle({
        body: self.remap_expr(object, handle.body),
        result_binder: self.remap_value_id(object, handle.result_binder),
        result_type: self.remap_type(object, handle.result_type),
        final_body: self.remap_expr(object, handle.final_body),
        handlers: handle.handlers.map(fn(table) {
          self.remap_handler_table(object, table)
        }),
      })
    Resume(id) => Resume(self.remap_value_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_handler_table(
  self : BuslaneLinker,
  object : ModuleObject,
  table : @buslane.HandlerTable,
) -> @buslane.HandlerTable {
  {
    handled_effect: self.remap_effect(object, table.handled_effect),
    operations: table.operations.map(fn(alternative) {
      self.remap_operation_alternative(object, alternative)
    }),
  }
}

///|
fn BuslaneLinker::remap_operation_alternative(
  self : BuslaneLinker,
  object : ModuleObject,
  alternative : @buslane.OperationAlternative,
) -> @buslane.OperationAlternative {
  {
    operation: self.remap_operation_id(object, alternative.operation),
    payload_binders: alternative.payload_binders.map(fn(id) {
      self.remap_value_id(object, id)
    }),
    resume_binder: self.remap_value_id(object, alternative.resume_binder),
    body: self.remap_expr(object, alternative.body),
  }
}

///|
fn BuslaneLinker::remap_alt_constructor(
  self : BuslaneLinker,
  object : ModuleObject,
  alt_constructor : @buslane.AltCon,
) -> @buslane.AltCon {
  match alt_constructor {
    Default => Default
    Literal(literal) => Literal(literal)
    DataCon(id) => DataCon(self.remap_data_constructor_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_type(
  self : BuslaneLinker,
  object : ModuleObject,
  type_ : @buslane.Type,
) -> @buslane.Type {
  match type_ {
    Primitive(primitive) => Primitive(primitive)
    Parameter(id) => Parameter(self.remap_type_parameter_id(object, id))
    Constructor(id) => Constructor(self.remap_type_id(object, id))
    Apply(callee, arguments) =>
      Apply(
        self.remap_type(object, callee),
        arguments.map(fn(argument) { self.remap_type(object, argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_type(object, body),
      )
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { self.remap_type(object, parameter) }),
        self.remap_type(object, result),
        self.remap_effect(object, effect),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_type(object, body),
      )
  }
}

///|
fn BuslaneLinker::remap_effect(
  self : BuslaneLinker,
  object : ModuleObject,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  match effect {
    Empty => Empty
    Singleton(id, arguments) =>
      Singleton(
        self.remap_effect_id(object, id),
        arguments.map(fn(argument) { self.remap_type(object, argument) }),
      )
    Parameter(parameter) =>
      Parameter(self.remap_type_parameter_id(object, parameter))
    Union(effects) =>
      Union(effects.map(fn(effect) { self.remap_effect(object, effect) }))
  }
}

///|
fn BuslaneLinker::remap_type_parameter_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  for entry in self.type_parameters {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.type_parameter_info(source) is Some(info) else {
    abort("unknown Buslane type parameter id")
  }
  let target = self.metadata.define_type_parameter(info.kind)
  self.type_parameters.push({
    module_path_text: object.module_path_text,
    source,
    target,
  })
  target
}

///|
fn BuslaneLinker::remap_type_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.TypeId,
) -> @buslane.TypeId {
  for entry in self.types {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.type_info(source) is Some(info) else {
    abort("unknown Buslane type id")
  }
  let target = self.metadata.define_type(
    info.parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
  )
  self.types.push({ module_path_text: object.module_path_text, source, target })
  for data_constructor in info.constructors {
    ignore(self.remap_data_constructor_id(object, data_constructor))
  }
  target
}

///|
fn BuslaneLinker::remap_effect_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.EffectId,
) -> @buslane.EffectId {
  for entry in self.effects {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.effect_info(source) is Some(info) else {
    abort("unknown Buslane effect id")
  }
  let target = self.metadata.define_effect(
    info.parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
  )
  self.effects.push({
    module_path_text: object.module_path_text,
    source,
    target,
  })
  for operation in info.operations {
    ignore(self.remap_operation_id(object, operation))
  }
  target
}

///|
fn BuslaneLinker::remap_operation_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.OperationId,
) -> @buslane.OperationId {
  for entry in self.operations {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.operation_info(source) is Some(info) else {
    abort("unknown Buslane operation id")
  }
  let target = self.metadata.define_operation(
    self.remap_effect_id(object, info.owner),
    info.payload_types.map(fn(type_) { self.remap_type(object, type_) }),
    self.remap_type(object, info.result_type),
  )
  self.operations.push({
    module_path_text: object.module_path_text,
    source,
    target,
  })
  target
}

///|
fn BuslaneLinker::remap_value_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.ValueId,
) -> @buslane.ValueId {
  for entry in self.values {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.value_info(source) is Some(info) else {
    abort("unknown Buslane value id")
  }
  let target = self.metadata.define_value(
    info.kind,
    self.remap_type(object, info.type_),
  )
  self.values.push({ module_path_text: object.module_path_text, source, target })
  target
}

///|
fn BuslaneLinker::remap_data_constructor_id(
  self : BuslaneLinker,
  object : ModuleObject,
  source : @buslane.DataConId,
) -> @buslane.DataConId {
  for entry in self.data_constructors {
    if entry.module_path_text == object.module_path_text &&
      entry.source == source {
      return entry.target
    }
  }
  guard object.metadata.data_constructor_info(source) is Some(info) else {
    abort("unknown Buslane data constructor id")
  }
  let target = self.metadata.define_data_constructor(
    self.remap_type_id(object, info.owner),
    info.hidden_type_parameters.map(fn(id) {
      self.remap_type_parameter_id(object, id)
    }),
    info.payload_types.map(fn(type_) { self.remap_type(object, type_) }),
  )
  self.data_constructors.push({
    module_path_text: object.module_path_text,
    source,
    target,
  })
  target
}

///|
fn validate_link_object(
  modules : Array[CompiledModule],
  module_ : CompiledModule,
  object : ModuleObject,
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  if module_.module_path_text != object.module_path_text {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(
        StaleModuleObject(
          module_path_text=module_.module_path_text,
          reason="module object mismatch",
        ),
        None,
      ),
    )
  }
  if module_.fingerprint != object.fingerprint {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(
        StaleModuleObject(
          module_path_text=module_.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  for imported in object.imported_interface_fingerprints {
    match find_compiled_module(modules, imported.module_path_text) {
      Some(imported_module) => {
        if interface_fingerprint(imported_module.interface) !=
          imported.fingerprint {
          diagnostics.push(
            CompileErrorKind::to_diagnostic(
              ImportedInterfaceFingerprintMismatch(
                importer=module_.module_path_text,
                imported=imported.module_path_text,
              ),
              None,
            ),
          )
        }
        diagnostics.append(validate_imported_exports(module_, imported_module))
      }
      None =>
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            MissingImportedObject(imported.module_path_text),
            None,
          ),
        )
    }
  }
  diagnostics.append(validate_imported_references(module_, object, modules))
  diagnostics
}

///|
fn validate_imported_references(
  module_ : CompiledModule,
  object : ModuleObject,
  modules : Array[CompiledModule],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for imported in object.imports {
    match find_compiled_module(modules, imported.module_path_text) {
      Some(imported_module) =>
        if imported.fingerprint != imported_module.fingerprint {
          diagnostics.push(
            CompileErrorKind::to_diagnostic(
              ImportedReferenceFingerprintMismatch(
                importer=module_.module_path_text,
                imported=imported.module_path_text,
                name=imported.name,
              ),
              None,
            ),
          )
        } else {
          match
            find_module_export(
              imported_module.object.exports,
              imported.kind,
              imported.name,
            ) {
            Some(item) =>
              if !imported_reference_shape_matches_export(imported, item) {
                diagnostics.push(
                  CompileErrorKind::to_diagnostic(
                    ImportedReferenceMismatch(
                      importer=module_.module_path_text,
                      imported=imported.module_path_text,
                      name=imported.name,
                    ),
                    None,
                  ),
                )
              }
            None => ()
          }
        }
      None =>
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            MissingImportedObject(imported.module_path_text),
            None,
          ),
        )
    }
  }
  diagnostics
}

///|
fn imported_reference_shape_matches_export(
  imported : ModuleImportedReference,
  item : @elaborate.BuslaneModuleExport,
) -> Bool {
  if imported.kind != item.kind {
    return false
  }
  match imported.kind {
    Type => imported.type_id is Some(_) && item.type_id is Some(_)
    DataConstructor =>
      imported.data_constructor is Some(_) && item.data_constructor is Some(_)
    FieldSelector | Value => imported.value is Some(_) && item.value is Some(_)
  }
}

///|
fn validate_imported_exports(
  module_ : CompiledModule,
  imported : CompiledModule,
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for value in imported.interface.values {
    if !module_exports_value(imported.object.exports, value.name) {
      diagnostics.push(
        CompileErrorKind::to_diagnostic(
          MissingExported(
            kind="value",
            provider=imported.module_path_text,
            name=value.name,
            importer=module_.module_path_text,
          ),
          None,
        ),
      )
    }
  }
  for type_ in imported.interface.types {
    let name = interface_type_name(type_)
    if !module_exports_type(imported.object.exports, name) {
      diagnostics.push(
        CompileErrorKind::to_diagnostic(
          MissingExported(
            kind="type",
            provider=imported.module_path_text,
            name~,
            importer=module_.module_path_text,
          ),
          None,
        ),
      )
    }
    let constructor_names = interface_type_constructors(type_)
    for constructor_name in constructor_names {
      if !module_exports_data_constructor(
          imported.object.exports,
          constructor_name,
        ) {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            MissingExported(
              kind="constructor",
              provider=imported.module_path_text,
              name=constructor_name,
              importer=module_.module_path_text,
            ),
            None,
          ),
        )
      }
    }
    for field_selector_name in interface_type_field_selectors(type_) {
      if !module_exports_field_selector(
          imported.object.exports,
          field_selector_name,
        ) {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            MissingExported(
              kind="field selector",
              provider=imported.module_path_text,
              name=field_selector_name,
              importer=module_.module_path_text,
            ),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn module_exports_value(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Value && item.name == name })
}

///|
fn module_exports_type(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Type && item.name == name })
}

///|
fn module_exports_data_constructor(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is DataConstructor && item.name == name })
}

///|
fn module_exports_field_selector(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is FieldSelector && item.name == name })
}

///|
fn interface_type_name(type_ : @module_interface.ModuleInterfaceType) -> String {
  match type_ {
    Struct(declaration) => declaration.name
    Enum(declaration) => declaration.name
  }
}

///|
fn interface_type_constructors(
  type_ : @module_interface.ModuleInterfaceType,
) -> Array[String] {
  match type_ {
    Struct(declaration) => [declaration.name]
    Enum(declaration) => declaration.variants.map(fn(variant) { variant.name })
  }
}

///|
fn interface_type_field_selectors(
  type_ : @module_interface.ModuleInterfaceType,
) -> Array[String] {
  match type_ {
    Struct(declaration) =>
      declaration.fields.map(fn(field) {
        field_selector_export_name(declaration.name, field.name)
      })
    Enum(_) => []
  }
}

///|
fn field_selector_export_name(
  type_name : String,
  field_name : String,
) -> String {
  "\{type_name}.\{field_name}"
}

///|
fn lower_compiled_module_objects(
  modules : Array[CompiledModule],
) -> Array[CompiledModule] {
  let lowered_modules : Array[CompiledModule] = []
  for module_ in modules {
    let imported = imported_interfaces_from_modules(
      module_.imported_interface_fingerprints,
      lowered_modules,
    )
    let lowered = @elaborate.lower_checked_source_file_to_buslane_object_with_imports(
      module_.object.checked,
      imported,
    )
    lowered_modules.push(
      attach_lowered_object(module_, lowered, lowered_modules),
    )
  }
  lowered_modules
}

///|
fn imported_interfaces_from_modules(
  imported : Array[ImportedInterfaceFingerprint],
  modules : Array[CompiledModule],
) -> @module_interface.ImportedEnvironment {
  let interfaces = []
  for item in imported {
    if find_compiled_module(modules, item.module_path_text) is Some(module_) {
      interfaces.push(module_.interface)
    }
  }
  { modules: interfaces }
}

///|
fn attach_lowered_object(
  module_ : CompiledModule,
  lowered : @elaborate.BuslaneModuleObject,
  imported_modules : Array[CompiledModule],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    metadata: lowered.metadata,
    terms: lowered.terms,
    externals: lowered.externals,
    entries: lowered.entries,
    exports: lowered.exports,
    imports: module_imported_references_from_lowered(
      lowered.imports,
      imported_modules,
      module_.module_path_text,
    ),
    fingerprint: module_.object.fingerprint,
    imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
fn attach_lowered_object_from_interfaces(
  module_ : CompiledModule,
  lowered : @elaborate.BuslaneModuleObject,
  interfaces : Array[ModuleInterfaceArtifact],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    metadata: lowered.metadata,
    terms: lowered.terms,
    externals: lowered.externals,
    entries: lowered.entries,
    exports: lowered.exports,
    imports: module_imported_references_from_interface_artifacts(
      lowered.imports,
      interfaces,
      module_.module_path_text,
    ),
    fingerprint: module_.object.fingerprint,
    imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
fn module_imported_references_from_lowered(
  imports : Array[@elaborate.BuslaneModuleImport],
  imported_modules : Array[CompiledModule],
  module_path_text : String,
) -> Array[ModuleImportedReference] {
  imports.map(fn(item) {
    let fingerprint = match
      find_compiled_module(imported_modules, item.module_path_text) {
      Some(module_) => module_.fingerprint
      None =>
        abort(
          "missing imported module fingerprint \{module_path_text} -> \{item.module_path_text}",
        )
    }
    {
      module_path_text: item.module_path_text,
      kind: item.kind,
      name: item.name,
      fingerprint,
      type_id: item.type_id,
      data_constructor: item.data_constructor,
      value: item.value,
    }
  })
}

///|
fn module_imported_references_from_interface_artifacts(
  imports : Array[@elaborate.BuslaneModuleImport],
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
) -> Array[ModuleImportedReference] {
  imports.map(fn(item) {
    let fingerprint = match
      find_module_interface_artifact(interfaces, item.module_path_text) {
      Some(interface) => interface.module_fingerprint
      None =>
        abort(
          "missing imported module fingerprint \{module_path_text} -> \{item.module_path_text}",
        )
    }
    {
      module_path_text: item.module_path_text,
      kind: item.kind,
      name: item.name,
      fingerprint,
      type_id: item.type_id,
      data_constructor: item.data_constructor,
      value: item.value,
    }
  })
}

///|
fn find_module_export(
  exports : Array[@elaborate.BuslaneModuleExport],
  kind : @elaborate.BuslaneModuleExportKind,
  name : String,
) -> @elaborate.BuslaneModuleExport? {
  for item in exports {
    if item.kind == kind && item.name == name {
      return Some(item)
    }
  }
  None
}

///|
fn find_compiled_module(
  modules : Array[CompiledModule],
  path : String,
) -> CompiledModule? {
  for module_ in modules {
    if module_.module_path_text == path {
      return Some(module_)
    }
  }
  None
}

///|
fn imported_environment_fingerprints(
  imported : @module_interface.ImportedEnvironment,
) -> Array[ImportedInterfaceFingerprint] {
  imported.modules.map(fn(interface) {
    {
      module_path_text: interface.module_path,
      fingerprint: interface_fingerprint(interface),
    }
  })
}

///|
fn module_fingerprint(
  interface : @module_interface.ModuleInterface,
  imported : Array[ImportedInterfaceFingerprint],
) -> CompilationFingerprint {
  let imports = imported
    .map(fn(entry) { "\{entry.module_path_text}=\{entry.fingerprint.value}" })
    .join(";")
  { value: "\{interface_fingerprint(interface).value}|imports:\{imports}" }
}

///|
fn interface_fingerprint(
  interface : @module_interface.ModuleInterface,
) -> CompilationFingerprint {
  let context = fingerprint_type_context(interface)
  let type_fingerprints = interface.types
    .map(fn(type_) { interface_type_fingerprint(context, type_) })
    .join(",")
  let alias_fingerprints = interface.type_aliases
    .map(fn(type_alias) { interface_alias_fingerprint(context, type_alias) })
    .join(",")
  let effect_fingerprints = interface.effects
    .map(fn(effect) { interface_effect_fingerprint(context, effect) })
    .join(",")
  let value_fingerprints = interface.values
    .map(fn(value) { interface_value_fingerprint(context, value) })
    .join(",")
  let hint_fingerprints = interface.optimization_hints
    .map(fn(hint) { hint.name })
    .join(",")
  {
    value: "\{interface.module_path}|types:\{type_fingerprints}|aliases:\{alias_fingerprints}|effects:\{effect_fingerprints}|values:\{value_fingerprints}|hints:\{hint_fingerprints}",
  }
}

///|
fn fingerprint_type_context(
  interface : @module_interface.ModuleInterface,
) -> FingerprintTypeContext {
  let nominal_types = []
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        nominal_types.push({
          symbol: declaration.symbol,
          name: declaration.name,
        })
      Enum(declaration) =>
        nominal_types.push({
          symbol: declaration.symbol,
          name: declaration.name,
        })
    }
  }
  { nominal_types, type_parameters: [] }
}

///|
fn interface_type_fingerprint(
  context : FingerprintTypeContext,
  type_ : @module_interface.ModuleInterfaceType,
) -> String {
  match type_ {
    Struct(declaration) => {
      let context = context.with_type_parameters(declaration.type_parameters)
      let context = context.with_type_parameters(
        declaration.type_members.map(fn(type_member) {
          type_member.type_parameter
        }),
      )
      let type_parameters = declaration.type_parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let type_members = declaration.type_members
        .map(interface_type_member_fingerprint)
        .join(",")
      let fields = declaration.fields
        .map(fn(field) { interface_field_fingerprint(context, field) })
        .join(",")
      "struct \{declaration.name}[\{type_parameters}]{\{type_members}|\{fields}}"
    }
    Enum(declaration) => {
      let context = context.with_type_parameters(declaration.type_parameters)
      let type_parameters = declaration.type_parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let variants = declaration.variants
        .map(fn(variant) { interface_variant_fingerprint(context, variant) })
        .join(",")
      "enum \{declaration.name}[\{type_parameters}]{\{variants}}"
    }
  }
}

///|
fn interface_type_member_fingerprint(
  type_member : @module_interface.ModuleInterfaceTypeMember,
) -> String {
  "\{type_member.name}:\{kind_fingerprint(type_member.kind)}#\{type_member.index}"
}

///|
fn interface_field_fingerprint(
  context : FingerprintTypeContext,
  field : @module_interface.ModuleInterfaceField,
) -> String {
  let offered = if field.is_offered { ":offer" } else { "" }
  "\{field.name}:\{context.type_fingerprint(field.type_)}#\{field.index}\{offered}"
}

///|
fn interface_variant_fingerprint(
  context : FingerprintTypeContext,
  variant : @module_interface.ModuleInterfaceVariant,
) -> String {
  let context = context.with_type_parameters(variant.type_parameters)
  let type_parameters = variant.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let payload = variant.payload
    .map(fn(type_) { context.type_fingerprint(type_) })
    .join(",")
  "\{variant.name}[\{type_parameters}](\{payload})#\{variant.index}"
}

///|
fn interface_alias_fingerprint(
  context : FingerprintTypeContext,
  type_alias : @module_interface.ModuleInterfaceTypeAlias,
) -> String {
  "\{type_alias.name}:\{kind_fingerprint(type_alias.kind)}=\{context.type_fingerprint(type_alias.body)}"
}

///|
fn interface_effect_fingerprint(
  context : FingerprintTypeContext,
  effect : @module_interface.ModuleInterfaceEffect,
) -> String {
  let context = context.with_type_parameters(effect.type_parameters)
  let type_parameters = effect.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let operations = effect.operations
    .map(fn(operation) { interface_operation_fingerprint(context, operation) })
    .join(",")
  "effect \{effect.name}[\{type_parameters}]{\{operations}}"
}

///|
fn interface_operation_fingerprint(
  context : FingerprintTypeContext,
  operation : @module_interface.ModuleInterfaceOperation,
) -> String {
  let context = context.with_type_parameters(operation.type_parameters)
  let type_parameters = operation.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let payload = operation.payload
    .map(fn(type_) { context.type_fingerprint(type_) })
    .join(",")
  let result = context.type_fingerprint(operation.result)
  "\{operation.name}[\{type_parameters}](\{payload})->\{result}#\{operation.index}"
}

///|
fn interface_value_fingerprint(
  context : FingerprintTypeContext,
  value : @module_interface.ModuleInterfaceValue,
) -> String {
  let kind = module_value_kind_fingerprint(value.kind)
  let type_ = context.type_fingerprint(value.type_)
  let parameters = interface_value_parameters_fingerprint(
    context,
    value.parameters,
  )
  "\{value.name}:\{kind}:\{type_}(\{parameters})"
}

///|
fn interface_value_parameters_fingerprint(
  context : FingerprintTypeContext,
  parameters : Array[@module_interface.ModuleInterfaceValueParameter]?,
) -> String {
  match parameters {
    Some(parameters) =>
      parameters
      .map(fn(parameter) {
        let auto = if parameter.is_auto { ":auto" } else { "" }
        let offered = if parameter.is_offered { ":offer" } else { "" }
        "\{parameter.name}:\{context.type_fingerprint(parameter.type_)}\{auto}\{offered}"
      })
      .join(",")
    None => ""
  }
}

///|
fn module_value_kind_fingerprint(
  kind : @module_interface.ModuleInterfaceValueKind,
) -> String {
  match kind {
    Function => "function"
    Let => "let"
    Offer => "offer"
  }
}

///|
fn type_parameter_fingerprint(parameter : @types.TypeParameter) -> String {
  kind_fingerprint(parameter.kind)
}

///|
fn FingerprintTypeContext::with_type_parameters(
  self : FingerprintTypeContext,
  parameters : Array[@types.TypeParameter],
) -> FingerprintTypeContext {
  let type_parameters = self.type_parameters.copy()
  for parameter in parameters {
    type_parameters.push({
      symbol: parameter.id,
      name: parameter.name,
      kind: parameter.kind,
    })
  }
  { nominal_types: self.nominal_types, type_parameters }
}

///|
fn FingerprintTypeContext::type_fingerprint(
  self : FingerprintTypeContext,
  type_ : @types.Type,
) -> String {
  match type_ {
    Error => "<error>"
    Primitive(primitive) => @prettyprinter.render(primitive.pretty(), width=100)
    Constructor(symbol) => self.type_name(symbol)
    Apply(callee, arguments) => {
      let callee_fingerprint = self.type_fingerprint(callee)
      let arguments = arguments
        .map(fn(argument) { self.type_fingerprint(argument) })
        .join(",")
      "\{callee_fingerprint}[\{arguments}]"
    }
    TypeLambda(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      let parameter_fingerprints = parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let body_fingerprint = context.type_fingerprint(body)
      "type[\{parameter_fingerprints}]=>\{body_fingerprint}"
    }
    Parameter(symbol) => self.type_parameter_name(symbol)
    Function(parameters, result, effect) => {
      let parameters = parameters
        .map(fn(parameter) { self.type_fingerprint(parameter) })
        .join(",")
      let result = self.type_fingerprint(result)
      let effect = self.effect_fingerprint(effect)
      "(\{parameters})->\{result}!\{effect}"
    }
    Forall(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      let parameter_fingerprints = parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let body_fingerprint = context.type_fingerprint(body)
      "forall[\{parameter_fingerprints}].\{body_fingerprint}"
    }
  }
}

///|
fn FingerprintTypeContext::effect_fingerprint(
  self : FingerprintTypeContext,
  effect : @types.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Singleton(symbol, arguments) => {
      let arguments = arguments
        .map(fn(argument) { self.type_fingerprint(argument) })
        .join(",")
      "\{@prettyprinter.render(symbol.pretty(), width=100)}[\{arguments}]"
    }
    Parameter(symbol) => self.type_parameter_name(symbol)
    Union(effects) =>
      "{\{effects.map(fn(effect) { self.effect_fingerprint(effect) }).join(",")}}"
  }
}

///|
fn FingerprintTypeContext::type_name(
  self : FingerprintTypeContext,
  symbol : @symbol.TypeSymbolId,
) -> String {
  for item in self.nominal_types {
    if item.symbol == symbol {
      return item.name
    }
  }
  @prettyprinter.render(symbol.pretty(), width=100)
}

///|
fn FingerprintTypeContext::type_parameter_name(
  self : FingerprintTypeContext,
  symbol : @symbol.TypeParameterId,
) -> String {
  for item in self.type_parameters {
    if item.symbol == symbol {
      return "\{item.name}:\{kind_fingerprint(item.kind)}"
    }
  }
  @prettyprinter.render(symbol.pretty(), width=100)
}

///|
fn kind_fingerprint(kind : @types.Kind) -> String {
  @prettyprinter.render(kind.pretty(), width=100)
}

///|
