///|
priv struct ResidualComputationSchema {
  effect : @buslane.Effect
  residual_effect : @buslane.Effect
  result_type : @buslane.Type
  type_ : @buslane.Type
}

///|
priv struct ResidualFrame {
  answer_parameter : @buslane.TypeParameterId
  answer_type : @buslane.Type
  context_parameters : Array[@buslane.ValueId]
  environment : CpsEnvironment
  continuation : @buslane.ValueId
}

///|
priv struct CpsValueInitializer {
  id : @buslane.ValueId
  value : Expr
}

///|
priv struct ResidualRelayPlan {
  bindings : Array[CpsContextBinding]
  initializers : Array[CpsValueInitializer]
}

///|
fn build_residual_computation_schema(
  schema : DictionaryCpsSchema,
  effect : @buslane.Effect,
  result_type : @buslane.Type,
) -> ResidualComputationSchema raise SynthesisError {
  let canonical = mon_effect_part(effect)
  let residual_effect = residual_effect_part(effect)
  let rewritten_result = schema.rewrite_type(result_type)
  if canonical == Empty {
    {
      effect: canonical,
      residual_effect,
      result_type: rewritten_result,
      type_: rewritten_result,
    }
  } else {
    let answer_parameter = schema.metadata.define_type_parameter(
      "%residual_answer",
      Type,
    )
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    {
      effect: canonical,
      residual_effect,
      result_type: rewritten_result,
      type_: Forall(
        [answer_parameter],
        Function(
          schema.context_argument_types(canonical, answer_type) +
          [Function([rewritten_result], answer_type, residual_effect)],
          answer_type,
          residual_effect,
        ),
      ),
    }
  }
}

///|
fn ResidualComputationSchema::fresh_frame(
  self : ResidualComputationSchema,
  schema : DictionaryCpsSchema,
  program : Program,
) -> ResidualFrame raise SynthesisError {
  let answer_parameter = program.metadata.define_type_parameter(
    "%residual_answer",
    Type,
  )
  let answer_type = @buslane.Type::Parameter(answer_parameter)
  let context_parameters = []
  let bindings = []
  for term in effect_terms(self.effect) {
    let parameter = program.metadata.define_value(
      "%residual_context",
      Parameter,
      schema.context_term_type(term, answer_type, self.residual_effect),
    )
    context_parameters.push(parameter)
    bindings.push({ term, value: Ref(parameter) })
  }
  let continuation = program.metadata.define_value(
    "%residual_continuation",
    Parameter,
    Function([self.result_type], answer_type, self.residual_effect),
  )
  {
    answer_parameter,
    answer_type,
    context_parameters,
    environment: { effect: self.effect, bindings },
    continuation,
  }
}

///|
fn ResidualFrame::wrap(self : ResidualFrame, body : Expr) -> Expr {
  TypeLambda(
    [self.answer_parameter],
    Function({
      parameters: self.context_parameters + [self.continuation],
      result_type: self.answer_type,
      body,
    }),
  )
}

///|
fn ResidualComputationSchema::pure(
  self : ResidualComputationSchema,
  schema : DictionaryCpsSchema,
  program : Program,
  value : Expr,
) -> Expr raise SynthesisError {
  if self.effect == Empty {
    value
  } else {
    let frame = self.fresh_frame(schema, program)
    frame.wrap(Call(Ref(frame.continuation), [value]))
  }
}

///|
fn ResidualComputationSchema::run(
  self : ResidualComputationSchema,
  computation : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  if self.effect == Empty {
    Call(continuation, [computation])
  } else {
    Call(
      TypeApply(computation, [TypeArgument(answer_type)]),
      effect_terms(self.effect).map(term => find_cps_context(environment, term)) +
      [continuation],
    )
  }
}

///|
fn build_residual_relay_bindings(
  schema : DictionaryCpsSchema,
  program : Program,
  residual : ResidualComputationSchema,
  outer_environment : CpsEnvironment,
) -> ResidualRelayPlan raise SynthesisError {
  let bindings = []
  let initializers = []
  for term in effect_terms(residual.effect) {
    match term {
      Io => ()
      Singleton(effect, arguments) => {
        let value = build_concrete_relay_dictionary(
          schema, program, residual, effect, arguments,
        )
        let id = program.metadata.define_value(
          "%relay_dictionary",
          Local,
          schema.context_term_type(
            term,
            residual.type_,
            residual.residual_effect,
          ),
        )
        bindings.push({ term, value: Ref(id) })
        initializers.push({ id, value })
      }
      Parameter(_) =>
        bindings.push({ term, value: find_cps_context(outer_environment, term) })
      Empty | Union(_) => abort("canonical residual effect term expected")
    }
  }
  { bindings, initializers }
}

