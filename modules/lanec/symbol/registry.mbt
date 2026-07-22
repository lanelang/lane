///|

///|
pub struct SymbolRegistry {
  types : Array[TypeSymbolMetadata]
  scoped_types : Map[String, TypeSymbolId]
  type_parameters : Array[TypeParameterMetadata]
  type_members : Array[TypeMemberSymbolMetadata]
  scoped_type_members : Map[String, TypeMemberSymbolId]
  values : Array[ValueSymbolMetadata]
  scoped_values : Map[String, ValueSymbolId]
  fields : Array[FieldSymbolMetadata]
  scoped_fields : Map[String, FieldSymbolId]
  variants : Array[VariantSymbolMetadata]
  scoped_variants : Map[String, VariantSymbolId]
  effects : Array[EffectSymbolMetadata]
  scoped_effects : Map[String, EffectSymbolId]
  operations : Array[OperationSymbolMetadata]
  scoped_operations : Map[String, OperationSymbolId]
} derive(Debug, Eq)

///|
/// Allocates stable declaration identities for one source across revisions.
pub struct DeclarationSymbolScope {
  registry : SymbolRegistry
  scope_key : String
  claimed_types : Map[String, Bool]
  claimed_values : Map[String, Bool]
  claimed_effects : Map[String, Bool]
  claimed_type_members : Map[String, Bool]
  claimed_fields : Map[String, Bool]
  claimed_variants : Map[String, Bool]
  claimed_operations : Map[String, Bool]
}

///|
/// Creates an empty symbol registry.
pub fn SymbolRegistry::SymbolRegistry() -> SymbolRegistry {
  {
    types: [],
    scoped_types: Map([]),
    type_parameters: [],
    type_members: [],
    scoped_type_members: Map([]),
    values: [],
    scoped_values: Map([]),
    fields: [],
    scoped_fields: Map([]),
    variants: [],
    scoped_variants: Map([]),
    effects: [],
    scoped_effects: Map([]),
    operations: [],
    scoped_operations: Map([]),
  }
}

///|
/// Opens the stable allocation scope used while resolving one source revision.
pub fn SymbolRegistry::declaration_scope(
  self : SymbolRegistry,
  scope_key : String,
) -> DeclarationSymbolScope {
  {
    registry: self,
    scope_key,
    claimed_types: Map([]),
    claimed_values: Map([]),
    claimed_effects: Map([]),
    claimed_type_members: Map([]),
    claimed_fields: Map([]),
    claimed_variants: Map([]),
    claimed_operations: Map([]),
  }
}

///|
/// Defines a nominal type symbol and returns its identity.
pub fn SymbolRegistry::define_type(
  self : SymbolRegistry,
  name : String,
  kind : NominalTypeKind,
  arity : Int,
  loc : SourceSpan,
) -> TypeSymbolId {
  let id = TypeSymbolId::{ index: self.types.length() }
  self.types.push({ id, name, kind, arity, loc })
  id
}

///|
/// Defines a scoped nominal type, reusing its identity across source revisions.
pub fn DeclarationSymbolScope::define_type(
  self : DeclarationSymbolScope,
  name : String,
  kind : NominalTypeKind,
  arity : Int,
  loc : SourceSpan,
) -> TypeSymbolId {
  let key = scoped_symbol_name(self.scope_key, name)
  if self.claimed_types.contains(key) {
    return self.registry.define_type(name, kind, arity, loc)
  }
  self.claimed_types[key] = true
  if self.registry.scoped_types.get(key) is Some(id) {
    self.registry.types[id.index] = { id, name, kind, arity, loc }
    return id
  }
  let id = TypeSymbolId::{ index: self.registry.types.length() }
  self.registry.types.push({ id, name, kind, arity, loc })
  self.registry.scoped_types[key] = id
  id
}

///|
/// Defines a type parameter symbol and returns its identity.
pub fn SymbolRegistry::define_type_parameter(
  self : SymbolRegistry,
  name : String,
  loc : SourceSpan,
) -> TypeParameterId {
  let id = TypeParameterId::{ index: self.type_parameters.length() }
  self.type_parameters.push({ id, name, loc })
  id
}

