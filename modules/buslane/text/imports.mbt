///|
using @buslane {
  type Alternative,
  type BuslaneName,
  type BuslaneUnique,
  type DataConId,
  type DataConInfo,
  type Effect,
  type EffectId,
  type EffectInfo,
  type Expr,
  type GenericArgument,
  type HandlerTable,
  type Kind,
  type Literal,
  type MetadataRegistry,
  type MetadataNameAllocator,
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
fn make_metadata(
  name_allocator : MetadataNameAllocator,
  declarations : Array[MetadataDeclaration],
) -> Result[MetadataRegistry, String] {
  let types = collect_metadata_table(
    declarations,
    "type",
    index => "type#\{index}",
    declaration => {
      match declaration {
        TypeInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let type_parameters = collect_metadata_table(
    declarations,
    "type_parameter",
    index => "tparam#\{index}",
    declaration => {
      match declaration {
        TypeParameterInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let values = collect_metadata_table(
    declarations,
    "value",
    index => "value#\{index}",
    declaration => {
      match declaration {
        ValueInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let data_constructors = collect_metadata_table(
    declarations,
    "data_constructor",
    index => "datacon#\{index}",
    declaration => {
      match declaration {
        DataConInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let effects = collect_metadata_table(
    declarations,
    "effect",
    index => "effect#\{index}",
    declaration => {
      match declaration {
        EffectInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let operations = collect_metadata_table(
    declarations,
    "operation",
    index => "operation#\{index}",
    declaration => {
      match declaration {
        OperationInfoDecl(id, info) => Some((id.index, info))
        _ => None
      }
    },
  )
  let registry = match
    (types, type_parameters, values, data_constructors, effects, operations) {
    (
      Ok(types),
      Ok(type_parameters),
      Ok(values),
      Ok(data_constructors),
      Ok(effects),
      Ok(operations),
    ) =>
      MetadataRegistry::{
        name_allocator,
        types,
        type_parameters,
        values,
        data_constructors,
        effects,
        operations,
      }
    (Err(message), _, _, _, _, _)
    | (_, Err(message), _, _, _, _)
    | (_, _, Err(message), _, _, _)
    | (_, _, _, Err(message), _, _)
    | (_, _, _, _, Err(message), _)
    | (_, _, _, _, _, Err(message)) => return Err(message)
  }
  match registry.identity_errors().get(0) {
    Some(NegativeUnique(unique)) =>
      Err("invalid metadata name unique#\{unique.value}")
    Some(DuplicateUnique(unique)) =>
      Err("duplicate metadata name unique#\{unique.value}")
    Some(NegativeNextUnique(next)) =>
      Err("next_unique#\{next.value} must be non-negative")
    Some(NextUniqueNotFresh(next~, maximum~)) =>
      Err(
        "next_unique#\{next.value} must be greater than used unique#\{maximum.value}",
      )
    Some(AllocatorExhaustedBeforeMaximum(maximum_unique~)) => {
      let maximum = match maximum_unique {
        Some(unique) => "unique#\{unique.value}"
        None => "no allocated unique"
      }
      Err(
        "next_unique#exhausted requires used unique#2147483647; found \{maximum}",
      )
    }
    None => Ok(registry)
  }
}

///|
priv struct ParsedBuslaneName {
  occurrence : String
  unique : BuslaneUnique
}

///|
fn parsed_name(
  name_space : NameNamespace,
  occurrence : String,
  unique : BuslaneUnique,
) -> BuslaneName {
  { name_space, occurrence, unique, }
}

///|
fn[T] collect_metadata_table(
  declarations : Array[MetadataDeclaration],
  table_name : String,
  format_id : (Int) -> String,
  select : (MetadataDeclaration) -> (Int, T)?,
) -> Result[Array[T], String] {
  let entries : Array[(Int, T)] = []
  for declaration in declarations {
    if select(declaration) is Some((index, value)) {
      if index < 0 {
        return Err("negative metadata \{table_name} id \{format_id(index)}")
      }
      entries.push((index, value))
    }
  }
  entries.sort_by((left, right) => Int::compare(left.0, right.0))
  for index in 1..<entries.length() {
    if entries[index - 1].0 == entries[index].0 {
      return Err(
        "duplicate metadata \{table_name} id \{format_id(entries[index].0)}",
      )
    }
  }
  let items = []
  for expected, entry in entries {
    if entry.0 != expected {
      return Err(
        "sparse metadata \{table_name} table: missing \{format_id(expected)}",
      )
    }
    items.push(entry.1)
  }
  Ok(items)
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