///|
fn build_concrete_relay_dictionary(
  schema : DictionaryCpsSchema,
  program : Program,
  residual : ResidualComputationSchema,
  effect : @buslane.EffectId,
  arguments : Array[@buslane.GenericArgument],
) -> Expr raise SynthesisError {
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
    fields.push(
      build_residual_relay_field(
        schema,
        program,
        residual,
        Singleton(effect, arguments),
        effect_info.operations[index],
        instance.field_types[index],
      ),
    )
  }
  Construct({
    data_constructor: instance.data_constructor,
    type_arguments: instance.type_arguments,
    hidden_witnesses: [],
    payloads: fields,
  })
}

///|
fn build_residual_relay_field(
  schema : DictionaryCpsSchema,
  program : Program,
  residual : ResidualComputationSchema,
  term : @buslane.Effect,
  operation : @buslane.OperationId,
  field_type : @buslane.Type,
) -> Expr raise SynthesisError {
  let (type_binders, function_type) = freshen_relay_field_type(
    program.metadata,
    field_type,
  )
  guard function_type is Function(parameter_types, result_type, function_effect) &&
    function_effect == residual.residual_effect else {
    raise ExpectedFunction(function_type)
  }
  let parameters = parameter_types.map(type_ => {
    program.metadata.define_value("%relay_parameter", Parameter, type_)
  })
  guard parameters.last() is Some(resume_parameter) else {
    raise ArityMismatch(expected=1, actual=0)
  }
  guard parameter_types.last()
    is Some(Function([operation_result], resume_result, resume_effect)) &&
    resume_effect == residual.residual_effect else {
    raise ExpectedFunction(parameter_types.last().unwrap())
  }
  if !resume_result.equals(residual.type_) ||
    !result_type.equals(residual.type_) {
    raise ExpectedFunction(function_type)
  }
  let frame = residual.fresh_frame(schema, program)
  let operation_result_parameter = program.metadata.define_value(
    "%relay_result",
    Parameter,
    operation_result,
  )
  let resumed = Expr::Call(Ref(resume_parameter), [
    Ref(operation_result_parameter),
  ])
  let resume_continuation = Expr::Function({
    parameters: [operation_result_parameter],
    result_type: frame.answer_type,
    body: residual.run(
      resumed,
      frame.environment,
      frame.answer_type,
      Ref(frame.continuation),
    ),
  })
  guard term is Singleton(_, arguments) else {
    abort("concrete relay term expected")
  }
  let payloads : Array[Expr] = []
  for index in 0..<(parameters.length() - 1) {
    payloads.push(Ref(parameters[index]))
  }
  let field_body = lower_cps_invoke(
    schema,
    program,
    {
      operation,
      effect_arguments: arguments,
      hidden_witnesses: type_binders.map(parameter => {
        TypeArgument(Parameter(parameter))
      }),
      payloads,
    },
    frame.environment,
    frame.answer_type,
    resume_continuation,
  )
  let function = Expr::Function({
    parameters,
    result_type: residual.type_,
    body: frame.wrap(field_body),
  })
  if type_binders.is_empty() {
    function
  } else {
    TypeLambda(type_binders, function)
  }
}

///|
fn freshen_relay_field_type(
  metadata : @buslane.MetadataRegistry,
  field_type : @buslane.Type,
) -> (Array[@buslane.TypeParameterId], @buslane.Type) {
  match field_type {
    Forall(parameters, body) => {
      let fresh = parameters.map(parameter => {
        let info = metadata.type_parameter_info(parameter).unwrap()
        metadata.define_type_parameter("%relay_type", info.kind)
      })
      let substitution = @buslane.TypeSubstitution::TypeSubstitution()
      for index in 0..<parameters.length() {
        substitution.insert(parameters[index], Parameter(fresh[index]))
      }
      (fresh, body.substitute(substitution))
    }
    _ => ([], field_type)
  }
}
