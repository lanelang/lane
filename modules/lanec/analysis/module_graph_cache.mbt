///|
priv struct CachedModuleGraph {
  ordered_module_source_ids : Array[String]
  ordered_module_paths : Array[String]
  module_slots_by_source : Map[String, Int]
  module_slots_by_path : Map[String, Int]
  reverse_dependencies : Map[String, Array[String]]
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
  result : @module_frontend.TolerantModuleGraphResult,
) -> CachedModuleGraph {
  let ordered_module_source_ids = result.graph.modules.map(fn(module_) {
    module_.source_id
  })
  let ordered_module_paths = result.graph.modules.map(fn(module_) {
    module_.header.module_path_text
  })
  let module_slots_by_source : Map[String, Int] = Map([])
  let module_slots_by_path : Map[String, Int] = Map([])
  let reverse_dependencies : Map[String, Array[String]] = Map([])
  for index, module_ in result.graph.modules {
    let module_path = module_.header.module_path_text
    module_slots_by_source[module_.source_id] = index
    module_slots_by_path[module_path] = index
    reverse_dependencies[module_path] = []
  }
  for module_ in result.graph.modules {
    let module_path = module_.header.module_path_text
    for import_ in module_.header.imports {
      if reverse_dependencies.get(import_.module_path_text) is Some(dependents) {
        dependents.push(module_path)
      }
    }
  }
  {
    ordered_module_source_ids,
    ordered_module_paths,
    module_slots_by_source,
    module_slots_by_path,
    reverse_dependencies,
    diagnostics: result.diagnostics.copy(),
  }
}

///|
fn CachedModuleGraph::module_slot_for_source(
  self : CachedModuleGraph,
  source_id : String,
) -> Int? {
  self.module_slots_by_source.get(source_id)
}

///|
fn CachedModuleGraph::module_slot_for_path(
  self : CachedModuleGraph,
  module_path : String,
) -> Int? {
  self.module_slots_by_path.get(module_path)
}

///|
fn CachedModuleGraph::dependents(
  self : CachedModuleGraph,
  module_path : String,
) -> Array[String] {
  self.reverse_dependencies.get(module_path).unwrap_or([])
}

///|
fn cached_module_graph_input_header(
  module_ : @module_frontend.ParsedModuleInput,
) -> CachedModuleGraphInputHeader {
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
}
