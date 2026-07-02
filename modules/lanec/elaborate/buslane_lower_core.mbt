///|
priv struct TypeMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.TypeId
}

///|
priv struct TypeParameterMapEntry {
  source : @symbol.TypeParameterId
  target : @buslane.TypeParameterId
}

///|
priv struct ValueMapEntry {
  source : @symbol.ValueSymbolId
  target : @buslane.ValueId
}

///|
priv struct DataConMapEntry {
  source : @symbol.VariantSymbolId
  target : @buslane.DataConId
}

///|
priv struct EffectMapEntry {
  source : @symbol.EffectSymbolId
  target : @buslane.EffectId
}

///|
priv struct OperationMapEntry {
  source : @symbol.OperationSymbolId
  target : @buslane.OperationId
}

///|
priv struct StructConMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.DataConId
}

///|
priv struct FieldSelectorMapEntry {
  source : @symbol.FieldSymbolId
  target : @buslane.ValueId
}

///|
priv struct SelectorTermEntry {
  module_path_text : String
  term : @buslane.TopTerm
}

///|
priv struct ModuleEntries {
  module_path_text : String
  entries : Array[BuslaneEntry]
}

///|
priv struct BuslaneLowerer {
  metadata : @buslane.MetadataRegistry
  registry : BuslaneLoweringRegistry
  selector_terms : Array[SelectorTermEntry]
  external_terms : Array[@buslane.TopTerm]
  builtin_externals : Array[BuslaneBuiltinExternal]
  entries : Array[BuslaneEntry]
  imports : Array[BuslaneModuleImport]
}

///|
priv struct BuslaneLoweringRegistry {
  type_symbols : Array[TypeMapEntry]
  type_parameters : Array[TypeParameterMapEntry]
  values : Array[ValueMapEntry]
  data_constructors : Array[DataConMapEntry]
  effects : Array[EffectMapEntry]
  operations : Array[OperationMapEntry]
  struct_constructors : Array[StructConMapEntry]
  field_selectors : Array[FieldSelectorMapEntry]
}

///|
priv struct LowerPatternRow {
  patterns : Array[@checked.CheckedPattern]
  body : @buslane.Expr
}

///|
priv struct LoweredHandlerTable {
  handled_effect : @types.Effect
  operations : Array[LoweredOperationAlternative]
}

///|
priv struct LoweredOperationAlternative {
  operation : @symbol.OperationSymbolId
  type_binders : Array[@buslane.TypeParameterId]
  payload_binders : Array[@buslane.ValueId]
  resume_binder : @buslane.ValueId
  body : @buslane.Expr
}

///|
priv struct LowerHandlerOperationGroup {
  operation : @symbol.OperationSymbolId
  type_binders : Array[@types.TypeParameter]
  payload_types : Array[@types.Type]
  resume_type : @types.Type
  arms : Array[@checked.CheckedHandlerOperationArm]
}

///|
priv struct LowerConstructorSignature {
  alt_constructor : @buslane.AltCon
  argument_types : Array[@types.Type]
  type_binders : Array[@buslane.TypeParameterId]
}

///|
fn BuslaneLowerer::BuslaneLowerer() -> BuslaneLowerer {
  {
    metadata: MetadataRegistry(),
    registry: BuslaneLoweringRegistry(),
    selector_terms: [],
    external_terms: [],
    builtin_externals: [],
    entries: [],
    imports: [],
  }
}

///|
fn BuslaneLoweringRegistry::BuslaneLoweringRegistry() -> BuslaneLoweringRegistry {
  {
    type_symbols: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
    struct_constructors: [],
    field_selectors: [],
  }
}

