///|
priv enum ContextRequirement {
  Direct(@buslane.Effect)
  Packed(@buslane.Effect)
}

///|
priv struct AppliedGenericArgument {
  parameter : @buslane.TypeParameterId
  argument : @buslane.GenericArgument
}

///|
priv struct SelectedContexts {
  values : Array[Expr]
  adapted : Bool
}

///|
fn generated_cps_answer(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> CpsAnswer? raise SynthesisError {
  let argument_groups = []
  let base = collect_cps_type_applications(expression, argument_groups)
  if argument_groups.is_empty() {
    return None
  }
  let parameters = []
  ignore(
    collect_cps_forall_parameters(
      synthesize_expr_or_raise(metadata, base).type_,
      parameters,
    ),
  )
  let arguments = []
  for group in argument_groups {
    arguments.append(group)
  }
  if arguments.length() <= parameters.length() {
    return None
  }
  // Arguments past the source binders are the ones this pass added: the answer
  // type and the residual it instantiated the callable at.
  let mut answer_type = None
  let mut residual = None
  let mut index = arguments.length()
  while index > parameters.length() {
    index -= 1
    match arguments[index] {
      TypeArgument(answer) if answer_type is None => answer_type = Some(answer)
      EffectArgument(effect) if residual is None => residual = Some(effect)
      _ => ()
    }
  }
  answer_type.map(type_ => { type_, residual: residual.unwrap_or(Empty) })
}

///|
fn lower_cps_type_apply_chain(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  answer : CpsAnswer,
) -> Expr raise SynthesisError {
  let argument_groups = []
  let base = collect_cps_type_applications(expression, argument_groups)
  let parameters = []
  ignore(
    collect_cps_forall_parameters(
      synthesize_expr_or_raise(program.metadata, base).type_,
      parameters,
    ),
  )
  let mut argument_count = 0
  for group in argument_groups {
    argument_count += group.length()
  }
  if argument_count < parameters.length() {
    raise ArityMismatch(expected=parameters.length(), actual=argument_count)
  }
  let mut result = lower_cps_direct_expr(schema, program, base, Some(answer))
  let mut parameter_index = 0
  for group in argument_groups {
    let rewritten_arguments = []
    for argument in group {
      if parameter_index < parameters.length() {
        rewritten_arguments.push(
          rewrite_cps_application_argument(
            schema,
            parameters[parameter_index],
            argument,
          ),
        )
        parameter_index += 1
      } else {
        rewritten_arguments.push(
          rewrite_cps_expression_argument(schema, argument),
        )
      }
    }
    result = TypeApply(result, rewritten_arguments)
  }
  result
}

///|
fn rewrite_cps_application_argument(
  schema : DictionaryCpsSchema,
  parameter : @buslane.TypeParameterId,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise SynthesisError {
  guard schema.metadata.type_parameter_info(parameter) is Some(info) else {
    return schema.rewrite_generic_argument(argument)
  }
  match (info.kind, argument) {
    (_, TypeArgument(type_)) => TypeArgument(schema.rewrite_type(type_))
    (_, EffectArgument(effect)) =>
      TypeArgument(schema.companion_context_argument(effect))
  }
}

///|
fn rewrite_cps_expression_argument(
  schema : DictionaryCpsSchema,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise SynthesisError {
  match argument {
    TypeArgument(type_) => TypeArgument(schema.rewrite_type(type_))
    EffectArgument(effect) =>
      TypeArgument(schema.companion_context_argument(effect))
  }
}

///|
fn cps_call_context_requirements(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
) -> Array[ContextRequirement] raise SynthesisError {
  let argument_groups = []
  let base = collect_cps_type_applications(callee, argument_groups)
  let base_type = synthesize_expr_or_raise(metadata, base).type_
  let parameters = []
  let terminal_type = collect_cps_forall_parameters(base_type, parameters)
  let arguments = []
  for group in argument_groups {
    for argument in group {
      arguments.push(argument)
    }
  }
  if arguments.length() < parameters.length() {
    raise ArityMismatch(expected=parameters.length(), actual=arguments.length())
  }
  let applied = []
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for index in 0..<parameters.length() {
    applied.push({ parameter: parameters[index], argument: arguments[index] })
    substitution.insert_argument(parameters[index], arguments[index])
  }
  guard terminal_type is Function(_, _, latent_effect) else {
    let actual = terminal_type.substitute(substitution)
    raise ExpectedFunction(actual)
  }
  effect_terms(metadata, mon_effect_part(metadata, latent_effect)).map(term => {
    match term {
      Parameter(parameter) =>
        match applied_effect_argument(applied, parameter) {
          Some(effect) =>
            Packed(substitute_cps_effect(metadata, effect, substitution))
          None => Direct(substitute_cps_effect(metadata, term, substitution))
        }
      _ => Direct(substitute_cps_effect(metadata, term, substitution))
    }
  })
}

///|
fn collect_cps_type_applications(
  expression : Expr,
  groups : Array[Array[@buslane.GenericArgument]],
) -> Expr {
  match expression {
    TypeApply(callee, arguments) => {
      let base = collect_cps_type_applications(callee, groups)
      groups.push(arguments)
      base
    }
    _ => expression
  }
}

///|
fn collect_cps_forall_parameters(
  type_ : @buslane.Type,
  parameters : Array[@buslane.TypeParameterId],
) -> @buslane.Type {
  match type_ {
    Forall(next, body) => {
      for parameter in next {
        parameters.push(parameter)
      }
      collect_cps_forall_parameters(body, parameters)
    }
    _ => type_
  }
}

///|
fn applied_effect_argument(
  applied : Array[AppliedGenericArgument],
  parameter : @buslane.TypeParameterId,
) -> @buslane.Effect? {
  for entry in applied {
    if entry.parameter == parameter {
      match entry.argument {
        EffectArgument(effect) => return Some(effect)
        _ => return None
      }
    }
  }
  None
}

///|
fn substitute_cps_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  substitution : @buslane.TypeSubstitution,
) -> @buslane.Effect {
  metadata.canonicalize_effect(effect.substitute(substitution))
}

///|
fn select_cps_contexts(
  schema : DictionaryCpsSchema,
  requirements : Array[ContextRequirement],
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> SelectedContexts raise SynthesisError {
  let values = []
  let mut adapted = false
  for requirement in requirements {
    match requirement {
      Direct(term) =>
        values.push(find_cps_context(schema.metadata, environment, term))
      Packed(effect) => {
        let packed = pack_cps_context(
          schema, environment, effect, answer_type, residual_effect,
        )
        values.push(packed.0)
        adapted = adapted || packed.1
      }
    }
  }
  { values, adapted }
}

///|
fn find_cps_context(
  metadata : @buslane.MetadataRegistry,
  environment : CpsEnvironment,
  term : @buslane.Effect,
) -> Expr raise SynthesisError {
  for binding in environment.bindings {
    if metadata.effects_definitionally_equal(binding.term, term) {
      return binding.value
    }
  }
  raise MissingEffectContext(term)
}

///|
fn pack_cps_context(
  schema : DictionaryCpsSchema,
  environment : CpsEnvironment,
  effect : @buslane.Effect,
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> (Expr, Bool) raise SynthesisError {
  let terms = effect_terms(
    schema.metadata,
    mon_effect_part(schema.metadata, effect),
  )
  let values = terms.map(term => {
    find_cps_context(schema.metadata, environment, term)
  })
  match values {
    [] => (Literal(Unit), true)
    [value] =>
      (value, !schema.metadata.effects_definitionally_equal(effect, terms[0]))
    values => {
      let pack = schema.context_pack(values.length())
      guard schema.metadata.type_info(pack.type_id) is Some(info) else {
        raise UnknownType(pack.type_id)
      }
      guard info.constructors is [data_constructor] else {
        raise UnknownType(pack.type_id)
      }
      (
        Construct({
          data_constructor,
          type_arguments: terms.map(term => {
            TypeArgument(
              schema.context_term_type(term, answer_type, residual_effect),
            )
          }),
          hidden_witnesses: [],
          payloads: values,
        }),
        true,
      )
    }
  }
}

///|
fn answer_or_unit(answer : CpsAnswer?) -> CpsAnswer {
  match answer {
    Some(answer) => answer
    None => { type_: Primitive(Unit), residual: Empty }
  }
}
