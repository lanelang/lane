///|
priv enum SemanticBindingIdentity {
  ValueBinding(@symbol.ValueSymbolId)
  TypeBinding(@symbol.TypeSymbolId)
  EffectBinding(@symbol.EffectSymbolId)
  TypeParameterBinding(@symbol.TypeParameterId)
  AliasBinding(String)
} derive(Eq)

///|
priv enum SemanticBindingVisibility {
  GlobalBinding
  ScopedBinding(@basic.SourceSpan)
  OrderedBinding(scope~ : @basic.SourceSpan, declaration~ : @basic.SourceSpan)
}

///|
priv enum SemanticBindingKind {
  ValueBindingKind
  FunctionBindingKind
  TypeBindingKind
  TypeParameterBindingKind
  EffectBindingKind
}

///|
priv struct SemanticBindingFact {
  identity : SemanticBindingIdentity
  name : String
  kind : SemanticBindingKind
  is_offered : Bool
  mut detail : String
  mut type_ : @types.Type?
  visibility : SemanticBindingVisibility
}

///|
priv enum SemanticMemberIdentity {
  FieldMember(@symbol.FieldSymbolId)
  TypeMember(@symbol.TypeMemberSymbolId)
  VariantMember(@symbol.VariantSymbolId)
  OperationMember(@symbol.OperationSymbolId)
} derive(Eq)

///|
priv enum SemanticMemberKind {
  FieldMemberKind
  TypeMemberKind
  VariantMemberKind
  OperationMemberKind
}

///|
priv struct SemanticMemberFact {
  identity : SemanticMemberIdentity
  owner_name : String
  owner_type : @symbol.TypeSymbolId?
  name : String
  kind : SemanticMemberKind
  mut navigation_detail : String
  mut completion_detail : String
  payload_count : Int?
}

///|
priv enum GenericParameterKind {
  GenericTypeParameter
  GenericEffectParameter
}

///|
priv struct GenericParameterFact {
  symbol : @symbol.TypeParameterId
  name : String
  kind : GenericParameterKind
  loc : @basic.SourceSpan
}

///|
priv enum TopLevelSymbol {
  TopLevelValue(@symbol.ValueSymbolId)
  TopLevelType(@symbol.TypeSymbolId)
  TopLevelEffect(@symbol.EffectSymbolId)
  TopLevelAlias(String)
} derive(Eq)

///|
priv enum TopLevelDeclarationKind {
  ValueDeclaration
  FunctionDeclaration
  StructDeclaration
  EnumDeclaration
  ExternalTypeDeclaration
  EffectDeclaration
  TypeAliasDeclaration
  EffectAliasDeclaration
}

///|
priv struct TopLevelDeclarationFact {
  symbol : TopLevelSymbol
  name : String
  kind : TopLevelDeclarationKind
  is_public : Bool
  name_loc : @basic.SourceSpan
  loc : @basic.SourceSpan
}

///|
priv struct TopLevelReferenceFact {
  from : TopLevelSymbol
  to : TopLevelSymbol
}

///|
priv struct ParameterHintSignature {
  symbol : AnalysisSymbol
  parameters : Array[ParameterHintParameter]
}

///|
priv struct ParameterHintParameter {
  name : String
  is_auto : Bool
}

///|
priv struct SemanticIndex {
  registry : @symbol.SymbolRegistry
  source_id : String
  value_type_presentations : Array[@resolve.ResolvedValueTypePresentation]
  has_checked_source : Bool
  bindings : Array[SemanticBindingFact]
  members : Array[SemanticMemberFact]
  annotated_values : Array[@symbol.ValueSymbolId]
  generic_parameters : Array[GenericParameterFact]
  generic_parameter_references : Array[@symbol.TypeParameterId]
  used_import_symbols : Array[@resolve.ResolvedImportSymbol]
  top_level_declarations : Array[TopLevelDeclarationFact]
  top_level_references : Array[TopLevelReferenceFact]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
  inlay_hints : Array[InlayHintEntry]
  parameter_signatures : Array[ParameterHintSignature]
  mut current_top_level : TopLevelSymbol?
}

///|
fn SemanticIndex::from_sources(
  resolved : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile?,
  display : @typecheck.TypeDisplayContext,
  source_id : String,
  _source_text : String,
) -> SemanticIndex {
  let index = SemanticIndex::{
    registry: resolved.symbols,
    source_id,
    value_type_presentations: resolved.value_type_presentations,
    has_checked_source: checked is Some(_),
    bindings: [],
    members: [],
    annotated_values: [],
    generic_parameters: [],
    generic_parameter_references: [],
    used_import_symbols: [],
    top_level_declarations: [],
    top_level_references: [],
    definitions: [],
    references: [],
    hovers: [],
    inlay_hints: [],
    parameter_signatures: [],
    current_top_level: None,
  }
  for declaration in resolved.declarations {
    index.add_top_level_declaration(declaration)
  }
  for declaration in resolved.declarations {
    index.collect_resolved_declaration(declaration)
  }
  if checked is Some(source) {
    for declaration in source.declarations {
      index.enrich_checked_declaration_header(declaration, display)
    }
    for declaration in source.declarations {
      index.enrich_checked_declaration(declaration, display)
    }
  }
  index
}

