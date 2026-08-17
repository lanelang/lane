///|
priv struct ExprFacts {
  type_ : @buslane.Type
  effect : @buslane.Effect
}

///|
fn[T] normalization_or_synthesis_defect(
  compute : () -> T raise @buslane.TypeNormalizationError,
) -> T raise SynthesisError {
  compute() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
pub(all) suberror SynthesisError {
  InvalidProgram(
    stage~ : EffectLoweringVerificationStage,
    result~ : @buslane.VerifyResult
  )
  TypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  MetadataAllocationCompilerDefect(@buslane.MetadataAllocationError)
  UnknownValue(@buslane.ValueId)
  UnknownType(@buslane.TypeId)
  UnknownTypeParameter(@buslane.TypeParameterId)
  UnknownDataConstructor(@buslane.DataConId)
  UnknownEffect(@buslane.EffectId)
  UnknownOperation(@buslane.OperationId)
  ExpectedFunction(@buslane.Type)
  ExpectedForall(@buslane.Type)
  ExpectedKindFunction(@buslane.Kind)
  ArityMismatch(expected~ : Int, actual~ : Int)
  EffectfulTypeLambda(@buslane.Effect)
  EffectfulRecursiveBinding(@buslane.ValueId, @buslane.Effect)
  MissingEffectContext(@buslane.Effect)
  MissingOperationClause(@buslane.OperationId)
  ResidualInvoke(@buslane.OperationId)
  ResidualInstall
  ResidualBind
  ResidualEffectParameter(@buslane.TypeParameterId)
  ResidualEffectArgument(@buslane.Effect)
  ResidualLatentEffect(@buslane.Effect)
  ConcreteOpenContext(source~ : @buslane.Effect, target~ : @buslane.Effect)
  ResidualOpenContext(source~ : @buslane.Effect, target~ : @buslane.Effect)
  UnsupportedTopLevelEffect(@buslane.Effect)
  BindingTypeMismatch(
    value~ : @buslane.ValueId,
    expected~ : @buslane.Type,
    actual~ : @buslane.Type
  )
} derive(Debug, Eq)

///|
fn define_synthetic_value(
  metadata : @buslane.MetadataRegistry,
  occurrence : String,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId raise SynthesisError {
  metadata.define_value(occurrence, kind, type_) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
}

///|
fn effects_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Effect,
  right : @buslane.Effect,
) -> Bool raise SynthesisError {
  normalization_or_synthesis_defect(() => {
    metadata.effects_definitionally_equal(left, right)
  })
}

///|
fn canonicalize_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect raise SynthesisError {
  normalization_or_synthesis_defect(() => metadata.canonicalize_effect(effect))
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
      if !effects_definitionally_equal(metadata, body_facts.effect, Empty) {
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
        effect: effect_union(metadata, [
          initializer_facts.effect,
          body_facts.effect,
        ]),
      }
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        let rhs_facts = synthesize_expr_or_raise(metadata, binding.rhs)
        if !effects_definitionally_equal(metadata, rhs_facts.effect, Empty) {
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
      { type_: match_.result_type, effect: effect_union(metadata, effects) }
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
        effect: effect_union(metadata, [computation_facts.effect, latent_effect]),
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
  if arguments.length() > parameters.length() &&
    !effects_definitionally_equal(metadata, latent_effect, Empty) {
    guard arguments.last() is Some(continuation) else {
      raise ArityMismatch(
        expected=parameters.length(),
        actual=arguments.length(),
      )
    }
    let continuation_facts = synthesize_expr_or_raise(metadata, continuation)
    guard continuation_facts.type_ is Function(_, answer, Empty) else {
      raise ExpectedFunction(continuation_facts.type_)
    }
    let effects = [callee_facts.effect]
    for argument in arguments {
      effects.push(synthesize_expr_or_raise(metadata, argument).effect)
    }
    return { type_: answer, effect: effect_union(metadata, effects) }
  }
  require_arity(parameters.length(), arguments.length())
  let effects = [callee_facts.effect]
  for argument in arguments {
    effects.push(synthesize_expr_or_raise(metadata, argument).effect)
  }
  effects.push(latent_effect)
  { type_: result, effect: effect_union(metadata, effects) }
}

///|
fn synthesize_type_apply(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
  arguments : Array[@buslane.GenericArgument],
) -> ExprFacts raise SynthesisError {
  let callee_facts = synthesize_expr_or_raise(metadata, callee)
  guard callee_facts.type_ is Forall(parameters, body) else {
    if callee_facts.type_ is Function(_, _, _) {
      return callee_facts
    }
    raise ExpectedForall(callee_facts.type_)
  }
  if arguments.length() < parameters.length() {
    raise ArityMismatch(expected=parameters.length(), actual=arguments.length())
  }
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
    effect: effect_union(metadata, effects),
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
    effect: effect_union(metadata, effects),
  }
}

///|
fn synthesize_install(
  metadata : @buslane.MetadataRegistry,
  install : InstallExpr,
) -> ExprFacts raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(metadata, install.body)
  let handled = install.dictionaries.map(dictionary => dictionary.handled_effect)
  let effects = [remove_handled_effects(metadata, body_facts.effect, handled)]
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
  { type_: install.result_type, effect: effect_union(metadata, effects) }
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
    I64(_) => Primitive(I64)
    I32(_) => Primitive(I32)
    Char(_) => Primitive(Char)
    F64(_) => Primitive(F64)
    F32(_) => Primitive(F32)
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
fn effect_union(
  metadata : @buslane.MetadataRegistry,
  effects : Array[@buslane.Effect],
) -> @buslane.Effect raise SynthesisError {
  canonicalize_effect(metadata, Union(effects))
}

///|
fn effect_terms(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Array[@buslane.Effect] raise SynthesisError {
  match canonicalize_effect(metadata, effect) {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn remove_handled_effects(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  handled : Array[@buslane.Effect],
) -> @buslane.Effect raise SynthesisError {
  effect_union(
    metadata,
    effect_terms(metadata, effect).filter(term => {
      let mut is_handled = false
      for handled_effect in handled {
        if effects_definitionally_equal(metadata, term, handled_effect) {
          is_handled = true
          break
        }
      }
      !is_handled
    }),
  )
}

///|
fn require_arity(expected : Int, actual : Int) -> Unit raise SynthesisError {
  if expected != actual {
    raise ArityMismatch(expected~, actual~)
  }
}
