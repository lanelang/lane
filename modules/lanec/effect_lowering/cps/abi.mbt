///|
priv struct CpsContextBinding {
  term : @buslane.Effect
  value : Expr
}

///|
priv struct CpsEnvironment {
  effect : @buslane.Effect
  bindings : Array[CpsContextBinding]
}

///|
pub fn rewrite_selective_cps_abis(
  program : Program,
) -> Result[Program, SynthesisError] {
  match rewrite_selective_cps_abis_with_companions(program) {
    Ok(result) => Ok(result.program)
    Err(error) => Err(error)
  }
}

///|
pub(all) struct SelectiveCpsRewrite {
  program : Program
  effect_companions : Array[EffectCompanionBinding]
} derive(Debug, Eq)

///|
pub fn rewrite_selective_cps_abis_with_companions(
  program : Program,
) -> Result[SelectiveCpsRewrite, SynthesisError] {
  Ok(rewrite_selective_cps_abis_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn rewrite_selective_cps_abis_or_raise(
  program : Program,
) -> SelectiveCpsRewrite raise SynthesisError {
  let counts = CpsSourceCounts::{
    types: program.metadata.types.length(),
    data_constructors: program.metadata.data_constructors.length(),
    values: program.metadata.values.length(),
  }
  let schema = build_dictionary_cps_schema_or_raise(program.metadata)
  let terms = program.terms.map(term => {
    lower_cps_top_term(schema, program, term)
  })
  rewrite_cps_source_metadata(schema, counts)
  let output = Program::{ metadata: program.metadata, terms }
  synchronize_cps_top_level_value_types(output)
  validate_mon_trans_output_or_raise(output)
  { program: output, effect_companions: schema.companions }
}

///|
fn lower_cps_top_term(
  schema : DictionaryCpsSchema,
  program : Program,
  term : TopTerm,
) -> TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      if facts.effect == Empty {
        let lowered = match expression {
          Function(_) | TypeLambda(_, _) =>
            lower_cps_recursable(
              schema,
              program,
              expression,
              Some(value_type(program.metadata, id)),
            )
          _ => lower_cps_direct_expr(schema, program, expression, None)
        }
        Let(id, lowered)
      } else {
        raise UnsupportedTopLevelEffect(facts.effect)
      }
    }
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(
            schema,
            program,
            binding.rhs,
            Some(value_type(program.metadata, binding.id)),
          ),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn lower_cps_recursable(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  expected_type : @buslane.Type?,
) -> Expr raise SynthesisError {
  match expression {
    TypeLambda(parameters, body) => {
      let expected_body = match expected_type {
        Some(Forall(_, body)) => Some(body)
        _ => None
      }
      TypeLambda(
        parameters.map(parameter => schema.companion_parameter(parameter)),
        lower_cps_recursable(schema, program, body, expected_body),
      )
    }
    Function(function) =>
      lower_cps_function(schema, program, function, expected_type)
    _ => lower_cps_direct_expr(schema, program, expression, None)
  }
}

///|
fn lower_cps_function(
  schema : DictionaryCpsSchema,
  program : Program,
  function : FunctionExpr,
  expected_type : @buslane.Type?,
) -> Expr raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(program.metadata, function.body)
  let latent_effect = match expected_type {
    Some(Function(_, _, effect)) => effect
    _ => body_facts.effect
  }
  let residual_effect = residual_effect_part(program.metadata, latent_effect)
  let result_type = schema.rewrite_type(function.result_type)
  if !is_mon_effect(program.metadata, latent_effect) {
    Function({
      parameters: function.parameters,
      result_type,
      body: lower_cps_direct_expr(schema, program, function.body, None),
    })
  } else {
    let answer_parameter = program.metadata.define_type_parameter(
      "%answer",
      Type,
    )
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    let context_terms = effect_terms(
      mon_effect_part(program.metadata, latent_effect),
    )
    let context_parameters = []
    let bindings = []
    for term in context_terms {
      let parameter = program.metadata.define_value(
        "%context",
        Parameter,
        schema.context_term_type(term, answer_type, residual_effect),
      )
      context_parameters.push(parameter)
      bindings.push({ term, value: Ref(parameter) })
    }
    let continuation = program.metadata.define_value(
      "%continuation",
      Parameter,
      Function([result_type], answer_type, residual_effect),
    )
    let environment = CpsEnvironment::{ effect: latent_effect, bindings }
    TypeLambda(
      [answer_parameter],
      Function({
        parameters: context_parameters + function.parameters + [continuation],
        result_type: answer_type,
        body: lower_cps_with_continuation(
          schema,
          program,
          function.body,
          environment,
          answer_type,
          Ref(continuation),
        ),
      }),
    )
  }
}

