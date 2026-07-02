///|
using @buslane {
  type AltCon,
  type Alternative,
  type BuslaneName,
  type DataConId,
  type DataConInfo,
  type Effect,
  type EffectId,
  type EffectInfo,
  type Expr,
  type HandlerTable,
  type Kind,
  type Literal,
  type MetadataRegistry,
  type NameNamespace,
  type OperationAlternative,
  type OperationId,
  type OperationInfo,
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
      EffectInfoDecl(id, info) => set_at(effects, id.index, info)
      OperationInfoDecl(id, info) => set_at(operations, id.index, info)
    }
  }
  {
    next_unique: next_metadata_unique(declarations),
    types,
    type_parameters,
    values,
    data_constructors,
    effects,
    operations,
  }
}

///|
priv struct ParsedBuslaneName {
  occurrence : String
  unique : Int
}

///|
fn parse_text_int(text : String) -> Int {
  @string.parse_int(text, base=10) catch {
    _ => 0
  }
}

///|
fn parsed_name(
  name_space : NameNamespace,
  occurrence : String,
  index : Int,
) -> BuslaneName {
  { name_space, occurrence, unique: { value: index } }
}

///|
fn next_metadata_unique(declarations : Array[MetadataDeclaration]) -> Int {
  let mut next = 0
  for declaration in declarations {
    let candidate = declaration.name().unique.value + 1
    if candidate > next {
      next = candidate
    }
  }
  next
}

///|
fn MetadataDeclaration::name(self : MetadataDeclaration) -> BuslaneName {
  match self {
    TypeInfoDecl(_, info) => info.name
    TypeParameterInfoDecl(_, info) => info.name
    ValueInfoDecl(_, info) => info.name
    DataConInfoDecl(_, info) => info.name
    EffectInfoDecl(_, info) => info.name
    OperationInfoDecl(_, info) => info.name
  }
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
  EffectInfoDecl(EffectId, EffectInfo)
  OperationInfoDecl(OperationId, OperationInfo)
}
