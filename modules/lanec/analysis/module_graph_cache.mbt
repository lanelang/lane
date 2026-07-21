///|
priv struct CachedModuleGraph {
  root_module_path_text : String
  input_headers : Array[CachedModuleGraphInputHeader]
  unavailable_module_path_texts : Array[String]
  ordered_module_source_ids : Array[String]
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct CachedModuleGraphInputHeader {
  source_id : String
  module_path_text : String
  module_span : @basic.SourceSpan
  imports : Array[CachedModuleGraphImportHeader]
} derive(Eq)

///|
priv struct CachedModuleGraphImportHeader {
  module_path_text : String
  import_span : @basic.SourceSpan
} derive(Eq)

///|
fn CachedModuleGraph::from_graph(
  inputs : @module_frontend.ModuleInputSet,
  unavailable_module_path_texts : Array[String],
  result : @module_frontend.TolerantModuleGraphResult,
) -> CachedModuleGraph {
  {
    root_module_path_text: inputs.root_module_path_text,
    input_headers: module_graph_input_headers(inputs.modules),
    unavailable_module_path_texts: unavailable_module_path_texts.copy(),
    ordered_module_source_ids: result.graph.modules.map(fn(module_) {
      module_.source_id
    }),
    diagnostics: result.diagnostics.copy(),
  }
}

///|
fn CachedModuleGraph::rehydrate(
  self : CachedModuleGraph,
  inputs : @module_frontend.ModuleInputSet,
  unavailable_module_path_texts : Array[String],
) -> @module_frontend.TolerantModuleGraphResult? {
  if self.root_module_path_text != inputs.root_module_path_text ||
    self.input_headers != module_graph_input_headers(inputs.modules) ||
    self.unavailable_module_path_texts != unavailable_module_path_texts {
    return None
  }
  let modules_by_source : Map[String, @module_frontend.ParsedModuleInput] = Map([],
  )
  for module_ in inputs.modules {
    modules_by_source[module_.source_id] = module_
  }
  let modules = []
  for source_id in self.ordered_module_source_ids {
    guard modules_by_source.get(source_id) is Some(module_) else { return None }
    modules.push(module_)
  }
  Some({
    graph: {
      root_module_path_text: inputs.root_module_path_text,
      modules,
      reachable_module_path_texts: inputs.modules.map(fn(module_) {
        module_.header.module_path_text
      }),
    },
    diagnostics: self.diagnostics.copy(),
  })
}

///|
fn module_graph_input_headers(
  modules : Array[@module_frontend.ParsedModuleInput],
) -> Array[CachedModuleGraphInputHeader] {
  modules.map(fn(module_) {
    {
      source_id: module_.source_id,
      module_path_text: module_.header.module_path_text,
      module_span: module_.header.module_span,
      imports: module_.header.imports.map(fn(import_) {
        {
          module_path_text: import_.module_path_text,
          import_span: import_.import_span,
        }
      }),
    }
  })
}

///|
fn SemanticWorkspace::module_graph_for_inputs(
  self : SemanticWorkspace,
  inputs : @module_frontend.ModuleInputSet,
  unavailable_module_path_texts : Array[String],
) -> @module_frontend.TolerantModuleGraphResult {
  if self.graph_cache is Some(cache) &&
    cache.rehydrate(inputs, unavailable_module_path_texts) is Some(result) {
    return result
  }
  let result = @module_frontend.build_tolerant_module_graph(
    inputs,
    unavailable_module_path_texts~,
  )
  self.graph_cache = Some(
    CachedModuleGraph::from_graph(inputs, unavailable_module_path_texts, result),
  )
  result
}
