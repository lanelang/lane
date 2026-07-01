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
pub(all) enum SemanticTokenKind {
  VariableToken
  ParameterToken
} derive(Debug, Eq)

///|
pub(all) struct SemanticTokenEntry {
  location : AnalysisLocation
  kind : SemanticTokenKind
} derive(Debug, Eq)

///|
pub(all) enum InlayHintKind {
  TypeHint
  ParameterHint
  ImplicitArgumentHint
} derive(Debug, Eq)

///|
pub(all) struct InlayHintEntry {
  location : AnalysisLocation
  kind : InlayHintKind
  label : String
} derive(Debug, Eq)

///|
pub(all) struct AnalysisResult {
  diagnostics : Array[CompileDiagnostic]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
  semantic_tokens : Array[SemanticTokenEntry]
  inlay_hints : Array[InlayHintEntry]
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
    Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
    Ok(inputs) =>
      match build_module_graph(inputs) {
        Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
        Ok(graph) => analyze_module_graph(graph)
      }
  }
}

///|
pub fn analyze_import_reachable_source_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> AnalysisResult {
  match
    parse_import_reachable_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
    Ok(inputs) =>
      match build_module_graph(inputs) {
        Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
        Ok(graph) => analyze_module_graph(graph)
      }
  }
}

///|
fn AnalysisResult::from_diagnostics(
  diagnostics : Array[CompileDiagnostic],
) -> AnalysisResult {
  {
    diagnostics,
    definitions: [],
    references: [],
    hovers: [],
    semantic_tokens: [],
    inlay_hints: [],
  }
}

///|
fn analyze_module_graph(graph : ModuleGraph) -> AnalysisResult {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let display = TypeDisplayContext::from_registry(registry)
  let modules : Array[CompiledModule] = []
  let diagnostics = []
  let definitions = []
  let references = []
  let hovers = []
  let inlay_hints = []
  for input in graph.modules {
    let imported = imported_interfaces(input.header, modules)
    let resolved = @resolve.resolve_source_file_with_imports_result(
      input.source,
      registry,
      imported,
    )
    diagnostics.append(
      resolved.diagnostics.map(fn(diagnostic) {
        resolve_diagnostic(diagnostic, display).with_source_id(input.source_id)
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
            typecheck_diagnostic(diagnostic, display).with_source_id(
              input.source_id,
            )
          }),
        )
        let annotated_values = annotated_value_symbols(resolved.source)
        match (checked.source, checked.module_interface) {
          (Some(source), Some(interface)) if checked.diagnostics.is_empty() => {
            let imported_fingerprints = imported_environment_fingerprints(
              imported,
            )
            let fingerprint = module_fingerprint(
              interface, imported_fingerprints,
            )
            let object : ModuleObject = {
              module_path_text: input.header.module_path_text,
              checked: source,
              metadata: MetadataRegistry(),
              terms: [],
              externals: { builtins: [] },
              entries: [],
              exports: [],
              imports: [],
              fingerprint,
              imported_interface_fingerprints: imported_fingerprints,
            }
            modules.push({
              module_path_text: input.header.module_path_text,
              interface,
              object,
              fingerprint,
              imported_interface_fingerprints: imported_fingerprints,
            })
            collect_checked_source_analysis(
              input.source_id,
              input.text,
              source,
              display,
              definitions,
              references,
              hovers,
              inlay_hints,
              annotated_values,
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
  let semantic_tokens = build_semantic_tokens(definitions, references, registry)
  { diagnostics, definitions, references, hovers, semantic_tokens, inlay_hints }
}

///|
fn build_semantic_tokens(
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  registry : @symbol.SymbolRegistry,
) -> Array[SemanticTokenEntry] {
  let tokens = []
  for definition in definitions {
    add_value_semantic_token(
      tokens,
      registry,
      definition.symbol,
      definition.location,
    )
  }
  for reference in references {
    add_value_semantic_token(
      tokens,
      registry,
      reference.symbol,
      reference.location,
    )
  }
  tokens
}

///|
fn add_value_semantic_token(
  tokens : Array[SemanticTokenEntry],
  registry : @symbol.SymbolRegistry,
  symbol : AnalysisSymbol,
  location : AnalysisLocation,
) -> Unit {
  match symbol {
    Value(symbol) =>
      match semantic_token_kind_for_value(registry, symbol) {
        Some(kind) => tokens.push({ location, kind })
        None => ()
      }
    _ => ()
  }
}

///|
fn semantic_token_kind_for_value(
  registry : @symbol.SymbolRegistry,
  symbol : @symbol.ValueSymbolId,
) -> SemanticTokenKind? {
  guard registry.value_metadata(symbol) is Some(metadata) else { return None }
  match metadata.kind {
    Parameter => Some(ParameterToken)
    TopLevelValue | LocalBinding | PatternBinder => Some(VariableToken)
    TopLevelFunction | LocalFunction => None
  }
}
