///|
pub(all) enum AnalysisSymbol {
  Value(@symbol.ValueSymbolId)
  Type(@symbol.TypeSymbolId)
  Field(@symbol.FieldSymbolId)
  Variant(@symbol.VariantSymbolId)
  Effect(@symbol.EffectSymbolId)
  Operation(@symbol.OperationSymbolId)
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
  diagnostics : Array[CompilerDiagnostic]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
  semantic_tokens : Array[SemanticTokenEntry]
  inlay_hints : Array[InlayHintEntry]
} derive(Debug, Eq)

///|
priv struct AnalysisModuleSummary {
  module_path_text : String
  interface : @module_interface.ModuleInterface
}

///|
pub fn analyze_sources(
  root_source : String,
  library_sources : Array[String],
) -> AnalysisResult {
  let library_inputs : Array[@module_frontend.SourceInput] = []
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
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
) -> AnalysisResult {
  match
    @module_frontend.parse_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
    Ok(inputs) =>
      match @module_frontend.build_module_graph(inputs) {
        Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
        Ok(graph) => analyze_module_graph(graph)
      }
  }
}

///|
pub fn analyze_import_reachable_source_inputs(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
) -> AnalysisResult {
  match
    @module_frontend.parse_import_reachable_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
    Ok(inputs) =>
      match @module_frontend.build_module_graph(inputs) {
        Err(diagnostics) => AnalysisResult::from_diagnostics(diagnostics)
        Ok(graph) => analyze_module_graph(graph)
      }
  }
}

///|
fn AnalysisResult::from_diagnostics(
  diagnostics : Array[CompilerDiagnostic],
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
fn analyze_module_graph(graph : @module_frontend.ModuleGraph) -> AnalysisResult {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let modules : Array[AnalysisModuleSummary] = []
  let diagnostics = []
  let definitions = []
  let references = []
  let hovers = []
  let inlay_hints = []
  for input in graph.modules {
    let imported = analysis_imported_interfaces(input.header, modules)
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
        match (checked.source, checked.module_interface) {
          (Some(source), Some(interface)) if checked.diagnostics.is_empty() => {
            let semantic_index = SemanticIndex::from_sources(
              resolved.source,
              Some(source),
              display,
              input.source_id,
              input.text,
            )
            diagnostics.append(
              checked_unused_local_value_binding_diagnostics(source, input.text).map(fn(
                  diagnostic,
                ) {
                  diagnostic.with_source_id(input.source_id)
                },
              ),
            )
            diagnostics.append(
              semantic_warning_diagnostics_from_index(
                semantic_index,
                resolved.source,
              ).map(fn(diagnostic) {
                diagnostic.with_source_id(input.source_id)
              }),
            )
            let interface = { ..interface, source_id: Some(input.source_id) }
            modules.push({
              module_path_text: input.header.module_path_text,
              interface,
            })
            semantic_index.append_analysis(
              definitions, references, hovers, inlay_hints,
            )
          }
          _ => {
            let semantic_index = SemanticIndex::from_sources(
              resolved.source,
              None,
              display,
              input.source_id,
              input.text,
            )
            semantic_index.append_analysis(
              definitions, references, hovers, inlay_hints,
            )
          }
        }
      }
      None => {
        let semantic_index = SemanticIndex::from_sources(
          resolved.source,
          None,
          display,
          input.source_id,
          input.text,
        )
        semantic_index.append_analysis(
          definitions, references, hovers, inlay_hints,
        )
      }
    }
  }
  let semantic_tokens = build_semantic_tokens(definitions, references, registry)
  { diagnostics, definitions, references, hovers, semantic_tokens, inlay_hints }
}

///|
fn SemanticIndex::append_analysis(
  self : SemanticIndex,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  inlay_hints : Array[InlayHintEntry],
) -> Unit {
  definitions.append(self.definitions)
  references.append(self.references)
  hovers.append(self.hovers)
  inlay_hints.append(self.inlay_hints)
}

///|
fn analysis_imported_interfaces(
  header : @module_frontend.ModuleHeader,
  modules : Array[AnalysisModuleSummary],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if find_analysis_module(modules, import_.module_path_text) is Some(module_) {
      imported.push(module_.interface)
    }
  }
  { modules: imported }
}

///|
fn find_analysis_module(
  modules : Array[AnalysisModuleSummary],
  module_path_text : String,
) -> AnalysisModuleSummary? {
  for module_ in modules {
    if module_.module_path_text == module_path_text {
      return Some(module_)
    }
  }
  None
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
