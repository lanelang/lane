///|
pub(all) struct VerifyDiagnostic {
  kind : VerifyDiagnosticKind
} derive(Debug, Eq)

///|
pub(all) enum VerifyDiagnosticKind {
  UnknownType(TypeId)
  UnknownTypeParameter(TypeParameterId)
  UnknownValue(ValueId)
  UnknownDataConstructor(DataConId)
  UnknownEffect(EffectId)
  UnknownOperation(OperationId)
  KindMismatch(expected~ : Kind, actual~ : Kind)
  TypeMismatch(expected~ : Type, actual~ : Type)
  EffectMismatch(expected~ : Effect, actual~ : Effect)
  NotFunction(Type)
  NotForall(Type)
  ArityMismatch(expected~ : Int, actual~ : Int)
  InvalidExternal(ValueId)
  InvalidLetRecRhs(ValueId)
  InvalidAlternativeBinderCount
  DuplicateDefaultAlternative
  DefaultAlternativeNotLast
  DuplicateAlternative
  NonExhaustiveMatch
} derive(Debug, Eq)

///|
pub struct VerifyResult {
  diagnostics : Array[VerifyDiagnostic]
} derive(Debug, Eq)

///|
priv struct VerifyContext {
  program : Program
  diagnostics : Array[VerifyDiagnostic]
}

///|
priv struct ValueScope {
  values : Array[ValueId]
}

///|
priv struct TypeScope {
  parameters : Array[TypeParameterId]
}

///|
priv struct SynthesizedExpr {
  type_ : Type
  effect : Effect
}

///|
/// Verifies a complete Buslane program.
pub fn verify_program(program : Program) -> VerifyResult {
  let context = VerifyContext::{ program, diagnostics: [] }
  context.verify_metadata()
  context.verify_terms()
  { diagnostics: context.diagnostics }
}

///|
/// Returns whether verification completed without diagnostics.
pub fn VerifyResult::is_ok(self : VerifyResult) -> Bool {
  self.diagnostics.is_empty()
}

///|
fn VerifyContext::report(
  self : VerifyContext,
  kind : VerifyDiagnosticKind,
) -> Unit {
  self.diagnostics.push({ kind, })
}

///|
fn VerifyContext::verify_metadata(self : VerifyContext) -> Unit {
  for type_info in self.program.metadata.types {
    for parameter in type_info.parameters {
      self.require_type_parameter(parameter)
    }
    for data_constructor in type_info.constructors {
      self.require_data_constructor(data_constructor)
    }
  }
  for value in self.program.metadata.values {
    if value.kind.has_closed_metadata_type() {
      self.verify_value_type(value.type_, { parameters: [] })
    }
  }
  for data_constructor in self.program.metadata.data_constructors {
    self.require_type(data_constructor.owner)
    let scope = TypeScope::{
      parameters: data_constructor.hidden_type_parameters.copy(),
    }
    guard self.program.metadata.type_info(data_constructor.owner) is Some(owner) else {
      continue
    }
    for parameter in owner.parameters {
      scope.parameters.push(parameter)
    }
    for parameter in data_constructor.hidden_type_parameters {
      self.require_type_parameter(parameter)
    }
    for payload_type in data_constructor.payload_types {
      self.verify_value_type(payload_type, scope)
    }
  }
  for effect in self.program.metadata.effects {
    for parameter in effect.parameters {
      self.require_type_parameter(parameter)
    }
    for operation in effect.operations {
      self.require_operation(operation)
    }
  }
  for operation in self.program.metadata.operations {
    self.require_effect(operation.owner)
    let scope = TypeScope::{
      parameters: operation.hidden_type_parameters.copy(),
    }
    if self.program.metadata.effect_info(operation.owner) is Some(owner) {
      for parameter in owner.parameters {
        scope.parameters.push(parameter)
      }
    }
    for parameter in operation.hidden_type_parameters {
      self.require_type_parameter(parameter)
    }
    for payload_type in operation.payload_types {
      self.verify_value_type(payload_type, scope)
    }
    self.verify_value_type(operation.result_type, scope)
  }
}

///|
fn ValueKind::has_closed_metadata_type(self : ValueKind) -> Bool {
  match self {
    Function | Value | External => true
    Parameter | Local | MatchBinder => false
  }
}

///|
fn VerifyContext::verify_terms(self : VerifyContext) -> Unit {
  let scope = ValueScope::{ values: [] }
  for term in self.program.terms {
    match term {
      Let(id, _) | External(id) => scope.values.push(id)
      LetRec(bindings) =>
        for binding in bindings {
          scope.values.push(binding.id)
        }
    }
  }
  for term in self.program.terms {
    match term {
      External(id) => self.verify_external(id)
      Let(id, initializer) => self.verify_top_let(id, initializer, scope)
      LetRec(bindings) => self.verify_top_letrec(bindings, scope)
    }
  }
}

