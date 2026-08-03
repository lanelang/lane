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
  EffectFlavorMismatch(parameter~ : TypeParameterId, argument~ : Effect)
  TypeNormalizationFailure(TypeNormalizationError)
  TypeSubstitutionFailure(TypeSubstitutionError)
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
  InvalidCharLiteral(Int)
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
pub(all) struct ExpressionFacts {
  priv type_ : Type
  priv effect : Effect
} derive(Debug, Eq)

///|
pub(all) struct ExpressionFactsQuery {
  priv program : Program
  priv values : Array[ValueId]
  priv type_parameters : Array[TypeParameterId]
}

///|
pub fn ExpressionFacts::type_(self : ExpressionFacts) -> Type {
  self.type_
}

///|
pub fn ExpressionFacts::effect(self : ExpressionFacts) -> Effect {
  self.effect
}

///|
pub fn ExpressionFactsQuery::new(program : Program) -> ExpressionFactsQuery {
  let values : Array[ValueId] = []
  for index in 0..<program.metadata.values.length() {
    values.push({ index, })
  }
  let type_parameters : Array[TypeParameterId] = []
  for index in 0..<program.metadata.type_parameters.length() {
    type_parameters.push({ index, })
  }
  { program, values, type_parameters }
}

///|
pub fn ExpressionFactsQuery::synthesize(
  self : ExpressionFactsQuery,
  expression : Expr,
) -> Result[ExpressionFacts, VerifyResult] {
  let context = VerifyContext::{ program: self.program, diagnostics: [] }
  let facts = context.synthesize_expr(expression, { values: self.values }, {
    parameters: self.type_parameters,
  })
  let blockers = context.diagnostics.filter(diagnostic => {
    diagnostic.blocks_expression_facts()
  })
  if blockers.is_empty() {
    Ok(facts)
  } else {
    Err({ diagnostics: blockers })
  }
}

///|
fn VerifyDiagnostic::blocks_expression_facts(self : VerifyDiagnostic) -> Bool {
  !self.kind.is_type_compatibility_diagnostic()
}

///|
fn VerifyDiagnosticKind::is_type_compatibility_diagnostic(
  self : VerifyDiagnosticKind,
) -> Bool {
  self is TypeMismatch(_)
}

