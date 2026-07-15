///|
priv struct EffectGenericDefinition {
  id : @buslane.ValueId
  parameters : Array[@buslane.TypeParameterId]
  rhs : @buslane.Expr
}

///|
priv struct EffectSpecializationBinding {
  parameter : @buslane.TypeParameterId
  argument : @buslane.GenericArgument
} derive(Eq)

///|
priv struct EffectSpecializationInstance {
  source : @buslane.ValueId
  bindings : Array[EffectSpecializationBinding]
  target : @buslane.ValueId
}

///|
priv struct EffectLocalDefinitionGroup {
  definitions : Array[EffectGenericDefinition]
  instances : Array[EffectSpecializationInstance]
}

///|
priv enum EffectGenericDefinitionSite {
  TopLevel(EffectGenericDefinition)
  Local(EffectGenericDefinition, Array[EffectSpecializationInstance])
}

///|
priv struct EffectValueBinding {
  source : @buslane.ValueId
  target : @buslane.ValueId
}

///|
priv struct EffectRewriteScope {
  type_bindings : Array[EffectSpecializationBinding]
  value_bindings : Array[EffectValueBinding]
  local_definition_groups : Array[EffectLocalDefinitionGroup]
}

///|
fn EffectRewriteScope::new(
  type_bindings : Array[EffectSpecializationBinding],
) -> EffectRewriteScope {
  { type_bindings, value_bindings: [], local_definition_groups: [] }
}

///|
fn EffectRewriteScope::enter_scope(
  self : EffectRewriteScope,
) -> EffectRewriteScope {
  {
    type_bindings: self.type_bindings,
    value_bindings: self.value_bindings.copy(),
    local_definition_groups: self.local_definition_groups.copy(),
  }
}

///|
fn EffectRewriteScope::with_type_bindings(
  self : EffectRewriteScope,
  bindings : Array[EffectSpecializationBinding],
) -> EffectRewriteScope {
  let type_bindings = self.type_bindings.copy()
  type_bindings.append(bindings)
  {
    type_bindings,
    value_bindings: self.value_bindings.copy(),
    local_definition_groups: self.local_definition_groups.copy(),
  }
}

///|
fn EffectRewriteScope::lookup_value(
  self : EffectRewriteScope,
  source : @buslane.ValueId,
) -> @buslane.ValueId? {
  for binding in self.value_bindings.rev_iter() {
    if binding.source == source {
      return Some(binding.target)
    }
  }
  None
}

///|
fn EffectRewriteScope::bind_value(
  self : EffectRewriteScope,
  source : @buslane.ValueId,
  target : @buslane.ValueId,
) -> Unit {
  self.value_bindings.push({ source, target })
}

///|
fn EffectRewriteScope::bind_local_definition_group(
  self : EffectRewriteScope,
  group : EffectLocalDefinitionGroup,
) -> Unit {
  self.local_definition_groups.push(group)
}

///|
fn EffectRewriteScope::find_local_definition(
  self : EffectRewriteScope,
  id : @buslane.ValueId,
) -> (EffectGenericDefinition, Array[EffectSpecializationInstance])? {
  for group in self.local_definition_groups.rev_iter() {
    for definition in group.definitions {
      if definition.id == id {
        return Some((definition, group.instances))
      }
    }
  }
  None
}

///|
priv struct EffectDataConstructorBinding {
  source : @buslane.DataConId
  target : @buslane.DataConId
}

///|
priv struct EffectDataInstance {
  source : @buslane.TypeId
  bindings : Array[EffectSpecializationBinding]
  target : @buslane.TypeId
  constructors : Array[EffectDataConstructorBinding]
}

///|
priv struct EffectSpecializer {
  program : @buslane.Program
  definitions : Array[EffectGenericDefinition]
  instances : Array[EffectSpecializationInstance]
  data_instances : Array[EffectDataInstance]
  reachable : Array[Bool]
}

