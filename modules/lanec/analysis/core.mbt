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
