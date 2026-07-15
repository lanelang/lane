///|
priv struct DictionaryInstance {
  data_constructor : @buslane.DataConId
  type_arguments : Array[@buslane.GenericArgument]
  field_types : Array[@buslane.Type]
}

///|
fn instantiate_dictionary(
  schema : DictionaryCpsSchema,
  effect : @buslane.EffectId,
  arguments : Array[@buslane.GenericArgument],
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> DictionaryInstance raise SynthesisError {
  let header = schema.dictionary(effect, residual_effect)
  guard schema.metadata.type_info(header.type_id) is Some(dictionary) else {
    raise UnknownType(header.type_id)
  }
  guard dictionary.constructors is [data_constructor] else {
    raise UnknownType(header.type_id)
  }
  guard schema.metadata.data_constructor_info(data_constructor)
    is Some(data_info) else {
    raise UnknownDataConstructor(data_constructor)
  }
  let type_arguments = arguments.map(argument => {
      rewrite_cps_expression_argument(schema, argument, Some(answer_type))
    }) +
    [TypeArgument(answer_type)]
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for index in 0..<dictionary.parameters.length() {
    substitution.insert_argument(
      dictionary.parameters[index],
      type_arguments[index],
    )
  }
  {
    data_constructor,
    type_arguments,
    field_types: data_info.payload_types.map(type_ => {
      type_.substitute(substitution)
    }),
  }
}
