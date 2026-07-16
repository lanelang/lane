///|
pub struct SymbolRegistry {
  types : Array[TypeSymbolMetadata]
  type_parameters : Array[TypeParameterMetadata]
  type_members : Array[TypeMemberSymbolMetadata]
  values : Array[ValueSymbolMetadata]
  fields : Array[FieldSymbolMetadata]
  variants : Array[VariantSymbolMetadata]
  effects : Array[EffectSymbolMetadata]
  operations : Array[OperationSymbolMetadata]
} derive(Debug, Eq)

///|
/// Creates an empty symbol registry.
pub fn SymbolRegistry::SymbolRegistry() -> SymbolRegistry {
  {
    types: [],
    type_parameters: [],
    type_members: [],
    values: [],
    fields: [],
    variants: [],
    effects: [],
    operations: [],
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

///|
/// Looks up a nominal type symbol by source name.
pub fn SymbolRegistry::type_named(
  self : SymbolRegistry,
  name : String,
) -> TypeSymbolId? {
  for metadata in self.types {
    if metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Looks up an effect constructor symbol by source name.
pub fn SymbolRegistry::effect_named(
  self : SymbolRegistry,
  name : String,
) -> EffectSymbolId? {
  for metadata in self.effects {
    if metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Looks up an enum variant symbol by owner type and source name.
pub fn SymbolRegistry::variant_named(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
) -> VariantSymbolId? {
  for metadata in self.variants {
    if metadata.owner == owner && metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Returns all enum variant symbols with the given source name.
pub fn SymbolRegistry::variants_named(
  self : SymbolRegistry,
  name : String,
) -> Array[VariantSymbolId] {
  let variants = []
  for metadata in self.variants {
    if metadata.name == name {
      variants.push(metadata.id)
    }
  }
  variants
}

///|
/// Looks up an effect operation symbol by owner effect and source name.
pub fn SymbolRegistry::operation_named(
  self : SymbolRegistry,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId? {
  for metadata in self.operations {
    if metadata.owner == owner && metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Returns all effect operation symbols with the given source name.
pub fn SymbolRegistry::operations_named(
  self : SymbolRegistry,
  name : String,
) -> Array[OperationSymbolId] {
  let operations = []
  for metadata in self.operations {
    if metadata.name == name {
      operations.push(metadata.id)
    }
  }
  operations
}

///|
/// Returns all effect operation metadata entries declared by an effect.
pub fn SymbolRegistry::operations_of(
  self : SymbolRegistry,
  owner : EffectSymbolId,
) -> Array[OperationSymbolMetadata] {
  let operations = []
  for metadata in self.operations {
    if metadata.owner == owner {
      operations.push(metadata)
    }
  }
  operations
}

///|
/// Looks up a struct type-member symbol by owner type and source name.
pub fn SymbolRegistry::type_member_named(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
) -> TypeMemberSymbolId? {
  for metadata in self.type_members {
    if metadata.owner == owner && metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Returns all type-member metadata entries declared by a struct type.
pub fn SymbolRegistry::type_members_of(
  self : SymbolRegistry,
  owner : TypeSymbolId,
) -> Array[TypeMemberSymbolMetadata] {
  let members = []
  for metadata in self.type_members {
    if metadata.owner == owner {
      members.push(metadata)
    }
  }
  members
}

///|
/// Looks up a struct field symbol by owner type and source name.
pub fn SymbolRegistry::field_named(
  self : SymbolRegistry,
  owner : TypeSymbolId,
  name : String,
) -> FieldSymbolId? {
  for metadata in self.fields {
    if metadata.owner == owner && metadata.name == name {
      return Some(metadata.id)
    }
  }
  None
}

///|
/// Returns all field metadata entries declared by a struct type.
pub fn SymbolRegistry::fields_of(
  self : SymbolRegistry,
  owner : TypeSymbolId,
) -> Array[FieldSymbolMetadata] {
  let fields = []
  for metadata in self.fields {
    if metadata.owner == owner {
      fields.push(metadata)
    }
  }
  fields
}
