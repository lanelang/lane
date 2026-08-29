///|
priv struct UnhandledComputationSchema {
  effect : @buslane.Effect
  residual_effect : @buslane.Effect
  result_type : @buslane.Type
  type_ : @buslane.Type
}

///|
priv struct UnhandledFrame {
  answer_parameter : @buslane.TypeParameterId
  residual_parameter : @buslane.TypeParameterId
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
priv struct RelayPlan {
  bindings : Array[CpsContextBinding]
  initializers : Array[CpsValueInitializer]
}

///|
fn build_unhandled_computation_schema(
  schema : DictionaryCpsSchema,
  effect : @buslane.Effect,
  result_type : @buslane.Type,
) -> UnhandledComputationSchema raise SynthesisError {
  let canonical = mon_effect_part(schema.metadata, effect)
  let residual_effect = schema.rewrite_residual_effect(effect)
  let rewritten_result = schema.rewrite_type(result_type)
  if cps_effects_definitionally_equal(schema.metadata, canonical, Empty) {
    {
      effect: canonical,
      residual_effect,
      result_type: rewritten_result,
      type_: rewritten_result,
    }
  } else {
    // A unhandled computation is a CPS'd callable like any other, so it carries
    // the same binders: callers instantiate the unhandled it runs under rather
    // than being handed one fixed at the install site.
    let answer_parameter = schema.metadata.define_cps_type_parameter(
      "%unhandled_answer",
      Type,
    )
    let residual_parameter = schema.metadata.define_cps_type_parameter(
      "%unhandled",
      Effect,
      flavor=External,
    )
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    let frame_residual = cps_canonicalize_effect(
      schema.metadata,
      Union([residual_effect, Parameter(residual_parameter)]),
    )
    {
      effect: canonical,
      residual_effect,
      result_type: rewritten_result,
      type_: Forall(
        [answer_parameter, residual_parameter],
        Function(
          schema.context_argument_types(canonical, answer_type, frame_residual) +
          [Function([rewritten_result], answer_type, frame_residual)],
          answer_type,
          frame_residual,
        ),
      ),
    }
  }
}

///|
fn UnhandledComputationSchema::fresh_frame(
  self : UnhandledComputationSchema,
  schema : DictionaryCpsSchema,
) -> UnhandledFrame raise SynthesisError {
  let answer_parameter = schema.metadata.define_cps_type_parameter(
    "%unhandled_answer",
    Type,
  )
  let residual_parameter = schema.metadata.define_cps_type_parameter(
    "%unhandled",
    Effect,
    flavor=External,
  )
  let answer_type = @buslane.Type::Parameter(answer_parameter)
  let frame_residual = cps_canonicalize_effect(
    schema.metadata,
    Union([self.residual_effect, Parameter(residual_parameter)]),
  )
  let context_parameters = []
  let bindings = []
  for term in effect_terms(schema.metadata, self.effect) {
    let parameter = schema.metadata.define_cps_value(
      "%unhandled_context",
      Parameter,
      schema.context_term_type(term, answer_type, frame_residual),
    )
    context_parameters.push(parameter)
    bindings.push({ term, value: Ref(parameter), })
  }
  let continuation = schema.metadata.define_cps_value(
    "%unhandled_continuation",
    Parameter,
    Function([self.result_type], answer_type, frame_residual),
  )
  {
    answer_parameter,
    residual_parameter,
    answer_type,
    context_parameters,
    environment: {
      effect: cps_canonicalize_effect(
        schema.metadata,
        Union([self.effect, self.residual_effect]),
      ),
      residual: frame_residual,
      bindings,
    },
    continuation,
  }
}

///|
fn UnhandledFrame::wrap(self : UnhandledFrame, body : Expr) -> Expr {
  TypeLambda(
    [self.answer_parameter, self.residual_parameter],
    Function({
      origin: SelectiveCps,
      parameters: self.context_parameters + [self.continuation],
      result_type: self.answer_type,
      body,
    }),
  )
}

///|
fn UnhandledComputationSchema::pure(
  self : UnhandledComputationSchema,
  schema : DictionaryCpsSchema,
  value : Expr,
) -> Expr raise SynthesisError {
  if cps_effects_definitionally_equal(schema.metadata, self.effect, Empty) {
    value
  } else {
    let frame = self.fresh_frame(schema)
    frame.wrap(Call(Ref(frame.continuation), [value]))
  }
}

///|
fn UnhandledComputationSchema::run(
  self : UnhandledComputationSchema,
  metadata : @buslane.MetadataRegistry,
  computation : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  if cps_effects_definitionally_equal(metadata, self.effect, Empty) {
    Call(continuation, [computation])
  } else {
    Call(
      TypeApply(computation, environment.answer(answer_type).arguments()),
      effect_terms(metadata, self.effect).map(term => {
        find_cps_context(metadata, environment, term)
      }) +
      [continuation],
    )
  }
}

///|
fn build_relay_bindings(
  schema : DictionaryCpsSchema,
  program : Program,
  unhandled : UnhandledComputationSchema,
  outer_environment : CpsEnvironment,
) -> RelayPlan raise SynthesisError {
  let bindings = []
  let initializers = []
  for term in effect_terms(schema.metadata, unhandled.effect) {
    match term {
      Builtin(_) => ()
      Singleton(effect, arguments) => {
        let value = build_concrete_relay_dictionary(
          schema, program, unhandled, effect, arguments,
        )
        let id = schema.metadata.define_cps_value(
          "%relay_dictionary",
          Local,
          schema.context_term_type(
            term,
            unhandled.type_,
            unhandled.residual_effect,
          ),
        )
        bindings.push({ term, value: Ref(id), })
        initializers.push({ id, value, })
      }
      Parameter(_) =>
        bindings.push({
          term,
          value: find_cps_context(schema.metadata, outer_environment, term),
        })
      Empty | Union(_) => abort("canonical unhandled effect term expected")
    }
  }
  { bindings, initializers, }
}

///|
fn build_concrete_relay_dictionary(
  schema : DictionaryCpsSchema,
  program : Program,
  unhandled : UnhandledComputationSchema,
  effect : @buslane.EffectId,
  arguments : Array[@buslane.GenericArgument],
) -> Expr raise SynthesisError {
  guard schema.metadata.effect_info(effect) is Some(effect_info) else {
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
    fields.push(
      build_relay_field(
        schema,
        program,
        unhandled,
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
fn build_relay_field(
  schema : DictionaryCpsSchema,
  program : Program,
  unhandled : UnhandledComputationSchema,
  term : @buslane.Effect,
  operation : @buslane.OperationId,
  field_type : @buslane.Type,
) -> Expr raise SynthesisError {
  let (type_binders, function_type) = freshen_relay_field_type(
    schema.metadata,
    field_type,
  )
  guard function_type is Function(parameter_types, result_type, function_effect) &&
    cps_effects_definitionally_equal(
      schema.metadata,
      function_effect,
      unhandled.residual_effect,
    ) else {
    raise ExpectedFunction(function_type)
  }
  let parameters = parameter_types.map(type_ => {
    schema.metadata.define_cps_value("%relay_parameter", Parameter, type_)
  })
  guard parameters.last() is Some(resume_parameter) else {
    raise ArityMismatch(expected=1, actual=0)
  }
  guard parameter_types.last()
    is Some(Function([operation_result], resume_result, resume_effect)) &&
    cps_effects_definitionally_equal(
      schema.metadata,
      resume_effect,
      unhandled.residual_effect,
    ) else {
    raise ExpectedFunction(parameter_types.last().unwrap())
  }
  if !cps_types_definitionally_equal(
      schema.metadata,
      resume_result,
      unhandled.type_,
    ) ||
    !cps_types_definitionally_equal(
      schema.metadata,
      result_type,
      unhandled.type_,
    ) {
    raise ExpectedFunction(function_type)
  }
  let frame = unhandled.fresh_frame(schema)
  let operation_result_parameter = schema.metadata.define_cps_value(
    "%relay_result",
    Parameter,
    operation_result,
  )
  let resumed = Expr::Call(Ref(resume_parameter), [
    Ref(operation_result_parameter),
  ])
  let resume_continuation = Expr::Function({
    origin: SelectiveCps,
    parameters: [operation_result_parameter],
    result_type: frame.answer_type,
    body: unhandled.run(
      schema.metadata,
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
        match schema.metadata.type_parameter_info(parameter) {
          Some({ kind: Effect, .. }) => EffectArgument(Parameter(parameter))
          _ => TypeArgument(Parameter(parameter))
        }
      }),
      payloads,
    },
    frame.environment,
    frame.answer_type,
    resume_continuation,
  )
  let function = Expr::Function({
    origin: SelectiveCps,
    parameters,
    result_type: unhandled.type_,
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
) -> (Array[@buslane.TypeParameterId], @buslane.Type) raise SynthesisError {
  match field_type {
    Forall(parameters, body) => {
      let fresh = parameters.map(parameter => {
        let info = metadata.type_parameter_info(parameter).unwrap()
        metadata.define_cps_type_parameter("%relay_type", info.kind)
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
