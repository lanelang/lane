///|
fn EffectSpecializer::rewrite_specialized_definition(
  self : EffectSpecializer,
  definition : EffectGenericDefinition,
  instance : EffectSpecializationInstance,
) -> @buslane.Expr raise SpecializationError {
  self.rewrite_specialized_definition_in_scope(
    definition,
    instance,
    self.root_scope(definition.id),
  )
}

///|
fn EffectSpecializer::rewrite_specialized_definition_in_scope(
  self : EffectSpecializer,
  definition : EffectGenericDefinition,
  instance : EffectSpecializationInstance,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise SpecializationError {
  let (parameters, body) = collect_type_lambda(definition.rhs)
  let retained = parameters.filter(parameter => {
    !instance.bindings.any(binding => binding.parameter == parameter)
  })
  let rewritten = self.rewrite_expr(
    body,
    scope.with_owner(definition.id).with_type_bindings(instance.bindings),
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
) -> @buslane.Expr raise SpecializationError {
  match expression {
    Ref(id) =>
      if scope.lookup_value(id) is Some(target) {
        Ref(target)
      } else if self.resolve_definition(scope, id) is Some(_) {
        guard self.program.metadata.value_info(id) is Some(info) else {
          raise RewriterInvariant(
            specialization_error_context(
              "effect-polymorphic value metadata is missing",
              source=Value(id),
              specialization_key=scope.type_bindings,
            ),
          )
        }
        raise UnsupportedProgram(
          specialization_error_context(
            "reachable effect-polymorphic value `\{info.name.occurrence}` must be explicitly applied",
            source=Value(id),
            specialization_key=scope.type_bindings,
          ),
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
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.rewrite_expr(body, scope))
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
) -> @buslane.Expr raise SpecializationError {
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
) -> @buslane.Expr raise SpecializationError {
  match effect_scheme_parameters(self.program.metadata, id) {
    Some(parameters) => {
      let site = SpecializationDefinitionSite::Local(
        owner=scope.owner,
        value=id,
      )
      let group = EffectLocalDefinitionGroup::{
        owner: scope.owner,
        definitions: [{ id, parameters, rhs: initializer, }],
      }
      let body_scope = scope.enter_scope()
      body_scope.bind_local_definition_group(group)
      let ambient_bindings = self.planned_ambient_bindings(
        site,
        scope.type_bindings,
      )
      let retained = self.plan.retains(
        self.program.metadata,
        site,
        ambient_bindings,
      )
      let mut retained_target = None
      let mut rewritten_initializer = None
      if retained {
        retained_target = Some(self.fresh_bound_value(id, body_scope))
        rewritten_initializer = Some(
          self.rewrite_expr(initializer, scope.with_owner(id)),
        )
      }
      let rewritten_body = self.rewrite_expr(body, body_scope)
      let specialized_bindings = []
      self.rewrite_local_instances(group, body_scope, specialized_bindings)
      let specialized_body = if specialized_bindings.is_empty() {
        rewritten_body
      } else {
        LetRec(specialized_bindings, rewritten_body)
      }
      match (retained_target, rewritten_initializer) {
        (Some(target), Some(rewritten)) =>
          Let(target, rewritten, specialized_body)
        _ => specialized_body
      }
    }
    None => {
      let rewritten_initializer = self.rewrite_expr(
        initializer,
        scope.with_owner(id),
      )
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
) -> @buslane.Expr raise SpecializationError {
  let recursive_scope = scope.enter_scope()
  let definitions = []
  let ordinary_bindings = []
  let ordinary_targets = []
  for binding in bindings {
    match effect_scheme_parameters(self.program.metadata, binding.id) {
      Some(parameters) => {
        definitions.push({ id: binding.id, parameters, rhs: binding.rhs, })
        let site = SpecializationDefinitionSite::Local(
          owner=scope.owner,
          value=binding.id,
        )
        let ambient_bindings = self.planned_ambient_bindings(
          site,
          scope.type_bindings,
        )
        if self.plan.retains(self.program.metadata, site, ambient_bindings) {
          ordinary_bindings.push(binding)
          ordinary_targets.push(
            self.fresh_bound_value(binding.id, recursive_scope),
          )
        }
      }
      None => {
        ordinary_bindings.push(binding)
        ordinary_targets.push(
          self.fresh_bound_value(binding.id, recursive_scope),
        )
      }
    }
  }
  let group = EffectLocalDefinitionGroup::{ owner: scope.owner, definitions, }
  if !definitions.is_empty() {
    recursive_scope.bind_local_definition_group(group)
  }
  let rewritten_bindings : Array[@buslane.RecursiveBinding] = []
  for index in 0..<ordinary_bindings.length() {
    rewritten_bindings.push({
      id: ordinary_targets[index],
      rhs: self.rewrite_expr(
        ordinary_bindings[index].rhs,
        recursive_scope.with_owner(ordinary_bindings[index].id),
      ),
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
) -> Unit raise SpecializationError {
  for instance in self.instances {
    guard instance.site is Local(owner~, value~) && owner == group.owner else {
      continue
    }
    let ambient_bindings = self.planned_ambient_bindings(
      instance.site,
      scope.type_bindings,
    )
    if !specialization_bindings_equal(
        self.program.metadata,
        instance.ambient_bindings,
        ambient_bindings,
      ) {
      continue
    }
    guard group.find_definition(value) is Some(definition) else {
      raise RewriterInvariant(
        specialization_error_context(
          "a requested local effect specialization has no lexical definition",
          site=instance.site,
          source=Value(value),
          specialization_key=instance.bindings,
        ),
      )
    }
    rewritten_bindings.push({
      id: instance.target,
      rhs: self.rewrite_specialized_definition_in_scope(
        definition, instance, scope,
      ),
    })
  }
}

///|
fn EffectSpecializer::rewrite_match(
  self : EffectSpecializer,
  match_ : @buslane.MatchExpr,
  scope : EffectRewriteScope,
) -> @buslane.Expr raise SpecializationError {
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
) -> @buslane.Expr raise SpecializationError {
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
) -> @buslane.Expr raise SpecializationError {
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
    let (definition, site) = match definition_site {
      TopLevel(definition) =>
        (definition, SpecializationDefinitionSite::TopLevel(source))
      Local(definition, site) => (definition, site)
    }
    let ambient_bindings = self.planned_ambient_bindings(
      site,
      scope.type_bindings,
    )
    let classified = classify_effect_generic_use(
      self.program.metadata,
      definition.parameters,
      arguments,
    )
    match classified.mode {
      Incomplete | Symbolic => {
        if !self.plan.retains(self.program.metadata, site, ambient_bindings) {
          raise RewriterInvariant(
            specialization_error_context(
              "a symbolic effect application is missing its planned generic definition",
              site~,
              source=Value(source),
              specialization_key=ambient_bindings,
            ),
          )
        }
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
      Concrete(bindings) => {
        let instance = self.planned_instance(site, ambient_bindings, bindings)
        if classified.retained_arguments.is_empty() {
          Ref(instance.target)
        } else {
          TypeApply(Ref(instance.target), classified.retained_arguments)
        }
      }
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
