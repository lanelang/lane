///|
priv struct DirectToCpsCallable {
  answer_parameter : @buslane.TypeParameterId
  residual_parameter : @buslane.TypeParameterId
  parameters : Array[@buslane.Type]
  value_parameter_start : Int
  value_parameter_count : Int
}

///|
fn lower_cps_call_arguments(
  schema : DictionaryCpsSchema,
  program : Program,
  arguments : Array[Expr],
  target_callee : Expr,
  current_answer : CpsAnswer?,
) -> Array[Expr] raise SynthesisError {
  let lowered = arguments.map(argument => {
    lower_cps_direct_expr(schema, program, argument, current_answer)
  })
  let target_callee_type = synthesize_expr_or_raise(
      schema.metadata,
      target_callee,
    ).type_
  guard cps_value_parameter_types(target_callee_type, arguments.length())
    is Some(target_parameter_types) else {
    raise ExpectedFunction(target_callee_type)
  }
  lowered.mapi((index, argument) => {
    adapt_direct_argument_to_cps(
      schema,
      argument,
      target_parameter_types[index],
    )
  })
}

///|
fn cps_value_parameter_types(
  callable_type : @buslane.Type,
  value_parameter_count : Int,
) -> Array[@buslane.Type]? {
  match callable_type {
    Function(parameters, result, _) =>
      call_value_parameter_slice(parameters, result, value_parameter_count)
    Forall(
      [answer_parameter, _],
      Function(parameters, Parameter(result_parameter), _)
    ) if answer_parameter == result_parameter =>
      call_value_parameter_slice(
        parameters,
        Parameter(answer_parameter),
        value_parameter_count,
      )
    _ => None
  }
}

///|
fn call_value_parameter_slice(
  parameters : Array[@buslane.Type],
  result_type : @buslane.Type,
  value_parameter_count : Int,
) -> Array[@buslane.Type]? {
  if parameters.length() == value_parameter_count {
    return Some(parameters)
  }
  if parameters.length() < value_parameter_count + 1 {
    return None
  }
  guard parameters.last() is Some(Function([_], continuation_result, _)) &&
    continuation_result == result_type else {
    return None
  }
  let start = parameters.length() - value_parameter_count - 1
  Some(Array::makei(value_parameter_count, index => parameters[start + index]))
}

///|
fn adapt_direct_argument_to_cps(
  schema : DictionaryCpsSchema,
  argument : Expr,
  target_parameter_type : @buslane.Type,
) -> Expr raise SynthesisError {
  let actual_type = synthesize_expr_or_raise(schema.metadata, argument).type_
  if schema.metadata.types_definitionally_equal(
      actual_type, target_parameter_type,
    ) {
    return argument
  }
  guard direct_to_cps_callable(
      schema.metadata,
      actual_type,
      target_parameter_type,
    )
    is Some(callable) else {
    return argument
  }
  let source = schema.metadata.define_value(
    "%direct_cps_source",
    Value,
    actual_type,
  )
  let parameters = callable.parameters.map(type_ => {
    schema.metadata.define_value("%direct_cps_parameter", Parameter, type_)
  })
  let value_parameters : Array[Expr] = Array::makei(
    callable.value_parameter_count,
    index => Ref(parameters[callable.value_parameter_start + index]),
  )
  let continuation = parameters.last().unwrap()
  Let(
    source,
    argument,
    TypeLambda(
      [callable.answer_parameter, callable.residual_parameter],
      Function({
        parameters,
        result_type: Parameter(callable.answer_parameter),
        body: Call(Ref(continuation), [Call(Ref(source), value_parameters)]),
      }),
    ),
  )
}

///|
fn direct_to_cps_callable(
  metadata : @buslane.MetadataRegistry,
  actual_type : @buslane.Type,
  target_parameter_type : @buslane.Type,
) -> DirectToCpsCallable? {
  guard actual_type is Function(actual_parameters, actual_result, actual_effect) else {
    return None
  }
  guard target_parameter_type
    is Forall(
      [answer_parameter, residual_parameter],
      Function(parameters, Parameter(result_parameter), residual_effect)
    ) &&
    answer_parameter == result_parameter else {
    return None
  }
  if parameters.length() < actual_parameters.length() + 1 {
    return None
  }
  let value_parameter_start = parameters.length() -
    actual_parameters.length() -
    1
  guard parameters.last()
    is Some(
      Function(
        [continuation_input],
        Parameter(continuation_result),
        continuation_effect
      )
    ) &&
    continuation_result == answer_parameter &&
    metadata.effects_definitionally_equal(continuation_effect, residual_effect) else {
    return None
  }
  // The adapter body calls the wrapped function and then the continuation, so
  // its row is the union of the two. It matches the shape being adapted to
  // exactly when the wrapped function stays inside the target's residual.
  if !metadata.types_definitionally_equal(actual_result, continuation_input) ||
    !metadata.effect_is_subeffect_of(actual_effect, residual_effect) {
    return None
  }
  for index in 0..<actual_parameters.length() {
    if !metadata.types_definitionally_equal(
        actual_parameters[index],
        parameters[value_parameter_start + index],
      ) {
      return None
    }
  }
  Some({
    answer_parameter,
    residual_parameter,
    parameters,
    value_parameter_start,
    value_parameter_count: actual_parameters.length(),
  })
}
