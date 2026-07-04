///|
priv struct LinkTypeMapEntry {
  module_path_text : String
  source : @buslane.TypeId
  target : @buslane.TypeId
}

///|
priv struct LinkTypeParameterMapEntry {
  module_path_text : String
  source : @buslane.TypeParameterId
  target : @buslane.TypeParameterId
}

///|
priv struct LinkValueMapEntry {
  module_path_text : String
  source : @buslane.ValueId
  target : @buslane.ValueId
}

///|
priv struct LinkDataConMapEntry {
  module_path_text : String
  source : @buslane.DataConId
  target : @buslane.DataConId
}

///|
priv struct LinkEffectMapEntry {
  module_path_text : String
  source : @buslane.EffectId
  target : @buslane.EffectId
}

///|
priv struct LinkOperationMapEntry {
  module_path_text : String
  source : @buslane.OperationId
  target : @buslane.OperationId
}

///|
priv struct BuslaneLinker {
  metadata : @buslane.MetadataRegistry
  identities : LinkIdentityMaps
}

///|
priv struct LinkIdentityMaps {
  types : Array[LinkTypeMapEntry]
  type_parameters : Array[LinkTypeParameterMapEntry]
  values : Array[LinkValueMapEntry]
  data_constructors : Array[LinkDataConMapEntry]
  effects : Array[LinkEffectMapEntry]
  operations : Array[LinkOperationMapEntry]
}

///|
priv struct RemappedModuleObject {
  module_path_text : String
  terms : Array[@buslane.TopTerm]
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  exports : Array[@elaborate.BuslaneModuleExport]
  fingerprint : CompilationFingerprint
}

///|
priv struct LinkedModuleExport {
  module_path_text : String
  kind : @elaborate.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
}

///|
priv struct OrderedCompiledModulesResult {
  modules : Array[CompiledModule]
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv enum LinkedEntryMode {
  RootEntries(String)
  QualifiedEntries
}

///|
fn BuslaneLinker::BuslaneLinker() -> BuslaneLinker {
  { metadata: MetadataRegistry(), identities: LinkIdentityMaps() }
}

///|
fn LinkIdentityMaps::LinkIdentityMaps() -> LinkIdentityMaps {
  {
    types: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
  }
}

///|
fn LinkIdentityMaps::find_type(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeId,
) -> @buslane.TypeId? {
  for entry in self.types {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_type(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeId,
  target : @buslane.TypeId,
) -> @buslane.TypeId {
  if self.find_type(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.types.push({ module_path_text, source, target })
    target
  }
}

///|
fn LinkIdentityMaps::find_type_parameter(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId? {
  for entry in self.type_parameters {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_type_parameter(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeParameterId,
  target : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  if self.find_type_parameter(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.type_parameters.push({ module_path_text, source, target })
    target
  }
}

///|
fn LinkIdentityMaps::find_value(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.ValueId,
) -> @buslane.ValueId? {
  for entry in self.values {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_value(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.ValueId,
  target : @buslane.ValueId,
) -> @buslane.ValueId {
  if self.find_value(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.values.push({ module_path_text, source, target })
    target
  }
}

///|
fn LinkIdentityMaps::find_data_constructor(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.DataConId,
) -> @buslane.DataConId? {
  for entry in self.data_constructors {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_data_constructor(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.DataConId,
  target : @buslane.DataConId,
) -> @buslane.DataConId {
  if self.find_data_constructor(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.data_constructors.push({ module_path_text, source, target })
    target
  }
}

///|
fn LinkIdentityMaps::find_effect(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.EffectId,
) -> @buslane.EffectId? {
  for entry in self.effects {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_effect(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.EffectId,
  target : @buslane.EffectId,
) -> @buslane.EffectId {
  if self.find_effect(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.effects.push({ module_path_text, source, target })
    target
  }
}

///|
fn LinkIdentityMaps::find_operation(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.OperationId,
) -> @buslane.OperationId? {
  for entry in self.operations {
    if entry.module_path_text == module_path_text && entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn LinkIdentityMaps::bind_operation(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.OperationId,
  target : @buslane.OperationId,
) -> @buslane.OperationId {
  if self.find_operation(module_path_text, source) is Some(existing) {
    existing
  } else {
    self.operations.push({ module_path_text, source, target })
    target
  }
}
