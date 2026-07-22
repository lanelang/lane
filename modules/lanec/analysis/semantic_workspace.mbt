///|
priv struct CachedSemanticModule {
  input : @module_frontend.ParsedModuleInput
  completion_source : CompletionSource
  imported : @module_interface.ImportedEnvironment
  index : SemanticIndex
  diagnostics : Array[CompilerDiagnostic]
  semantic_tokens : Array[SemanticTokenEntry]
  last_successful_interface : @module_interface.ModuleInterface?
  last_successful_symbols : @symbol.SymbolMetadataArena?
}

///|
priv enum CachedSemanticSlot {
  Missing
  Available(CachedSemanticModule)
}

///|
priv struct CachedParsedSource {
  source : @module_frontend.SourceInput
  module_ : @module_frontend.ParsedModuleInput?
  module_path_text : String?
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct SourceLayout {
  source_ids : Array[String]
  slots : Map[String, Int]
}

///|
fn SourceLayout::from_ids(source_ids : Array[String]) -> SourceLayout {
  let slots : Map[String, Int] = Map([])
  for index, source_id in source_ids {
    slots[source_id] = index
  }
  { source_ids, slots }
}

///|
pub struct SemanticSnapshot {
  priv revision : Int
  priv source_layout : SourceLayout
  priv parsed_sources : SnapshotTree[CachedParsedSource]
  priv graph : CachedModuleGraph?
  priv modules : SnapshotTree[CachedSemanticSlot]
  priv definition_locations : SymbolLocationIndex
  priv completion : CompletionIndex
  priv changed_source_ids : Array[String]
}

///|
pub struct SemanticWorkspace {
  priv mut revision : Int
  priv mut sources : Map[String, @module_frontend.SourceInput]
  priv mut source_layout : SourceLayout
  priv dirty_sources : Array[String]
  priv dirty_source_set : Map[String, Bool]
  priv mut current : SemanticSnapshot?
  priv mut allocator : @symbol.SymbolIdentityAllocator
  priv parse_cache : Map[String, CachedParsedSource]
  priv mut module_cache : Map[String, CachedSemanticModule]
  priv mut parsed_sources : SnapshotTree[CachedParsedSource]
  priv mut modules : SnapshotTree[CachedSemanticSlot]
  priv mut definition_locations : SymbolLocationIndex
  priv mut graph_cache : CachedModuleGraph?
}

///|
pub fn SemanticWorkspace::new() -> SemanticWorkspace {
  {
    revision: 0,
    sources: Map([]),
    source_layout: SourceLayout::from_ids([]),
    dirty_sources: [],
    dirty_source_set: Map([]),
    current: None,
    allocator: SymbolIdentityAllocator(),
    parse_cache: Map([]),
    module_cache: Map([]),
    parsed_sources: Empty,
    modules: Empty,
    definition_locations: SymbolLocationIndex::empty(),
    graph_cache: None,
  }
}

///|
pub fn SemanticWorkspace::replace_sources(
  self : SemanticWorkspace,
  sources : Array[@module_frontend.SourceInput],
) -> SemanticSnapshot? {
  let next_sources : Map[String, @module_frontend.SourceInput] = Map([])
  let next_source_ids = []
  for source in sources {
    if !next_sources.contains(source.source_id) {
      next_source_ids.push(source.source_id)
    }
    next_sources[source.source_id] = source
  }
  next_source_ids.sort_by(String::compare)
  let source_set_changed = next_source_ids != self.source_layout.source_ids
  for source_id, source in self.sources {
    match next_sources.get(source_id) {
      Some(next) if next == source => ()
      _ => self.enqueue_dirty_source(source_id)
    }
  }
  for source_id, source in next_sources {
    match self.sources.get(source_id) {
      Some(previous) if previous == source => ()
      _ => self.enqueue_dirty_source(source_id)
    }
  }
  if self.dirty_sources.is_empty() {
    return self.current
  }
  self.sources = next_sources
  if source_set_changed {
    self.source_layout = SourceLayout::from_ids(next_source_ids)
  }
  self.revision += 1
  self.current = self.refresh_snapshot(source_set_changed)
  self.current
}

///|
pub fn SemanticWorkspace::snapshot(
  self : SemanticWorkspace,
) -> SemanticSnapshot? {
  self.current
}

///|
pub fn SemanticWorkspace::upsert_source(
  self : SemanticWorkspace,
  source : @module_frontend.SourceInput,
) -> SemanticSnapshot? {
  match self.sources.get(source.source_id) {
    Some(previous) if previous == source => return self.current
    _ => ()
  }
  let source_set_changed = !self.sources.contains(source.source_id)
  self.sources[source.source_id] = source
  if source_set_changed {
    let source_ids = self.source_layout.source_ids.copy()
    source_ids.push(source.source_id)
    source_ids.sort_by(String::compare)
    self.source_layout = SourceLayout::from_ids(source_ids)
  }
  self.enqueue_dirty_source(source.source_id)
  self.revision += 1
  self.current = self.refresh_snapshot(source_set_changed)
  self.current
}

///|
pub fn SemanticWorkspace::remove_source(
  self : SemanticWorkspace,
  source_id : String,
) -> SemanticSnapshot? {
  guard self.sources.contains(source_id) else { return self.current }
  self.sources.remove(source_id)
  self.source_layout = SourceLayout::from_ids(
    self.source_layout.source_ids.filter(fn(id) { id != source_id }),
  )
  self.enqueue_dirty_source(source_id)
  self.revision += 1
  self.current = self.refresh_snapshot(true)
  self.current
}

///|
pub fn SemanticWorkspace::sources(
  self : SemanticWorkspace,
) -> Array[@module_frontend.SourceInput] {
  let result = []
  for source_id in self.source_layout.source_ids {
    if self.sources.get(source_id) is Some(source) {
      result.push(source)
    }
  }
  result
}

///|
pub fn SemanticWorkspace::revision(self : SemanticWorkspace) -> Int {
  self.revision
}

///|
pub fn SemanticWorkspace::clear(self : SemanticWorkspace) -> Unit {
  self.revision += 1
  self.sources.clear()
  self.source_layout = SourceLayout::from_ids([])
  self.dirty_sources.clear()
  self.dirty_source_set.clear()
  self.current = None
  self.allocator = SymbolIdentityAllocator()
  self.parse_cache.clear()
  self.module_cache.clear()
  self.parsed_sources = Empty
  self.modules = Empty
  self.definition_locations = SymbolLocationIndex::empty()
  self.graph_cache = None
}

///|
fn SemanticWorkspace::enqueue_dirty_source(
  self : SemanticWorkspace,
  source_id : String,
) -> Unit {
  if !self.dirty_source_set.contains(source_id) {
    self.dirty_source_set[source_id] = true
    self.dirty_sources.push(source_id)
  }
}

///|
fn SemanticWorkspace::refresh_snapshot(
  self : SemanticWorkspace,
  source_set_changed : Bool,
) -> SemanticSnapshot? {
  if self.sources.is_empty() {
    self.parse_cache.clear()
    self.module_cache.clear()
    self.parsed_sources = Empty
    self.modules = Empty
    self.definition_locations = SymbolLocationIndex::empty()
    self.graph_cache = None
    self.dirty_sources.clear()
    self.dirty_source_set.clear()
    return None
  }
  let changed_source_ids = self.dirty_sources.copy()
  self.dirty_sources.clear()
  self.dirty_source_set.clear()
  let dirty_module_paths = []
  let mut topology_changed = source_set_changed
  for source_id in changed_source_ids {
    let previous = self.parse_cache.get(source_id)
    let next = match self.sources.get(source_id) {
      Some(source) => Some(parse_cached_source(source))
      None => None
    }
    if !same_parsed_topology(previous, next) {
      topology_changed = true
    }
    if previous is Some(cached) && cached.module_path_text is Some(module_path) {
      push_unique(dirty_module_paths, module_path)
    }
    match next {
      Some(cached) => {
        if cached.module_path_text is Some(module_path) {
          push_unique(dirty_module_paths, module_path)
        }
        self.parse_cache[source_id] = cached
      }
      None => self.parse_cache.remove(source_id)
    }
  }
  self.update_parsed_source_tree(changed_source_ids, source_set_changed)
  let changed_semantic_sources = if topology_changed {
    self.rebuild_topology()
  } else {
    self.rebuild_dirty_modules(dirty_module_paths)
  }
  for source_id in changed_semantic_sources {
    push_unique(changed_source_ids, source_id)
  }
  Some(self.snapshot_from_current_state(changed_source_ids))
}

///|
fn SemanticWorkspace::update_parsed_source_tree(
  self : SemanticWorkspace,
  changed_source_ids : Array[String],
  source_set_changed : Bool,
) -> Unit {
  if source_set_changed ||
    self.parsed_sources.length() != self.source_layout.source_ids.length() {
    let parsed = []
    for source_id in self.source_layout.source_ids {
      if self.parse_cache.get(source_id) is Some(cached) {
        parsed.push(cached)
      }
    }
    self.parsed_sources = SnapshotTree::from_array(parsed)
    return
  }
  let mut tree = self.parsed_sources
  for source_id in changed_source_ids {
    if self.source_layout.slots.get(source_id) is Some(slot) &&
      self.parse_cache.get(source_id) is Some(cached) {
      tree = tree.set(slot, cached)
    }
  }
  self.parsed_sources = tree
}

///|
fn parse_cached_source(
  source : @module_frontend.SourceInput,
) -> CachedParsedSource {
  let parsed = @module_frontend.parse_module_inputs(source, [])
  let module_path_text = match parsed.headers.get(0) {
    Some(header) => Some(header.module_path_text)
    None => None
  }
  {
    source,
    module_: parsed.modules.get(0),
    module_path_text,
    diagnostics: parsed.diagnostics,
  }
}

///|
fn same_parsed_topology(
  previous : CachedParsedSource?,
  next : CachedParsedSource?,
) -> Bool {
  match (previous, next) {
    (None, None) => true
    (Some(previous), Some(next)) =>
      previous.module_path_text == next.module_path_text &&
      parsed_module_header(previous) == parsed_module_header(next)
    _ => false
  }
}

///|
fn parsed_module_header(
  source : CachedParsedSource,
) -> CachedModuleGraphInputHeader? {
  source.module_.map(cached_module_graph_input_header)
}

///|
fn SemanticWorkspace::rebuild_topology(
  self : SemanticWorkspace,
) -> Array[String] {
  let parsed_modules = []
  let known_module_paths = []
  for source_id in self.source_layout.source_ids {
    if self.parse_cache.get(source_id) is Some(cached) {
      if cached.module_path_text is Some(module_path) {
        known_module_paths.push(module_path)
      }
      if cached.module_ is Some(module_) {
        parsed_modules.push(module_)
      }
    }
  }
  guard parsed_modules.get(0) is Some(root_module) else {
    self.graph_cache = None
    self.modules = Empty
    self.definition_locations = SymbolLocationIndex::empty()
    return self.source_layout.source_ids.copy()
  }
  let inputs : @module_frontend.ModuleInputSet = {
    root_module_path_text: root_module.header.module_path_text,
    modules: parsed_modules,
  }
  let parsed_module_paths = parsed_modules.map(fn(module_) {
    module_.header.module_path_text
  })
  let unavailable_module_paths = known_module_paths.filter(fn(module_path) {
    !parsed_module_paths.contains(module_path)
  })
  let result = @module_frontend.build_tolerant_module_graph(
    inputs,
    unavailable_module_path_texts=unavailable_module_paths,
  )
  let graph = CachedModuleGraph::from_graph(result)
  self.graph_cache = Some(graph)
  self.rebuild_all_modules(result.graph.modules, unavailable_module_paths)
  self.source_layout.source_ids.copy()
}

///|
fn SemanticWorkspace::rebuild_all_modules(
  self : SemanticWorkspace,
  graph_modules : Array[@module_frontend.ParsedModuleInput],
  unavailable_module_paths : Array[String],
) -> Unit {
  let next_cache : Map[String, CachedSemanticModule] = Map([])
  let current_module_paths = graph_modules.map(fn(module_) {
    module_.header.module_path_text
  })
  current_module_paths.append(unavailable_module_paths)
  let changed_interfaces = []
  for module_path, _ in self.module_cache {
    if !current_module_paths.contains(module_path) {
      changed_interfaces.push(module_path)
    }
  }
  for module_path in unavailable_module_paths {
    if self.module_cache.get(module_path) is Some(cached) {
      next_cache[module_path] = cached
    }
  }
  let slots = Array::make(graph_modules.length(), Missing)
  let mut definition_locations = SymbolLocationIndex::empty()
  for index, input in graph_modules {
    let module_path = input.header.module_path_text
    let imported = imported_environment(input.header, next_cache)
    if imported.modules.length() != input.header.imports.length() {
      continue
    }
    let previous = self.module_cache.get(module_path)
    let input_changed = match previous {
      Some(cached) => !same_module_input(cached.input, input)
      None => true
    }
    let imports_changed = input.header.imports.any(fn(import_) {
      changed_interfaces.contains(import_.module_path_text)
    })
    let module_ = match previous {
      Some(cached) if !input_changed && !imports_changed => cached
      _ => {
        let rebuilt = build_cached_semantic_module(
          input,
          imported,
          imported_symbol_metadata(input.header, next_cache),
          self.allocator,
          previous,
        )
        preserve_last_successful_interface(rebuilt, previous)
      }
    }
    let previous_interface = match previous {
      Some(cached) => cached.last_successful_interface
      None => None
    }
    if !same_module_interface_semantics(
        module_.last_successful_interface,
        previous_interface,
      ) {
      changed_interfaces.push(module_path)
    }
    next_cache[module_path] = module_
    slots[index] = Available(module_)
    definition_locations = definition_locations.replace_definitions(
      [],
      module_.index.definitions,
    )
  }
  self.module_cache = next_cache
  self.modules = SnapshotTree::from_array(slots)
  self.definition_locations = definition_locations
}

///|
fn same_module_input(
  left : @module_frontend.ParsedModuleInput,
  right : @module_frontend.ParsedModuleInput,
) -> Bool {
  left.source_id == right.source_id && left.text == right.text
}

///|
fn SemanticWorkspace::rebuild_dirty_modules(
  self : SemanticWorkspace,
  dirty_module_paths : Array[String],
) -> Array[String] {
  guard self.graph_cache is Some(graph) else { return [] }
  let dirty_slots = Array::make(graph.ordered_module_paths.length(), false)
  for module_path in dirty_module_paths {
    if graph.module_slot_for_path(module_path) is Some(slot) {
      dirty_slots[slot] = true
    }
  }
  let changed_source_ids = []
  let mut modules = self.modules
  let mut definition_locations = self.definition_locations
  for index in 0..<dirty_slots.length() {
    if !dirty_slots[index] {
      continue
    }
    let module_path = graph.ordered_module_paths[index]
    let source_id = graph.ordered_module_source_ids[index]
    changed_source_ids.push(source_id)
    guard self.parse_cache.get(source_id) is Some(parsed) &&
      parsed.module_ is Some(input) else {
      continue
    }
    let imported = imported_environment(input.header, self.module_cache)
    let previous_definitions = match modules.get(index) {
      Some(Available(module_)) => module_.index.definitions
      _ => []
    }
    if imported.modules.length() != input.header.imports.length() {
      self.module_cache.remove(module_path)
      modules = modules.set(index, Missing)
      definition_locations = definition_locations.replace_definitions(
        previous_definitions,
        [],
      )
      continue
    }
    let previous = self.module_cache.get(module_path)
    let rebuilt = build_cached_semantic_module(
      input,
      imported,
      imported_symbol_metadata(input.header, self.module_cache),
      self.allocator,
      previous,
    )
    let module_ = preserve_last_successful_interface(rebuilt, previous)
    self.module_cache[module_path] = module_
    modules = modules.set(index, Available(module_))
    definition_locations = definition_locations.replace_definitions(
      previous_definitions,
      module_.index.definitions,
    )
    let previous_interface = match previous {
      Some(cached) => cached.last_successful_interface
      None => None
    }
    if !same_module_interface_semantics(
        module_.last_successful_interface,
        previous_interface,
      ) {
      for dependent_slot in graph.dependents_of_slot(index) {
        if dependent_slot > index {
          dirty_slots[dependent_slot] = true
        }
      }
    }
  }
  self.modules = modules
  self.definition_locations = definition_locations
  changed_source_ids
}

///|
fn imported_environment(
  header : @module_frontend.ModuleHeader,
  modules : Map[String, CachedSemanticModule],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if modules.get(import_.module_path_text) is Some(cached) &&
      cached.last_successful_interface is Some(interface) {
      imported.push({ ..interface, source_id: Some(cached.input.source_id) })
    }
  }
  { modules: imported }
}