///|
fn specialize_reachable_effects(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> @buslane.Program raise ExecutableElaborationError {
  let roots = effect_specialization_initializer_roots(program)
  let occurrence = @occurrence.analyze({ program, entry, roots })
  let reachable = occurrence.facts.map(fact => fact.reachable_from_entry)
  let specializer = EffectSpecializer::{
    program,
    definitions: collect_effect_generic_definitions(program),
    instances: [],
    data_instances: [],
    reachable,
  }
  if specializer.find_definition(entry) is Some(_) {
    raise UnsupportedEffectSpecialization(
      detail="an executable entry cannot retain effect parameters",
    )
  }
  let terms : Array[@buslane.TopTerm] = []
  for term in program.terms {
    match term {
      Let(id, rhs) =>
        if specializer.is_reachable(id) &&
          specializer.find_definition(id) is None {
          terms.push(
            Let(id, specializer.rewrite_expr(rhs, EffectRewriteScope::new([]))),
          )
        }
      LetRec(bindings) => {
        let rewritten : Array[@buslane.RecursiveBinding] = []
        for binding in bindings {
          if specializer.is_reachable(binding.id) &&
            specializer.find_definition(binding.id) is None {
            rewritten.push({
              id: binding.id,
              rhs: specializer.rewrite_expr(
                binding.rhs,
                EffectRewriteScope::new([]),
              ),
            })
          }
        }
        if !rewritten.is_empty() {
          terms.push(LetRec(rewritten))
        }
      }
      External(id) =>
        if specializer.is_reachable(id) {
          terms.push(External(id))
        }
    }
  }
  let specialized_bindings : Array[@buslane.RecursiveBinding] = []
  let mut index = 0
  while index < specializer.instances.length() {
    let instance = specializer.instances[index]
    guard specializer.find_definition(instance.source) is Some(definition) else {
      raise UnsupportedEffectSpecialization(
        detail="a requested effect specialization has no top-level definition",
      )
    }
    specialized_bindings.push({
      id: instance.target,
      rhs: specializer.rewrite_specialized_definition(definition, instance),
    })
    index = index + 1
  }
  if !specialized_bindings.is_empty() {
    terms.push(LetRec(specialized_bindings))
  }
  { metadata: program.metadata, terms }
}

///|
fn collect_effect_generic_definitions(
  program : @buslane.Program,
) -> Array[EffectGenericDefinition] {
  let definitions = []
  for term in program.terms {
    match term {
      Let(id, rhs) =>
        if effect_scheme_parameters(program.metadata, id) is Some(parameters) {
          definitions.push({ id, parameters, rhs })
        }
      LetRec(bindings) =>
        for binding in bindings {
          if effect_scheme_parameters(program.metadata, binding.id)
            is Some(parameters) {
            definitions.push({ id: binding.id, parameters, rhs: binding.rhs })
          }
        }
      External(_) => ()
    }
  }
  definitions
}

///|
fn effect_scheme_parameters(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
) -> Array[@buslane.TypeParameterId]? {
  guard metadata.value_info(id) is Some(info) else { return None }
  let parameters = collect_forall_parameters(info.type_)
  if parameters.any(parameter => type_parameter_is_effect(metadata, parameter)) {
    Some(parameters)
  } else {
    None
  }
}

///|
fn collect_forall_parameters(
  type_ : @buslane.Type,
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  collect_forall_parameters_into(type_, parameters)
  parameters
}

///|
fn collect_forall_parameters_into(
  type_ : @buslane.Type,
  parameters : Array[@buslane.TypeParameterId],
) -> Unit {
  if type_ is Forall(next, body) {
    parameters.append(next)
    collect_forall_parameters_into(body, parameters)
  }
}

///|
fn type_parameter_is_effect(
  metadata : @buslane.MetadataRegistry,
  parameter : @buslane.TypeParameterId,
) -> Bool {
  match metadata.type_parameter_info(parameter) {
    Some({ kind: Effect, .. }) => true
    _ => false
  }
}

///|
fn EffectSpecializer::find_definition(
  self : EffectSpecializer,
  id : @buslane.ValueId,
) -> EffectGenericDefinition? {
  for definition in self.definitions {
    if definition.id == id {
      return Some(definition)
    }
  }
  None
}

///|
fn EffectLocalDefinitionGroup::find_definition(
  self : EffectLocalDefinitionGroup,
  id : @buslane.ValueId,
) -> EffectGenericDefinition? {
  for definition in self.definitions {
    if definition.id == id {
      return Some(definition)
    }
  }
  None
}

///|
fn EffectSpecializer::resolve_definition(
  self : EffectSpecializer,
  scope : EffectRewriteScope,
  id : @buslane.ValueId,
) -> EffectGenericDefinitionSite? {
  match scope.find_local_definition(id) {
    Some((definition, instances)) => Some(Local(definition, instances))
    None => self.find_definition(id).map(definition => TopLevel(definition))
  }
}

///|
fn EffectSpecializer::is_reachable(
  self : EffectSpecializer,
  id : @buslane.ValueId,
) -> Bool {
  self.reachable.get(id.index).unwrap_or(false)
}

///|
fn EffectSpecializer::rewrite_specialized_definition(
  self : EffectSpecializer,
  definition : EffectGenericDefinition,
  instance : EffectSpecializationInstance,
) -> @buslane.Expr raise ExecutableElaborationError {
  self.rewrite_specialized_definition_in_scope(
    definition,
    instance,
    EffectRewriteScope::new([]),
  )
}

///|
fn EffectSpecializer::rewrite_specialized_definition_in_scope(
  self : EffectSpecializer,
  definition : EffectGenericDefinition,
  instance : EffectSpecializationInstance,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let (parameters, body) = collect_type_lambda(definition.rhs)
  let retained = parameters.filter(parameter => {
    !instance.bindings.any(binding => binding.parameter == parameter)
  })
  let rewritten = self.rewrite_expr(
    body,
    scope.with_type_bindings(instance.bindings),
  )
  if retained.is_empty() {
    rewritten
  } else {
    TypeLambda(retained, rewritten)
  }
}

///|
fn collect_type_lambda(
  expression : @buslane.Expr,
) -> (Array[@buslane.TypeParameterId], @buslane.Expr) {
  let parameters = []
  let body = collect_type_lambda_into(expression, parameters)
  (parameters, body)
}

///|
fn collect_type_lambda_into(
  expression : @buslane.Expr,
  parameters : Array[@buslane.TypeParameterId],
) -> @buslane.Expr {
  match expression {
    TypeLambda(next, body) => {
      parameters.append(next)
      collect_type_lambda_into(body, parameters)
    }
    _ => expression
  }
}

///|
fn EffectSpecializer::rewrite_expr(
  self : EffectSpecializer,
  expression : @buslane.Expr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  match expression {
    Ref(id) =>
      if scope.lookup_value(id) is Some(target) {
        Ref(target)
      } else if self.resolve_definition(scope, id) is Some(_) {
        raise UnsupportedEffectSpecialization(
          detail="a reachable effect-polymorphic value must be explicitly applied",
        )
      } else {
        Ref(id)
      }
    Literal(_) => expression
    Function(function) => self.rewrite_function(function, scope)
    Call(callee, arguments) =>
      Call(
        self.rewrite_expr(callee, scope),
        arguments.map(argument => self.rewrite_expr(argument, scope)),
      )
    TypeLambda(parameters, body) => {
      if parameters.any(parameter => {
          type_parameter_is_effect(self.program.metadata, parameter)
        }) {
        raise UnsupportedEffectSpecialization(
          detail="an executable effect-polymorphic type lambda must be bound before specialization",
        )
      }
      TypeLambda(parameters, self.rewrite_expr(body, scope))
    }
    TypeApply(_, _) => self.rewrite_type_application(expression, scope)
    Construct(construct) => {
      let type_arguments = construct.type_arguments.map(argument => {
        self.specialize_argument(argument, scope.type_bindings)
      })
      let (data_constructor, type_arguments) = self.specialize_constructor(
        construct.data_constructor,
        type_arguments,
      )
      Construct({
        data_constructor,
        type_arguments,
        hidden_witnesses: construct.hidden_witnesses.map(argument => {
          self.specialize_argument(argument, scope.type_bindings)
        }),
        payloads: construct.payloads.map(payload => {
          self.rewrite_expr(payload, scope)
        }),
      })
    }
    Let(id, initializer, body) => self.rewrite_let(id, initializer, body, scope)
    LetRec(bindings, body) => self.rewrite_let_rec(bindings, body, scope)
    Match(match_) => self.rewrite_match(match_, scope)
    Perform(perform) =>
      Perform({
        operation: perform.operation,
        effect_arguments: perform.effect_arguments.map(argument => {
          self.specialize_argument(argument, scope.type_bindings)
        }),
        hidden_witnesses: perform.hidden_witnesses.map(argument => {
          self.specialize_argument(argument, scope.type_bindings)
        }),
        payloads: perform.payloads.map(payload => {
          self.rewrite_expr(payload, scope)
        }),
      })
    Handle(handle) => self.rewrite_handle(handle, scope)
    Resume(id) =>
      match scope.lookup_value(id) {
        Some(target) => Resume(target)
        None => Resume(id)
      }
  }
}

///|
fn EffectSpecializer::rewrite_function(
  self : EffectSpecializer,
  function : @buslane.FunctionExpr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let body_scope = scope.enter_scope()
  let parameters = function.parameters.map(parameter => {
    self.fresh_bound_value(parameter, body_scope)
  })
  Function({
    parameters,
    result_type: self.specialize_type(function.result_type, scope.type_bindings),
    body: self.rewrite_expr(function.body, body_scope),
  })
}

///|
fn EffectSpecializer::rewrite_let(
  self : EffectSpecializer,
  id : @buslane.ValueId,
  initializer : @buslane.Expr,
  body : @buslane.Expr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  match effect_scheme_parameters(self.program.metadata, id) {
    Some(parameters) => {
      let group = EffectLocalDefinitionGroup::{
        definitions: [{ id, parameters, rhs: initializer }],
        instances: [],
      }
      let body_scope = scope.enter_scope()
      body_scope.bind_local_definition_group(group)
      let rewritten_body = self.rewrite_expr(body, body_scope)
      let specialized_bindings = []
      self.rewrite_local_instances(group, body_scope, specialized_bindings)
      if specialized_bindings.is_empty() {
        rewritten_body
      } else {
        LetRec(specialized_bindings, rewritten_body)
      }
    }
    None => {
      let rewritten_initializer = self.rewrite_expr(initializer, scope)
      let body_scope = scope.enter_scope()
      let target = self.fresh_bound_value(id, body_scope)
      Let(target, rewritten_initializer, self.rewrite_expr(body, body_scope))
    }
  }
}

///|
fn EffectSpecializer::rewrite_let_rec(
  self : EffectSpecializer,
  bindings : Array[@buslane.RecursiveBinding],
  body : @buslane.Expr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let recursive_scope = scope.enter_scope()
  let definitions = []
  let ordinary_bindings = []
  let ordinary_targets = []
  for binding in bindings {
    match effect_scheme_parameters(self.program.metadata, binding.id) {
      Some(parameters) =>
        definitions.push({ id: binding.id, parameters, rhs: binding.rhs })
      None => {
        ordinary_bindings.push(binding)
        ordinary_targets.push(
          self.fresh_bound_value(binding.id, recursive_scope),
        )
      }
    }
  }
  let group = EffectLocalDefinitionGroup::{ definitions, instances: [] }
  if !definitions.is_empty() {
    recursive_scope.bind_local_definition_group(group)
  }
  let rewritten_bindings : Array[@buslane.RecursiveBinding] = []
  for index in 0..<ordinary_bindings.length() {
    rewritten_bindings.push({
      id: ordinary_targets[index],
      rhs: self.rewrite_expr(ordinary_bindings[index].rhs, recursive_scope),
    })
  }
  let rewritten_body = self.rewrite_expr(body, recursive_scope)
  self.rewrite_local_instances(group, recursive_scope, rewritten_bindings)
  if rewritten_bindings.is_empty() {
    rewritten_body
  } else {
    LetRec(rewritten_bindings, rewritten_body)
  }
}

///|
fn EffectSpecializer::rewrite_local_instances(
  self : EffectSpecializer,
  group : EffectLocalDefinitionGroup,
  scope : EffectRewriteScope,
  rewritten_bindings : Array[@buslane.RecursiveBinding],
) -> Unit raise ExecutableElaborationError {
  let mut index = 0
  while index < group.instances.length() {
    let instance = group.instances[index]
    guard group.find_definition(instance.source) is Some(definition) else {
      raise UnsupportedEffectSpecialization(
        detail="a requested local effect specialization has no lexical definition",
      )
    }
    rewritten_bindings.push({
      id: instance.target,
      rhs: self.rewrite_specialized_definition_in_scope(
        definition, instance, scope,
      ),
    })
    index = index + 1
  }
}

///|
fn EffectSpecializer::rewrite_match(
  self : EffectSpecializer,
  match_ : @buslane.MatchExpr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let match_scope = scope.enter_scope()
  let binder = self.fresh_bound_value(match_.binder, match_scope)
  Match({
    scrutinee: self.rewrite_expr(match_.scrutinee, scope),
    binder,
    result_type: self.specialize_type(match_.result_type, scope.type_bindings),
    alternatives: match_.alternatives.map(alternative => {
      let alternative_scope = match_scope.enter_scope()
      let value_binders = alternative.value_binders.map(value => {
        self.fresh_bound_value(value, alternative_scope)
      })
      {
        alt_constructor: self.specialize_alt_constructor(
          alternative.alt_constructor,
          binder,
        ),
        type_binders: alternative.type_binders,
        value_binders,
        body: self.rewrite_expr(alternative.body, alternative_scope),
      }
    }),
  })
}

///|
fn EffectSpecializer::rewrite_handle(
  self : EffectSpecializer,
  handle : @buslane.HandleExpr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let final_scope = scope.enter_scope()
  let result_binder = self.fresh_bound_value(handle.result_binder, final_scope)
  Handle({
    body: self.rewrite_expr(handle.body, scope),
    result_binder,
    result_type: self.specialize_type(handle.result_type, scope.type_bindings),
    final_body: self.rewrite_expr(handle.final_body, final_scope),
    handlers: handle.handlers.map(table => {
      handled_effect: self.specialize_effect(
        table.handled_effect,
        scope.type_bindings,
      ),
      operations: table.operations.map(alternative => {
        let operation_scope = scope.enter_scope()
        let payload_binders = alternative.payload_binders.map(value => {
          self.fresh_bound_value(value, operation_scope)
        })
        let resume_binder = self.fresh_bound_value(
          alternative.resume_binder,
          operation_scope,
        )
        {
          operation: alternative.operation,
          type_binders: alternative.type_binders,
          payload_binders,
          resume_binder,
          body: self.rewrite_expr(alternative.body, operation_scope),
        }
      }),
    }),
  })
}

///|
fn EffectSpecializer::rewrite_type_application(
  self : EffectSpecializer,
  expression : @buslane.Expr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise ExecutableElaborationError {
  let groups : Array[Array[@buslane.GenericArgument]] = []
  let base = collect_type_application_groups(expression, groups)
  let arguments = []
  for group in groups {
    for argument in group {
      arguments.push(self.specialize_argument(argument, scope.type_bindings))
    }
  }
  if base is Ref(source) &&
    self.resolve_definition(scope, source) is Some(definition_site) {
    let (definition, instances, ambient_bindings) = match definition_site {
      TopLevel(definition) => (definition, self.instances, [])
      Local(definition, instances) =>
        (definition, instances, scope.type_bindings)
    }
    if arguments.length() < definition.parameters.length() {
      raise UnsupportedEffectSpecialization(
        detail="a reachable effect-polymorphic value is only partially applied",
      )
    }
    let instance = self.require_instance(
      definition, arguments, instances, ambient_bindings,
    )
    let retained_arguments = []
    for index in 0..<definition.parameters.length() {
      if !type_parameter_is_effect(
          self.program.metadata,
          definition.parameters[index],
        ) {
        retained_arguments.push(arguments[index])
      }
    }
    for index in definition.parameters.length()..<arguments.length() {
      retained_arguments.push(arguments[index])
    }
    if retained_arguments.is_empty() {
      Ref(instance.target)
    } else {
      TypeApply(Ref(instance.target), retained_arguments)
    }
  } else {
    let rewritten_base = self.rewrite_expr(base, scope)
    let mut rewritten = rewritten_base
    for group in groups {
      rewritten = TypeApply(
        rewritten,
        group.map(argument => {
          self.specialize_argument(argument, scope.type_bindings)
        }),
      )
    }
    rewritten
  }
}

///|
fn collect_type_application_groups(
  expression : @buslane.Expr,
  groups : Array[Array[@buslane.GenericArgument]],
) -> @buslane.Expr {
  match expression {
    TypeApply(callee, arguments) => {
      let base = collect_type_application_groups(callee, groups)
      groups.push(arguments)
      base
    }
    _ => expression
  }
}

///|
fn EffectSpecializer::require_instance(
  self : EffectSpecializer,
  definition : EffectGenericDefinition,
  arguments : Array[@buslane.GenericArgument],
  instances : Array[EffectSpecializationInstance],
  ambient_bindings : Array[EffectSpecializationBinding],
) -> EffectSpecializationInstance raise ExecutableElaborationError {
  let bindings = []
  for index in 0..<definition.parameters.length() {
    let parameter = definition.parameters[index]
    if type_parameter_is_effect(self.program.metadata, parameter) {
      guard arguments[index] is EffectArgument(effect) else {
        raise UnsupportedEffectSpecialization(
          detail="an effect parameter requires an effect argument",
        )
      }
      let specialized = abstract_effect_type_arguments(
        effect.canonicalize(),
        definition.parameters,
        arguments,
        self.program.metadata,
      )
      if effect_contains_parameter(specialized) {
        raise UnsupportedEffectSpecialization(
          detail="a reachable effect specialization must have a concrete residual effect",
        )
      }
      bindings.push({ parameter, argument: EffectArgument(specialized) })
    }
  }
  for instance in instances {
    if instance.source == definition.id && instance.bindings == bindings {
      return instance
    }
  }
  guard self.program.metadata.value_info(definition.id) is Some(info) else {
    raise UnsupportedEffectSpecialization(
      detail="effect-polymorphic value metadata is missing",
    )
  }
  let specialized_bindings = ambient_bindings.copy()
  specialized_bindings.append(bindings)
  let specialized_type = self.specialize_type_scheme(
    info.type_,
    specialized_bindings,
  )
  let target = self.program.metadata.define_value(
    "\{info.name.occurrence}%effect",
    info.kind,
    specialized_type,
  )
  let instance = EffectSpecializationInstance::{
    source: definition.id,
    bindings,
    target,
  }
  instances.push(instance)
  instance
}

///|
fn EffectSpecializer::specialize_type_scheme(
  self : EffectSpecializer,
  type_ : @buslane.Type,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Type raise ExecutableElaborationError {
  let parameters = collect_forall_parameters(type_)
  let mut body = type_
  while body is Forall(_, next) {
    body = next
  }
  let retained = parameters.filter(parameter => {
    !bindings.any(binding => binding.parameter == parameter)
  })
  let specialized = self.specialize_type(body, bindings)
  if retained.is_empty() {
    specialized
  } else {
    Forall(retained, specialized)
  }
}

///|
fn EffectSpecializer::fresh_bound_value(
  self : EffectSpecializer,
  source : @buslane.ValueId,
  scope : EffectRewriteScope,
) -> @buslane.ValueId raise ExecutableElaborationError {
  guard self.program.metadata.value_info(source) is Some(info) else {
    raise UnsupportedEffectSpecialization(
      detail="a specialized local value is missing metadata",
    )
  }
  let target = self.program.metadata.define_value(
    info.name.occurrence,
    info.kind,
    self.specialize_type(info.type_, scope.type_bindings),
  )
  scope.bind_value(source, target)
  target
}

///|
fn raw_substitute_specialized_type(
  type_ : @buslane.Type,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Type {
  type_.substitute(effect_specialization_substitution(bindings))
}

///|
fn raw_substitute_specialized_argument(
  argument : @buslane.GenericArgument,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) =>
      TypeArgument(raw_substitute_specialized_type(type_, bindings))
    EffectArgument(effect) =>
      EffectArgument(raw_substitute_specialized_effect(effect, bindings))
  }
}

///|
fn raw_substitute_specialized_effect(
  effect : @buslane.Effect,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Effect {
  guard @buslane.Type::Function([], Primitive(Unit), effect).substitute(
      effect_specialization_substitution(bindings),
    )
    is Function(_, _, specialized) else {
    abort("effect substitution must preserve a function type")
  }
  specialized.canonicalize()
}

///|
fn effect_specialization_substitution(
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.TypeSubstitution {
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for binding in bindings {
    substitution.insert_argument(binding.parameter, binding.argument)
  }
  substitution
}

///|
fn effect_contains_parameter(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty => false
    Parameter(_) => true
    Singleton(_, arguments) =>
      arguments.any(generic_argument_contains_effect_parameter)
    Union(effects) => effects.any(effect_contains_parameter)
  }
}

///|
fn generic_argument_contains_effect_parameter(
  argument : @buslane.GenericArgument,
) -> Bool {
  match argument {
    TypeArgument(type_) => type_contains_effect_parameter(type_)
    EffectArgument(effect) => effect_contains_parameter(effect)
  }
}

///|
fn type_contains_effect_parameter(type_ : @buslane.Type) -> Bool {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => false
    Apply(callee, arguments) =>
      type_contains_effect_parameter(callee) ||
      arguments.any(generic_argument_contains_effect_parameter)
    TypeLambda(_, body) | Forall(_, body) =>
      type_contains_effect_parameter(body)
    Function(parameters, result, effect) =>
      parameters.any(type_contains_effect_parameter) ||
      type_contains_effect_parameter(result) ||
      effect_contains_parameter(effect)
  }
}

///|
fn abstract_effect_type_arguments(
  effect : @buslane.Effect,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.Effect {
  match effect {
    Empty | Parameter(_) => effect
    Singleton(id, effect_arguments) =>
      Singleton(
        id,
        effect_arguments.map(argument => {
          abstract_generic_type_argument(
            argument, parameters, arguments, metadata,
          )
        }),
      )
    Union(effects) =>
      @buslane.Effect::Union(
        effects.map(effect => {
          abstract_effect_type_arguments(
            effect, parameters, arguments, metadata,
          )
        }),
      ).canonicalize()
  }
}

///|
fn abstract_generic_type_argument(
  argument : @buslane.GenericArgument,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) =>
      TypeArgument(
        abstract_specialized_type(type_, parameters, arguments, metadata),
      )
    EffectArgument(effect) =>
      EffectArgument(
        abstract_effect_type_arguments(effect, parameters, arguments, metadata),
      )
  }
}

///|
fn abstract_specialized_type(
  type_ : @buslane.Type,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
  metadata : @buslane.MetadataRegistry,
) -> @buslane.Type {
  for index in 0..<parameters.length() {
    if !type_parameter_is_effect(metadata, parameters[index]) &&
      arguments[index] is TypeArgument(actual) &&
      type_ == actual {
      return Parameter(parameters[index])
    }
  }
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => type_
    Apply(callee, nested) =>
      Apply(
        abstract_specialized_type(callee, parameters, arguments, metadata),
        nested.map(argument => {
          abstract_generic_type_argument(
            argument, parameters, arguments, metadata,
          )
        }),
      )
    TypeLambda(bound, body) =>
      TypeLambda(
        bound,
        abstract_specialized_type(body, parameters, arguments, metadata),
      )
    Function(inputs, result, effect) =>
      Function(
        inputs.map(input => {
          abstract_specialized_type(input, parameters, arguments, metadata)
        }),
        abstract_specialized_type(result, parameters, arguments, metadata),
        abstract_effect_type_arguments(effect, parameters, arguments, metadata),
      )
    Forall(bound, body) =>
      Forall(
        bound,
        abstract_specialized_type(body, parameters, arguments, metadata),
      )
  }
}

///|
fn effect_specialization_initializer_roots(
  program : @buslane.Program,
) -> Array[@buslane.ValueId] {
  let roots = []
  for term in program.terms {
    match term {
      Let(id, expression) =>
        if !is_static_top_level_expression(expression) {
          roots.push(id)
        }
      LetRec(bindings) =>
        if !bindings.all(binding => is_static_top_level_expression(binding.rhs)) {
          for binding in bindings {
            roots.push(binding.id)
          }
        }
      External(_) => ()
    }
  }
  roots
}
