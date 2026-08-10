///|
pub(all) enum AnalysisSymbol {
  Value(@symbol.ValueSymbolId)
  Type(@symbol.TypeSymbolId)
  TypeAlias(@symbol.TypeAliasSymbolId)
  Field(@symbol.FieldSymbolId)
  Variant(@symbol.VariantSymbolId)
  Effect(@symbol.EffectSymbolId)
  Operation(@symbol.OperationSymbolId)
  TypeParameter(@symbol.TypeParameterId)
  TypeMember(@symbol.TypeMemberSymbolId)
  ModuleBinding(source_id~ : String, exposure_id~ : Int)
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
pub(all) struct AnalysisPosition {
  source_id : String
  line : Int
  column : Int
} derive(Debug, Eq)

///|
pub(all) struct InlayHintEntry {
  position : AnalysisPosition
  kind : InlayHintKind
  label : String
} derive(Debug, Eq)

///|
priv struct InlayHintFact {
  hint : InlayHintEntry
  origin : @basic.SourceSpan
}

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
  inlay_hints.append(present_inlay_hints(self.inlay_hints))
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
  let metadata = required_value_metadata(registry, symbol)
  match metadata.provenance {
    GeneratedLocal => None
    Authored =>
      match metadata.kind {
        Parameter => Some(ParameterToken)
        TopLevelValue | LocalBinding | PatternBinder => Some(VariableToken)
        TopLevelFunction | LocalFunction => None
      }
  }
}

///|
fn required_value_metadata(
  registry : @symbol.SymbolRegistry,
  symbol : @symbol.ValueSymbolId,
) -> @symbol.ValueSymbolMetadata {
  guard registry.value_metadata(symbol) is Some(metadata) else {
    abort("semantic analysis missing metadata for value#\{symbol.index}")
  }
  metadata
}
