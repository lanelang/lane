///|
priv struct CpsSourceCounts {
  types : Int
  data_constructors : Int
  values : Int
}

///|
fn rewrite_cps_source_metadata(
  schema : DictionaryCpsSchema,
  counts : CpsSourceCounts,
) -> Unit raise SynthesisError {
  for index in 0..<counts.types {
    let info = schema.metadata.types[index]
    schema.metadata.types[index] = {
      name: info.name,
      flavor: info.flavor,
      parameters: info.parameters,
      constructors: info.constructors,
    }
  }
  for index in 0..<counts.data_constructors {
    let info = schema.metadata.data_constructors[index]
    schema.metadata.data_constructors[index] = {
      name: info.name,
      owner: info.owner,
      hidden_type_parameters: info.hidden_type_parameters,
      payload_types: info.payload_types.map(type_ => schema.rewrite_type(type_)),
    }
  }
  for index in 0..<counts.values {
    let info = schema.metadata.values[index]
    schema.metadata.values[index] = {
      name: info.name,
      kind: info.kind,
      type_: schema.rewrite_type(info.type_),
    }
  }
}

///|
fn commit_cps_binding_type(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
  initializer : Expr,
) -> Unit raise SynthesisError {
  store_cps_value_type(
    metadata,
    id,
    synthesize_expr_or_raise(metadata, initializer).type_,
  )
}

///|
fn commit_cps_recursive_binding_types(
  metadata : @buslane.MetadataRegistry,
  bindings : Array[RecursiveBinding],
) -> Unit raise SynthesisError {
  let types = bindings.map(binding => {
    synthesize_expr_or_raise(metadata, binding.rhs).type_
  })
  for index in 0..<bindings.length() {
    store_cps_value_type(metadata, bindings[index].id, types[index])
  }
}

///|
fn store_cps_value_type(
  metadata : @buslane.MetadataRegistry,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit raise SynthesisError {
  guard metadata.values.get(value.index) is Some(info) else {
    raise UnknownValue(value)
  }
  metadata.values[value.index] = { ..info, type_, }
}
