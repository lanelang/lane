///|
pub(all) struct ExprFacts {
  type_ : @buslane.Type
  effect : @buslane.Effect
} derive(Debug, Eq)

///|
pub(all) suberror SynthesisError {
  UnknownValue(@buslane.ValueId)
  UnknownType(@buslane.TypeId)
  UnknownDataConstructor(@buslane.DataConId)
  UnknownEffect(@buslane.EffectId)
  UnknownOperation(@buslane.OperationId)
  ExpectedFunction(@buslane.Type)
  ExpectedForall(@buslane.Type)
  ArityMismatch(expected~ : Int, actual~ : Int)
  EffectfulTypeLambda(@buslane.Effect)
  EffectfulRecursiveBinding(@buslane.ValueId, @buslane.Effect)
  MissingEffectContext(@buslane.Effect)
  MissingOperationClause(@buslane.OperationId)
  UnsupportedTopLevelEffect(@buslane.Effect)
} derive(Debug, Eq)

///|
pub fn synthesize_expr(
  program : Program,
  expression : Expr,
) -> Result[ExprFacts, SynthesisError] {
  Ok(synthesize_expr_or_raise(program.metadata, expression)) catch {
    error => Err(error)
  }
}

///|
fn synthesize_expr_or_raise(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> ExprFacts raise SynthesisError {
  match expression {
    Ref(id) => pure_facts(value_type(metadata, id))
    Literal(literal) => pure_facts(literal_type(literal))
    Function(function) => synthesize_function(metadata, function)
    Call(callee, arguments) => synthesize_call(metadata, callee, arguments)
    TypeLambda(parameters, body) => {
      let body_facts = synthesize_expr_or_raise(metadata, body)
      if body_facts.effect != Empty {
        raise EffectfulTypeLambda(body_facts.effect)
      }
      pure_facts(Forall(parameters, body_facts.type_))
    }
    TypeApply(callee, arguments) =>
      synthesize_type_apply(metadata, callee, arguments)
    Construct(construct) => synthesize_construct(metadata, construct)
    Let(_, initializer, body) => {
      let initializer_facts = synthesize_expr_or_raise(metadata, initializer)
      let body_facts = synthesize_expr_or_raise(metadata, body)
      {
        type_: body_facts.type_,
        effect: effect_union([initializer_facts.effect, body_facts.effect]),
      }
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        let rhs_facts = synthesize_expr_or_raise(metadata, binding.rhs)
        if rhs_facts.effect != Empty {
          raise EffectfulRecursiveBinding(binding.id, rhs_facts.effect)
        }
      }
      synthesize_expr_or_raise(metadata, body)
    }
    Match(match_) => {
      let effects = [
        synthesize_expr_or_raise(metadata, match_.scrutinee).effect,
      ]
      for alternative in match_.alternatives {
        effects.push(
          synthesize_expr_or_raise(metadata, alternative.body).effect,
        )
      }
      { type_: match_.result_type, effect: effect_union(effects) }
    }
    Invoke(invoke) => synthesize_invoke(metadata, invoke)
    Install(install) => synthesize_install(metadata, install)
    Bind(bind) => {
      let computation_facts = synthesize_expr_or_raise(
        metadata,
        bind.computation,
      )
      let continuation_facts = synthesize_function(metadata, bind.continuation)
      guard continuation_facts.type_ is Function(_, result_type, latent_effect) else {
        raise ExpectedFunction(continuation_facts.type_)
      }
      {
        type_: result_type,
        effect: effect_union([computation_facts.effect, latent_effect]),
      }
    }
    OpenContext(open) => synthesize_expr_or_raise(metadata, open.body)
  }
}

///|
fn synthesize_function(
  metadata : @buslane.MetadataRegistry,
  function : FunctionExpr,
) -> ExprFacts raise SynthesisError {
  let parameter_types = function.parameters.map(id => value_type(metadata, id))
  let body_facts = synthesize_expr_or_raise(metadata, function.body)
  pure_facts(Function(parameter_types, function.result_type, body_facts.effect))
}

///|
fn synthesize_call(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
  arguments : Array[Expr],
) -> ExprFacts raise SynthesisError {
  let callee_facts = synthesize_expr_or_raise(metadata, callee)
  guard callee_facts.type_ is Function(parameters, result, latent_effect) else {
    raise ExpectedFunction(callee_facts.type_)
  }
  require_arity(parameters.length(), arguments.length())
  let effects = [callee_facts.effect]
  for argument in arguments {
    effects.push(synthesize_expr_or_raise(metadata, argument).effect)
  }
  effects.push(latent_effect)
  { type_: result, effect: effect_union(effects) }
}

///|
fn synthesize_type_apply(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
  arguments : Array[@buslane.GenericArgument],
) -> ExprFacts raise SynthesisError {
  let callee_facts = synthesize_expr_or_raise(metadata, callee)
  guard callee_facts.type_ is Forall(parameters, body) else {
    raise ExpectedForall(callee_facts.type_)
  }
  require_arity(parameters.length(), arguments.length())
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for index in 0..<parameters.length() {
    substitution.insert_argument(parameters[index], arguments[index])
  }
  { type_: body.substitute(substitution), effect: callee_facts.effect }
}

