///|
test "panic interface freshening rejects an unmapped type parameter" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let environment = InterfaceFresheningEnvironment::{
    registry,
    types: [],
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
