///|
priv struct CachedSemanticModule {
  input : @module_frontend.ParsedModuleInput
  completion_source : CompletionSource
  imported : @module_interface.ImportedEnvironment
  index : SemanticIndex
  diagnostics : Array[CompilerDiagnostic]
  last_successful_interface : @module_interface.ModuleInterface?
}

///|
priv struct CachedParsedSource {
  source : @module_frontend.SourceInput
  module_ : @module_frontend.ParsedModuleInput?
  module_path_text : String?
  diagnostics : Array[CompilerDiagnostic]
}

///|
pub struct SemanticSnapshot {
  priv revision : Int
  priv completion : CompletionIndex
  priv result : AnalysisResult
}

///|
pub struct SemanticWorkspace {
  priv mut revision : Int
  priv mut sources : Array[@module_frontend.SourceInput]
  priv mut current : SemanticSnapshot?
  priv registry : @symbol.SymbolRegistry
  priv mut parse_cache : Map[String, CachedParsedSource]
  priv mut module_cache : Map[String, CachedSemanticModule]
  priv mut graph_cache : CachedModuleGraph?
}

///|
pub fn SemanticWorkspace::new() -> SemanticWorkspace {
  {
    revision: 0,
    sources: [],
    current: None,
    registry: SymbolRegistry(),
    parse_cache: Map([]),
    module_cache: Map([]),
    graph_cache: None,
  }
}

///|
pub fn SemanticWorkspace::replace_sources(
  self : SemanticWorkspace,
  sources : Array[@module_frontend.SourceInput],
) -> SemanticSnapshot? {
  let sources = sources.copy()
  sources.sort_by(fn(left, right) {
    String::compare(left.source_id, right.source_id)
  })
  if sources == self.sources {
    return self.current
  }
  self.sources = sources
  self.revision += 1
  self.current = self.build_snapshot(sources, self.revision)
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
  let sources = self.sources.copy()
  let mut replaced = false
  for index, existing in sources {
    if existing.source_id == source.source_id {
      if existing.text == source.text {
        return self.current
      }
      sources[index] = source
      replaced = true
      break
    }
  }
  if !replaced {
    sources.push(source)
  }
  self.replace_sources(sources)
}

///|
pub fn SemanticWorkspace::remove_source(
  self : SemanticWorkspace,
  source_id : String,
) -> SemanticSnapshot? {
  self.replace_sources(
    self.sources.filter(fn(source) { source.source_id != source_id }),
  )
}

///|
pub fn SemanticWorkspace::sources(
  self : SemanticWorkspace,
) -> Array[@module_frontend.SourceInput] {
  self.sources.copy()
}

///|
pub fn SemanticWorkspace::revision(self : SemanticWorkspace) -> Int {
  self.revision
}

///|
pub fn SemanticWorkspace::clear(self : SemanticWorkspace) -> Unit {
  self.revision += 1
  self.sources = []
  self.current = None
  self.parse_cache.clear()
  self.module_cache.clear()
  self.graph_cache = None
}