///|
fn imported_symbol_metadata(
  header : @module_frontend.ModuleHeader,
  modules : Map[String, CachedSemanticModule],
) -> Array[@symbol.SymbolMetadataArena] {
  let imported = []
  for import_ in header.imports {
    if modules.get(import_.module_path_text) is Some(cached) &&
      cached.last_successful_symbols is Some(symbols) {
      imported.push(symbols)
    }
  }
  imported
}

///|
fn preserve_last_successful_interface(
  rebuilt : CachedSemanticModule,
  previous : CachedSemanticModule?,
) -> CachedSemanticModule {
  match (rebuilt.last_successful_interface, previous) {
    (None, Some(previous)) =>
      {
        ..rebuilt,
        last_successful_interface: previous.last_successful_interface,
        last_successful_symbols: previous.last_successful_symbols,
      }
    _ => rebuilt
  }
}

///|
fn same_module_interface_semantics(
  left : @module_interface.ModuleInterface?,
  right : @module_interface.ModuleInterface?,
) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(left), Some(right)) =>
      match
        (
          @artifact_core.canonical_module_interface_bytes(left),
          @artifact_core.canonical_module_interface_bytes(right),
        ) {
        (Ok(left), Ok(right)) => left == right
        _ => false
      }
    _ => false
  }
}

