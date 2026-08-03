///|
/// Rewrites the declarations this pass is responsible for.
///
/// Only the ones the program mentions. A declaration effect specialization made
/// dead is legal Buslane already and stays legal by being left alone; rewriting
/// the types under it while its binders stay as they were is what would make it
/// illegal. Type declarations are untouched either way, since nothing in a
/// `TypeInfo` needs the companion form.
fn rewrite_cps_source_metadata(
  schema : DictionaryCpsSchema,
  declarations : @effect_lowering_core.ProgramDeclarations,
) -> Unit raise SynthesisError {
  for data_constructor in declarations.data_constructor_ids() {
    let info = schema.metadata.data_constructors[data_constructor.index]
    schema.metadata.data_constructors[data_constructor.index] = {
      name: info.name,
      owner: info.owner,
      hidden_type_parameters: info.hidden_type_parameters,
      payload_types: info.payload_types.map(type_ => schema.rewrite_type(type_)),
    }
  }
  for value in declarations.value_ids() {
    let info = schema.metadata.values[value.index]
    let (target_type, callable_shape) = schema.rewrite_value_type(info.type_)
    schema.callable_shapes[value.index] = callable_shape
    schema.metadata.values[value.index] = {
      name: info.name,
      kind: info.kind,
      type_: target_type,
    }
  }
}

///|
fn validate_cps_binding_type(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
  initializer : Expr,
) -> Unit raise SynthesisError {
  guard metadata.value_info(id) is Some(info) else { raise UnknownValue(id) }
  let actual = synthesize_expr_or_raise(metadata, initializer).type_
  if !cps_type_is_consumable_as(metadata, actual, info.type_) {
    raise BindingTypeMismatch(value=id, expected=info.type_, actual~)
  }
}

///|
fn validate_cps_recursive_binding_types(
  metadata : @buslane.MetadataRegistry,
  bindings : Array[RecursiveBinding],
) -> Unit raise SynthesisError {
  for binding in bindings {
    validate_cps_binding_type(metadata, binding.id, binding.rhs)
  }
}