///|
fn lower_cps_direct_expr(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  current_answer : @buslane.Type?,
) -> Expr raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) => lower_cps_function(schema, program, function, None)
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(parameter => schema.companion_parameter(parameter)),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    Call(callee, arguments) => {
      if generated_cps_answer_type(program.metadata, callee) is Some(answer) {
        return Call(
          lower_cps_type_apply_chain(schema, program, callee, answer),
          arguments.map(argument => {
            lower_cps_direct_expr(schema, program, argument, Some(answer))
          }),
        )
      }
      let callee_facts = synthesize_cps_callee_or_raise(
        program.metadata,
        callee,
      )
      guard callee_facts.type_ is Function(_, source_result, latent_effect) else {
        raise ExpectedFunction(callee_facts.type_)
      }
      if is_mon_effect(program.metadata, latent_effect) {
        raise MissingEffectContext(latent_effect)
      }
      if source_result is Function(_, _, result_effect) &&
        is_mon_effect(program.metadata, result_effect) {
        return lower_cps_effectful_result_call(
          schema, program, callee, arguments, source_result,
        )
      }
      lower_cps_direct_call(
        program,
        lower_cps_direct_expr(schema, program, callee, current_answer),
        arguments.map(argument => {
          lower_cps_direct_expr(schema, program, argument, current_answer)
        }),
        schema.rewrite_type(source_result),
        empty_result_context_count(program.metadata, callee),
      )
    }
    TypeApply(_, _) =>
      lower_cps_type_apply_chain(
        schema,
        program,
        expression,
        answer_or_unit(current_answer),
      )
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments.map(argument => {
          schema.rewrite_generic_argument(argument)
        }),
        hidden_witnesses: construct.hidden_witnesses.map(argument => {
          schema.rewrite_generic_argument(argument)
        }),
        payloads: construct.payloads.map(payload => {
          lower_cps_direct_expr(schema, program, payload, current_answer)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        id,
        lower_cps_direct_expr(schema, program, initializer, current_answer),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(
            schema,
            program,
            binding.rhs,
            Some(value_type(program.metadata, binding.id)),
          ),
        }),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    Match(match_) =>
      Match({
        scrutinee: lower_cps_direct_expr(
          schema,
          program,
          match_.scrutinee,
          current_answer,
        ),
        binder: match_.binder,
        result_type: schema.rewrite_type(match_.result_type),
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders,
          value_binders: alternative.value_binders,
          body: lower_cps_direct_expr(
            schema,
            program,
            alternative.body,
            current_answer,
          ),
        }),
      })
    Invoke(invoke) =>
      Invoke({
        ..invoke,
        payloads: invoke.payloads.map(payload => {
          lower_cps_direct_expr(schema, program, payload, current_answer)
        }),
      })
    Install(install) => lower_cps_direct_install(schema, program, install)
    Bind(_) | OpenContext(_) => expression
  }
}

