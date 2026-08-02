///|
priv struct CpsContextBinding {
  term : @buslane.Effect
  value : Expr
}

///|
priv struct CpsEnvironment {
  effect : @buslane.Effect
  residual : @buslane.Effect
  bindings : Array[CpsContextBinding]
}

///|
/// What a CPS'd callable is instantiated at: the answer type and the residual
/// its dictionary and continuation run under.
///
/// The two travel together because a dictionary type mentions both, so a site
/// that knows one without the other cannot name the type it is handling.
priv struct CpsAnswer {
  type_ : @buslane.Type
  residual : @buslane.Effect
}

///|
fn CpsAnswer::arguments(self : CpsAnswer) -> Array[@buslane.GenericArgument] {
  [TypeArgument(self.type_), EffectArgument(self.residual)]
}

///|
fn CpsEnvironment::answer(
  self : CpsEnvironment,
  answer_type : @buslane.Type,
) -> CpsAnswer {
  { type_: answer_type, residual: self.residual }
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
  let source = Program::{
    metadata: program.metadata.snapshot(),
    terms: program.terms,
  }
  let declarations = @effect_lowering_core.collect_program_declarations(source)
  let schema = build_dictionary_cps_schema_or_raise(program.metadata)
  rewrite_cps_source_metadata(schema, declarations)
  let terms = source.terms.map(term => lower_cps_top_term(schema, source, term))
  let output = Program::{ metadata: program.metadata, terms }
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
      if program.metadata.effects_definitionally_equal(facts.effect, Empty) {
        let lowered = lower_cps_binding_initializer(
          schema,
          program,
          id,
          expression,
          None,
        )
        Let(id, lowered)
      } else {
        raise UnsupportedTopLevelEffect(facts.effect)
      }
    }
    LetRec(bindings) =>
      LetRec(lower_cps_recursive_bindings(schema, program, bindings))
    External(id) => External(id)
  }
}

///|
fn lower_cps_binding_initializer(
  schema : DictionaryCpsSchema,
  program : Program,
  id : @buslane.ValueId,
  initializer : Expr,
  current_answer : CpsAnswer?,
) -> Expr raise SynthesisError {
  let lowered = match initializer {
    Function(_) | TypeLambda(_, _) =>
      lower_cps_recursable(
        schema,
        program,
        initializer,
        Some(value_type(program.metadata, id)),
        Some(value_type(schema.metadata, id)),
      )
    _ => lower_cps_direct_expr(schema, program, initializer, current_answer)
  }
  validate_cps_binding_type(schema.metadata, id, lowered)
  lowered
}

///|
fn lower_cps_recursive_bindings(
  schema : DictionaryCpsSchema,
  program : Program,
  bindings : Array[RecursiveBinding],
) -> Array[RecursiveBinding] raise SynthesisError {
  let lowered = bindings.map(binding => RecursiveBinding::{
    id: binding.id,
    rhs: lower_cps_recursable(
      schema,
      program,
      binding.rhs,
      Some(value_type(program.metadata, binding.id)),
      Some(value_type(schema.metadata, binding.id)),
    ),
  })
  validate_cps_recursive_binding_types(schema.metadata, lowered)
  lowered
}

///|
fn lower_cps_recursable(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  expected_type : @buslane.Type?,
  expected_cps_type : @buslane.Type?,
) -> Expr raise SynthesisError {
  match expression {
    TypeLambda(parameters, body) => {
      let expected_body = match expected_type {
        Some(Forall(_, body)) => Some(body)
        _ => None
      }
      let expected_cps_body = match expected_cps_type {
        Some(Forall(_, body)) => Some(body)
        _ => None
      }
      TypeLambda(
        schema.rewrite_cps_parameters(parameters),
        lower_cps_recursable(
          schema, program, body, expected_body, expected_cps_body,
        ),
      )
    }
    Function(function) =>
      lower_cps_function(
        schema, program, function, expected_type, expected_cps_type,
      )
    _ => lower_cps_direct_expr(schema, program, expression, None)
  }
}

