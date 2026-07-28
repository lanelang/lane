///|
/// Allocates globally unique symbol identities without retaining revision
/// metadata.
///
/// Persistent revision identities and discard-only measurement identities use
/// disjoint namespaces.
pub struct SymbolIdentityAllocator {
  mut next_type : Int
  mut next_type_alias : Int
  mut next_type_parameter : Int
  mut next_type_member : Int
  mut next_value : Int
  mut next_field : Int
  mut next_variant : Int
  mut next_effect : Int
  mut next_operation : Int
  mut next_measurement : Int
} derive(Debug, Eq)

///|
/// Metadata owned by one module snapshot or exported interface snapshot.
pub struct SymbolMetadataArena {
  types : Map[Int, TypeSymbolMetadata]
  type_aliases : Map[Int, TypeAliasSymbolMetadata]
  type_parameters : Map[Int, TypeParameterMetadata]
  type_members : Map[Int, TypeMemberSymbolMetadata]
  values : Map[Int, ValueSymbolMetadata]
  fields : Map[Int, FieldSymbolMetadata]
  variants : Map[Int, VariantSymbolMetadata]
  effects : Map[Int, EffectSymbolMetadata]
  operations : Map[Int, OperationSymbolMetadata]
} derive(Debug, Eq)

///|
/// Stable declaration identities owned by one module revision.
pub struct DeclarationIdentities {
  types : Map[String, TypeSymbolId]
  type_aliases : Map[String, TypeAliasSymbolId]
  values : Map[String, ValueSymbolId]
  effects : Map[String, EffectSymbolId]
  type_members : Map[String, TypeMemberSymbolId]
  fields : Map[String, FieldSymbolId]
  variants : Map[String, VariantSymbolId]
  operations : Map[String, OperationSymbolId]
} derive(Debug, Eq)

///|
/// Symbol metadata visible while resolving and checking one module revision.
pub struct SymbolRegistry {
  allocator : SymbolIdentityAllocator
  uses_measurement_identities : Bool
  metadata : SymbolMetadataArena
  imports : Array[SymbolMetadataArena]
  declarations : DeclarationIdentities
} derive(Debug, Eq)

///|
/// Allocates stable declaration identities for one module revision.
pub struct DeclarationSymbolScope {
  registry : SymbolRegistry
  previous : DeclarationIdentities?
  claimed_types : Map[String, Bool]
  claimed_type_aliases : Map[String, Bool]
  claimed_values : Map[String, Bool]
  claimed_effects : Map[String, Bool]
  claimed_type_members : Map[String, Bool]
  claimed_fields : Map[String, Bool]
  claimed_variants : Map[String, Bool]
  claimed_operations : Map[String, Bool]
}

///|
pub fn SymbolIdentityAllocator::SymbolIdentityAllocator() -> SymbolIdentityAllocator {
  {
    next_type: 0,
    next_type_alias: 0,
    next_type_parameter: 0,
    next_type_member: 0,
    next_value: 0,
    next_field: 0,
    next_variant: 0,
    next_effect: 0,
    next_operation: 0,
    next_measurement: -1,
  }
}

///|
fn SymbolMetadataArena::empty() -> SymbolMetadataArena {
  {
    types: Map([]),
    type_aliases: Map([]),
    type_parameters: Map([]),
    type_members: Map([]),
    values: Map([]),
    fields: Map([]),
    variants: Map([]),
    effects: Map([]),
    operations: Map([]),
  }
}

///|
fn DeclarationIdentities::empty() -> DeclarationIdentities {
  {
    types: Map([]),
    type_aliases: Map([]),
    values: Map([]),
    effects: Map([]),
    type_members: Map([]),
    fields: Map([]),
    variants: Map([]),
    operations: Map([]),
  }
}

///|
pub fn SymbolIdentityAllocator::registry(
  self : SymbolIdentityAllocator,
  imports? : Array[SymbolMetadataArena] = [],
) -> SymbolRegistry {
  {
    allocator: self,
    uses_measurement_identities: false,
    metadata: SymbolMetadataArena::empty(),
    imports,
    declarations: DeclarationIdentities::empty(),
  }
}

///|
/// Creates a standalone symbol registry.
pub fn SymbolRegistry::SymbolRegistry() -> SymbolRegistry {
  SymbolIdentityAllocator().registry()
}