///|
fn synthesize_construct(
  metadata : @buslane.MetadataRegistry,
  construct : ConstructExpr,
) -> ExprFacts raise SynthesisError {
  guard metadata.data_constructor_info(construct.data_constructor) is Some(info) else {
    raise UnknownDataConstructor(construct.data_constructor)
  }
  guard metadata.type_info(info.owner) is Some(owner) else {
    raise UnknownType(info.owner)
  }
  require_arity(owner.parameters.length(), construct.type_arguments.length())
  require_arity(
    info.hidden_type_parameters.length(),
    construct.hidden_witnesses.length(),
  )
  require_arity(info.payload_types.length(), construct.payloads.length())
  let effects = construct.payloads.map(payload => {
    synthesize_expr_or_raise(metadata, payload).effect
  })
  {
    type_: nominal_type(info.owner, construct.type_arguments),
    effect: effect_union(effects),
  }
}

///|
fn synthesize_invoke(
  metadata : @buslane.MetadataRegistry,
  invoke : InvokeExpr,
) -> ExprFacts raise SynthesisError {
  guard metadata.operation_info(invoke.operation) is Some(info) else {
    raise UnknownOperation(invoke.operation)
  }
  guard metadata.effect_info(info.owner) is Some(owner) else {
    raise UnknownEffect(info.owner)
  }
  require_arity(owner.parameters.length(), invoke.effect_arguments.length())
  require_arity(
    info.hidden_type_parameters.length(),
    invoke.hidden_witnesses.length(),
  )
  require_arity(info.payload_types.length(), invoke.payloads.length())
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for index in 0..<owner.parameters.length() {
    substitution.insert_argument(
      owner.parameters[index],
      invoke.effect_arguments[index],
    )
  }
  for index in 0..<info.hidden_type_parameters.length() {
    substitution.insert_argument(
      info.hidden_type_parameters[index],
      invoke.hidden_witnesses[index],
    )
  }
  let effects = invoke.payloads.map(payload => {
    synthesize_expr_or_raise(metadata, payload).effect
  })
  effects.push(Singleton(info.owner, invoke.effect_arguments))
  {
    type_: info.result_type.substitute(substitution),
    effect: effect_union(effects),
  }
}

///|
fn synthesize_install(
  metadata : @buslane.MetadataRegistry,
  install : InstallExpr,
) -> ExprFacts raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(metadata, install.body)
  let handled = install.dictionaries.map(dictionary => dictionary.handled_effect)
  let effects = [remove_handled_effects(body_facts.effect, handled)]
  let final_facts = synthesize_function(metadata, install.final_clause)
  effects.push(callable_latent_effect(final_facts.type_))
  for dictionary in install.dictionaries {
    for operation in dictionary.operations {
      effects.push(
        callable_latent_effect(
          synthesize_clause_callable(metadata, operation.callable),
        ),
      )
    }
  }
  { type_: install.result_type, effect: effect_union(effects) }
}

///|
fn synthesize_clause_callable(
  metadata : @buslane.MetadataRegistry,
  callable : ClauseCallable,
) -> @buslane.Type raise SynthesisError {
  match callable {
    Monomorphic(function) => synthesize_function(metadata, function).type_
    Polymorphic(parameters, function) =>
      Forall(parameters, synthesize_function(metadata, function).type_)
  }
}

///|
fn callable_latent_effect(
  type_ : @buslane.Type,
) -> @buslane.Effect raise SynthesisError {
  match type_ {
    Function(_, _, effect) => effect
    Forall(_, body) => callable_latent_effect(body)
    _ => raise ExpectedFunction(type_)
  }
}

///|
fn value_type(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
) -> @buslane.Type raise SynthesisError {
  guard metadata.value_info(id) is Some(info) else { raise UnknownValue(id) }
  info.type_
}

///|
fn literal_type(literal : @buslane.Literal) -> @buslane.Type {
  match literal {
    Unit => Primitive(Unit)
    Bool(_) => Primitive(Bool)
    Int(_) => Primitive(Int)
    Double(_) => Primitive(Double)
    String(_) => Primitive(String)
  }
}

///|
fn nominal_type(
  owner : @buslane.TypeId,
  arguments : Array[@buslane.GenericArgument],
) -> @buslane.Type {
  if arguments.is_empty() {
    Constructor(owner)
  } else {
    Apply(Constructor(owner), arguments)
  }
}

///|
fn pure_facts(type_ : @buslane.Type) -> ExprFacts {
  { type_, effect: Empty }
}

///|
fn effect_union(effects : Array[@buslane.Effect]) -> @buslane.Effect {
  @buslane.Effect::Union(effects).canonicalize()
}

///|
fn effect_terms(effect : @buslane.Effect) -> Array[@buslane.Effect] {
  match effect.canonicalize() {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn remove_handled_effects(
  effect : @buslane.Effect,
  handled : Array[@buslane.Effect],
) -> @buslane.Effect {
  effect_union(
    effect_terms(effect).filter(term => {
      !handled.any(handled_effect => term == handled_effect)
    }),
  )
}

///|
fn require_arity(expected : Int, actual : Int) -> Unit raise SynthesisError {
  if expected != actual {
    raise ArityMismatch(expected~, actual~)
  }
}
