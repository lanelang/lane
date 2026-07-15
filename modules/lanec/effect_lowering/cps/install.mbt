///|
priv struct HandlerDictionaryPlan {
  bindings : Array[CpsContextBinding]
  initializers : Array[CpsValueInitializer]
}

///|
fn lower_cps_direct_install(
  schema : DictionaryCpsSchema,
  program : Program,
  install : InstallExpr,
) -> Expr raise SynthesisError {
  let facts = synthesize_expr_or_raise(program.metadata, Install(install))
  if is_mon_effect(facts.effect) {
    raise MissingEffectContext(facts.effect)
  }
  let result_type = schema.rewrite_type(install.result_type)
  let result = program.metadata.define_value(
    "%handler_result",
    Parameter,
    result_type,
  )
  lower_cps_install(
    schema,
    program,
    install,
    { effect: facts.effect, bindings: [] },
    result_type,
    Function({ parameters: [result], result_type, body: Ref(result) }),
  )
}

///|
fn lower_cps_install(
  schema : DictionaryCpsSchema,
  program : Program,
  install : InstallExpr,
  outer_environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(program.metadata, install.body)
  let install_facts = synthesize_expr_or_raise(
    program.metadata,
    Install(install),
  )
  let residual = build_residual_computation_schema(
    schema,
    install_facts.effect,
    install.result_type,
  )
  let relay = build_residual_relay_bindings(
    schema, program, residual, outer_environment,
  )
  let relay_environment = CpsEnvironment::{
    effect: @buslane.Effect::Union([residual.effect, residual.residual_effect]).canonicalize(),
    bindings: relay.bindings,
  }
  let handlers = build_handler_dictionary_plan(
    schema, program, install, residual, relay_environment,
  )
  let final_continuation = lower_handler_final_clause(
    schema,
    program,
    install.final_clause,
    residual,
    relay_environment,
  )
  let inner_environment = CpsEnvironment::{
    effect: body_facts.effect,
    bindings: handlers.bindings + relay.bindings,
  }
  let body = lower_cps_with_continuation(
    schema,
    program,
    install.body,
    inner_environment,
    residual.type_,
    final_continuation,
  )
  let scoped = wrap_cps_initializers(
    relay.initializers + handlers.initializers,
    0,
    body,
  )
  residual.run(scoped, outer_environment, answer_type, continuation)
}

///|
fn build_handler_dictionary_plan(
  schema : DictionaryCpsSchema,
  program : Program,
  install : InstallExpr,
  residual : ResidualComputationSchema,
  relay_environment : CpsEnvironment,
) -> HandlerDictionaryPlan raise SynthesisError {
  let bindings = []
  let initializers = []
  for dictionary in install.dictionaries {
    guard dictionary.handled_effect is Singleton(effect, arguments) else {
      abort("verified handler dictionary must handle one concrete effect")
    }
    guard program.metadata.effect_info(effect) is Some(effect_info) else {
      raise UnknownEffect(effect)
    }
    let instance = instantiate_dictionary(
      schema,
      effect,
      arguments,
      residual.type_,
      residual.residual_effect,
    )
    let fields = []
    for index in 0..<effect_info.operations.length() {
      let operation = effect_info.operations[index]
      let clause = find_operation_clause(dictionary.operations, operation)
      fields.push(
        lower_handler_operation_clause(
          schema,
          program,
          clause,
          instance.field_types[index],
          residual,
          relay_environment,
        ),
      )
    }
    let value = Expr::Construct({
      data_constructor: instance.data_constructor,
      type_arguments: instance.type_arguments,
      hidden_witnesses: [],
      payloads: fields,
    })
    let id = program.metadata.define_value(
      "%handler_dictionary",
      Local,
      schema.context_term_type(
        dictionary.handled_effect,
        residual.type_,
        residual.residual_effect,
      ),
    )
    bindings.push({ term: dictionary.handled_effect, value: Ref(id) })
    initializers.push({ id, value })
  }
  { bindings, initializers }
}

///|
fn find_operation_clause(
  clauses : Array[OperationClause],
  operation : @buslane.OperationId,
) -> OperationClause raise SynthesisError {
  for clause in clauses {
    if clause.operation == operation {
      return clause
    }
  }
  raise MissingOperationClause(operation)
}