///|
fn BuslaneLoweringRegistry::find_type(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
) -> @buslane.TypeId? {
  for entry in self.type_symbols {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_type(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
  target : @buslane.TypeId,
) -> @buslane.TypeId {
  if self.find_type(source) is Some(existing) {
    existing
  } else {
    self.type_symbols.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_type(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
) -> @buslane.TypeId {
  match self.find_type(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing type id")
  }
}

///|
fn BuslaneLoweringRegistry::find_type_parameter(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId? {
  for entry in self.type_parameters {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_type_parameter(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeParameterId,
  target : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  if self.find_type_parameter(source) is Some(existing) {
    existing
  } else {
    self.type_parameters.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_type_parameter(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId {
  match self.find_type_parameter(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing type parameter id")
  }
}

///|
fn BuslaneLoweringRegistry::find_value(
  self : BuslaneLoweringRegistry,
  source : @symbol.ValueSymbolId,
) -> @buslane.ValueId? {
  for entry in self.values {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_value(
  self : BuslaneLoweringRegistry,
  source : @symbol.ValueSymbolId,
  target : @buslane.ValueId,
) -> @buslane.ValueId {
  if self.find_value(source) is Some(existing) {
    existing
  } else {
    self.values.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_value(
  self : BuslaneLoweringRegistry,
  source : @symbol.ValueSymbolId,
) -> @buslane.ValueId {
  match self.find_value(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing value id")
  }
}

///|
fn BuslaneLoweringRegistry::find_data_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.VariantSymbolId,
) -> @buslane.DataConId? {
  for entry in self.data_constructors {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_data_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.VariantSymbolId,
  target : @buslane.DataConId,
) -> @buslane.DataConId {
  if self.find_data_constructor(source) is Some(existing) {
    existing
  } else {
    self.data_constructors.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_data_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.VariantSymbolId,
) -> @buslane.DataConId {
  match self.find_data_constructor(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing data constructor id")
  }
}

///|
fn BuslaneLoweringRegistry::find_effect(
  self : BuslaneLoweringRegistry,
  source : @symbol.EffectSymbolId,
) -> @buslane.EffectId? {
  for entry in self.effects {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_effect(
  self : BuslaneLoweringRegistry,
  source : @symbol.EffectSymbolId,
  target : @buslane.EffectId,
) -> @buslane.EffectId {
  if self.find_effect(source) is Some(existing) {
    existing
  } else {
    self.effects.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_effect(
  self : BuslaneLoweringRegistry,
  source : @symbol.EffectSymbolId,
) -> @buslane.EffectId {
  match self.find_effect(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing effect id")
  }
}

///|
fn BuslaneLoweringRegistry::find_operation(
  self : BuslaneLoweringRegistry,
  source : @symbol.OperationSymbolId,
) -> @buslane.OperationId? {
  for entry in self.operations {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_operation(
  self : BuslaneLoweringRegistry,
  source : @symbol.OperationSymbolId,
  target : @buslane.OperationId,
) -> @buslane.OperationId {
  if self.find_operation(source) is Some(existing) {
    existing
  } else {
    self.operations.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_operation(
  self : BuslaneLoweringRegistry,
  source : @symbol.OperationSymbolId,
) -> @buslane.OperationId {
  match self.find_operation(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing operation id")
  }
}

///|
fn BuslaneLoweringRegistry::find_struct_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
) -> @buslane.DataConId? {
  for entry in self.struct_constructors {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_struct_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
  target : @buslane.DataConId,
) -> @buslane.DataConId {
  if self.find_struct_constructor(source) is Some(existing) {
    existing
  } else {
    self.struct_constructors.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_struct_constructor(
  self : BuslaneLoweringRegistry,
  source : @symbol.TypeSymbolId,
) -> @buslane.DataConId {
  match self.find_struct_constructor(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing struct constructor id")
  }
}

///|
fn BuslaneLoweringRegistry::find_field_selector(
  self : BuslaneLoweringRegistry,
  source : @symbol.FieldSymbolId,
) -> @buslane.ValueId? {
  for entry in self.field_selectors {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn BuslaneLoweringRegistry::register_field_selector(
  self : BuslaneLoweringRegistry,
  source : @symbol.FieldSymbolId,
  target : @buslane.ValueId,
) -> @buslane.ValueId {
  if self.find_field_selector(source) is Some(existing) {
    existing
  } else {
    self.field_selectors.push({ source, target })
    target
  }
}

///|
fn BuslaneLoweringRegistry::require_field_selector(
  self : BuslaneLoweringRegistry,
  source : @symbol.FieldSymbolId,
) -> @buslane.ValueId {
  match self.find_field_selector(source) {
    Some(target) => target
    None => abort("Buslane lowering registry missing field selector id")
  }
}

///|
