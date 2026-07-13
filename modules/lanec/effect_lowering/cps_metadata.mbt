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

///|
fn synchronize_cps_top_level_value_types(
  program : Program,
) -> Unit raise SynthesisError {
  for term in program.terms {
    match term {
      Let(id, expression) =>
        synchronize_cps_value_type(
          program.metadata,
          id,
          synthesize_expr_or_raise(program.metadata, expression).type_,
        )
      LetRec(bindings) =>
        for binding in bindings {
          synchronize_cps_value_type(
            program.metadata,
            binding.id,
            synthesize_expr_or_raise(program.metadata, binding.rhs).type_,
          )
        }
      External(_) => ()
    }
  }
}

///|
fn synchronize_cps_value_type(
  metadata : @buslane.MetadataRegistry,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit raise SynthesisError {
  guard metadata.values.get(value.index) is Some(info) else {
    raise UnknownValue(value)
  }
  metadata.values[value.index] = { ..info, type_, }
}