///|
/// Defines a struct type-member symbol and returns its identity.
pub fn SymbolRegistry::define_type_member(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  type_parameter : TypeParameterId,
  loc : SourceSpan,
) -> TypeMemberSymbolId {
  let id = TypeMemberSymbolId::{ index: self.type_members.length() }
  self.type_members.push({ id, owner, type_parameter, name, index, loc })
  id
}

///|
/// Defines a scoped struct type member, reusing its identity across revisions.
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
  if self.registry.scoped_type_members.get(key) is Some(id) {
    self.registry.type_members[id.index] = {
      id,
      owner,
      type_parameter,
      name,
      index,
      loc,
    }
    return id
  }
  let id = self.registry.define_type_member(
    owner, name, index, type_parameter, loc,
  )
  self.registry.scoped_type_members[key] = id
  id
}

///|
/// Defines a value symbol and returns its identity.
pub fn SymbolRegistry::define_value(
  self : SymbolRegistry,
  name : String,
  kind : ValueSymbolKind,
  loc : SourceSpan,
) -> ValueSymbolId {
  let id = ValueSymbolId::{ index: self.values.length() }
  self.values.push({ id, name, kind, loc })
  id
}

///|
/// Defines a scoped top-level value, reusing its identity across source revisions.
pub fn DeclarationSymbolScope::define_value(
  self : DeclarationSymbolScope,
  name : String,
  kind : ValueSymbolKind,
  loc : SourceSpan,
) -> ValueSymbolId {
  let key = scoped_symbol_name(self.scope_key, name)
  if self.claimed_values.contains(key) {
    return self.registry.define_value(name, kind, loc)
  }
  self.claimed_values[key] = true
  if self.registry.scoped_values.get(key) is Some(id) {
    self.registry.values[id.index] = { id, name, kind, loc }
    return id
  }
  let id = ValueSymbolId::{ index: self.registry.values.length() }
  self.registry.values.push({ id, name, kind, loc })
  self.registry.scoped_values[key] = id
  id
}

///|
/// Defines a struct field symbol and returns its identity.
pub fn SymbolRegistry::define_field(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  loc : SourceSpan,
) -> FieldSymbolId {
  let id = FieldSymbolId::{ index: self.fields.length() }
  self.fields.push({ id, owner, name, index, loc })
  id
}

///|
/// Defines an enum variant symbol and returns its identity.
pub fn SymbolRegistry::define_variant(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> VariantSymbolId {
  let id = VariantSymbolId::{ index: self.variants.length() }
  self.variants.push({ id, owner, name, index, payload_count, loc })
  id
}

///|
/// Defines an effect constructor symbol and returns its identity.
pub fn SymbolRegistry::define_effect(
  self : SymbolRegistry,
  name : String,
  arity : Int,
  loc : SourceSpan,
  flavor? : EffectFlavor = Algebraic,
) -> EffectSymbolId {
  let id = EffectSymbolId::{ index: self.effects.length() }
  self.effects.push({ id, name, flavor, arity, loc })
  id
}

///|
/// Defines a scoped effect, reusing its identity across source revisions.
pub fn DeclarationSymbolScope::define_effect(
  self : DeclarationSymbolScope,
  name : String,
  arity : Int,
  loc : SourceSpan,
  flavor? : EffectFlavor = Algebraic,
) -> EffectSymbolId {
  let key = scoped_symbol_name(self.scope_key, name)
  if self.claimed_effects.contains(key) {
    return self.registry.define_effect(name, arity, loc, flavor~)
  }
  self.claimed_effects[key] = true
  if self.registry.scoped_effects.get(key) is Some(id) {
    self.registry.effects[id.index] = { id, name, flavor, arity, loc }
    return id
  }
  let id = EffectSymbolId::{ index: self.registry.effects.length() }
  self.registry.effects.push({ id, name, flavor, arity, loc })
  self.registry.scoped_effects[key] = id
  id
}

///|
/// Defines or updates a field owned by a stable module type.
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
  if self.registry.scoped_fields.get(key) is Some(id) {
    self.registry.fields[id.index] = { id, owner, name, index, loc }
    return id
  }
  let id = self.registry.define_field(owner, name, index, loc)
  self.registry.scoped_fields[key] = id
  id
}