///|
/// Creates an isolated registry for bounded, discard-only semantic measurement.
///
/// Persistent identities are non-negative. New identities in this registry use
/// the allocator's negative measurement namespace, so they cannot alias
/// persistent identities or identities from another measurement registry.
/// Measurement identities must not escape into checked output or revision
/// snapshots.
/// Imported arenas are immutable snapshots and remain shared.
pub fn SymbolRegistry::measurement_registry(
  self : SymbolRegistry,
) -> SymbolRegistry {
  {
    allocator: self.allocator,
    uses_measurement_identities: true,
    metadata: {
      types: self.metadata.types.copy(),
      type_aliases: self.metadata.type_aliases.copy(),
      type_parameters: self.metadata.type_parameters.copy(),
      type_members: self.metadata.type_members.copy(),
      values: self.metadata.values.copy(),
      fields: self.metadata.fields.copy(),
      variants: self.metadata.variants.copy(),
      effects: self.metadata.effects.copy(),
      operations: self.metadata.operations.copy(),
    },
    imports: self.imports,
    declarations: {
      types: self.declarations.types.copy(),
      type_aliases: self.declarations.type_aliases.copy(),
      values: self.declarations.values.copy(),
      effects: self.declarations.effects.copy(),
      type_members: self.declarations.type_members.copy(),
      fields: self.declarations.fields.copy(),
      variants: self.declarations.variants.copy(),
      operations: self.declarations.operations.copy(),
    },
  }
}

///|
pub fn SymbolRegistry::declaration_identities(
  self : SymbolRegistry,
) -> DeclarationIdentities {
  self.declarations
}

///|
/// Opens the stable allocation scope used while resolving one module revision.
pub fn SymbolRegistry::declaration_scope(
  self : SymbolRegistry,
  previous? : DeclarationIdentities? = None,
) -> DeclarationSymbolScope {
  {
    registry: self,
    previous,
    claimed_types: Map([]),
    claimed_type_aliases: Map([]),
    claimed_values: Map([]),
    claimed_effects: Map([]),
    claimed_type_members: Map([]),
    claimed_fields: Map([]),
    claimed_variants: Map([]),
    claimed_operations: Map([]),
  }
}

///|
pub fn SymbolRegistry::metadata_for(
  self : SymbolRegistry,
  symbols : Array[SymbolId],
) -> SymbolMetadataArena {
  let metadata = SymbolMetadataArena::empty()
  for symbol in symbols {
    match symbol {
      Type(id) =>
        if self.type_metadata(id) is Some(value) {
          metadata.types[id.index] = value
        }
      TypeAlias(id) =>
        if self.type_alias_metadata(id) is Some(value) {
          metadata.type_aliases[id.index] = value
        }
      TypeParameter(id) =>
        if self.type_parameter_metadata(id) is Some(value) {
          metadata.type_parameters[id.index] = value
        }
      TypeMember(id) =>
        if self.type_member_metadata(id) is Some(value) {
          metadata.type_members[id.index] = value
        }
      Value(id) =>
        if self.value_metadata(id) is Some(value) {
          metadata.values[id.index] = value
        }
      Field(id) =>
        if self.field_metadata(id) is Some(value) {
          metadata.fields[id.index] = value
        }
      Variant(id) =>
        if self.variant_metadata(id) is Some(value) {
          metadata.variants[id.index] = value
        }
      Effect(id) =>
        if self.effect_metadata(id) is Some(value) {
          metadata.effects[id.index] = value
        }
      Operation(id) =>
        if self.operation_metadata(id) is Some(value) {
          metadata.operations[id.index] = value
        }
    }
  }
  metadata
}

///|
fn SymbolRegistry::allocate_type(self : SymbolRegistry) -> TypeSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_type
    self.allocator.next_type = index + 1
    index
  }
  let id = TypeSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_type_alias(
  self : SymbolRegistry,
) -> TypeAliasSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_type_alias
    self.allocator.next_type_alias = index + 1
    index
  }
  { index, }
}

