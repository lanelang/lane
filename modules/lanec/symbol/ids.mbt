///|
pub(all) struct TypeSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct TypeParameterId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct TypeMemberSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct ValueSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct FieldSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct VariantSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct EffectSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct OperationSymbolId {
  index : Int
} derive(Debug, Eq, Compare)

///|
/// A heterogeneous symbol identity used when selecting metadata for a module
/// interface snapshot.
pub(all) enum SymbolId {
  Type(TypeSymbolId)
  TypeParameter(TypeParameterId)
  TypeMember(TypeMemberSymbolId)
  Value(ValueSymbolId)
  Field(FieldSymbolId)
  Variant(VariantSymbolId)
  Effect(EffectSymbolId)
  Operation(OperationSymbolId)
} derive(Debug, Eq)
