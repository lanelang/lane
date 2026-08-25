///|
priv struct LinkTypeKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv struct LinkTypeParameterKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv struct LinkValueKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv struct LinkDataConKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv struct LinkEffectKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv struct LinkOperationKey {
  module_path_text : String
  source_index : Int
} derive(Eq, Hash)

///|
priv enum LinkModuleReferenceKind {
  TypeReference
  DataConstructorReference
  EffectReference
  OperationReference
  FieldSelectorReference
  ValueReference
} derive(Eq, Hash)

///|
priv struct LinkExportKey {
  kind : LinkModuleReferenceKind
  name : String
} derive(Eq, Hash)

///|
priv struct LinkExportIndex {
  references : Map[LinkExportKey, @buslane_lowering.BuslaneModuleReference]
}

///|
priv struct LinkedModuleExports {
  fingerprint : @artifact_model.CompilationFingerprint
  index : LinkExportIndex
}

///|
priv struct BuslaneLinker {
  metadata : @buslane.MetadataRegistry
  identities : LinkIdentityMaps
}

///|
priv struct LinkIdentityMaps {
  types : Map[LinkTypeKey, @buslane.TypeId]
  type_parameters : Map[LinkTypeParameterKey, @buslane.TypeParameterId]
  values : Map[LinkValueKey, @buslane.ValueId]
  data_constructors : Map[LinkDataConKey, @buslane.DataConId]
  effects : Map[LinkEffectKey, @buslane.EffectId]
  operations : Map[LinkOperationKey, @buslane.OperationId]
}

///|
priv struct RemappedModuleObject {
  module_path_text : String
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  fingerprint : @artifact_model.CompilationFingerprint
}

///|
priv struct OrderedLinkModulesResult {
  modules : Array[LinkModuleObject]
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct LinkModuleIndex {
  modules : Array[LinkModuleObject]
  module_slots_by_path : Map[String, Int]
  exports_by_path : Map[String, LinkExportIndex]
}

///|
priv enum LinkedEntryMode {
  RootEntries(String)
  QualifiedEntries
}

///|
priv enum LinkModuleSelection {
  AllModules
  Reachable(String)
}

///|
priv enum LinkedTopTermIdentity {
  Value(Int)
  External(Int)
} derive(Eq, Hash)

///|
fn BuslaneLinker::BuslaneLinker() -> BuslaneLinker {
  { metadata: MetadataRegistry(), identities: LinkIdentityMaps(), }
}

///|
fn LinkIdentityMaps::LinkIdentityMaps() -> LinkIdentityMaps {
  {
    types: Map([]),
    type_parameters: Map([]),
    values: Map([]),
    data_constructors: Map([]),
    effects: Map([]),
    operations: Map([]),
  }
}

///|
fn[K : Hash + Eq, V] bind_first(entries : Map[K, V], key : K, target : V) -> V {
  match entries.get(key) {
    Some(existing) => existing
    None => {
      entries[key] = target
      target
    }
  }
}

///|
fn LinkIdentityMaps::find_type(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeId,
) -> @buslane.TypeId? {
  self.types.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_type(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeId,
  target : @buslane.TypeId,
) -> @buslane.TypeId {
  bind_first(
    self.types,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkIdentityMaps::find_type_parameter(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId? {
  self.type_parameters.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_type_parameter(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.TypeParameterId,
  target : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  bind_first(
    self.type_parameters,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkIdentityMaps::find_value(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.ValueId,
) -> @buslane.ValueId? {
  self.values.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_value(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.ValueId,
  target : @buslane.ValueId,
) -> @buslane.ValueId {
  bind_first(
    self.values,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkIdentityMaps::find_data_constructor(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.DataConId,
) -> @buslane.DataConId? {
  self.data_constructors.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_data_constructor(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.DataConId,
  target : @buslane.DataConId,
) -> @buslane.DataConId {
  bind_first(
    self.data_constructors,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkIdentityMaps::find_effect(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.EffectId,
) -> @buslane.EffectId? {
  self.effects.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_effect(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.EffectId,
  target : @buslane.EffectId,
) -> @buslane.EffectId {
  bind_first(
    self.effects,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkIdentityMaps::find_operation(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.OperationId,
) -> @buslane.OperationId? {
  self.operations.get({ module_path_text, source_index: source.index, })
}

///|
fn LinkIdentityMaps::bind_operation(
  self : LinkIdentityMaps,
  module_path_text : String,
  source : @buslane.OperationId,
  target : @buslane.OperationId,
) -> @buslane.OperationId {
  bind_first(
    self.operations,
    { module_path_text, source_index: source.index, },
    target,
  )
}

///|
fn LinkExportIndex::from_exports(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
) -> LinkExportIndex {
  let references : Map[LinkExportKey, @buslane_lowering.BuslaneModuleReference] = Map([],
  )
  for item in exports {
    ignore(
      bind_first(
        references,
        { kind: link_module_reference_kind(item.reference), name: item.name, },
        item.reference,
      ),
    )
  }
  { references, }
}

///|
fn LinkExportIndex::find(
  self : LinkExportIndex,
  reference : @buslane_lowering.BuslaneModuleReference,
  name : String,
) -> @buslane_lowering.BuslaneModuleReference? {
  self.references.get({ kind: link_module_reference_kind(reference), name, })
}

///|
fn LinkExportIndex::contains(
  self : LinkExportIndex,
  kind : LinkModuleReferenceKind,
  name : String,
) -> Bool {
  self.references.contains({ kind, name, })
}

///|
fn link_module_reference_kind(
  reference : @buslane_lowering.BuslaneModuleReference,
) -> LinkModuleReferenceKind {
  match reference {
    Type(_) => TypeReference
    DataConstructor(_) => DataConstructorReference
    Effect(_) => EffectReference
    Operation(_) => OperationReference
    FieldSelector(_) => FieldSelectorReference
    Value(_) => ValueReference
  }
}