///|
fn SymbolRegistry::allocate_type_parameter(
  self : SymbolRegistry,
) -> TypeParameterId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_type_parameter
    self.allocator.next_type_parameter = index + 1
    index
  }
  let id = TypeParameterId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_type_member(
  self : SymbolRegistry,
) -> TypeMemberSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_type_member
    self.allocator.next_type_member = index + 1
    index
  }
  let id = TypeMemberSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_value(self : SymbolRegistry) -> ValueSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_value
    self.allocator.next_value = index + 1
    index
  }
  let id = ValueSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_field(self : SymbolRegistry) -> FieldSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_field
    self.allocator.next_field = index + 1
    index
  }
  let id = FieldSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_variant(self : SymbolRegistry) -> VariantSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_variant
    self.allocator.next_variant = index + 1
    index
  }
  let id = VariantSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_effect(self : SymbolRegistry) -> EffectSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_effect
    self.allocator.next_effect = index + 1
    index
  }
  let id = EffectSymbolId::{ index, }
  id
}

///|
fn SymbolRegistry::allocate_operation(
  self : SymbolRegistry,
) -> OperationSymbolId {
  let index = if self.uses_measurement_identities {
    self.allocator.allocate_measurement()
  } else {
    let index = self.allocator.next_operation
    self.allocator.next_operation = index + 1
    index
  }
  let id = OperationSymbolId::{ index, }
  id
}

///|
fn SymbolIdentityAllocator::allocate_measurement(
  self : SymbolIdentityAllocator,
) -> Int {
  let index = self.next_measurement
  self.next_measurement = index - 1
  index
}

///|
pub fn SymbolRegistry::define_type(
  self : SymbolRegistry,
  name : String,
  kind : NominalTypeKind,
  arity : Int,
  loc : SourceSpan,
) -> TypeSymbolId {
  let id = self.allocate_type()
  self.metadata.types[id.index] = { id, name, kind, arity, loc }
  id
}

///|
pub fn DeclarationSymbolScope::define_type(
  self : DeclarationSymbolScope,
  name : String,
  kind : NominalTypeKind,
  arity : Int,
  loc : SourceSpan,
) -> TypeSymbolId {
  if self.claimed_types.contains(name) {
    return self.registry.define_type(name, kind, arity, loc)
  }
  self.claimed_types[name] = true
  if self.previous is Some(previous) && previous.types.get(name) is Some(id) {
    self.registry.metadata.types[id.index] = { id, name, kind, arity, loc }
    self.registry.declarations.types[name] = id
    return id
  }
  let id = self.registry.define_type(name, kind, arity, loc)
  self.registry.declarations.types[name] = id
  id
}

///|
pub fn SymbolRegistry::define_type_alias(
  self : SymbolRegistry,
  name : String,
  loc : SourceSpan,
) -> TypeAliasSymbolId {
  let id = self.allocate_type_alias()
  self.metadata.type_aliases[id.index] = { id, name, loc }
  id
}

///|
pub fn DeclarationSymbolScope::define_type_alias(
  self : DeclarationSymbolScope,
  name : String,
  loc : SourceSpan,
) -> TypeAliasSymbolId {
  if self.claimed_type_aliases.contains(name) {
    return self.registry.define_type_alias(name, loc)
  }
  self.claimed_type_aliases[name] = true
  if self.previous is Some(previous) &&
    previous.type_aliases.get(name) is Some(id) {
    self.registry.metadata.type_aliases[id.index] = { id, name, loc }
    self.registry.declarations.type_aliases[name] = id
    return id
  }
  let id = self.registry.define_type_alias(name, loc)
  self.registry.declarations.type_aliases[name] = id
  id
}

///|
pub fn SymbolRegistry::define_type_parameter(
  self : SymbolRegistry,
  name : String,
  loc : SourceSpan,
) -> TypeParameterId {
  let id = self.allocate_type_parameter()
  self.metadata.type_parameters[id.index] = { id, name, loc }
  id
}

///|
pub fn SymbolRegistry::define_type_member(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  type_parameter : TypeParameterId,
  loc : SourceSpan,
) -> TypeMemberSymbolId {
  let id = self.allocate_type_member()
  self.metadata.type_members[id.index] = {
    id,
    owner,
    type_parameter,
    name,
    index,
    loc,
  }
  id
}