///|
/// Defines or updates a variant owned by a stable module type.
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
  if self.registry.scoped_variants.get(key) is Some(id) {
    self.registry.variants[id.index] = {
      id,
      owner,
      name,
      index,
      payload_count,
      loc,
    }
    return id
  }
  let id = self.registry.define_variant(owner, name, index, payload_count, loc)
  self.registry.scoped_variants[key] = id
  id
}

///|
/// Defines or updates an operation owned by a stable module effect.
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
  if self.registry.scoped_operations.get(key) is Some(id) {
    self.registry.operations[id.index] = {
      id,
      owner,
      name,
      index,
      payload_count,
      loc,
    }
    return id
  }
  let id = self.registry.define_operation(
    owner, name, index, payload_count, loc,
  )
  self.registry.scoped_operations[key] = id
  id
}

///|
fn scoped_symbol_name(scope_key : String, name : String) -> String {
  "\{scope_key.length()}:\{scope_key}\{name}"
}

///|
fn owned_symbol_name(owner : Int, name : String) -> String {
  "\{owner}:\{name}"
}

///|
/// Defines an effect operation symbol and returns its identity.
pub fn SymbolRegistry::define_operation(
  self : SymbolRegistry,
  owner : EffectSymbolId,
  name : String,
  index : Int,
  payload_count : Int,
  loc : SourceSpan,
) -> OperationSymbolId {
  let id = OperationSymbolId::{ index: self.operations.length() }
  self.operations.push({ id, owner, name, index, payload_count, loc })
  id
}

///|
/// Returns metadata for a nominal type symbol.
pub fn SymbolRegistry::type_metadata(
  self : SymbolRegistry,
  id : TypeSymbolId,
) -> TypeSymbolMetadata? {
  self.types.get(id.index)
}

///|
/// Returns metadata for a type parameter symbol.
pub fn SymbolRegistry::type_parameter_metadata(
  self : SymbolRegistry,
  id : TypeParameterId,
) -> TypeParameterMetadata? {
  self.type_parameters.get(id.index)
}

///|
/// Returns metadata for a struct type-member symbol.
pub fn SymbolRegistry::type_member_metadata(
  self : SymbolRegistry,
  id : TypeMemberSymbolId,
) -> TypeMemberSymbolMetadata? {
  self.type_members.get(id.index)
}

///|
/// Returns metadata for a value symbol.
pub fn SymbolRegistry::value_metadata(
  self : SymbolRegistry,
  id : ValueSymbolId,
) -> ValueSymbolMetadata? {
  self.values.get(id.index)
}

///|
/// Returns metadata for a struct field symbol.
pub fn SymbolRegistry::field_metadata(
  self : SymbolRegistry,
  id : FieldSymbolId,
) -> FieldSymbolMetadata? {
  self.fields.get(id.index)
}

///|
/// Returns metadata for an enum variant symbol.
pub fn SymbolRegistry::variant_metadata(
  self : SymbolRegistry,
  id : VariantSymbolId,
) -> VariantSymbolMetadata? {
  self.variants.get(id.index)
}

///|
/// Returns metadata for an effect constructor symbol.
pub fn SymbolRegistry::effect_metadata(
  self : SymbolRegistry,
  id : EffectSymbolId,
) -> EffectSymbolMetadata? {
  self.effects.get(id.index)
}

///|
/// Returns metadata for an effect operation symbol.
pub fn SymbolRegistry::operation_metadata(
  self : SymbolRegistry,
  id : OperationSymbolId,
) -> OperationSymbolMetadata? {
  self.operations.get(id.index)
}