///|
fn VerifyContext::verify_external(self : VerifyContext, id : ValueId) -> Unit {
  guard self.program.metadata.value_info(id) is Some(info) else {
    self.report(UnknownValue(id))
    return
  }
  if info.kind != External {
    self.report(InvalidExternal(id))
  }
}

///|
fn VerifyContext::verify_top_let(
  self : VerifyContext,
  id : ValueId,
  initializer : Expr,
  scope : ValueScope,
) -> Unit {
  guard self.program.metadata.value_info(id) is Some(info) else {
    self.report(UnknownValue(id))
    return
  }
  let effect = self.check_expr(initializer, info.type_, scope, {
    parameters: [],
  })
  self.require_effect_equals(Empty, effect)
}

///|
fn VerifyContext::verify_top_letrec(
  self : VerifyContext,
  bindings : Array[RecursiveBinding],
  scope : ValueScope,
) -> Unit {
  for binding in bindings {
    if !binding.rhs.is_recursable_function() {
      self.report(InvalidLetRecRhs(binding.id))
    }
    guard self.program.metadata.value_info(binding.id) is Some(info) else {
      self.report(UnknownValue(binding.id))
      continue
    }
    let effect = self.check_expr(binding.rhs, info.type_, scope, {
      parameters: [],
    })
    self.require_effect_equals(Empty, effect)
  }
}

///|
fn VerifyContext::check_expr(
  self : VerifyContext,
  expr : Expr,
  expected : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  let actual = self.synthesize_expr(expr, value_scope, type_scope)
  if actual.type_ != expected {
    self.report(TypeMismatch(expected~, actual=actual.type_))
  }
  actual.effect
}

///|
fn VerifyContext::synthesize_expr(
  self : VerifyContext,
  expr : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  match expr {
    Ref(id) => self.synthesize_ref(id, value_scope)
    Literal(literal) => pure_expr(literal.type_())
    Function(function) =>
      self.synthesize_function(function, value_scope, type_scope)
    Call(callee, arguments) =>
      self.synthesize_call(callee, arguments, value_scope, type_scope)
    TypeLambda(parameters, body) =>
      self.synthesize_type_lambda(parameters, body, value_scope, type_scope)
    TypeApply(callee, arguments) =>
      self.synthesize_type_apply(callee, arguments, value_scope, type_scope)
    Construct(construct) =>
      self.synthesize_construct(construct, value_scope, type_scope)
    Let(id, initializer, body) =>
      self.synthesize_let(id, initializer, body, value_scope, type_scope)
    LetRec(bindings, body) =>
      self.synthesize_letrec(bindings, body, value_scope, type_scope)
    Match(match_) => self.synthesize_match(match_, value_scope, type_scope)
    Perform(perform) =>
      self.synthesize_perform(perform, value_scope, type_scope)
    Handle(handle) => self.synthesize_handle(handle, value_scope, type_scope)
    Resume(id) => self.synthesize_ref(id, value_scope)
  }
}

///|
fn VerifyContext::synthesize_ref(
  self : VerifyContext,
  id : ValueId,
  scope : ValueScope,
) -> SynthesizedExpr {
  guard self.program.metadata.value_info(id) is Some(info) else {
    self.report(UnknownValue(id))
    return pure_expr(Primitive(Unit))
  }
  if !scope.contains(id) {
    self.report(UnknownValue(id))
  }
  pure_expr(info.type_)
}

///|
fn VerifyContext::synthesize_function(
  self : VerifyContext,
  function : FunctionExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let parameters : Array[Type] = []
  let body_scope = value_scope.copy()
  for parameter in function.parameters {
    guard self.program.metadata.value_info(parameter) is Some(info) else {
      self.report(UnknownValue(parameter))
      continue
    }
    parameters.push(info.type_)
    body_scope.values.push(parameter)
  }
  self.verify_value_type(function.result_type, type_scope)
  let latent_effect = self.check_expr(
    function.body,
    function.result_type,
    body_scope,
    type_scope,
  )
  pure_expr(Function(parameters, function.result_type, latent_effect))
}

///|
fn VerifyContext::synthesize_call(
  self : VerifyContext,
  callee : Expr,
  arguments : Array[Expr],
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let callee_result = self.synthesize_expr(callee, value_scope, type_scope)
  guard callee_result.type_
    is Function(parameter_types, result_type, latent_effect) else {
    self.report(NotFunction(callee_result.type_))
    return { type_: Primitive(Unit), effect: callee_result.effect }
  }
  let effects = [callee_result.effect]
  if parameter_types.length() != arguments.length() {
    self.report(
      ArityMismatch(
        expected=parameter_types.length(),
        actual=arguments.length(),
      ),
    )
    return {
      type_: result_type,
      effect: effect_union(effects + [latent_effect]),
    }
  }
  for index in 0..<arguments.length() {
    let argument_effect = self.check_expr(
      arguments[index],
      parameter_types[index],
      value_scope,
      type_scope,
    )
    effects.push(argument_effect)
  }
  effects.push(latent_effect)
  { type_: result_type, effect: effect_union(effects) }
}