///|
fn SemanticWorkspace::snapshot_from_current_state(
  self : SemanticWorkspace,
  changed_source_ids : Array[String],
) -> SemanticSnapshot {
  let visible_symbols = []
  for _, module_ in self.module_cache {
    if module_.last_successful_symbols is Some(symbols) {
      visible_symbols.push(symbols)
    }
  }
  let display = @typecheck.TypeDisplayContext::from_registry(
    self.allocator.registry(imports=visible_symbols),
  )
  {
    revision: self.revision,
    source_layout: self.source_layout,
    parsed_sources: self.parsed_sources,
    graph: self.graph_cache,
    modules: self.modules,
    definition_locations: self.definition_locations,
    completion: { display, graph: self.graph_cache, modules: self.modules },
    changed_source_ids,
  }
}

///|
fn build_cached_semantic_module(
  input : @module_frontend.ParsedModuleInput,
  imported : @module_interface.ImportedEnvironment,
  imported_symbols : Array[@symbol.SymbolMetadataArena],
  allocator : @symbol.SymbolIdentityAllocator,
  previous : CachedSemanticModule?,
) -> CachedSemanticModule {
  let registry = allocator.registry(imports=imported_symbols)
  let previous_declarations = previous.map(fn(previous) {
    previous.index.registry.declaration_identities()
  })
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported,
    previous_declarations~,
  )
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    resolve_diagnostic(diagnostic, display).with_source_id(input.source_id)
  })
  let checked = if resolved.diagnostics.is_empty() {
    Some(
      @typecheck.typecheck_checked_source_file_with_imported_environment(
        resolved.source,
        imported,
      ),
    )
  } else {
    None
  }
  let mut checked_source = None
  let mut interface = None
  let mut exported_symbols = None
  if checked is Some(checked) {
    diagnostics.append(
      checked.diagnostics.map(fn(diagnostic) {
        typecheck_diagnostic(diagnostic, display).with_source_id(
          input.source_id,
        )
      }),
    )
    if checked.diagnostics.is_empty() {
      checked_source = checked.source
      interface = checked.module_interface
      if interface is Some(interface) {
        exported_symbols = Some(
          interface.exported_symbol_metadata(resolved.source.symbols),
        )
      }
    }
  }
  let index = SemanticIndex::from_sources(
    resolved.source,
    checked_source,
    display,
    input.source_id,
    input.text,
  )
  if checked_source is Some(source) {
    diagnostics.append(
      checked_unused_local_value_binding_diagnostics(source, input.text).map(fn(
        diagnostic,
      ) {
        diagnostic.with_source_id(input.source_id)
      }),
    )
    diagnostics.append(
      semantic_warning_diagnostics_from_index(index, resolved.source).map(fn(
        diagnostic,
      ) {
        diagnostic.with_source_id(input.source_id)
      }),
    )
  }
  {
    input,
    completion_source: CompletionSource::from_input(input),
    imported,
    index,
    diagnostics,
    semantic_tokens: build_semantic_tokens(
      index.definitions,
      index.references,
      registry,
    ),
    last_successful_interface: interface,
    last_successful_symbols: exported_symbols,
  }
}