///|
fn SemanticWorkspace::build_snapshot(
  self : SemanticWorkspace,
  sources : Array[@module_frontend.SourceInput],
  revision : Int,
) -> SemanticSnapshot? {
  if sources.is_empty() {
    self.parse_cache.clear()
    self.module_cache.clear()
    self.graph_cache = None
    return None
  }
  let modules = []
  let known_module_paths = []
  let diagnostics = []
  let next_parse_cache : Map[String, CachedParsedSource] = Map([])
  for source in sources {
    let cached = match self.parse_cache.get(source.source_id) {
      Some(cached) if cached.source == source => cached
      _ => parse_cached_source(source)
    }
    diagnostics.append(cached.diagnostics)
    if cached.module_path_text is Some(module_path) {
      known_module_paths.push(module_path)
    }
    if cached.module_ is Some(module_) {
      modules.push(module_)
    }
    next_parse_cache[source.source_id] = cached
  }
  self.parse_cache = next_parse_cache
  guard modules.get(0) is Some(root_module) else {
    self.graph_cache = None
    return Some(self.snapshot_from_diagnostics(revision, diagnostics))
  }
  let inputs : @module_frontend.ModuleInputSet = {
    root_module_path_text: root_module.header.module_path_text,
    modules,
  }
  let parsed_module_paths = modules.map(fn(module_) {
    module_.header.module_path_text
  })
  let unavailable_module_paths = known_module_paths.filter(fn(module_path) {
    !parsed_module_paths.contains(module_path)
  })
  let tolerant = self.module_graph_for_inputs(inputs, unavailable_module_paths)
  Some(
    self.build_graph_snapshot(
      tolerant.graph,
      revision,
      unavailable_module_paths,
      initial_diagnostics=diagnostics + tolerant.diagnostics,
    ),
  )
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
fn SemanticWorkspace::snapshot_from_diagnostics(
  self : SemanticWorkspace,
  revision : Int,
  diagnostics : Array[CompilerDiagnostic],
) -> SemanticSnapshot {
  {
    revision,
    completion: {
      display: @typecheck.TypeDisplayContext::from_registry(self.registry),
      modules: [],
    },
    result: AnalysisResult::from_diagnostics(diagnostics),
  }
}

///|
fn SemanticWorkspace::build_graph_snapshot(
  self : SemanticWorkspace,
  graph : @module_frontend.ModuleGraph,
  revision : Int,
  unavailable_module_paths : Array[String],
  initial_diagnostics? : Array[CompilerDiagnostic] = [],
) -> SemanticSnapshot {
  let registry = self.registry
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let compiled : Array[AnalysisModuleSummary] = []
  let modules : Array[CachedSemanticModule] = []
  let next_cache : Map[String, CachedSemanticModule] = Map([])
  let dirty_modules = self.dirty_modules(graph)
  let changed_interfaces = self.removed_module_paths(
    graph, unavailable_module_paths,
  )
  let diagnostics = initial_diagnostics.copy()
  let definitions = []
  let references = []
  let hovers = []
  let inlay_hints = []
  for module_path in unavailable_module_paths {
    if self.module_cache.get(module_path) is Some(cached) {
      next_cache[module_path] = cached
      if cached.last_successful_interface is Some(module_interface) {
        compiled.push({
          module_path_text: module_path,
          interface: module_interface,
        })
      }
    }
  }
  for input in graph.modules {
    let module_path = input.header.module_path_text
    let imported = analysis_imported_interfaces(input.header, compiled)
    if imported.modules.length() != input.header.imports.length() {
      continue
    }
    let imports_changed = input.header.imports.any(fn(import_) {
      changed_interfaces.contains(import_.module_path_text)
    })
    let previous = self.module_cache.get(module_path)
    let module_ = if !dirty_modules.contains(module_path) &&
      !imports_changed &&
      previous is Some(cached) {
      cached
    } else {
      let rebuilt = build_cached_semantic_module(
        input, imported, registry, display,
      )
      match (rebuilt.last_successful_interface, previous) {
        (None, Some(previous)) =>
          {
            ..rebuilt,
            last_successful_interface: previous.last_successful_interface,
          }
        _ => rebuilt
      }
    }
    let previous_interface = match previous {
      Some(previous) => previous.last_successful_interface
      None => None
    }
    if module_.last_successful_interface != previous_interface {
      changed_interfaces.push(module_path)
    }
    diagnostics.append(module_.diagnostics)
    if module_.last_successful_interface is Some(module_interface) {
      compiled.push({
        module_path_text: module_path,
        interface: { ..module_interface, source_id: Some(input.source_id) },
      })
    }
    module_.index.append_analysis(definitions, references, hovers, inlay_hints)
    modules.push(module_)
    next_cache[module_path] = module_
  }
  self.module_cache = next_cache
  let semantic_tokens = build_semantic_tokens(definitions, references, registry)
  {
    revision,
    completion: { display, modules },
    result: {
      diagnostics,
      definitions,
      references,
      hovers,
      semantic_tokens,
      inlay_hints,
    },
  }
}

///|
fn SemanticWorkspace::dirty_modules(
  self : SemanticWorkspace,
  graph : @module_frontend.ModuleGraph,
) -> Array[String] {
  let dirty = []
  for input in graph.modules {
    let module_path = input.header.module_path_text
    match self.module_cache.get(module_path) {
      Some(cached) if same_module_input(cached.input, input) => ()
      _ => dirty.push(module_path)
    }
  }
  dirty
}

///|
fn SemanticWorkspace::removed_module_paths(
  self : SemanticWorkspace,
  graph : @module_frontend.ModuleGraph,
  unavailable_module_paths : Array[String],
) -> Array[String] {
  let current_paths = graph.modules.map(fn(module_) {
    module_.header.module_path_text
  })
  current_paths.append(unavailable_module_paths)
  let removed = []
  for module_path, _ in self.module_cache {
    if !current_paths.contains(module_path) {
      removed.push(module_path)
    }
  }
  removed
}

///|
fn same_module_input(
  left : @module_frontend.ParsedModuleInput,
  right : @module_frontend.ParsedModuleInput,
) -> Bool {
  left.source_id == right.source_id && left.text == right.text
}

///|
fn build_cached_semantic_module(
  input : @module_frontend.ParsedModuleInput,
  imported : @module_interface.ImportedEnvironment,
  registry : @symbol.SymbolRegistry,
  display : @typecheck.TypeDisplayContext,
) -> CachedSemanticModule {
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported,
  )
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
    last_successful_interface: interface,
  }
}

///|
pub fn SemanticSnapshot::revision(self : SemanticSnapshot) -> Int {
  self.revision
}

///|
pub fn SemanticSnapshot::analysis(self : SemanticSnapshot) -> AnalysisResult {
  self.result.copy()
}

///|
pub fn SemanticSnapshot::diagnostics(
  self : SemanticSnapshot,
) -> Array[CompilerDiagnostic] {
  self.result.diagnostics.copy()
}

///|
pub fn SemanticSnapshot::definition_at(
  self : SemanticSnapshot,
  source_id : String,
  line : Int,
  column : Int,
) -> AnalysisLocation? {
  self.result.definition_at(source_id, line, column)
}

///|
pub fn SemanticSnapshot::hover_at(
  self : SemanticSnapshot,
  source_id : String,
  line : Int,
  column : Int,
) -> HoverEntry? {
  self.result.hover_at(source_id, line, column)
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
  self.result.inlay_hints_in_range(
    source_id, start_line, start_column, end_line, end_column,
  )
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

///|
fn AnalysisResult::copy(self : AnalysisResult) -> AnalysisResult {
  {
    diagnostics: self.diagnostics.copy(),
    definitions: self.definitions.copy(),
    references: self.references.copy(),
    hovers: self.hovers.copy(),
    semantic_tokens: self.semantic_tokens.copy(),
    inlay_hints: self.inlay_hints.copy(),
  }
}
