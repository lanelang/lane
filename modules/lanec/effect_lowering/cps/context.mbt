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
fn lower_cps_type_apply_chain(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  answer_type : @buslane.Type,
) -> Expr raise SynthesisError {
  match expression {
    TypeApply(callee, arguments) => {
      let callee_facts = synthesize_expr_or_raise(program.metadata, callee)
      guard callee_facts.type_ is Forall(parameters, _) else {
        raise ExpectedForall(callee_facts.type_)
      }
      require_arity(parameters.length(), arguments.length())
      let rewritten_arguments = []
      for index in 0..<arguments.length() {
        rewritten_arguments.push(
          rewrite_cps_application_argument(
            schema,
            parameters[index],
            arguments[index],
            answer_type,
          ),
        )
      }
      TypeApply(
        lower_cps_type_apply_chain(schema, program, callee, answer_type),
        rewritten_arguments,
      )
    }
    _ => lower_cps_direct_expr(schema, program, expression, Some(answer_type))
  }
}

///|
fn rewrite_cps_application_argument(
  schema : DictionaryCpsSchema,
  parameter : @buslane.TypeParameterId,
  argument : @buslane.GenericArgument,
  answer_type : @buslane.Type,
) -> @buslane.GenericArgument raise SynthesisError {
  guard schema.metadata.type_parameter_info(parameter) is Some(info) else {
    return schema.rewrite_generic_argument(argument)
  }
  match (info.kind, argument) {
    (Effect, EffectArgument(effect)) =>
      TypeArgument(schema.packed_context_type(effect, answer_type))
    (_, TypeArgument(type_)) => TypeArgument(schema.rewrite_type(type_))
    (_, EffectArgument(effect)) =>
      TypeArgument(schema.packed_context_type(effect, answer_type))
  }
}

///|
fn rewrite_cps_expression_argument(
  schema : DictionaryCpsSchema,
  argument : @buslane.GenericArgument,
  current_answer : @buslane.Type?,
) -> @buslane.GenericArgument raise SynthesisError {
  match argument {
    TypeArgument(type_) => TypeArgument(schema.rewrite_type(type_))
    EffectArgument(effect) =>
      TypeArgument(
        schema.packed_context_type(effect, answer_or_unit(current_answer)),
      )
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
  require_arity(parameters.length(), arguments.length())
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
  effect_terms(latent_effect).map(term => {
    match term {
      Parameter(parameter) =>
        match applied_effect_argument(applied, parameter) {
          Some(effect) => Packed(substitute_cps_effect(effect, substitution))
          None => Direct(substitute_cps_effect(term, substitution))
        }
      _ => Direct(substitute_cps_effect(term, substitution))
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
  effect : @buslane.Effect,
  substitution : @buslane.TypeSubstitution,
) -> @buslane.Effect {
  guard @buslane.Type::Function([], Primitive(Unit), effect).substitute(
      substitution,
    )
    is Function(_, _, substituted) else {
    abort("effect substitution must preserve function type")
  }
  substituted.canonicalize()
}

///|
fn select_cps_contexts(
  schema : DictionaryCpsSchema,
  requirements : Array[ContextRequirement],
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
) -> SelectedContexts raise SynthesisError {
  let values = []
  let mut adapted = false
  for requirement in requirements {
    match requirement {
      Direct(term) => values.push(find_cps_context(environment, term))
      Packed(effect) => {
        let packed = pack_cps_context(schema, environment, effect, answer_type)
        values.push(packed.0)
        adapted = adapted || packed.1
      }
    }
  }
  { values, adapted }
}

///|
fn find_cps_context(
  environment : CpsEnvironment,
  term : @buslane.Effect,
) -> Expr raise SynthesisError {
  for binding in environment.bindings {
    if binding.term == term {
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
) -> (Expr, Bool) raise SynthesisError {
  let terms = effect_terms(effect)
  let values = terms.map(term => find_cps_context(environment, term))
  match values {
    [] => (Literal(Unit), true)
    [value] => (value, effect.canonicalize() != terms[0])
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
            TypeArgument(schema.context_term_type(term, answer_type))
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
fn answer_or_unit(answer : @buslane.Type?) -> @buslane.Type {
  match answer {
    Some(answer) => answer
    None => Primitive(Unit)
  }
}
