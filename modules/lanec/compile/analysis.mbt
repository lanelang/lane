///|
pub(all) enum AnalysisSymbol {
  Value(@symbol.ValueSymbolId)
  Type(@symbol.TypeSymbolId)
  Field(@symbol.FieldSymbolId)
  Variant(@symbol.VariantSymbolId)
  TypeParameter(@symbol.TypeParameterId)
  TypeMember(@symbol.TypeMemberSymbolId)
} derive(Debug, Eq)

///|
pub(all) struct AnalysisLocation {
  source_id : String
  span : @basic.SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DefinitionEntry {
  symbol : AnalysisSymbol
  location : AnalysisLocation
  label : String
  detail : String
} derive(Debug, Eq)

///|
pub(all) struct ReferenceEntry {
  location : AnalysisLocation
  symbol : AnalysisSymbol
  hover : String?
} derive(Debug, Eq)

///|
pub(all) struct HoverEntry {
  location : AnalysisLocation
  contents : String
} derive(Debug, Eq)

///|
pub(all) struct AnalysisResult {
  diagnostics : Array[CompileDiagnostic]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
} derive(Debug, Eq)

///|
pub fn analyze_sources(
  root_source : String,
  library_sources : Array[String],
) -> AnalysisResult {
  let library_inputs = []
  for index, source in library_sources {
    library_inputs.push({ source_id: "<library:\{index}>", text: source })
  }
  analyze_source_inputs(
    { source_id: "<root>", text: root_source },
    library_inputs,
  )
}

///|
pub fn analyze_source_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> AnalysisResult {
  match parse_module_input_set_from_inputs(root_source, library_sources) {
    Err(diagnostics) =>
      { diagnostics, definitions: [], references: [], hovers: [] }
    Ok(inputs) =>
      match build_module_graph(inputs) {
        Err(diagnostics) =>
          { diagnostics, definitions: [], references: [], hovers: [] }
        Ok(graph) => analyze_module_graph(graph)
      }
  }
}

///|
fn analyze_module_graph(graph : ModuleGraph) -> AnalysisResult {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let objects : Array[ModuleObject] = []
  let diagnostics = []
  let definitions = []
  let references = []
  let hovers = []
  for input in graph.modules {
    let imported = imported_objects(input.header, objects)
    let resolved = @resolve.resolve_source_file_with_imports_result(
      input.source,
      registry,
      imported,
    )
    diagnostics.append(
      resolved.diagnostics.map(fn(diagnostic) {
        make_error(
          @prettyprinter.render(diagnostic.kind, width=100),
          span=Some(diagnostic.loc),
        )
      }),
    )
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
    match checked {
      Some(checked) => {
        diagnostics.append(
          checked.diagnostics.map(fn(diagnostic) {
            make_error(
              @prettyprinter.render(diagnostic.kind, width=100),
              span=Some(diagnostic.loc),
            )
          }),
        )
        match (checked.source, checked.module_interface) {
          (Some(source), Some(interface)) if checked.diagnostics.is_empty() => {
            objects.push({
              module_path_text: input.header.module_path_text,
              interface,
              checked: source,
            })
            collect_checked_source_analysis(
              input.source_id,
              input.text,
              source,
              definitions,
              references,
              hovers,
            )
            collect_resolved_type_references(
              input.source_id,
              input.text,
              resolved.source,
              references,
              hovers,
            )
          }
          _ =>
            collect_resolved_source_analysis(
              input.source_id,
              input.text,
              resolved.source,
              definitions,
              references,
              hovers,
            )
        }
      }
      None =>
        collect_resolved_source_analysis(
          input.source_id,
          input.text,
          resolved.source,
          definitions,
          references,
          hovers,
        )
    }
  }
  { diagnostics, definitions, references, hovers }
}