///|
/// Returns whether an expression has an empty synthesized effect.
///
/// A synthesis or normalization failure is returned as a blocking verifier
/// diagnostic rather than being converted to a negative answer or an abort.
pub fn ExpressionFactsQuery::has_empty_effect(
  self : ExpressionFactsQuery,
  expression : Expr,
) -> Result[Bool, VerifyResult] {
  match self.synthesize(expression) {
    Err(result) => Err(result)
    Ok(facts) =>
      Ok(
        self.program.metadata.effects_definitionally_equal(facts.effect, Empty),
      ) catch {
        error =>
          Err({ diagnostics: [{ kind: TypeNormalizationFailure(error) }] })
      }
  }
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
/// Returns the verification diagnostics in report order.
pub fn VerifyResult::diagnostics(
  self : VerifyResult,
) -> Array[VerifyDiagnostic] {
  self.diagnostics.copy()
}

///|
fn VerifyContext::report(
  self : VerifyContext,
  kind : VerifyDiagnosticKind,
) -> Unit {
  self.diagnostics.push({ kind, })
}

///|
fn VerifyContext::report_normalization_failure(
  self : VerifyContext,
  error : TypeNormalizationError,
) -> Unit {
  let kind = VerifyDiagnosticKind::TypeNormalizationFailure(error)
  if !self.diagnostics.any(diagnostic => diagnostic.kind == kind) {
    self.report(kind)
  }
}

///|
fn[T] VerifyContext::recover_normalization_failure(
  self : VerifyContext,
  fallback : T,
  compute : () -> T raise TypeNormalizationError,
) -> T {
  compute() catch {
    error => {
      self.report_normalization_failure(error)
      fallback
    }
  }
}

///|
fn VerifyContext::normalize_type(self : VerifyContext, type_ : Type) -> Type {
  self.recover_normalization_failure(type_, () => type_.normalize())
}

///|
/// Applies an instantiation, reporting a diagnostic instead of aborting when
/// the substitution refuses to capture. The unsubstituted type is returned so
/// checking can continue past the report.
fn VerifyContext::substituted(
  self : VerifyContext,
  type_ : Type,
  substitution : TypeSubstitution,
) -> Type {
  type_.try_substitute(substitution) catch {
    error => {
      let kind = VerifyDiagnosticKind::TypeSubstitutionFailure(error)
      if !self.diagnostics.any(diagnostic => diagnostic.kind == kind) {
        self.report(kind)
      }
      type_
    }
  }
}

///|
fn VerifyContext::normalize_effect(
  self : VerifyContext,
  effect : Effect,
) -> Effect {
  self.recover_normalization_failure(effect, () => effect.normalize())
}

///|
fn VerifyContext::types_definitionally_equal(
  self : VerifyContext,
  left : Type,
  right : Type,
) -> Bool {
  self.recover_normalization_failure(false, () => {
    self.program.metadata.types_definitionally_equal(left, right)
  })
}

///|
fn VerifyContext::type_is_consumable_as(
  self : VerifyContext,
  actual : Type,
  expected : Type,
) -> Bool {
  self.recover_normalization_failure(false, () => {
    self.program.metadata.type_is_consumable_as(actual, expected)
  })
}

///|
fn VerifyContext::effects_definitionally_equal(
  self : VerifyContext,
  left : Effect,
  right : Effect,
) -> Bool {
  self.recover_normalization_failure(false, () => {
    self.program.metadata.effects_definitionally_equal(left, right)
  })
}

///|
fn VerifyContext::canonicalize_effect(
  self : VerifyContext,
  effect : Effect,
) -> Effect {
  self.recover_normalization_failure(effect, () => {
    self.program.metadata.canonicalize_effect(effect)
  })
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
  let effect = self.check_binding_initializer(
    if info.kind is Function {
      FunctionBinding
    } else {
      OrdinaryBinding
    },
    initializer,
    info.type_,
    scope,
    { parameters: [] },
  )
  self.require_effect_equals(Empty, effect)
}

///|
fn VerifyContext::verify_top_letrec(
  self : VerifyContext,
  bindings : Array[RecursiveBinding],
  scope : ValueScope,
) -> Unit {
  for binding in bindings {
    if !binding.rhs.is_direct_function_implementation() {
      self.report(InvalidLetRecRhs(binding.id))
    }
    guard self.program.metadata.value_info(binding.id) is Some(info) else {
      self.report(UnknownValue(binding.id))
      continue
    }
    let effect = self.check_binding_initializer(
      FunctionBinding,
      binding.rhs,
      info.type_,
      scope,
      { parameters: [] },
    )
    self.require_effect_equals(Empty, effect)
  }
}

///|
/// Checks an expression against the type its consumer requires.
///
/// This asks whether the value may be used there, not whether the two types
/// denote the same thing, so a function that performs less than its position
/// allows is accepted. Dictionary-passing CPS depends on it: a handler's final
/// branch may be pure while the callable it is handed to declares the
/// installation's residual, and no term can bridge that gap by construction.
fn VerifyContext::check_expr(
  self : VerifyContext,
  expr : Expr,
  expected : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  let actual = self.synthesize_expr(expr, value_scope, type_scope)
  if !self.type_is_consumable_as(actual.type_, expected) {
    self.report(TypeMismatch(expected~, actual=actual.type_))
  }
  actual.effect
}

///|
fn VerifyContext::check_function_implementation(
  self : VerifyContext,
  expr : Expr,
  expected : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  let actual = self.synthesize_expr(expr, value_scope, type_scope)
  if !self.function_implementation_matches(actual.type_, expected) {
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
) -> ExpressionFacts {
  let facts = match expr {
    Ref(id) => self.synthesize_ref(id, value_scope)
    Literal(literal) => {
      self.verify_literal(literal)
      pure_expr(literal.type_())
    }
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
  {
    type_: self.normalize_type(facts.type_),
    effect: self.normalize_effect(facts.effect),
  }
}

///|
fn VerifyContext::synthesize_ref(
  self : VerifyContext,
  id : ValueId,
  scope : ValueScope,
) -> ExpressionFacts {
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
) -> ExpressionFacts {
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
) -> ExpressionFacts {
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
      effect: self.effect_union(effects + [latent_effect]),
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
  { type_: result_type, effect: self.effect_union(effects) }
}

///|
fn VerifyContext::synthesize_type_lambda(
  self : VerifyContext,
  parameters : Array[TypeParameterId],
  body : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> ExpressionFacts {
  let body_scope = type_scope.copy()
  for parameter in parameters {
    self.require_type_parameter(parameter)
    body_scope.parameters.push(parameter)
  }
  let body_result = self.synthesize_expr(body, value_scope, body_scope)
  if !self.effects_definitionally_equal(body_result.effect, Empty) {
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
) -> ExpressionFacts {
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
  let substitution = self.verified_substitution(
    parameters, arguments, type_scope,
  )
  { type_: self.substituted(body, substitution), effect: callee_result.effect }
}

///|
fn VerifyContext::synthesize_construct(
  self : VerifyContext,
  construct : ConstructExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> ExpressionFacts {
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
  let substitution = self
    .verified_substitution(
      owner.parameters,
      construct.type_arguments,
      type_scope,
    )
    .overlay(
      self.verified_substitution(
        info.hidden_type_parameters,
        construct.hidden_witnesses,
        type_scope,
      ),
    )
  let effects = []
  for index in 0..<info.payload_types.length().min(construct.payloads.length()) {
    let payload_effect = self.check_expr(
      construct.payloads[index],
      self.substituted(info.payload_types[index], substitution),
      value_scope,
      type_scope,
    )
    effects.push(payload_effect)
  }
  {
    type_: nominal_type(info.owner, construct.type_arguments),
    effect: self.effect_union(effects),
  }
}

///|
fn VerifyContext::synthesize_perform(
  self : VerifyContext,
  perform : PerformExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> ExpressionFacts {
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
  let substitution = self
    .verified_substitution(
      owner.parameters,
      perform.effect_arguments,
      type_scope,
    )
    .overlay(
      self.verified_substitution(
        info.hidden_type_parameters,
        perform.hidden_witnesses,
        type_scope,
      ),
    )
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
      self.substituted(info.payload_types[index], substitution),
      value_scope,
      type_scope,
    )
    effects.push(payload_effect)
  }
  effects.push(Singleton(info.owner, perform.effect_arguments))
  {
    type_: self.substituted(info.result_type, substitution),
    effect: self.effect_union(effects),
  }
}

///|
fn VerifyContext::synthesize_handle(
  self : VerifyContext,
  handle : HandleExpr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> ExpressionFacts {
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
    return { type_: handle.result_type, effect: self.effect_union(effects) }
  }
  if !self.types_definitionally_equal(result_info.type_, body_result.type_) {
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
    let owner_substitution = match table.handled_effect {
      Singleton(owner, arguments) =>
        self.verify_effect_singleton(owner, arguments, type_scope)
      effect => {
        self.verify_effect(effect, type_scope)
        None
      }
    }
    for alternative in table.operations {
      let arm_effect = self.verify_operation_alternative(
        table.handled_effect,
        owner_substitution,
        alternative,
        handle.result_type,
        value_scope,
        type_scope,
      )
      effects.push(arm_effect)
    }
  }
  { type_: handle.result_type, effect: self.effect_union(effects) }
}

///|
fn VerifyContext::verify_operation_alternative(
  self : VerifyContext,
  handled_effect : Effect,
  owner_substitution : TypeSubstitution?,
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
  match handled_effect {
    Singleton(owner, _) =>
      if owner != info.owner {
        self.report(
          EffectMismatch(
            expected=handled_effect,
            actual=Singleton(info.owner, []),
          ),
        )
      }
    _ => self.report(EffectMismatch(expected=handled_effect, actual=Empty))
  }
  let arm_type_scope = type_scope.copy()
  let hidden_substitution = TypeSubstitution::TypeSubstitution()
  for
    index in 0..<alternative.type_binders
    .length()
    .min(info.hidden_type_parameters.length()) {
    let binder = alternative.type_binders[index]
    arm_type_scope.parameters.push(binder)
    self.insert_verified_binder(
      hidden_substitution,
      info.hidden_type_parameters[index],
      binder,
      arm_type_scope,
    )
  }
  let substitution = match owner_substitution {
    Some(owner_substitution) => owner_substitution.overlay(hidden_substitution)
    None => hidden_substitution
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
    let expected = self.substituted(info.payload_types[index], substitution)
    if !self.types_definitionally_equal(binder_info.type_, expected) {
      self.report(TypeMismatch(expected~, actual=binder_info.type_))
    }
    arm_scope.values.push(binder)
  }
  let resume_result = self.substituted(info.result_type, substitution)
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
  } else if !self.types_definitionally_equal(parameters[0], parameter) {
    self.report(TypeMismatch(expected=parameter, actual=parameters[0]))
  }
  if !self.types_definitionally_equal(actual_result, result) {
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
) -> ExpressionFacts {
  guard self.program.metadata.value_info(id) is Some(info) else {
    self.report(UnknownValue(id))
    return self.synthesize_expr(body, value_scope, type_scope)
  }
  let initializer_effect = self.check_binding_initializer(
    OrdinaryBinding,
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
    effect: self.effect_union([initializer_effect, body_result.effect]),
  }
}

///|
fn VerifyContext::synthesize_letrec(
  self : VerifyContext,
  bindings : Array[RecursiveBinding],
  body : Expr,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> ExpressionFacts {
  let body_scope = value_scope.copy()
  for binding in bindings {
    body_scope.values.push(binding.id)
  }
  for binding in bindings {
    if !binding.rhs.is_direct_function_implementation() {
      self.report(InvalidLetRecRhs(binding.id))
    }
    guard self.program.metadata.value_info(binding.id) is Some(info) else {
      self.report(UnknownValue(binding.id))
      continue
    }
    let rhs_effect = self.check_binding_initializer(
      FunctionBinding,
      binding.rhs,
      info.type_,
      body_scope,
      type_scope,
    )
    if !self.effects_definitionally_equal(rhs_effect, Empty) {
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
) -> ExpressionFacts {
  let scrutinee_result = self.synthesize_expr(
    match_.scrutinee,
    value_scope,
    type_scope,
  )
  guard self.program.metadata.value_info(match_.binder) is Some(binder_info) else {
    self.report(UnknownValue(match_.binder))
    return pure_expr(match_.result_type)
  }
  if !self.types_definitionally_equal(binder_info.type_, scrutinee_result.type_) {
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
  { type_: match_.result_type, effect: self.effect_union(effects) }
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
  for binder in alternative.type_binders {
    self.require_type_parameter(binder)
    alternative_type_scope.parameters.push(binder)
  }
  match alternative.alt_constructor {
    Default => ()
    Literal(literal) => {
      self.verify_literal(literal)
      let literal_type = literal.type_()
      if !self.types_definitionally_equal(literal_type, scrutinee_type) {
        self.report(TypeMismatch(expected=scrutinee_type, actual=literal_type))
      }
    }
    DataCon(data_constructor) =>
      self.verify_data_alternative(
        data_constructor, alternative, scrutinee_type, body_scope, alternative_type_scope,
      )
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
  let substitution = self.verified_substitution(
    owner.parameters,
    type_arguments,
    type_scope,
  )
  let hidden_substitution = TypeSubstitution::TypeSubstitution()
  for index in 0..<info.hidden_type_parameters.length() {
    self.insert_verified_binder(
      hidden_substitution,
      info.hidden_type_parameters[index],
      alternative.type_binders[index],
      type_scope,
    )
  }
  let substitution = substitution.overlay(hidden_substitution)
  for index in 0..<alternative.value_binders.length() {
    let binder = alternative.value_binders[index]
    guard self.program.metadata.value_info(binder) is Some(binder_info) else {
      self.report(UnknownValue(binder))
      continue
    }
    let expected = info.payload_types[index].substitute(substitution)
    if !self.types_definitionally_equal(binder_info.type_, expected) {
      self.report(TypeMismatch(expected~, actual=binder_info.type_))
    }
    body_scope.values.push(binder)
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
    Primitive(F64) => false
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
  ignore(self.require_kind(expected, self.synthesize_type_kind(type_, scope)))
}

///|
fn VerifyContext::require_kind(
  self : VerifyContext,
  expected : Kind,
  actual : Kind,
) -> Bool {
  if actual == expected {
    true
  } else {
    self.report(KindMismatch(expected~, actual~))
    false
  }
}

///|
fn VerifyContext::verify_generic_argument_kind(
  self : VerifyContext,
  argument : GenericArgument,
  expected : Kind,
  scope : TypeScope,
) -> Bool {
  match argument {
    TypeArgument(type_) => {
      let actual = self.synthesize_type_kind(type_, scope)
      if expected == Effect {
        self.require_kind(expected, Type)
      } else {
        self.require_kind(expected, actual)
      }
    }
    EffectArgument(effect) => {
      self.verify_effect(effect, scope)
      self.require_kind(expected, Effect)
    }
  }
}

///|
/// Enforces a declared parameter's Effect Row Variable Flavor on the argument
/// standing in for it: an External-flavored variable admits only rows of
/// External Effects, so an argument containing any algebraic term cannot
/// inhabit it.
fn VerifyContext::verify_argument_flavor(
  self : VerifyContext,
  parameter : TypeParameterId,
  parameter_info : TypeParameterInfo,
  argument : GenericArgument,
) -> Unit {
  guard parameter_info.flavor is External && argument is EffectArgument(effect) else {
    return
  }
  if self.program.metadata.effect_term_is_algebraic(effect) {
    self.report(EffectFlavorMismatch(parameter~, argument=effect))
  }
}

///|
fn VerifyContext::verified_substitution(
  self : VerifyContext,
  parameters : Array[TypeParameterId],
  arguments : Array[GenericArgument],
  scope : TypeScope,
) -> TypeSubstitution {
  let substitution = TypeSubstitution::TypeSubstitution()
  for index in 0..<parameters.length().min(arguments.length()) {
    self.insert_verified_argument(
      substitution,
      parameters[index],
      arguments[index],
      scope,
    )
  }
  substitution
}

///|
fn VerifyContext::insert_verified_argument(
  self : VerifyContext,
  substitution : TypeSubstitution,
  parameter : TypeParameterId,
  argument : GenericArgument,
  scope : TypeScope,
) -> Unit {
  guard self.program.metadata.type_parameter_info(parameter)
    is Some(parameter_info) else {
    self.report(UnknownTypeParameter(parameter))
    return
  }
  self.verify_argument_flavor(parameter, parameter_info, argument)
  if self.verify_generic_argument_kind(argument, parameter_info.kind, scope) {
    substitution.insert_argument(parameter, argument)
  }
}

///|
fn VerifyContext::insert_verified_binder(
  self : VerifyContext,
  substitution : TypeSubstitution,
  parameter : TypeParameterId,
  binder : TypeParameterId,
  scope : TypeScope,
) -> Unit {
  guard self.program.metadata.type_parameter_info(parameter)
    is Some(parameter_info) else {
    self.report(UnknownTypeParameter(parameter))
    return
  }
  let argument = if parameter_info.kind == Effect {
    EffectArgument(Parameter(binder))
  } else {
    TypeArgument(Parameter(binder))
  }
  self.verify_argument_flavor(parameter, parameter_info, argument)
  if self.verify_generic_argument_kind(argument, parameter_info.kind, scope) {
    substitution.insert_argument(parameter, argument)
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
          ignore(
            self.verify_generic_argument_kind(
              argument,
              parameter_kinds[index],
              scope,
            ),
          )
        } else {
          match argument {
            TypeArgument(type_) =>
              ignore(self.synthesize_type_kind(type_, scope))
            EffectArgument(effect) => self.verify_effect(effect, scope)
          }
        }
      }
      // A nominal application pairs each argument with a declared parameter,
      // so the parameter's flavor constrains it here too. Higher-kinded
      // callees carry kinds without declarations, and flavor is a property of
      // declared row variables, not of kinds.
      if callee is Constructor(callee_id) &&
        self.program.metadata.type_info(callee_id) is Some(callee_info) {
        for index in 0..<arguments.length().min(callee_info.parameters.length()) {
          let parameter = callee_info.parameters[index]
          if self.program.metadata.type_parameter_info(parameter)
            is Some(parameter_info) {
            self.verify_argument_flavor(
              parameter,
              parameter_info,
              arguments[index],
            )
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
    Empty | Io => ()
    Singleton(id, arguments) =>
      ignore(self.verify_effect_singleton(id, arguments, scope))
    Parameter(parameter) => self.verify_effect_parameter(parameter, scope)
    Union(effects) =>
      for nested in effects {
        self.verify_effect(nested, scope)
      }
  }
}

///|
fn VerifyContext::verify_effect_singleton(
  self : VerifyContext,
  id : EffectId,
  arguments : Array[GenericArgument],
  scope : TypeScope,
) -> TypeSubstitution? {
  guard self.program.metadata.effect_info(id) is Some(info) else {
    self.report(UnknownEffect(id))
    return None
  }
  if info.parameters.length() != arguments.length() {
    self.report(
      ArityMismatch(
        expected=info.parameters.length(),
        actual=arguments.length(),
      ),
    )
  }
  Some(self.verified_substitution(info.parameters, arguments, scope))
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
fn pure_expr(type_ : Type) -> ExpressionFacts {
  { type_, effect: Empty }
}

///|
fn VerifyContext::effect_union(
  self : VerifyContext,
  effects : Array[Effect],
) -> Effect {
  self.canonicalize_effect(Union(effects))
}

///|
fn VerifyContext::require_effect_equals(
  self : VerifyContext,
  expected : Effect,
  actual : Effect,
) -> Unit {
  if !self.effects_definitionally_equal(actual, expected) {
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
  let open_rows : Array[Effect] = []
  let effect_terms = self.effect_terms(effect)
  for term in effect_terms {
    match term {
      Parameter(_) => {
        open_rows.push(term)
        residual.push(term)
      }
      _ =>
        if !handled.any(fn(handled_effect) {
            self.effects_definitionally_equal(term, handled_effect)
          }) {
          residual.push(term)
        }
    }
  }
  for handled_effect in handled {
    if effect_terms.any(fn(term) {
        self.effects_definitionally_equal(term, handled_effect)
      }) {
      continue
    }
    // An absent handled effect may still hide inside an open row, but only
    // when the row's flavor admits it: an Algebraic row variable ranges over
    // any row, while an External one ranges over rows this effect could not
    // be in unless the effect itself is non-algebraic.
    if !open_rows.any(fn(row) {
        self.program.metadata.effect_term_is_algebraic(row) ||
        !self.program.metadata.effect_term_is_algebraic(handled_effect)
      }) {
      self.report(EffectMismatch(expected=handled_effect, actual=effect))
    }
  }
  self.effect_union(residual)
}

///|
fn VerifyContext::effect_terms(
  self : VerifyContext,
  effect : Effect,
) -> Array[Effect] {
  match self.canonicalize_effect(effect) {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn VerifyContext::verify_literal(
  self : VerifyContext,
  literal : Literal,
) -> Unit {
  if literal is Char(value) && value.to_char() is None {
    self.report(InvalidCharLiteral(value))
  }
}

///|
fn Literal::type_(self : Literal) -> Type {
  match self {
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
