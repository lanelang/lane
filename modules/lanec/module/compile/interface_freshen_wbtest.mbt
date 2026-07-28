///|
test "panic interface freshening rejects an unmapped type parameter" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let environment = InterfaceFresheningEnvironment::{
    registry,
    types: [],
    type_aliases: [],
    effects: [],
  }
  let interface : @module_interface.ModuleInterface = {
    module_path: "Broken",
    source_id: None,
    type_references: [],
    effect_references: [],
    types: [],
    effects: [],
    type_aliases: [],
    values: [],
    optimization_hints: [],
  }
  let freshener = InterfaceSymbolFreshener(environment, interface)
  ignore(freshener.remap_type_parameter({ index: 0 }))
}

///|
test "interface freshening reuses type alias identities by module path" {
  let source_registry = @symbol.SymbolRegistry::SymbolRegistry()
  let source_symbol = source_registry.define_type_alias(
    "Signals",
    @basic.SourceSpan::dummy(),
  )
  let interface : @module_interface.ModuleInterface = {
    module_path: "Lib",
    source_id: None,
    type_references: [],
    effect_references: [],
    types: [],
    effects: [],
    type_aliases: [
      {
        symbol: source_symbol,
        name: "Signals",
        type_parameters: [],
        body: EffectBody(Empty),
        kind: Effect,
        loc: @basic.SourceSpan::dummy(),
      },
    ],
    values: [],
    optimization_hints: [],
  }
  let environment = InterfaceFresheningEnvironment::{
    registry: SymbolRegistry(),
    types: [],
    type_aliases: [],
    effects: [],
  }
  let first = freshen_module_interface(environment, interface)
  let second = freshen_module_interface(environment, interface)
  let other = freshen_module_interface(environment, {
    ..interface,
    module_path: "Other",
  })
  assert_eq(first.type_aliases[0].symbol, second.type_aliases[0].symbol)
  assert_false(first.type_aliases[0].symbol == other.type_aliases[0].symbol)
}
