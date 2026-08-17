///|
pub struct ModuleGraph {
  priv root_module_path_text : String
  priv modules : Array[ParsedModuleInput]
  priv unavailable_sources : Array[UnavailableParsedSource]
  priv reachable_module_path_texts : Array[String]
}

///|
pub struct TolerantModuleGraphResult {
  priv graph : ModuleGraph
  priv diagnostics : Array[@compiler_diag.CompilerDiagnostic]
}

///|
priv struct ModuleGraphAnalysis {
  modules : Array[ParsedModuleInput]
  unavailable_sources : Array[UnavailableParsedSource]
  reachable_module_path_texts : Array[String]
  failures : Array[ModuleDependencyFailure]
}

///|
pub fn ModuleGraph::root_module_path_text(self : ModuleGraph) -> String {
  self.root_module_path_text
}

///|
pub fn ModuleGraph::modules(self : ModuleGraph) -> Array[ParsedModuleInput] {
  self.modules.map(copy_parsed_module_input)
}

///|
pub fn ModuleGraph::unavailable_sources(
  self : ModuleGraph,
) -> Array[UnavailableParsedSource] {
  self.unavailable_sources.map(copy_unavailable_parsed_source)
}

///|
pub fn ModuleGraph::unavailable_module_path_texts(
  self : ModuleGraph,
) -> Array[String] {
  self.unavailable_sources.filter_map(fn(source) {
    source.recovered_header.map(fn(header) { header.module_path_text })
  })
}

///|
pub fn ModuleGraph::reachable_module_path_texts(
  self : ModuleGraph,
) -> Array[String] {
  self.reachable_module_path_texts.copy()
}

///|
pub fn TolerantModuleGraphResult::graph(
  self : TolerantModuleGraphResult,
) -> ModuleGraph {
  self.graph
}

///|
pub fn TolerantModuleGraphResult::diagnostics(
  self : TolerantModuleGraphResult,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  self.diagnostics.copy()
}

///|
fn copy_parsed_module_input(input : ParsedModuleInput) -> ParsedModuleInput {
  {
    source_id: input.source_id,
    text: input.text,
    concrete: input.concrete,
    identifiers: input.identifiers,
    diagnostics: input.diagnostics.copy(),
    header: {
      module_path_text: input.header.module_path_text,
      module_span: input.header.module_span,
      imports: input.header.imports.copy(),
    },
    source: input.source,
  }
}

///|
fn copy_unavailable_parsed_source(
  source : UnavailableParsedSource,
) -> UnavailableParsedSource {
  {
    source_id: source.source_id,
    text: source.text,
    concrete: source.concrete,
    identifiers: source.identifiers,
    diagnostics: source.diagnostics.copy(),
    recovered_header: source.recovered_header.map(fn(header) {
      {
        source_id: header.source_id,
        module_path_text: header.module_path_text,
        imports: header.imports.copy(),
      }
    }),
  }
}

///|
pub fn build_tolerant_module_graph(
  sources : Array[ParsedSource],
) -> TolerantModuleGraphResult? {
  let roots = sources.filter_map(ParsedSource::module_path_text)
  guard roots.get(0) is Some(root_module_path_text) else { return None }
  let analysis = analyze_module_graph(sources, roots)
  Some({
    graph: {
      root_module_path_text,
      modules: analysis.modules,
      unavailable_sources: analysis.unavailable_sources,
      reachable_module_path_texts: analysis.reachable_module_path_texts,
    },
    diagnostics: analysis.failures.map(ModuleDependencyFailure::diagnostic),
  })
}

///|
fn build_strict_module_graph(
  sources : Array[ParsedSource],
  root_module_path_text : String,
) -> Result[ModuleGraph, Array[@compiler_diag.CompilerDiagnostic]] {
  let analysis = analyze_module_graph(sources, [root_module_path_text])
  let diagnostics = []
  for source in analysis.unavailable_sources {
    diagnostics.append(source.diagnostics)
  }
  diagnostics.append(analysis.failures.map(ModuleDependencyFailure::diagnostic))
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  Ok({
    root_module_path_text,
    modules: analysis.modules,
    unavailable_sources: [],
    reachable_module_path_texts: analysis.reachable_module_path_texts,
  })
}

///|
fn analyze_module_graph(
  sources : Array[ParsedSource],
  roots : Array[String],
) -> ModuleGraphAnalysis {
  let analysis : ModuleGraphAnalysis = {
    modules: [],
    unavailable_sources: [],
    reachable_module_path_texts: [],
    failures: [],
  }
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let candidates = module_candidates(sources)
  for root in roots {
    guard find_parsed_source(sources, root) is Some(source) else { continue }
    visit_module(
      sources,
      root,
      SourceInput(source_id=source.source_id(), span=None),
      candidates,
      visiting,
      visited,
      analysis,
    )
  }
  analysis
}

///|
fn visit_module(
  sources : Array[ParsedSource],
  path : String,
  provenance : ModuleDependencyProvenance,
  candidates : Array[String],
  visiting : Array[String],
  visited : Array[String],
  analysis : ModuleGraphAnalysis,
) -> Unit {
  if visited.contains(path) {
    return
  }
  let matches = sources.filter(fn(source) {
    source.module_path_text() == Some(path)
  })
  guard matches.get(0) is Some(source) else {
    analysis.failures.push(
      ModuleDependencyFailure::missing_import(
        path,
        source_modules=candidates,
        interface_modules=[],
        provenance~,
      ),
    )
    return
  }
  if visiting.contains(path) {
    analysis.failures.push(
      ModuleDependencyFailure::import_cycle(path, provenance),
    )
    return
  }
  for duplicate in matches[1:] {
    let span = duplicate
      .available_module()
      .map(fn(module_) { module_.header.module_span })
    analysis.failures.push(
      ModuleDependencyFailure::duplicate_module(
        path,
        SourceInput(source_id=duplicate.source_id(), span~),
      ),
    )
  }
  visiting.push(path)
  match source {
    Available(module_) =>
      for import_ in module_.header.imports {
        visit_module(
          sources,
          import_.module_path_text,
          SourceInput(
            source_id=module_.source_id,
            span=Some(import_.import_span),
          ),
          candidates,
          visiting,
          visited,
          analysis,
        )
      }
    Unavailable(source) =>
      if source.recovered_header is Some(header) {
        for import_ in header.imports {
          visit_module(
            sources,
            import_,
            SourceInput(source_id=source.source_id, span=None),
            candidates,
            visiting,
            visited,
            analysis,
          )
        }
      }
  }
  ignore(visiting.pop())
  visited.push(path)
  analysis.reachable_module_path_texts.push(path)
  match source {
    Available(module_) =>
      analysis.modules.push(copy_parsed_module_input(module_))
    Unavailable(source) =>
      analysis.unavailable_sources.push(copy_unavailable_parsed_source(source))
  }
}

///|
fn find_parsed_source(
  sources : Array[ParsedSource],
  module_path_text : String,
) -> ParsedSource? {
  for source in sources {
    if source.module_path_text() == Some(module_path_text) {
      return Some(source)
    }
  }
  None
}

///|
fn module_candidates(sources : Array[ParsedSource]) -> Array[String] {
  let candidates = []
  for source in sources {
    if source.module_path_text() is Some(path) && !candidates.contains(path) {
      candidates.push(path)
    }
  }
  candidates
}