///|
fn lower_handler_operation_clause(
  schema : DictionaryCpsSchema,
  program : Program,
  clause : OperationClause,
  field_type : @buslane.Type,
  residual : ResidualComputationSchema,
  relay_environment : CpsEnvironment,
) -> Expr raise SynthesisError {
  let (source_type_binders, source_function) = match clause.callable {
    Monomorphic(function) => ([], function)
    Polymorphic(parameters, function) => (parameters, function)
  }
  let type_binders = source_type_binders.map(parameter => {
    schema.companion_parameter(parameter)
  })
  let function_type = instantiate_clause_field_type(field_type, type_binders)
  guard function_type is Function(parameter_types, result_type, function_effect) &&
    function_effect == residual.residual_effect else {
    raise ExpectedFunction(function_type)
  }
  if !result_type.equals(residual.type_) {
    raise ExpectedFunction(function_type)
  }
  let source_parameters = source_function.parameters.copy()
  guard source_parameters.pop() is Some(source_resume) else {
    raise ArityMismatch(expected=1, actual=0)
  }
  require_arity(source_function.parameters.length(), parameter_types.length())
  guard parameter_types.last() is Some(direct_resume_type) else {
    raise ArityMismatch(expected=1, actual=0)
  }
  guard direct_resume_type
    is Function([operation_result], direct_result, resume_effect) &&
    resume_effect == residual.residual_effect else {
    raise ExpectedFunction(direct_resume_type)
  }
  if !direct_result.equals(residual.type_) {
    raise ExpectedFunction(direct_resume_type)
  }
  let direct_resume = program.metadata.define_value(
    "%resume_continuation",
    Parameter,
    direct_resume_type,
  )
  set_source_resume_effect(program.metadata, source_resume, residual.effect)
  let resume_value = build_handler_resume_value(
    schema, program, residual, operation_result, direct_resume,
  )
  let clause_body = lower_cps_with_continuation(
    schema,
    program,
    source_function.body,
    relay_environment,
    residual.type_,
    build_residual_result_continuation(schema, program, residual),
  )
  source_parameters.push(direct_resume)
  let function = Expr::Function({
    parameters: source_parameters,
    result_type: residual.type_,
    body: Let(source_resume, resume_value, clause_body),
  })
  if type_binders.is_empty() {
    function
  } else {
    TypeLambda(type_binders, function)
  }
}

///|
fn instantiate_clause_field_type(
  field_type : @buslane.Type,
  type_binders : Array[@buslane.TypeParameterId],
) -> @buslane.Type raise SynthesisError {
  match field_type {
    Forall(parameters, body) => {
      require_arity(parameters.length(), type_binders.length())
      let substitution = @buslane.TypeSubstitution::TypeSubstitution()
      for index in 0..<parameters.length() {
        substitution.insert(parameters[index], Parameter(type_binders[index]))
      }
      body.substitute(substitution)
    }
    _ => {
      require_arity(0, type_binders.length())
      field_type
    }
  }
}

///|
fn build_handler_resume_value(
  schema : DictionaryCpsSchema,
  program : Program,
  residual : ResidualComputationSchema,
  operation_result : @buslane.Type,
  direct_resume : @buslane.ValueId,
) -> Expr raise SynthesisError {
  let parameter = program.metadata.define_value(
    "%resume_result",
    Parameter,
    operation_result,
  )
  let resumed = Expr::Call(Ref(direct_resume), [Ref(parameter)])
  if residual.effect == Empty {
    Function({
      parameters: [parameter],
      result_type: residual.result_type,
      body: resumed,
    })
  } else {
    let frame = residual.fresh_frame(schema, program)
    frame.wrap_with_parameter(
      parameter,
      residual.run(
        resumed,
        frame.environment,
        frame.answer_type,
        Ref(frame.continuation),
      ),
    )
  }
}

///|
fn ResidualFrame::wrap_with_parameter(
  self : ResidualFrame,
  parameter : @buslane.ValueId,
  body : Expr,
) -> Expr {
  TypeLambda(
    [self.answer_parameter],
    Function({
      parameters: self.context_parameters + [parameter, self.continuation],
      result_type: self.answer_type,
      body,
    }),
  )
}

///|
fn build_residual_result_continuation(
  schema : DictionaryCpsSchema,
  program : Program,
  residual : ResidualComputationSchema,
) -> Expr raise SynthesisError {
  let result = program.metadata.define_value(
    "%handler_result",
    Parameter,
    residual.result_type,
  )
  Function({
    parameters: [result],
    result_type: residual.type_,
    body: residual.pure(schema, program, Ref(result)),
  })
}

///|
fn lower_handler_final_clause(
  schema : DictionaryCpsSchema,
  program : Program,
  final_clause : FunctionExpr,
  residual : ResidualComputationSchema,
  relay_environment : CpsEnvironment,
) -> Expr raise SynthesisError {
  require_arity(1, final_clause.parameters.length())
  Function({
    parameters: final_clause.parameters,
    result_type: residual.type_,
    body: lower_cps_with_continuation(
      schema,
      program,
      final_clause.body,
      relay_environment,
      residual.type_,
      build_residual_result_continuation(schema, program, residual),
    ),
  })
}

///|
fn wrap_cps_initializers(
  initializers : Array[CpsValueInitializer],
  index : Int,
  body : Expr,
) -> Expr {
  if index == initializers.length() {
    body
  } else {
    let initializer = initializers[index]
    Let(
      initializer.id,
      initializer.value,
      wrap_cps_initializers(initializers, index + 1, body),
    )
  }
}