///|
pub fn DeclarationSymbolScope::define_type_member(
  self : DeclarationSymbolScope,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  type_parameter : TypeParameterId,
  loc : SourceSpan,
) -> TypeMemberSymbolId {
  let key = owned_symbol_name(owner.index, name)
  if self.claimed_type_members.contains(key) {
    return self.registry.define_type_member(
      owner, name, index, type_parameter, loc,
    )
  }
  self.claimed_type_members[key] = true
  if self.previous is Some(previous) &&
    previous.type_members.get(key) is Some(id) {
    self.registry.metadata.type_members[id.index] = {
      id,
      owner,
      type_parameter,
      name,
      index,
      loc,
    }
    self.registry.declarations.type_members[key] = id
    return id
  }
  let id = self.registry.define_type_member(
    owner, name, index, type_parameter, loc,
  )
  self.registry.declarations.type_members[key] = id
  id
}

///|
pub fn SymbolRegistry::define_value(
  self : SymbolRegistry,
  name : String,
  kind : ValueSymbolKind,
  loc : SourceSpan,
) -> ValueSymbolId {
  let id = self.allocate_value()
  self.metadata.values[id.index] = { id, name, kind, provenance: Authored, loc }
  id
}

///|
/// Defines a compiler-generated local value with explicit provenance.
pub fn SymbolRegistry::define_generated_local(
  self : SymbolRegistry,
  name : String,
  loc : SourceSpan,
) -> ValueSymbolId {
  let id = self.allocate_value()
  self.metadata.values[id.index] = {
    id,
    name,
    kind: LocalBinding,
    provenance: GeneratedLocal,
    loc,
  }
  id
}

///|
pub fn DeclarationSymbolScope::define_value(
  self : DeclarationSymbolScope,
  name : String,
  kind : ValueSymbolKind,
  loc : SourceSpan,
) -> ValueSymbolId {
  if self.claimed_values.contains(name) {
    return self.registry.define_value(name, kind, loc)
  }
  self.claimed_values[name] = true
  if self.previous is Some(previous) && previous.values.get(name) is Some(id) {
    self.registry.metadata.values[id.index] = {
      id,
      name,
      kind,
      provenance: Authored,
      loc,
    }
    self.registry.declarations.values[name] = id
    return id
  }
  let id = self.registry.define_value(name, kind, loc)
  self.registry.declarations.values[name] = id
  id
}

///|
pub fn SymbolRegistry::define_field(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  loc : SourceSpan,
) -> FieldSymbolId {
  let id = self.allocate_field()
  self.metadata.fields[id.index] = { id, owner, name, index, loc }
  id
}

