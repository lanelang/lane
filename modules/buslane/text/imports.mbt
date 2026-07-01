///|
using @buslane {
  type AltCon,
  type Alternative,
  type DataConId,
  type DataConInfo,
  type Expr,
  type Kind,
  type Literal,
  type MetadataRegistry,
  type PrimitiveType,
  type Program,
  type RecursiveBinding,
  type TopTerm,
  type Type,
  type TypeId,
  type TypeInfo,
  type TypeParameterId,
  type TypeParameterInfo,
  type ValueId,
  type ValueInfo,
  type ValueKind,
}

///|
type SourceSpan = Unit

///|
fn[T] comma_push(items : Array[T], item : T) -> Array[T] {
  items.push(item)
  items
}

///|
fn make_metadata(declarations : Array[MetadataDeclaration]) -> MetadataRegistry {
  let types : Array[TypeInfo] = []
  let type_parameters : Array[TypeParameterInfo] = []
  let values : Array[ValueInfo] = []
  let data_constructors : Array[DataConInfo] = []
  let effects = []
  let operations = []
  for declaration in declarations {
    match declaration {
      TypeInfoDecl(id, info) => set_at(types, id.index, info)
      TypeParameterInfoDecl(id, info) => set_at(type_parameters, id.index, info)
      ValueInfoDecl(id, info) => set_at(values, id.index, info)
      DataConInfoDecl(id, info) => set_at(data_constructors, id.index, info)
    }
  }
  { types, type_parameters, values, data_constructors, effects, operations }
}

///|
fn[T] set_at(items : Array[T], index : Int, value : T) -> Unit {
  while items.length() <= index {
    items.push(value)
  }
  items[index] = value
}

///|
priv enum MetadataDeclaration {
  TypeInfoDecl(TypeId, TypeInfo)
  TypeParameterInfoDecl(TypeParameterId, TypeParameterInfo)
  ValueInfoDecl(ValueId, ValueInfo)
  DataConInfoDecl(DataConId, DataConInfo)
}
