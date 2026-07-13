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