///|
fn VerifyContext::synthesize_type_lambda(
  self : VerifyContext,
  parameters : Array[TypeParameterId],
  body : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let body_scope = type_scope.copy()
  for parameter in parameters {
    self.require_type_parameter(parameter)
    body_scope.parameters.push(parameter)
  }
  let body_result = self.synthesize_expr(body, value_scope, body_scope)
  if body_result.effect != Empty {
    self.report(EffectMismatch(expected=Empty, actual=body_result.effect))
  }
  pure_expr(Forall(parameters, body_result.type_))
}

///|
fn VerifyContext::synthesize_type_apply(
  self : VerifyContext,
  callee : Expr,
  arguments : Array[GenericArgument],
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let callee_result = self.synthesize_expr(callee, value_scope, type_scope)
  guard callee_result.type_ is Forall(parameters, body) else {
    self.report(NotForall(callee_result.type_))
    return { type_: Primitive(Unit), effect: callee_result.effect }
  }
  if parameters.length() != arguments.length() {
    self.report(
      ArityMismatch(expected=parameters.length(), actual=arguments.length()),
    )
    return { type_: body, effect: callee_result.effect }
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  for index in 0..<parameters.length() {
    guard self.program.metadata.type_parameter_info(parameters[index])
      is Some(info) else {
      self.report(UnknownTypeParameter(parameters[index]))
      continue
    }
    self.verify_generic_argument_kind(arguments[index], info.kind, type_scope)
    substitution.insert_argument(parameters[index], arguments[index])
  }
  { type_: body.substitute(substitution), effect: callee_result.effect }
}

///|
fn VerifyContext::synthesize_construct(
  self : VerifyContext,
  construct : ConstructExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  guard self.program.metadata.data_constructor_info(construct.data_constructor)
    is Some(info) else {
    self.report(UnknownDataConstructor(construct.data_constructor))
    return pure_expr(Primitive(Unit))
  }
  guard self.program.metadata.type_info(info.owner) is Some(owner) else {
    self.report(UnknownType(info.owner))
    return pure_expr(Primitive(Unit))
  }
  if owner.parameters.length() != construct.type_arguments.length() {
    self.report(
      ArityMismatch(
        expected=owner.parameters.length(),
        actual=construct.type_arguments.length(),
      ),
    )
  }
  if info.hidden_type_parameters.length() != construct.hidden_witnesses.length() {
    self.report(
      ArityMismatch(
        expected=info.hidden_type_parameters.length(),
        actual=construct.hidden_witnesses.length(),
      ),
    )
  }
  if info.payload_types.length() != construct.payloads.length() {
    self.report(
      ArityMismatch(
        expected=info.payload_types.length(),
        actual=construct.payloads.length(),
      ),
    )
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  for
    index in 0..<owner.parameters
    .length()
    .min(construct.type_arguments.length()) {
    let argument = construct.type_arguments[index]
    guard self.program.metadata.type_parameter_info(owner.parameters[index])
      is Some(parameter_info) else {
      self.report(UnknownTypeParameter(owner.parameters[index]))
      continue
    }
    self.verify_generic_argument_kind(argument, parameter_info.kind, type_scope)
    substitution.insert_argument(owner.parameters[index], argument)
  }
  for
    index in 0..<info.hidden_type_parameters
    .length()
    .min(construct.hidden_witnesses.length()) {
    let witness = construct.hidden_witnesses[index]
    guard self.program.metadata.type_parameter_info(
        info.hidden_type_parameters[index],
      )
      is Some(parameter_info) else {
      self.report(UnknownTypeParameter(info.hidden_type_parameters[index]))
      continue
    }
    self.verify_generic_argument_kind(witness, parameter_info.kind, type_scope)
    substitution.insert_argument(info.hidden_type_parameters[index], witness)
  }
  let effects = []
  for index in 0..<info.payload_types.length().min(construct.payloads.length()) {
    let payload_effect = self.check_expr(
      construct.payloads[index],
      info.payload_types[index].substitute(substitution),
      value_scope,
      type_scope,
    )
    effects.push(payload_effect)
  }
  {
    type_: nominal_type(info.owner, construct.type_arguments),
    effect: effect_union(effects),
  }
}

///|
fn VerifyContext::synthesize_perform(
  self : VerifyContext,
  perform : PerformExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  guard self.program.metadata.operation_info(perform.operation) is Some(info) else {
    self.report(UnknownOperation(perform.operation))
    return pure_expr(Primitive(Unit))
  }
  guard self.program.metadata.effect_info(info.owner) is Some(owner) else {
    self.report(UnknownEffect(info.owner))
    return pure_expr(info.result_type)
  }
  if owner.parameters.length() != perform.effect_arguments.length() {
    self.report(
      ArityMismatch(
        expected=owner.parameters.length(),
        actual=perform.effect_arguments.length(),
      ),
    )
  }
  if info.hidden_type_parameters.length() != perform.hidden_witnesses.length() {
    self.report(
      ArityMismatch(
        expected=info.hidden_type_parameters.length(),
        actual=perform.hidden_witnesses.length(),
      ),
    )
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  for
    index in 0..<owner.parameters
    .length()
    .min(perform.effect_arguments.length()) {
    guard self.program.metadata.type_parameter_info(owner.parameters[index])
      is Some(parameter_info) else {
      self.report(UnknownTypeParameter(owner.parameters[index]))
      continue
    }
    self.verify_generic_argument_kind(
      perform.effect_arguments[index],
      parameter_info.kind,
      type_scope,
    )
    substitution.insert_argument(
      owner.parameters[index],
      perform.effect_arguments[index],
    )
  }
  for
    index in 0..<info.hidden_type_parameters
    .length()
    .min(perform.hidden_witnesses.length()) {
    let witness = perform.hidden_witnesses[index]
    guard self.program.metadata.type_parameter_info(
        info.hidden_type_parameters[index],
      )
      is Some(parameter_info) else {
      self.report(UnknownTypeParameter(info.hidden_type_parameters[index]))
      continue
    }
    self.verify_generic_argument_kind(witness, parameter_info.kind, type_scope)
    substitution.insert_argument(info.hidden_type_parameters[index], witness)
  }
  if info.payload_types.length() != perform.payloads.length() {
    self.report(
      ArityMismatch(
        expected=info.payload_types.length(),
        actual=perform.payloads.length(),
      ),
    )
  }
  let effects = []
  for index in 0..<info.payload_types.length().min(perform.payloads.length()) {
    let payload_effect = self.check_expr(
      perform.payloads[index],
      info.payload_types[index].substitute(substitution),
      value_scope,
      type_scope,
    )
    effects.push(payload_effect)
  }
  effects.push(Singleton(info.owner, perform.effect_arguments))
  {
    type_: info.result_type.substitute(substitution),
    effect: effect_union(effects),
  }
}

///|
fn VerifyContext::synthesize_handle(
  self : VerifyContext,
  handle : HandleExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let body_result = self.synthesize_expr(handle.body, value_scope, type_scope)
  let handled_effects = handle.handlers.map(fn(table) { table.handled_effect })
  let residual_body_effect = self.remove_handled_effects(
    body_result.effect,
    handled_effects,
  )
  let effects = [residual_body_effect]
  guard self.program.metadata.value_info(handle.result_binder)
    is Some(result_info) else {
    self.report(UnknownValue(handle.result_binder))
    return { type_: handle.result_type, effect: effect_union(effects) }
  }
  if result_info.type_ != body_result.type_ {
    self.report(
      TypeMismatch(expected=body_result.type_, actual=result_info.type_),
    )
  }
  let final_scope = value_scope.copy()
  final_scope.values.push(handle.result_binder)
  let final_effect = self.check_expr(
    handle.final_body,
    handle.result_type,
    final_scope,
    type_scope,
  )
  effects.push(final_effect)
  for table in handle.handlers {
    self.verify_effect(table.handled_effect, type_scope)
    for alternative in table.operations {
      let arm_effect = self.verify_operation_alternative(
        table.handled_effect,
        alternative,
        handle.result_type,
        value_scope,
        type_scope,
      )
      effects.push(arm_effect)
    }
  }
  { type_: handle.result_type, effect: effect_union(effects) }
}

///|
fn VerifyContext::verify_operation_alternative(
  self : VerifyContext,
  handled_effect : Effect,
  alternative : OperationAlternative,
  handler_result : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  guard self.program.metadata.operation_info(alternative.operation)
    is Some(info) else {
    self.report(UnknownOperation(alternative.operation))
    return Empty
  }
  if alternative.type_binders.length() != info.hidden_type_parameters.length() {
    self.report(
      ArityMismatch(
        expected=info.hidden_type_parameters.length(),
        actual=alternative.type_binders.length(),
      ),
    )
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  match handled_effect {
    Singleton(owner, arguments) => {
      if owner != info.owner {
        self.report(
          EffectMismatch(
            expected=handled_effect,
            actual=Singleton(info.owner, []),
          ),
        )
      }
      if self.program.metadata.effect_info(info.owner) is Some(effect_info) {
        for index in 0..<effect_info.parameters.length().min(arguments.length()) {
          substitution.insert_argument(
            effect_info.parameters[index],
            arguments[index],
          )
        }
      }
    }
    _ => self.report(EffectMismatch(expected=handled_effect, actual=Empty))
  }
  let arm_type_scope = type_scope.copy()
  for
    index in 0..<alternative.type_binders
    .length()
    .min(info.hidden_type_parameters.length()) {
    let binder = alternative.type_binders[index]
    guard self.program.metadata.type_parameter_info(binder) is Some(binder_info) else {
      self.report(UnknownTypeParameter(binder))
      continue
    }
    guard self.program.metadata.type_parameter_info(
        info.hidden_type_parameters[index],
      )
      is Some(hidden_info) else {
      self.report(UnknownTypeParameter(info.hidden_type_parameters[index]))
      continue
    }
    if binder_info.kind != hidden_info.kind {
      self.report(
        KindMismatch(expected=hidden_info.kind, actual=binder_info.kind),
      )
    }
    if hidden_info.kind == Effect {
      substitution.insert_effect(
        info.hidden_type_parameters[index],
        Parameter(binder),
      )
    } else {
      substitution.insert(info.hidden_type_parameters[index], Parameter(binder))
    }
    arm_type_scope.parameters.push(binder)
  }
  if alternative.payload_binders.length() != info.payload_types.length() {
    self.report(
      ArityMismatch(
        expected=info.payload_types.length(),
        actual=alternative.payload_binders.length(),
      ),
    )
  }
  let arm_scope = value_scope.copy()
  for
    index in 0..<alternative.payload_binders
    .length()
    .min(info.payload_types.length()) {
    let binder = alternative.payload_binders[index]
    guard self.program.metadata.value_info(binder) is Some(binder_info) else {
      self.report(UnknownValue(binder))
      continue
    }
    let expected = info.payload_types[index].substitute(substitution)
    if binder_info.type_ != expected {
      self.report(TypeMismatch(expected~, actual=binder_info.type_))
    }
    arm_scope.values.push(binder)
  }
  let resume_result = info.result_type.substitute(substitution)
  self.verify_resume_binder(
    alternative.resume_binder,
    resume_result,
    handler_result,
    arm_scope,
  )
  self.check_expr(alternative.body, handler_result, arm_scope, arm_type_scope)
}

///|
fn VerifyContext::verify_resume_binder(
  self : VerifyContext,
  binder : ValueId,
  parameter : Type,
  result : Type,
  scope : ValueScope,
) -> Unit {
  guard self.program.metadata.value_info(binder) is Some(info) else {
    self.report(UnknownValue(binder))
    return
  }
  scope.values.push(binder)
  guard info.type_ is Function(parameters, actual_result, _) else {
    self.report(NotFunction(info.type_))
    return
  }
  if parameters.length() != 1 {
    self.report(ArityMismatch(expected=1, actual=parameters.length()))
  } else if parameters[0] != parameter {
    self.report(TypeMismatch(expected=parameter, actual=parameters[0]))
  }
  if actual_result != result {
    self.report(TypeMismatch(expected=result, actual=actual_result))
  }
}

///|
fn VerifyContext::synthesize_let(
  self : VerifyContext,
  id : ValueId,
  initializer : Expr,
  body : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  guard self.program.metadata.value_info(id) is Some(info) else {
    self.report(UnknownValue(id))
    return self.synthesize_expr(body, value_scope, type_scope)
  }
  let initializer_effect = self.check_expr(
    initializer,
    info.type_,
    value_scope,
    type_scope,
  )
  let body_scope = value_scope.copy()
  body_scope.values.push(id)
  let body_result = self.synthesize_expr(body, body_scope, type_scope)
  {
    type_: body_result.type_,
    effect: effect_union([initializer_effect, body_result.effect]),
  }
}

///|
fn VerifyContext::synthesize_letrec(
  self : VerifyContext,
  bindings : Array[RecursiveBinding],
  body : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let body_scope = value_scope.copy()
  for binding in bindings {
    body_scope.values.push(binding.id)
  }
  for binding in bindings {
    if !binding.rhs.is_recursable_function() {
      self.report(InvalidLetRecRhs(binding.id))
    }
    guard self.program.metadata.value_info(binding.id) is Some(info) else {
      self.report(UnknownValue(binding.id))
      continue
    }
    let rhs_effect = self.check_expr(
      binding.rhs,
      info.type_,
      body_scope,
      type_scope,
    )
    if rhs_effect != Empty {
      self.report(EffectMismatch(expected=Empty, actual=rhs_effect))
    }
  }
  self.synthesize_expr(body, body_scope, type_scope)
}

///|
fn VerifyContext::synthesize_match(
  self : VerifyContext,
  match_ : MatchExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> SynthesizedExpr {
  let scrutinee_result = self.synthesize_expr(
    match_.scrutinee,
    value_scope,
    type_scope,
  )
  guard self.program.metadata.value_info(match_.binder) is Some(binder_info) else {
    self.report(UnknownValue(match_.binder))
    return pure_expr(match_.result_type)
  }
  if binder_info.type_ != scrutinee_result.type_ {
    self.report(
      TypeMismatch(expected=scrutinee_result.type_, actual=binder_info.type_),
    )
  }
  self.verify_match_shape(match_, scrutinee_result.type_)
  let effects = [scrutinee_result.effect]
  for alternative in match_.alternatives {
    let alternative_effect = self.verify_alternative(
      alternative,
      scrutinee_result.type_,
      match_.result_type,
      value_scope,
      type_scope,
    )
    effects.push(alternative_effect)
  }
  { type_: match_.result_type, effect: effect_union(effects) }
}

///|
fn VerifyContext::verify_alternative(
  self : VerifyContext,
  alternative : Alternative,
  scrutinee_type : Type,
  result_type : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  let body_scope = value_scope.copy()
  let alternative_type_scope = type_scope.copy()
  match alternative.alt_constructor {
    Default => ()
    Literal(literal) => {
      let literal_type = literal.type_()
      if literal_type != scrutinee_type {
        self.report(TypeMismatch(expected=scrutinee_type, actual=literal_type))
      }
    }
    DataCon(data_constructor) =>
      self.verify_data_alternative(
        data_constructor, alternative, scrutinee_type, body_scope, alternative_type_scope,
      )
  }
  for binder in alternative.type_binders {
    self.require_type_parameter(binder)
    alternative_type_scope.parameters.push(binder)
  }
  for binder in alternative.value_binders {
    self.require_value(binder)
    body_scope.values.push(binder)
  }
  self.check_expr(
    alternative.body,
    result_type,
    body_scope,
    alternative_type_scope,
  )
}

///|
fn VerifyContext::verify_data_alternative(
  self : VerifyContext,
  data_constructor : DataConId,
  alternative : Alternative,
  scrutinee_type : Type,
  body_scope : ValueScope,
  type_scope : TypeScope,
) -> Unit {
  guard decompose_nominal_type(scrutinee_type)
    is Some((owner_id, type_arguments)) else {
    self.report(TypeMismatch(expected=scrutinee_type, actual=Primitive(Unit)))
    return
  }
  guard self.program.metadata.data_constructor_info(data_constructor)
    is Some(info) else {
    self.report(UnknownDataConstructor(data_constructor))
    return
  }
  if info.owner != owner_id {
    self.report(
      TypeMismatch(
        expected=scrutinee_type,
        actual=nominal_type(info.owner, type_arguments),
      ),
    )
  }
  if alternative.type_binders.length() != info.hidden_type_parameters.length() ||
    alternative.value_binders.length() != info.payload_types.length() {
    self.report(InvalidAlternativeBinderCount)
    return
  }
  guard self.program.metadata.type_info(info.owner) is Some(owner) else {
    self.report(UnknownType(info.owner))
    return
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  for index in 0..<owner.parameters.length().min(type_arguments.length()) {
    substitution.insert_argument(owner.parameters[index], type_arguments[index])
  }
  for index in 0..<info.hidden_type_parameters.length() {
    guard self.program.metadata.type_parameter_info(
        info.hidden_type_parameters[index],
      )
      is Some(hidden_info) else {
      self.report(UnknownTypeParameter(info.hidden_type_parameters[index]))
      continue
    }
    if hidden_info.kind == Effect {
      substitution.insert_effect(
        info.hidden_type_parameters[index],
        Parameter(alternative.type_binders[index]),
      )
    } else {
      substitution.insert(
        info.hidden_type_parameters[index],
        Parameter(alternative.type_binders[index]),
      )
    }
  }
  for index in 0..<alternative.value_binders.length() {
    let binder = alternative.value_binders[index]
    guard self.program.metadata.value_info(binder) is Some(binder_info) else {
      self.report(UnknownValue(binder))
      continue
    }
    let expected = info.payload_types[index].substitute(substitution)
    if !binder_info.type_.equals(expected) {
      self.report(TypeMismatch(expected~, actual=binder_info.type_))
    }
    body_scope.values.push(binder)
  }
  for binder in alternative.type_binders {
    type_scope.parameters.push(binder)
  }
}

///|
fn VerifyContext::verify_match_shape(
  self : VerifyContext,
  match_ : MatchExpr,
  scrutinee_type : Type,
) -> Unit {
  let mut seen_default = false
  let literal_alternatives : Array[Literal] = []
  let data_alternatives : Array[DataConId] = []
  for index in 0..<match_.alternatives.length() {
    match match_.alternatives[index].alt_constructor {
      Default => {
        if seen_default {
          self.report(DuplicateDefaultAlternative)
        }
        if index != match_.alternatives.length() - 1 {
          self.report(DefaultAlternativeNotLast)
        }
        seen_default = true
      }
      Literal(literal) =>
        if literal_alternatives.contains(literal) {
          self.report(DuplicateAlternative)
        } else {
          literal_alternatives.push(literal)
        }
      DataCon(data_constructor) =>
        if data_alternatives.contains(data_constructor) {
          self.report(DuplicateAlternative)
        } else {
          data_alternatives.push(data_constructor)
        }
    }
  }
  if !seen_default &&
    !self.is_exhaustive(scrutinee_type, literal_alternatives, data_alternatives) {
    self.report(NonExhaustiveMatch)
  }
}

///|
fn VerifyContext::is_exhaustive(
  self : VerifyContext,
  scrutinee_type : Type,
  literals : Array[Literal],
  data_constructors : Array[DataConId],
) -> Bool {
  match scrutinee_type {
    Primitive(Unit) => literals.contains(Unit)
    Primitive(Bool) =>
      literals.contains(Bool(true)) && literals.contains(Bool(false))
    type_ if decompose_nominal_type(type_) is Some((owner, _)) =>
      match self.program.metadata.type_info(owner) {
        Some(info) =>
          info.constructors.all(fn(data_constructor) {
            data_constructors.contains(data_constructor)
          })
        None => false
      }
    _ => false
  }
}

///|
fn VerifyContext::verify_value_type(
  self : VerifyContext,
  type_ : Type,
  scope : TypeScope,
) -> Unit {
  self.verify_type_kind(type_, Type, scope)
}

///|
fn VerifyContext::verify_type_kind(
  self : VerifyContext,
  type_ : Type,
  expected : Kind,
  scope : TypeScope,
) -> Unit {
  let actual = self.synthesize_type_kind(type_, scope)
  if actual != expected {
    self.report(KindMismatch(expected~, actual~))
  }
}

///|
fn VerifyContext::verify_generic_argument_kind(
  self : VerifyContext,
  argument : GenericArgument,
  expected : Kind,
  scope : TypeScope,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.verify_type_kind(type_, expected, scope)
    EffectArgument(effect) => {
      self.verify_effect(effect, scope)
      if expected != Effect {
        self.report(KindMismatch(expected~, actual=Effect))
      }
    }
  }
}

///|
fn VerifyContext::synthesize_type_kind(
  self : VerifyContext,
  type_ : Type,
  scope : TypeScope,
) -> Kind {
  match type_ {
    Primitive(_) => Type
    Parameter(parameter) => {
      if !scope.contains(parameter) {
        self.report(UnknownTypeParameter(parameter))
        return Type
      }
      match self.program.metadata.type_parameter_info(parameter) {
        Some(info) => info.kind
        None => {
          self.report(UnknownTypeParameter(parameter))
          Type
        }
      }
    }
    Constructor(id) => {
      guard self.program.metadata.type_info(id) is Some(info) else {
        self.report(UnknownType(id))
        return Type
      }
      if info.parameters.is_empty() {
        Type
      } else {
        Function(
          info.parameters.map(fn(parameter) {
            match self.program.metadata.type_parameter_info(parameter) {
              Some(parameter_info) => parameter_info.kind
              None => {
                self.report(UnknownTypeParameter(parameter))
                Type
              }
            }
          }),
          Type,
        )
      }
    }
    Apply(callee, arguments) => {
      let callee_kind = self.synthesize_type_kind(callee, scope)
      guard callee_kind is Function(parameter_kinds, result_kind) else {
        self.report(
          KindMismatch(expected=Function([], Type), actual=callee_kind),
        )
        return Type
      }
      if parameter_kinds.length() != arguments.length() {
        self.report(
          ArityMismatch(
            expected=parameter_kinds.length(),
            actual=arguments.length(),
          ),
        )
      }
      for index in 0..<arguments.length() {
        let argument = arguments[index]
        if index < parameter_kinds.length() {
          self.verify_generic_argument_kind(
            argument,
            parameter_kinds[index],
            scope,
          )
        } else {
          match argument {
            TypeArgument(type_) =>
              ignore(self.synthesize_type_kind(type_, scope))
            EffectArgument(effect) => self.verify_effect(effect, scope)
          }
        }
      }
      result_kind
    }
    TypeLambda(parameters, body) => {
      let body_scope = scope.copy()
      let parameter_kinds = []
      for parameter in parameters {
        self.require_type_parameter(parameter)
        body_scope.parameters.push(parameter)
        match self.program.metadata.type_parameter_info(parameter) {
          Some(info) => parameter_kinds.push(info.kind)
          None => parameter_kinds.push(Type)
        }
      }
      Function(parameter_kinds, self.synthesize_type_kind(body, body_scope))
    }
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.verify_type_kind(parameter, Type, scope)
      }
      self.verify_type_kind(result, Type, scope)
      self.verify_effect(effect, scope)
      Type
    }
    Forall(parameters, body) => {
      let body_scope = scope.copy()
      for parameter in parameters {
        self.require_type_parameter(parameter)
        body_scope.parameters.push(parameter)
      }
      self.verify_type_kind(body, Type, body_scope)
      Type
    }
  }
}

///|
fn VerifyContext::verify_effect(
  self : VerifyContext,
  effect : Effect,
  scope : TypeScope,
) -> Unit {
  match effect {
    Empty => ()
    Singleton(id, arguments) => {
      guard self.program.metadata.effect_info(id) is Some(info) else {
        self.report(UnknownEffect(id))
        return
      }
      if info.parameters.length() != arguments.length() {
        self.report(
          ArityMismatch(
            expected=info.parameters.length(),
            actual=arguments.length(),
          ),
        )
      }
      for index in 0..<info.parameters.length().min(arguments.length()) {
        guard self.program.metadata.type_parameter_info(info.parameters[index])
          is Some(parameter_info) else {
          self.report(UnknownTypeParameter(info.parameters[index]))
          continue
        }
        self.verify_generic_argument_kind(
          arguments[index],
          parameter_info.kind,
          scope,
        )
      }
    }
    Parameter(parameter) => self.verify_effect_parameter(parameter, scope)
    Union(effects) =>
      for nested in effects {
        self.verify_effect(nested, scope)
      }
  }
}

///|
fn VerifyContext::verify_effect_parameter(
  self : VerifyContext,
  parameter : TypeParameterId,
  scope : TypeScope,
) -> Unit {
  if !scope.contains(parameter) {
    self.report(UnknownTypeParameter(parameter))
    return
  }
  guard self.program.metadata.type_parameter_info(parameter) is Some(info) else {
    self.report(UnknownTypeParameter(parameter))
    return
  }
  if info.kind != Effect {
    self.report(KindMismatch(expected=Effect, actual=info.kind))
  }
}

///|
fn VerifyContext::require_type(self : VerifyContext, id : TypeId) -> Unit {
  if self.program.metadata.type_info(id) is None {
    self.report(UnknownType(id))
  }
}

///|
fn VerifyContext::require_type_parameter(
  self : VerifyContext,
  id : TypeParameterId,
) -> Unit {
  if self.program.metadata.type_parameter_info(id) is None {
    self.report(UnknownTypeParameter(id))
  }
}

///|
fn VerifyContext::require_value(self : VerifyContext, id : ValueId) -> Unit {
  if self.program.metadata.value_info(id) is None {
    self.report(UnknownValue(id))
  }
}

///|
fn VerifyContext::require_data_constructor(
  self : VerifyContext,
  id : DataConId,
) -> Unit {
  if self.program.metadata.data_constructor_info(id) is None {
    self.report(UnknownDataConstructor(id))
  }
}

///|
fn VerifyContext::require_effect(self : VerifyContext, id : EffectId) -> Unit {
  if self.program.metadata.effect_info(id) is None {
    self.report(UnknownEffect(id))
  }
}

///|
fn VerifyContext::require_operation(
  self : VerifyContext,
  id : OperationId,
) -> Unit {
  if self.program.metadata.operation_info(id) is None {
    self.report(UnknownOperation(id))
  }
}

///|
fn ValueScope::contains(self : ValueScope, id : ValueId) -> Bool {
  self.values.contains(id)
}

///|
fn ValueScope::copy(self : ValueScope) -> ValueScope {
  { values: self.values.copy() }
}

///|
fn TypeScope::contains(self : TypeScope, id : TypeParameterId) -> Bool {
  self.parameters.contains(id)
}

///|
fn TypeScope::copy(self : TypeScope) -> TypeScope {
  { parameters: self.parameters.copy() }
}

///|
fn pure_expr(type_ : Type) -> SynthesizedExpr {
  { type_, effect: Empty }
}

///|
fn effect_union(effects : Array[Effect]) -> Effect {
  Union(effects).canonicalize()
}

///|
fn VerifyContext::require_effect_equals(
  self : VerifyContext,
  expected : Effect,
  actual : Effect,
) -> Unit {
  if actual != expected {
    self.report(EffectMismatch(expected~, actual~))
  }
}

///|
fn VerifyContext::remove_handled_effects(
  self : VerifyContext,
  effect : Effect,
  handled : Array[Effect],
) -> Effect {
  let residual : Array[Effect] = []
  let mut has_open_row = false
  for term in effect_terms(effect) {
    match term {
      Parameter(_) => {
        has_open_row = true
        residual.push(term)
      }
      _ =>
        if !handled.any(fn(handled_effect) { term == handled_effect }) {
          residual.push(term)
        }
    }
  }
  if !has_open_row {
    for handled_effect in handled {
      if !effect_terms(effect).any(fn(term) { term == handled_effect }) {
        self.report(EffectMismatch(expected=handled_effect, actual=effect))
      }
    }
  }
  effect_union(residual)
}

///|
fn effect_terms(effect : Effect) -> Array[Effect] {
  match effect.canonicalize() {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn Literal::type_(self : Literal) -> Type {
  match self {
    Unit => Primitive(Unit)
    Bool(_) => Primitive(Bool)
    Int(_) => Primitive(Int)
    String(_) => Primitive(String)
  }
}

///|
fn Expr::is_recursable_function(self : Expr) -> Bool {
  match self {
    Function(_) => true
    TypeLambda(_, body) => body.is_recursable_function()
    _ => false
  }
}

///|
fn nominal_type(owner : TypeId, arguments : Array[GenericArgument]) -> Type {
  if arguments.is_empty() {
    Constructor(owner)
  } else {
    Apply(Constructor(owner), arguments)
  }
}

///|
fn decompose_nominal_type(type_ : Type) -> (TypeId, Array[GenericArgument])? {
  match type_ {
    Constructor(owner) => Some((owner, []))
    Apply(Constructor(owner), arguments) => Some((owner, arguments))
    _ => None
  }
}
