///|
priv enum AnalysisSymbolKey {
  ValueKey(Int)
  TypeKey(Int)
  FieldKey(Int)
  VariantKey(Int)
  EffectKey(Int)
  OperationKey(Int)
  TypeParameterKey(Int)
  TypeMemberKey(Int)
} derive(Eq, Hash)

///|
priv struct SymbolLocationIndex {
  locations : @immut_hashmap.HashMap[AnalysisSymbolKey, AnalysisLocation]
}

///|
fn SymbolLocationIndex::empty() -> SymbolLocationIndex {
  { locations: @immut_hashmap.HashMap::new() }
}

///|
fn SymbolLocationIndex::get(
  self : SymbolLocationIndex,
  symbol : AnalysisSymbol,
) -> AnalysisLocation? {
  self.locations.get(analysis_symbol_key(symbol))
}

///|
fn SymbolLocationIndex::replace_definitions(
  self : SymbolLocationIndex,
  previous : Array[DefinitionEntry],
  next : Array[DefinitionEntry],
) -> SymbolLocationIndex {
  let mut locations = self.locations
  for definition in previous {
    locations = locations.remove(analysis_symbol_key(definition.symbol))
  }
  for definition in next {
    locations = locations.add(
      analysis_symbol_key(definition.symbol),
      definition.location,
    )
  }
  { locations, }
}

///|
fn analysis_symbol_key(symbol : AnalysisSymbol) -> AnalysisSymbolKey {
  match symbol {
    Value(id) => ValueKey(id.index)
    Type(id) => TypeKey(id.index)
    Field(id) => FieldKey(id.index)
    Variant(id) => VariantKey(id.index)
    Effect(id) => EffectKey(id.index)
    Operation(id) => OperationKey(id.index)
    TypeParameter(id) => TypeParameterKey(id.index)
    TypeMember(id) => TypeMemberKey(id.index)
  }
}