///|
pub fn SymbolRegistry::define_variant(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> VariantSymbolId {
  let id = self.allocate_variant()
  self.metadata.variants[id.index] = {
    id,
    owner,
    name,
    index,
    payload_count,
    loc,
  }
  id
}

///|
pub fn SymbolRegistry::define_effect(
  self : SymbolRegistry,
  name : String,
  arity : Int,
  loc : SourceSpan,
  flavor? : EffectFlavor = Algebraic,
) -> EffectSymbolId {
  let id = self.allocate_effect()
  self.metadata.effects[id.index] = { id, name, flavor, arity, loc }
  id
}

///|
pub fn DeclarationSymbolScope::define_effect(
  self : DeclarationSymbolScope,
  name : String,
  arity : Int,
  loc : SourceSpan,
  flavor? : EffectFlavor = Algebraic,
) -> EffectSymbolId {
  if self.claimed_effects.contains(name) {
    return self.registry.define_effect(name, arity, loc, flavor~)
  }
  self.claimed_effects[name] = true
  if self.previous is Some(previous) && previous.effects.get(name) is Some(id) {
    self.registry.metadata.effects[id.index] = { id, name, flavor, arity, loc }
    self.registry.declarations.effects[name] = id
    return id
  }
  let id = self.registry.define_effect(name, arity, loc, flavor~)
  self.registry.declarations.effects[name] = id
  id
}

///|
pub fn DeclarationSymbolScope::define_field(
  self : DeclarationSymbolScope,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  loc : SourceSpan,
) -> FieldSymbolId {
  let key = owned_symbol_name(owner.index, name)
  if self.claimed_fields.contains(key) {
    return self.registry.define_field(owner, name, index, loc)
  }
  self.claimed_fields[key] = true
  if self.previous is Some(previous) && previous.fields.get(key) is Some(id) {
    self.registry.metadata.fields[id.index] = { id, owner, name, index, loc }
    self.registry.declarations.fields[key] = id
    return id
  }
  let id = self.registry.define_field(owner, name, index, loc)
  self.registry.declarations.fields[key] = id
  id
}

///|
pub fn DeclarationSymbolScope::define_variant(
  self : DeclarationSymbolScope,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> VariantSymbolId {
  let key = owned_symbol_name(owner.index, name)
  if self.claimed_variants.contains(key) {
    return self.registry.define_variant(owner, name, index, payload_count, loc)
  }
  self.claimed_variants[key] = true
  if self.previous is Some(previous) && previous.variants.get(key) is Some(id) {
    self.registry.metadata.variants[id.index] = {
      id,
      owner,
      name,
      index,
      payload_count,
      loc,
    }
    self.registry.declarations.variants[key] = id
    return id
  }
  let id = self.registry.define_variant(owner, name, index, payload_count, loc)
  self.registry.declarations.variants[key] = id
  id
}

///|
pub fn DeclarationSymbolScope::define_operation(
  self : DeclarationSymbolScope,
  owner : EffectSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> OperationSymbolId {
  let key = owned_symbol_name(owner.index, name)
  if self.claimed_operations.contains(key) {
    return self.registry.define_operation(
      owner, name, index, payload_count, loc,
    )
  }
  self.claimed_operations[key] = true
  if self.previous is Some(previous) && previous.operations.get(key) is Some(id) {
    self.registry.metadata.operations[id.index] = {
      id,
      owner,
      name,
      index,
      payload_count,
      loc,
    }
    self.registry.declarations.operations[key] = id
    return id
  }
  let id = self.registry.define_operation(
    owner, name, index, payload_count, loc,
  )
  self.registry.declarations.operations[key] = id
  id
}

///|
fn owned_symbol_name(owner : Int, name : String) -> String {
  "\{owner}:\{name}"
}

///|
pub fn SymbolRegistry::define_operation(
  self : SymbolRegistry,
  owner : EffectSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> OperationSymbolId {
  let id = self.allocate_operation()
  self.metadata.operations[id.index] = {
    id,
    owner,
    name,
    index,
    payload_count,
    loc,
  }
  id
}

///|
pub fn SymbolRegistry::type_metadata(
  self : SymbolRegistry,
  id : TypeSymbolId,
) -> TypeSymbolMetadata? {
  if self.metadata.types.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.types.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::type_alias_metadata(
  self : SymbolRegistry,
  id : TypeAliasSymbolId,
) -> TypeAliasSymbolMetadata? {
  if self.metadata.type_aliases.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.type_aliases.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::type_parameter_metadata(
  self : SymbolRegistry,
  id : TypeParameterId,
) -> TypeParameterMetadata? {
  if self.metadata.type_parameters.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.type_parameters.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::type_member_metadata(
  self : SymbolRegistry,
  id : TypeMemberSymbolId,
) -> TypeMemberSymbolMetadata? {
  if self.metadata.type_members.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.type_members.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::value_metadata(
  self : SymbolRegistry,
  id : ValueSymbolId,
) -> ValueSymbolMetadata? {
  if self.metadata.values.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.values.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::field_metadata(
  self : SymbolRegistry,
  id : FieldSymbolId,
) -> FieldSymbolMetadata? {
  if self.metadata.fields.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.fields.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::variant_metadata(
  self : SymbolRegistry,
  id : VariantSymbolId,
) -> VariantSymbolMetadata? {
  if self.metadata.variants.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.variants.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::effect_metadata(
  self : SymbolRegistry,
  id : EffectSymbolId,
) -> EffectSymbolMetadata? {
  if self.metadata.effects.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.effects.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn SymbolRegistry::operation_metadata(
  self : SymbolRegistry,
  id : OperationSymbolId,
) -> OperationSymbolMetadata? {
  if self.metadata.operations.get(id.index) is Some(value) {
    return Some(value)
  }
  for imported in self.imports {
    if imported.operations.get(id.index) is Some(value) {
      return Some(value)
    }
  }
  None
}