///|
fn lower_cps_function(
  schema : DictionaryCpsSchema,
  program : Program,
  function : FunctionExpr,
  expected_type : @buslane.Type?,
  expected_cps_type : @buslane.Type?,
) -> Expr raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(program.metadata, function.body)
  let latent_effect = match expected_type {
    Some(Function(_, _, effect)) => effect
    _ => body_facts.effect
  }
  let result_type = schema.rewrite_type(function.result_type)
  if !is_mon_effect(program.metadata, latent_effect) {
    Function({
      parameters: function.parameters,
      result_type,
      body: lower_cps_direct_expr(schema, program, function.body, None),
    })
  } else {
    let (answer_parameter, residual_parameter) = match expected_cps_type {
      Some(
        Forall(
          [answer_parameter, residual_parameter],
          Function(_, Parameter(result_parameter), _)
        )
      ) if answer_parameter == result_parameter =>
        (answer_parameter, residual_parameter)
      Some(type_) => raise ExpectedForall(type_)
      None =>
        (
          schema.metadata.define_type_parameter("%answer", Type),
          schema.metadata.define_type_parameter(
            "%residual",
            Effect,
            flavor=External,
          ),
        )
    }
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    let residual_effect = schema.cps_residual_effect(
      latent_effect,
      Parameter(residual_parameter),
    )
    let context_terms = effect_terms(
      program.metadata,
      mon_effect_part(program.metadata, latent_effect),
    )
    let context_parameters = []
    let bindings = []
    for term in context_terms {
      let parameter = schema.metadata.define_value(
        "%context",
        Parameter,
        schema.context_term_type(term, answer_type, residual_effect),
      )
      context_parameters.push(parameter)
      bindings.push({ term, value: Ref(parameter) })
    }
    let continuation = schema.metadata.define_value(
      "%continuation",
      Parameter,
      Function([result_type], answer_type, residual_effect),
    )
    let environment = CpsEnvironment::{
      effect: latent_effect,
      residual: residual_effect,
      bindings,
    }
    TypeLambda(
      [answer_parameter, residual_parameter],
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
  current_answer : CpsAnswer?,
) -> Expr raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) =>
      lower_cps_function(schema, program, function, None, None)
    TypeLambda(parameters, body) =>
      TypeLambda(
        schema.rewrite_cps_parameters(parameters),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    Call(callee, arguments) => {
      if generated_cps_answer(program.metadata, callee) is Some(answer) {
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
      let lowered_callee = lower_cps_direct_expr(
        schema, program, callee, current_answer,
      )
      lower_cps_direct_call(
        schema.metadata,
        lowered_callee,
        lower_cps_call_arguments(
          schema, program, arguments, lowered_callee, current_answer,
        ),
        schema.rewrite_type(source_result),
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
    Let(id, initializer, body) => {
      let lowered_initializer = lower_cps_binding_initializer(
        schema, program, id, initializer, current_answer,
      )
      Let(
        id,
        lowered_initializer,
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    }
    LetRec(bindings, body) => {
      let lowered = lower_cps_recursive_bindings(schema, program, bindings)
      LetRec(
        lowered,
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    }
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
    // Both mark a monadic computation, so the function around them is CPS'd and
    // they are reached through `lower_cps_with_continuation`. Arriving here
    // means something upstream is wrong, and passing the subtree through
    // unlowered would turn that into wrong output.
    Bind(bind) =>
      raise MissingEffectContext(
        synthesize_expr_or_raise(program.metadata, bind.computation).effect,
      )
    OpenContext(open) => raise MissingEffectContext(open.source_effect)
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
  let answer_parameter = schema.metadata.define_type_parameter("%answer", Type)
  let residual_parameter = schema.metadata.define_type_parameter(
    "%residual",
    Effect,
    flavor=External,
  )
  let answer_type = @buslane.Type::Parameter(answer_parameter)
  let residual_effect = schema.cps_residual_effect(
    latent_effect,
    Parameter(residual_parameter),
  )
  let answer = CpsAnswer::{ type_: answer_type, residual: residual_effect }
  let lowered_callee = lower_cps_direct_expr(
    schema,
    program,
    callee,
    Some(answer),
  )
  let bindings : Array[(@buslane.ValueId, Expr)] = []
  let lowered_arguments : Array[Expr] = []
  for
    lowered in lower_cps_call_arguments(
      schema,
      program,
      arguments,
      lowered_callee,
      Some(answer),
    ) {
    match lowered {
      Ref(_) | Literal(_) => lowered_arguments.push(lowered)
      _ => {
        let binding = schema.metadata.define_value(
          "%effectful_result_argument",
          Value,
          synthesize_expr_or_raise(schema.metadata, lowered).type_,
        )
        bindings.push((binding, lowered))
        lowered_arguments.push(Ref(binding))
      }
    }
  }
  let context_parameters = schema
    .context_argument_types(latent_effect, answer_type, residual_effect)
    .map(type_ => schema.metadata.define_value("%context", Parameter, type_))
  let value_parameters = parameter_types.map(type_ => {
    schema.metadata.define_value(
      "%effectful_result_parameter",
      Parameter,
      schema.rewrite_type(type_),
    )
  })
  let rewritten_result = schema.rewrite_type(result_type)
  let continuation = schema.metadata.define_value(
    "%continuation",
    Parameter,
    Function([rewritten_result], answer_type, residual_effect),
  )
  let produced : Expr = Call(lowered_callee, lowered_arguments)
  let expanded : Expr = TypeLambda(
    [answer_parameter, residual_parameter],
    Function({
      parameters: context_parameters + value_parameters + [continuation],
      result_type: answer_type,
      body: Call(
        TypeApply(produced, answer.arguments()),
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
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
  arguments : Array[Expr],
  result_type : @buslane.Type,
) -> Expr raise SynthesisError {
  let callee_type = synthesize_expr_or_raise(metadata, callee).type_
  match callee_type {
    Function(_, _, _) => Call(callee, arguments)
    Forall(
      [answer_parameter, residual_parameter],
      Function(parameters, Parameter(result_parameter), latent_effect)
    ) if answer_parameter == result_parameter => {
      guard metadata.type_parameter_info(residual_parameter) is Some(info) &&
        info.kind is Effect &&
        info.flavor is External &&
        effect_terms(metadata, latent_effect).any(term => {
          term is Parameter(bound) && bound == residual_parameter
        }) else {
        raise ExpectedFunction(callee_type)
      }
      let non_context_count = arguments.length() + 1
      if parameters.length() < non_context_count {
        raise ArityMismatch(
          expected=non_context_count,
          actual=parameters.length(),
        )
      }
      let context_count = parameters.length() - non_context_count
      for index in 0..<context_count {
        if !metadata.types_definitionally_equal(
            parameters[index],
            Primitive(Unit),
          ) {
          raise ExpectedFunction(callee_type)
        }
      }
      guard parameters.last()
        is Some(
          Function(
            [continuation_input],
            Parameter(continuation_result),
            continuation_effect
          )
        ) &&
        metadata.types_definitionally_equal(continuation_input, result_type) &&
        continuation_result == answer_parameter &&
        metadata.effects_definitionally_equal(
          continuation_effect, latent_effect,
        ) else {
        raise ExpectedFunction(callee_type)
      }
      build_empty_context_direct_call(
        metadata, callee, arguments, result_type, context_count,
      )
    }
    _ => raise ExpectedFunction(callee_type)
  }
}

///|
fn build_empty_context_direct_call(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
  arguments : Array[Expr],
  result_type : @buslane.Type,
  context_count : Int,
) -> Expr {
  // The local residual is empty because the identity continuation performs
  // nothing. Any residual owned by the source callable stays in its CPS type.
  let continuation_parameter = metadata.define_value(
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
  // Reaching here means every context the callee wants is absent, so the
  // identity continuation this hands it performs nothing and the callee is
  // instantiated at the empty residual.
  Call(
    TypeApply(callee, [TypeArgument(result_type), EffectArgument(Empty)]),
    call_arguments,
  )
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
        let lowered_initializer = lower_cps_binding_initializer(
          schema,
          program,
          id,
          initializer,
          Some(environment.answer(answer_type)),
        )
        Let(
          id,
          lowered_initializer,
          lower_cps_with_continuation(
            schema, program, body, environment, answer_type, continuation,
          ),
        )
      } else {
        lower_cps_monadic_let(
          schema, program, expression, environment, answer_type, continuation,
        )
      }
    }
    LetRec(bindings, body) => {
      let lowered = lower_cps_recursive_bindings(schema, program, bindings)
      LetRec(
        lowered,
        lower_cps_with_continuation(
          schema, program, body, environment, answer_type, continuation,
        ),
      )
    }
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
      if generated_cps_answer(program.metadata, callee) is Some(_) {
        return Call(continuation, [
          lower_cps_direct_expr(
            schema,
            program,
            Call(callee, arguments),
            Some(environment.answer(answer_type)),
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
            Some(environment.answer(answer_type)),
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
          lower_cps_direct_expr(
            schema,
            program,
            expression,
            Some(environment.answer(answer_type)),
          ),
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
        lower_cps_direct_expr(
          schema,
          program,
          expression,
          Some(environment.answer(answer_type)),
        ),
      ])
  }
}
