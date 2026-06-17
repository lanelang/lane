///|
pub(all) enum NominalTypeKind {
  Struct
  Enum
} derive(Debug, Eq)

///|
pub(all) enum ValueSymbolKind {
  TopLevelValue
  TopLevelFunction
  Parameter
  LocalBinding
  LocalFunction
  PatternBinder
} derive(Debug, Eq)

///|
pub(all) struct TypeSymbolMetadata {
  id : TypeSymbolId
  name : String
  kind : NominalTypeKind
  arity : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct TypeParameterMetadata {
  id : TypeParameterId
  name : String
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct TypeMemberSymbolMetadata {
  id : TypeMemberSymbolId
  owner : TypeSymbolId
  type_parameter : TypeParameterId
  name : String
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ValueSymbolMetadata {
  id : ValueSymbolId
  name : String
  kind : ValueSymbolKind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct FieldSymbolMetadata {
  id : FieldSymbolId
  owner : TypeSymbolId
  name : String
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct VariantSymbolMetadata {
  id : VariantSymbolId
  owner : TypeSymbolId
  name : String
  index : Int
  payload_count : Int
  loc : SourceSpan
} derive(Debug, Eq)
