///|
/// A function-object identity mapping produced by the Program snapshot owner.
/// Side tables keyed by FunctionExpr identity consume this mapping instead of
/// rediscovering clone relationships from expression structure.
pub(all) struct FunctionClone {
  source : FunctionExpr
  target : FunctionExpr
}

///|
fn Program::snapshot_with_function_clones(
  self : Program,
) -> (Program, Array[FunctionClone]) {
  let function_clones = []
  let program : Program = {
    metadata: self.metadata.snapshot(),
    terms: self.terms.map(term => term.snapshot(function_clones)),
  }
  (program, function_clones)
}

///|
fn TopTerm::snapshot(
  self : TopTerm,
  function_clones : Array[FunctionClone],
) -> TopTerm {
  match self {
    Let(value, expression) => Let(value, expression.snapshot(function_clones))
    LetRec(bindings) =>
      LetRec(bindings.map(binding => binding.snapshot(function_clones)))
    External(_) => self
  }
}

///|
fn RecursiveBinding::snapshot(
  self : RecursiveBinding,
  function_clones : Array[FunctionClone],
) -> RecursiveBinding {
  { id: self.id, rhs: self.rhs.snapshot(function_clones), }
}

///|
fn Expr::snapshot(self : Expr, function_clones : Array[FunctionClone]) -> Expr {
  match self {
    Ref(_) | Literal(_) | Resume(_) => self
    Function(function) => Function(function.snapshot(function_clones))
    Call(callee, arguments) =>
      Call(
        callee.snapshot(function_clones),
        arguments.map(argument => argument.snapshot(function_clones)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters.copy(), body.snapshot(function_clones))
    TypeApply(callee, arguments) =>
      TypeApply(
        callee.snapshot(function_clones),
        arguments.map(argument => argument.snapshot()),
      )
    Construct(construct) => Construct(construct.snapshot(function_clones))
    Let(value, rhs, body) =>
      Let(value, rhs.snapshot(function_clones), body.snapshot(function_clones))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => binding.snapshot(function_clones)),
        body.snapshot(function_clones),
      )
    Match(match_) => Match(match_.snapshot(function_clones))
    Perform(perform) => Perform(perform.snapshot(function_clones))
    Handle(handle) => Handle(handle.snapshot(function_clones))
  }
}

///|
fn FunctionExpr::snapshot(
  self : FunctionExpr,
  function_clones : Array[FunctionClone],
) -> FunctionExpr {
  let target : FunctionExpr = {
    parameters: self.parameters.copy(),
    result_type: self.result_type.snapshot(),
    body: self.body.snapshot(function_clones),
  }
  function_clones.push({ source: self, target, })
  target
}

///|
fn ConstructExpr::snapshot(
  self : ConstructExpr,
  function_clones : Array[FunctionClone],
) -> ConstructExpr {
  {
    data_constructor: self.data_constructor,
    type_arguments: self.type_arguments.map(argument => argument.snapshot()),
    hidden_witnesses: self.hidden_witnesses.map(argument => argument.snapshot()),
    payloads: self.payloads.map(payload => payload.snapshot(function_clones)),
  }
}

///|
fn MatchExpr::snapshot(
  self : MatchExpr,
  function_clones : Array[FunctionClone],
) -> MatchExpr {
  {
    scrutinee: self.scrutinee.snapshot(function_clones),
    binder: self.binder,
    result_type: self.result_type.snapshot(),
    alternatives: self.alternatives.map(alternative => {
      alternative.snapshot(function_clones)
    }),
  }
}

///|
fn PerformExpr::snapshot(
  self : PerformExpr,
  function_clones : Array[FunctionClone],
) -> PerformExpr {
  {
    operation: self.operation,
    effect_arguments: self.effect_arguments.map(argument => argument.snapshot()),
    hidden_witnesses: self.hidden_witnesses.map(argument => argument.snapshot()),
    payloads: self.payloads.map(payload => payload.snapshot(function_clones)),
  }
}