///|
fn lower_cps_effectful_result_call(
  schema : DictionaryCpsSchema,
  program : Program,
  callee : Expr,
  arguments : Array[Expr],
  source_result : @buslane.Type,
) -> Expr raise SynthesisError {
  guard source_result is Function(parameter_types, result_type, latent_effect) else {
    raise ExpectedFunction(source_result)
  }
  let bindings : Array[(@buslane.ValueId, Expr)] = []
  let lowered_arguments : Array[Expr] = []
  for argument in arguments {
    let lowered = lower_cps_direct_expr(schema, program, argument, None)
    match lowered {
      Ref(_) | Literal(_) => lowered_arguments.push(lowered)
      _ => {
        let facts = synthesize_expr_or_raise(program.metadata, argument)
        let binding = program.metadata.define_value(
          "%effectful_result_argument",
          Value,
          schema.rewrite_type(facts.type_),
        )
        bindings.push((binding, lowered))
        lowered_arguments.push(Ref(binding))
      }
    }
  }
  let answer_parameter = program.metadata.define_type_parameter("%answer", Type)
  let answer_type = @buslane.Type::Parameter(answer_parameter)
  let context_parameters = schema
    .context_argument_types(latent_effect, answer_type)
    .map(type_ => program.metadata.define_value("%context", Parameter, type_))
  let value_parameters = parameter_types.map(type_ => {
    program.metadata.define_value(
      "%effectful_result_parameter",
      Parameter,
      schema.rewrite_type(type_),
    )
  })
  let rewritten_result = schema.rewrite_type(result_type)
  let continuation = program.metadata.define_value(
    "%continuation",
    Parameter,
    Function([rewritten_result], answer_type, Empty),
  )
  let produced : Expr = Call(
    lower_cps_direct_expr(schema, program, callee, Some(answer_type)),
    lowered_arguments,
  )
  let expanded : Expr = TypeLambda(
    [answer_parameter],
    Function({
      parameters: context_parameters + value_parameters + [continuation],
      result_type: answer_type,
      body: Call(
        TypeApply(produced, [TypeArgument(answer_type)]),
        context_parameters.map(parameter => Ref(parameter)) +
        value_parameters.map(parameter => Ref(parameter)) +
        [Ref(continuation)],
      ),
    }),
  )
  let mut result = expanded
  for binding in bindings.rev_iter() {
    result = Let(binding.0, binding.1, result)
  }
  result
}

///|
fn lower_cps_direct_call(
  program : Program,
  callee : Expr,
  arguments : Array[Expr],
  result_type : @buslane.Type,
  empty_context_count : Int,
) -> Expr raise SynthesisError {
  if empty_context_count > 0 {
    return build_empty_context_direct_call(
      program, callee, arguments, result_type, empty_context_count,
    )
  }
  let callee_type = synthesize_expr_or_raise(program.metadata, callee).type_
  match callee_type {
    Function(_, _, _) => Call(callee, arguments)
    Forall(
      [answer_parameter],
      Function(parameters, Parameter(result_parameter), Empty)
    ) if answer_parameter == result_parameter => {
      let non_context_count = arguments.length() + 1
      if parameters.length() < non_context_count {
        raise ArityMismatch(
          expected=non_context_count,
          actual=parameters.length(),
        )
      }
      let context_count = parameters.length() - non_context_count
      for index in 0..<context_count {
        if parameters[index] != Primitive(Unit) {
          raise ExpectedFunction(callee_type)
        }
      }
      guard parameters.last()
        is Some(
          Function([continuation_input], Parameter(continuation_result), Empty)
        ) &&
        continuation_input == result_type &&
        continuation_result == answer_parameter else {
        raise ExpectedFunction(callee_type)
      }
      build_empty_context_direct_call(
        program, callee, arguments, result_type, context_count,
      )
    }
    _ => raise ExpectedFunction(callee_type)
  }
}

///|
fn build_empty_context_direct_call(
  program : Program,
  callee : Expr,
  arguments : Array[Expr],
  result_type : @buslane.Type,
  context_count : Int,
) -> Expr {
  let continuation_parameter = program.metadata.define_value(
    "%direct_result",
    Parameter,
    result_type,
  )
  let call_arguments : Array[Expr] = []
  for _index in 0..<context_count {
    call_arguments.push(Literal(Unit))
  }
  call_arguments.append(arguments)
  call_arguments.push(
    Function({
      parameters: [continuation_parameter],
      result_type,
      body: Ref(continuation_parameter),
    }),
  )
  Call(TypeApply(callee, [TypeArgument(result_type)]), call_arguments)
}

