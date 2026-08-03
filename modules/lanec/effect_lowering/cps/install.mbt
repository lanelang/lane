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
  if is_mon_effect(program.metadata, facts.effect) {
    raise MissingEffectContext(facts.effect)
  }
  let result_type = schema.rewrite_type(install.result_type)
  let result = schema.metadata.define_value(
    "%handler_result",
    Parameter,
    result_type,
  )
  lower_cps_install(
    schema,
    program,
    install,
    {
      effect: facts.effect,
      residual: schema.rewrite_residual_effect(facts.effect),
      bindings: [],
    },
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
  let unhandled = build_unhandled_computation_schema(
    schema,
    install_facts.effect,
    install.result_type,
  )
  let relay = build_relay_bindings(
    schema, program, unhandled, outer_environment,
  )
  let relay_environment = CpsEnvironment::{
    effect: cps_canonicalize_effect(
      program.metadata,
      Union([unhandled.effect, unhandled.residual_effect]),
    ),
    residual: unhandled.residual_effect,
    bindings: relay.bindings,
  }
  let handlers = build_handler_dictionary_plan(
    schema, program, install, unhandled, relay_environment,
  )
  let final_continuation = lower_handler_final_clause(
    schema,
    program,
    install.final_clause,
    unhandled,
    relay_environment,
  )
  // The handled expression runs under the install's unhandled, not its own: the
  // arms and the final branch it hands control to are the handler's, and their
  // effects are what the dictionary it receives performs.
  let inner_environment = CpsEnvironment::{
    effect: cps_canonicalize_effect(
      program.metadata,
      Union([body_facts.effect, unhandled.residual_effect]),
    ),
    residual: unhandled.residual_effect,
    bindings: handlers.bindings + relay.bindings,
  }
  let body = lower_cps_with_continuation(
    schema,
    program,
    install.body,
    inner_environment,
    unhandled.type_,
    final_continuation,
  )
  let scoped = wrap_cps_initializers(
    relay.initializers + handlers.initializers,
    0,
    body,
  )
  unhandled.run(
    schema.metadata,
    scoped,
    outer_environment,
    answer_type,
    continuation,
  )
}

///|
fn build_handler_dictionary_plan(
  schema : DictionaryCpsSchema,
  program : Program,
  install : InstallExpr,
  unhandled : UnhandledComputationSchema,
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
      unhandled.type_,
      unhandled.residual_effect,
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
          unhandled,
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
    let id = schema.metadata.define_value(
      "%handler_dictionary",
      Local,
      schema.context_term_type(
        dictionary.handled_effect,
        unhandled.type_,
        unhandled.residual_effect,
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
  unhandled : UnhandledComputationSchema,
  relay_environment : CpsEnvironment,
) -> Expr raise SynthesisError {
  let (source_type_binders, source_function) = match clause.callable {
    Monomorphic(function) => ([], function)
    Polymorphic(parameters, function) => (parameters, function)
  }
  let type_binders = schema.rewrite_cps_parameters(source_type_binders)
  let function_type = instantiate_clause_field_type(field_type, type_binders)
  guard function_type is Function(parameter_types, result_type, function_effect) &&
    cps_effects_definitionally_equal(
      schema.metadata,
      function_effect,
      unhandled.residual_effect,
    ) else {
    raise ExpectedFunction(function_type)
  }
  if !cps_types_definitionally_equal(
      schema.metadata,
      result_type,
      unhandled.type_,
    ) {
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
    cps_effects_definitionally_equal(
      schema.metadata,
      resume_effect,
      unhandled.residual_effect,
    ) else {
    raise ExpectedFunction(direct_resume_type)
  }
  if !cps_types_definitionally_equal(
      schema.metadata,
      direct_result,
      unhandled.type_,
    ) {
    raise ExpectedFunction(direct_resume_type)
  }
  let direct_resume = schema.metadata.define_value(
    "%resume_continuation",
    Parameter,
    direct_resume_type,
  )
  set_source_resume_effect(program.metadata, source_resume, unhandled.effect)
  let resume_value = build_handler_resume_value(
    schema, program, unhandled, operation_result, direct_resume,
  )
  validate_cps_binding_type(schema.metadata, source_resume, resume_value)
  let clause_body = lower_cps_with_continuation(
    schema,
    program,
    source_function.body,
    relay_environment,
    unhandled.type_,
    build_unhandled_result_continuation(schema, unhandled),
  )
  source_parameters.push(direct_resume)
  let function = Expr::Function({
    parameters: source_parameters,
    result_type: unhandled.type_,
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
  unhandled : UnhandledComputationSchema,
  operation_result : @buslane.Type,
  direct_resume : @buslane.ValueId,
) -> Expr raise SynthesisError {
  let parameter = schema.metadata.define_value(
    "%resume_result",
    Parameter,
    operation_result,
  )
  let resumed = Expr::Call(Ref(direct_resume), [Ref(parameter)])
  if cps_effects_definitionally_equal(program.metadata, unhandled.effect, Empty) {
    Function({
      parameters: [parameter],
      result_type: unhandled.result_type,
      body: resumed,
    })
  } else {
    let frame = unhandled.fresh_frame(schema)
    frame.wrap_with_parameter(
      parameter,
      unhandled.run(
        schema.metadata,
        resumed,
        frame.environment,
        frame.answer_type,
        Ref(frame.continuation),
      ),
    )
  }
}

///|
fn UnhandledFrame::wrap_with_parameter(
  self : UnhandledFrame,
  parameter : @buslane.ValueId,
  body : Expr,
) -> Expr {
  TypeLambda(
    [self.answer_parameter, self.residual_parameter],
    Function({
      parameters: self.context_parameters + [parameter, self.continuation],
      result_type: self.answer_type,
      body,
    }),
  )
}

///|
fn build_unhandled_result_continuation(
  schema : DictionaryCpsSchema,
  unhandled : UnhandledComputationSchema,
) -> Expr raise SynthesisError {
  let result = schema.metadata.define_value(
    "%handler_result",
    Parameter,
    unhandled.result_type,
  )
  Function({
    parameters: [result],
    result_type: unhandled.type_,
    body: unhandled.pure(schema, Ref(result)),
  })
}

///|
fn lower_handler_final_clause(
  schema : DictionaryCpsSchema,
  program : Program,
  final_clause : FunctionExpr,
  unhandled : UnhandledComputationSchema,
  relay_environment : CpsEnvironment,
) -> Expr raise SynthesisError {
  require_arity(1, final_clause.parameters.length())
  Function({
    parameters: final_clause.parameters,
    result_type: unhandled.type_,
    body: lower_cps_with_continuation(
      schema,
      program,
      final_clause.body,
      relay_environment,
      unhandled.type_,
      build_unhandled_result_continuation(schema, unhandled),
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