///|
fn push_unique(items : Array[String], item : String) -> Unit {
  if !items.contains(item) {
    items.push(item)
  }
}

///|
pub fn SemanticSnapshot::revision(self : SemanticSnapshot) -> Int {
  self.revision
}

///|
pub fn SemanticSnapshot::analysis(self : SemanticSnapshot) -> AnalysisResult {
  let diagnostics = self.parse_and_graph_diagnostics()
  let definitions = []
  let references = []
  let hovers = []
  let semantic_tokens = []
  let inlay_hints = []
  self.modules.each(fn(slot) {
    if slot is Available(module_) {
      diagnostics.append(module_.diagnostics)
      module_.index.append_analysis(
        definitions, references, hovers, inlay_hints,
      )
      semantic_tokens.append(module_.semantic_tokens)
    }
  })
  { diagnostics, definitions, references, hovers, semantic_tokens, inlay_hints }
}

///|
pub fn SemanticSnapshot::diagnostics(
  self : SemanticSnapshot,
) -> Array[CompilerDiagnostic] {
  let diagnostics = self.parse_and_graph_diagnostics()
  self.modules.each(fn(slot) {
    if slot is Available(module_) {
      diagnostics.append(module_.diagnostics)
    }
  })
  diagnostics
}

///|
fn SemanticSnapshot::diagnostics_for_source(
  self : SemanticSnapshot,
  source_id : String,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  if self.source_layout.slots.get(source_id) is Some(slot) &&
    self.parsed_sources.get(slot) is Some(source) {
    diagnostics.append(source.diagnostics)
  }
  if self.graph is Some(graph) {
    if graph.module_slot_for_source(source_id) is Some(slot) &&
      self.modules.get(slot) is Some(Available(module_)) {
      diagnostics.append(module_.diagnostics)
    }
    diagnostics.append(
      graph.diagnostics.filter(fn(diagnostic) {
        diagnostic.primary_source_id() == Some(source_id)
      }),
    )
  }
  diagnostics
}