///|
fn HandleExpr::snapshot(
  self : HandleExpr,
  function_clones : Array[FunctionClone],
) -> HandleExpr {
  {
    body: self.body.snapshot(function_clones),
    result_binder: self.result_binder,
    result_type: self.result_type.snapshot(),
    final_body: self.final_body.snapshot(function_clones),
    handlers: self.handlers.map(handler => handler.snapshot(function_clones)),
  }
}

///|
fn HandlerTable::snapshot(
  self : HandlerTable,
  function_clones : Array[FunctionClone],
) -> HandlerTable {
  {
    handled_effect: self.handled_effect.snapshot(),
    operations: self.operations.map(operation => {
      operation.snapshot(function_clones)
    }),
  }
}

///|
fn OperationAlternative::snapshot(
  self : OperationAlternative,
  function_clones : Array[FunctionClone],
) -> OperationAlternative {
  {
    operation: self.operation,
    type_binders: self.type_binders.copy(),
    payload_binders: self.payload_binders.copy(),
    resume_binder: self.resume_binder,
    body: self.body.snapshot(function_clones),
  }
}

///|
fn Alternative::snapshot(
  self : Alternative,
  function_clones : Array[FunctionClone],
) -> Alternative {
  {
    alt_constructor: self.alt_constructor,
    type_binders: self.type_binders.copy(),
    value_binders: self.value_binders.copy(),
    body: self.body.snapshot(function_clones),
  }
}

///|
fn Kind::snapshot(self : Kind) -> Kind {
  match self {
    Type | Effect => self
    Function(parameters, result) =>
      Function(
        parameters.map(parameter => parameter.snapshot()),
        result.snapshot(),
      )
  }
}

///|
fn Type::snapshot(self : Type) -> Type {
  match self {
    Primitive(_) | Parameter(_) | Constructor(_) => self
    Apply(callee, arguments) =>
      Apply(callee.snapshot(), arguments.map(argument => argument.snapshot()))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters.copy(), body.snapshot())
    Function(parameters, result, effect) =>
      Function(
        parameters.map(parameter => parameter.snapshot()),
        result.snapshot(),
        effect.snapshot(),
      )
    Forall(parameters, body) => Forall(parameters.copy(), body.snapshot())
  }
}

///|
fn Effect::snapshot(self : Effect) -> Effect {
  match self {
    Empty | Builtin(_) | Parameter(_) => self
    Singleton(owner, arguments) =>
      Singleton(owner, arguments.map(argument => argument.snapshot()))
    Union(effects) => Union(effects.map(effect => effect.snapshot()))
  }
}

///|
fn GenericArgument::snapshot(self : GenericArgument) -> GenericArgument {
  match self {
    TypeArgument(type_) => TypeArgument(type_.snapshot())
    EffectArgument(effect) => EffectArgument(effect.snapshot())
  }
}

///|
fn TypeInfo::snapshot(self : TypeInfo) -> TypeInfo {
  {
    name: self.name,
    flavor: self.flavor,
    parameters: self.parameters.copy(),
    constructors: self.constructors.copy(),
  }
}

///|
fn TypeParameterInfo::snapshot(self : TypeParameterInfo) -> TypeParameterInfo {
  { name: self.name, kind: self.kind.snapshot(), flavor: self.flavor, }
}

///|
fn ValueInfo::snapshot(self : ValueInfo) -> ValueInfo {
  { name: self.name, kind: self.kind, type_: self.type_.snapshot(), }
}

///|
fn DataConInfo::snapshot(self : DataConInfo) -> DataConInfo {
  {
    name: self.name,
    owner: self.owner,
    hidden_type_parameters: self.hidden_type_parameters.copy(),
    payload_types: self.payload_types.map(type_ => type_.snapshot()),
  }
}

///|
fn EffectInfo::snapshot(self : EffectInfo) -> EffectInfo {
  {
    name: self.name,
    flavor: self.flavor,
    parameters: self.parameters.copy(),
    operations: self.operations.copy(),
  }
}

///|
fn OperationInfo::snapshot(self : OperationInfo) -> OperationInfo {
  {
    name: self.name,
    owner: self.owner,
    hidden_type_parameters: self.hidden_type_parameters.copy(),
    payload_types: self.payload_types.map(type_ => type_.snapshot()),
    result_type: self.result_type.snapshot(),
  }
}