///|
fn SemanticIndex::unused_private_top_level_declarations(
  self : SemanticIndex,
) -> Array[TopLevelDeclarationFact] {
  let reachable = []
  for declaration in self.top_level_declarations {
    if declaration.is_public {
      self.mark_top_level_reachable(declaration.symbol, reachable)
    }
  }
  let unused = self.top_level_declarations.filter(fn(declaration) {
    !declaration.is_public &&
    !declaration.name.has_prefix("_") &&
    !reachable.contains(declaration.symbol)
  })
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn SemanticIndex::owner_members(
  self : SemanticIndex,
  owner : String,
) -> Array[SemanticMemberFact] {
  self.members.filter(fn(fact) {
    fact.owner_name == owner &&
    (match fact.kind {
      TypeMemberKind | VariantMemberKind | OperationMemberKind => true
      _ => false
    })
  })
}

///|
fn SemanticIndex::fields_for_type(
  self : SemanticIndex,
  owner : @symbol.TypeSymbolId,
) -> Array[SemanticMemberFact] {
  self.members.filter(fn(fact) {
    fact.kind is FieldMemberKind && fact.owner_type == Some(owner)
  })
}

///|
fn SemanticIndex::mark_top_level_reachable(
  self : SemanticIndex,
  symbol : TopLevelSymbol,
  reachable : Array[TopLevelSymbol],
) -> Unit {
  if reachable.contains(symbol) {
    return
  }
  reachable.push(symbol)
  for reference in self.top_level_references {
    if reference.from == symbol {
      self.mark_top_level_reachable(reference.to, reachable)
    }
  }
}

///|
fn SemanticIndex::with_top_level(
  self : SemanticIndex,
  symbol : TopLevelSymbol,
  collect : (SemanticIndex) -> Unit,
) -> Unit {
  let previous = self.current_top_level
  self.current_top_level = Some(symbol)
  collect(self)
  self.current_top_level = previous
}

///|
fn SemanticIndex::add_top_level_reference(
  self : SemanticIndex,
  target : TopLevelSymbol,
) -> Unit {
  if self.current_top_level is Some(from) &&
    self.top_level_declarations.any(fn(declaration) {
      declaration.symbol == target
    }) {
    self.top_level_references.push({ from, to: target })
  }
}

///|
fn SemanticIndex::unused_generic_parameters(
  self : SemanticIndex,
) -> Array[GenericParameterFact] {
  let unused = self.generic_parameters.filter(fn(parameter) {
    !parameter.name.has_prefix("_") &&
    !self.generic_parameter_references.contains(parameter.symbol)
  })
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn SemanticIndex::unused_import_exposures(
  self : SemanticIndex,
  source : @resolve.ResolvedSourceFile,
) -> Array[@resolve.ResolvedImportExposure] {
  let used_exposure_ids = []
  for use_ in source.import_uses {
    add_unique_int(used_exposure_ids, use_.exposure_id)
  }
  for exposure_symbol in source.import_symbols {
    if self.used_import_symbols.contains(exposure_symbol.symbol) {
      add_unique_int(used_exposure_ids, exposure_symbol.exposure_id)
    }
  }
  source.import_exposures.filter(fn(exposure) {
    match exposure.kind {
      ImportedModuleBinding => false
      _ => !used_exposure_ids.contains(exposure.id)
    }
  })
}

///|
fn add_unique_int(values : Array[Int], value : Int) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn SemanticIndex::use_import_symbol(
  self : SemanticIndex,
  symbol : @resolve.ResolvedImportSymbol,
) -> Unit {
  if !self.used_import_symbols.contains(symbol) {
    self.used_import_symbols.push(symbol)
  }
}

///|
fn SemanticIndex::visible_bindings(
  self : SemanticIndex,
  line : Int,
  column : Int,
) -> Array[SemanticBindingFact] {
  self.bindings.filter(fn(binding) {
    binding.visibility.is_visible_at(line, column)
  })
}

///|
fn SemanticBindingVisibility::is_visible_at(
  self : SemanticBindingVisibility,
  line : Int,
  column : Int,
) -> Bool {
  match self {
    GlobalBinding => true
    ScopedBinding(scope) => scope.contains_completion_position(line, column)
    OrderedBinding(scope~, declaration~) =>
      scope.contains_completion_position(line, column) &&
      (
        declaration.start_line < line ||
        (declaration.start_line == line && declaration.start_column < column)
      )
  }
}

///|
fn @basic.SourceSpan::contains_completion_position(
  self : @basic.SourceSpan,
  line : Int,
  column : Int,
) -> Bool {
  self.contains_position(line, column) ||
  (line == self.end_line && column == self.end_column)
}

///|
fn SemanticIndex::receiver_type(
  self : SemanticIndex,
  name : String,
  line : Int,
  column : Int,
) -> @types.Type? {
  for index = self.bindings.length(); index > 0; index = index - 1 {
    let binding = self.bindings[index - 1]
    if binding.name == name &&
      binding.visibility.is_visible_at(line, column) &&
      binding.type_ is Some(type_) {
      return Some(type_)
    }
  }
  None
}

///|
fn GenericParameterKind::text(self : GenericParameterKind) -> String {
  match self {
    GenericTypeParameter => "type parameter"
    GenericEffectParameter => "effect parameter"
  }
}

///|
fn TopLevelDeclarationKind::text(self : TopLevelDeclarationKind) -> String {
  match self {
    ValueDeclaration => "value"
    FunctionDeclaration => "function"
    StructDeclaration => "struct"
    EnumDeclaration => "enum"
    ExternalTypeDeclaration => "external type"
    EffectDeclaration => "effect"
    TypeAliasDeclaration => "type alias"
    EffectAliasDeclaration => "effect alias"
  }
}