///|
pub fn SemanticSnapshot::diagnostic_delta(
  self : SemanticSnapshot,
) -> Array[(@module_frontend.SourceInput, Array[CompilerDiagnostic])] {
  let delta = []
  for source_id in self.changed_source_ids {
    if self.source_layout.slots.get(source_id) is Some(slot) &&
      self.parsed_sources.get(slot) is Some(source) {
      delta.push((source.source, self.diagnostics_for_source(source_id)))
    }
  }
  delta
}

///|
fn SemanticSnapshot::parse_and_graph_diagnostics(
  self : SemanticSnapshot,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  self.parsed_sources.each(fn(source) { diagnostics.append(source.diagnostics) })
  if self.graph is Some(graph) {
    diagnostics.append(graph.diagnostics)
  }
  diagnostics
}

///|
pub fn SemanticSnapshot::definition_at(
  self : SemanticSnapshot,
  source_id : String,
  line : Int,
  column : Int,
) -> AnalysisLocation? {
  guard self.semantic_index(source_id) is Some(index) else { return None }
  match index.reference_at(line, column) {
    Some(reference) => self.definition_locations.get(reference.symbol)
    None =>
      index
      .definition_entry_at(line, column)
      .map(fn(definition) { definition.location })
  }
}

///|
pub fn SemanticSnapshot::hover_at(
  self : SemanticSnapshot,
  source_id : String,
  line : Int,
  column : Int,
) -> HoverEntry? {
  guard self.semantic_index(source_id) is Some(index) else { return None }
  index.hover_at(line, column)
}

///|
pub fn SemanticSnapshot::inlay_hints_in_range(
  self : SemanticSnapshot,
  source_id : String,
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
) -> Array[InlayHintEntry] {
  guard self.semantic_index(source_id) is Some(index) else { return [] }
  index.inlay_hints_in_range(start_line, start_column, end_line, end_column)
}

///|
fn SemanticSnapshot::semantic_index(
  self : SemanticSnapshot,
  source_id : String,
) -> SemanticIndex? {
  guard self.graph is Some(graph) &&
    graph.module_slot_for_source(source_id) is Some(slot) &&
    self.modules.get(slot) is Some(Available(module_)) else {
    return None
  }
  Some(module_.index)
}

///|
pub fn SemanticSnapshot::complete(
  self : SemanticSnapshot,
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  self.completion.complete(source_id, line, column, trigger)
}
