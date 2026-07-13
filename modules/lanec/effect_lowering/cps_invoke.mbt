///|
fn lower_cps_invoke(
  schema : DictionaryCpsSchema,
  program : Program,
  invoke : InvokeExpr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  guard program.metadata.operation_info(invoke.operation) is Some(operation) else {
    raise UnknownOperation(invoke.operation)
  }
  guard program.metadata.effect_info(operation.owner) is Some(effect) else {
    raise UnknownEffect(operation.owner)
  }
  let term = @buslane.Effect::Singleton(
    operation.owner,
    invoke.effect_arguments,
  )
  let dictionary_expression = find_cps_context(environment, term)
  let dictionary_type = schema.context_term_type(term, answer_type)
  let dictionary_binder = program.metadata.define_value(
    "%dictionary",
    MatchBinder,
    dictionary_type,
  )
  let header = schema.dictionary(operation.owner)
  guard program.metadata.type_info(header.type_id) is Some(dictionary) else {
    raise UnknownType(header.type_id)
  }
  guard dictionary.constructors is [data_constructor] else {
    raise UnknownType(header.type_id)
  }
  guard program.metadata.data_constructor_info(data_constructor)
    is Some(data_info) else {
    raise UnknownDataConstructor(data_constructor)
  }
  let type_arguments = invoke.effect_arguments.map(argument => {
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
  let field_binders = data_info.payload_types.map(type_ => {
    program.metadata.define_value(
      "%operation",
      MatchBinder,
      type_.substitute(substitution),
    )
  })
  let field_index = operation_field_index(effect.operations, invoke.operation)
  let field = Expr::Ref(field_binders[field_index])
  let callee = if invoke.hidden_witnesses.is_empty() {
    field
  } else {
    TypeApply(
      field,
      invoke.hidden_witnesses.map(argument => {
        rewrite_cps_expression_argument(schema, argument, Some(answer_type))
      }),
    )
  }
  Match({
    scrutinee: dictionary_expression,
    binder: dictionary_binder,
    result_type: answer_type,
    alternatives: [
      {
        alt_constructor: DataCon(data_constructor),
        type_binders: [],
        value_binders: field_binders,
        body: Call(
          callee,
          invoke.payloads.map(payload => {
            lower_cps_direct_expr(schema, program, payload, Some(answer_type))
          }) +
          [continuation],
        ),
      },
    ],
  })
}

///|
fn operation_field_index(
  operations : Array[@buslane.OperationId],
  operation : @buslane.OperationId,
) -> Int {
  for index in 0..<operations.length() {
    if operations[index] == operation {
      return index
    }
  }
  abort("operation owner metadata must contain the operation")
}