///|
fn empty_result_context_count(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Int raise SynthesisError {
  guard expression is Call(callee, _) else { return 0 }
  let argument_groups = []
  let base = collect_cps_type_applications(callee, argument_groups)
  let parameters = []
  let terminal_type = collect_cps_forall_parameters(
    synthesize_expr_or_raise(metadata, base).type_,
    parameters,
  )
  let arguments = []
  for group in argument_groups {
    arguments.append(group)
  }
  if arguments.length() < parameters.length() {
    raise ArityMismatch(expected=parameters.length(), actual=arguments.length())
  }
  guard terminal_type is Function(_, result_type, _) else { return 0 }
  guard source_callable_effect(result_type) is Some(result_effect) else {
    return 0
  }
  let mut count = 0
  for term in effect_terms(result_effect) {
    if term is Parameter(parameter) &&
      applied_empty_effect_argument(parameters, arguments, parameter) {
      count += 1
    }
  }
  count
}

///|
fn source_callable_effect(type_ : @buslane.Type) -> @buslane.Effect? {
  match type_ {
    Forall(_, body) => source_callable_effect(body)
    Function(_, _, effect) => Some(effect)
    _ => None
  }
}

///|
fn applied_empty_effect_argument(
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  parameter : @buslane.TypeParameterId,
) -> Bool {
  for index in 0..<parameters.length() {
    if parameters[index] == parameter {
      return arguments[index] is EffectArgument(Empty)
    }
  }
  false
}

///|
fn lower_cps_with_continuation(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  match expression {
    Let(id, initializer, body) => {
      let initializer_facts = synthesize_expr_or_raise(
        program.metadata,
        initializer,
      )
      if !is_mon_effect(program.metadata, initializer_facts.effect) {
        Let(
          id,
          lower_cps_direct_expr(schema, program, initializer, Some(answer_type)),
          lower_cps_with_continuation(
            schema, program, body, environment, answer_type, continuation,
          ),
        )
      } else {
        lower_cps_residual_bind(
          schema, program, expression, environment, answer_type, continuation,
        )
      }
    }
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(
            schema,
            program,
            binding.rhs,
            Some(value_type(program.metadata, binding.id)),
          ),
        }),
        lower_cps_with_continuation(
          schema, program, body, environment, answer_type, continuation,
        ),
      )
    Bind(bind) => {
      let next = Expr::Function({
        parameters: [bind.binder],
        result_type: answer_type,
        body: lower_cps_with_continuation(
          schema,
          program,
          bind.continuation.body,
          environment,
          answer_type,
          continuation,
        ),
      })
      lower_cps_computation(
        schema,
        program,
        bind.computation,
        environment,
        answer_type,
        next,
        Some(bind.binder),
      )
    }
    Call(callee, arguments) => {
      if generated_cps_answer_type(program.metadata, callee) is Some(_) {
        return Call(continuation, [
          lower_cps_direct_expr(
            schema,
            program,
            Call(callee, arguments),
            Some(answer_type),
          ),
        ])
      }
      let callee_facts = synthesize_cps_callee_or_raise(
        program.metadata,
        callee,
      )
      guard callee_facts.type_ is Function(_, _, latent_effect) else {
        raise ExpectedFunction(callee_facts.type_)
      }
      if !is_mon_effect(program.metadata, latent_effect) {
        Call(continuation, [
          lower_cps_direct_expr(
            schema,
            program,
            Call(callee, arguments),
            Some(answer_type),
          ),
        ])
      } else {
        lower_cps_monadic_call(
          schema, program, callee, arguments, environment, answer_type, continuation,
          latent_effect, false,
        )
      }
    }
    Match(match_) => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      if !is_mon_effect(program.metadata, facts.effect) {
        Call(continuation, [
          lower_cps_direct_expr(schema, program, expression, Some(answer_type)),
        ])
      } else {
        lower_cps_monadic_match(
          schema, program, match_, environment, answer_type, continuation,
        )
      }
    }
    OpenContext(open) =>
      match open.body {
        Call(callee, arguments) =>
          lower_cps_monadic_call(
            schema,
            program,
            callee,
            arguments,
            environment,
            answer_type,
            continuation,
            open.source_effect,
            true,
          )
        _ =>
          OpenContext({
            ..open,
            body: lower_cps_with_continuation(
              schema,
              program,
              open.body,
              environment,
              answer_type,
              continuation,
            ),
          })
      }
    Invoke(_) | Install(_) =>
      lower_cps_computation(
        schema,
        program,
        expression,
        environment,
        answer_type,
        continuation,
        None,
      )
    Ref(_)
    | Literal(_)
    | Function(_)
    | TypeLambda(_, _)
    | TypeApply(_, _)
    | Construct(_) =>
      Call(continuation, [
        lower_cps_direct_expr(schema, program, expression, Some(answer_type)),
      ])
  }
}
