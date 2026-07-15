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
priv struct EffectValueBinding {
  source : @buslane.ValueId
  target : @buslane.ValueId
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
          terms.push(Let(id, specializer.rewrite_expr(rhs, [], [], true)))
        }
      LetRec(bindings) => {
        let rewritten : Array[@buslane.RecursiveBinding] = []
        for binding in bindings {
          if specializer.is_reachable(binding.id) &&
            specializer.find_definition(binding.id) is None {
            rewritten.push({
              id: binding.id,
              rhs: specializer.rewrite_expr(binding.rhs, [], [], true),
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
  let (parameters, body) = collect_type_lambda(definition.rhs)
  let retained = parameters.filter(parameter => {
    !instance.bindings.any(binding => binding.parameter == parameter)
  })
  let rewritten = self.rewrite_expr(body, instance.bindings, [], true)
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
  type_bindings : Array[EffectSpecializationBinding],
  value_bindings : Array[EffectValueBinding],
  clone_values : Bool,
) -> @buslane.Expr raise ExecutableElaborationError {
  match expression {
    Ref(id) =>
      if find_effect_value_binding(value_bindings, id) is Some(target) {
        Ref(target)
      } else if self.find_definition(id) is Some(_) {
        raise UnsupportedEffectSpecialization(
          detail="a reachable effect-polymorphic value must be explicitly applied",
        )
      } else {
        Ref(id)
      }
    Literal(_) => expression
    Function(function) => {
      let next_values = value_bindings.copy()
      let parameters = function.parameters.map(parameter => {
        self.fresh_bound_value(
          parameter, type_bindings, next_values, clone_values,
        )
      })
      Function({
        parameters,
        result_type: self.specialize_type(function.result_type, type_bindings),
        body: self.rewrite_expr(
          function.body,
          type_bindings,
          next_values,
          clone_values,
        ),
      })
    }
    Call(callee, arguments) =>
      Call(
        self.rewrite_expr(callee, type_bindings, value_bindings, clone_values),
        arguments.map(argument => {
          self.rewrite_expr(
            argument, type_bindings, value_bindings, clone_values,
          )
        }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters,
        self.rewrite_expr(body, type_bindings, value_bindings, clone_values),
      )
    TypeApply(_, _) =>
      self.rewrite_type_application(
        expression, type_bindings, value_bindings, clone_values,
      )
    Construct(construct) => {
      let type_arguments = construct.type_arguments.map(argument => {
        self.specialize_argument(argument, type_bindings)
      })
      let (data_constructor, type_arguments) = self.specialize_constructor(
        construct.data_constructor,
        type_arguments,
      )
      Construct({
        data_constructor,
        type_arguments,
        hidden_witnesses: construct.hidden_witnesses.map(argument => {
          self.specialize_argument(argument, type_bindings)
        }),
        payloads: construct.payloads.map(payload => {
          self.rewrite_expr(
            payload, type_bindings, value_bindings, clone_values,
          )
        }),
      })
    }
    Let(id, initializer, body) => {
      let rewritten_initializer = self.rewrite_expr(
        initializer, type_bindings, value_bindings, clone_values,
      )
      let next_values = value_bindings.copy()
      let target = self.fresh_bound_value(
        id, type_bindings, next_values, clone_values,
      )
      Let(
        target,
        rewritten_initializer,
        self.rewrite_expr(body, type_bindings, next_values, clone_values),
      )
    }
    LetRec(bindings, body) => {
      let next_values = value_bindings.copy()
      let targets = bindings.map(binding => {
        self.fresh_bound_value(
          binding.id,
          type_bindings,
          next_values,
          clone_values,
        )
      })
      LetRec(
        bindings.mapi((index, binding) => {
          id: targets[index],
          rhs: self.rewrite_expr(
            binding.rhs,
            type_bindings,
            next_values,
            clone_values,
          ),
        }),
        self.rewrite_expr(body, type_bindings, next_values, clone_values),
      )
    }
    Match(match_) => {
      let next_values = value_bindings.copy()
      let binder = self.fresh_bound_value(
        match_.binder,
        type_bindings,
        next_values,
        clone_values,
      )
      Match({
        scrutinee: self.rewrite_expr(
          match_.scrutinee,
          type_bindings,
          value_bindings,
          clone_values,
        ),
        binder,
        result_type: self.specialize_type(match_.result_type, type_bindings),
        alternatives: match_.alternatives.map(alternative => {
          let alternative_values = next_values.copy()
          let value_binders = alternative.value_binders.map(value => {
            self.fresh_bound_value(
              value, type_bindings, alternative_values, clone_values,
            )
          })
          {
            alt_constructor: self.specialize_alt_constructor(
              alternative.alt_constructor,
              binder,
            ),
            type_binders: alternative.type_binders,
            value_binders,
            body: self.rewrite_expr(
              alternative.body,
              type_bindings,
              alternative_values,
              clone_values,
            ),
          }
        }),
      })
    }
    Perform(perform) =>
      Perform({
        operation: perform.operation,
        effect_arguments: perform.effect_arguments.map(argument => {
          self.specialize_argument(argument, type_bindings)
        }),
        hidden_witnesses: perform.hidden_witnesses.map(argument => {
          self.specialize_argument(argument, type_bindings)
        }),
        payloads: perform.payloads.map(payload => {
          self.rewrite_expr(
            payload, type_bindings, value_bindings, clone_values,
          )
        }),
      })
    Handle(handle) => {
      let final_values = value_bindings.copy()
      let result_binder = self.fresh_bound_value(
        handle.result_binder,
        type_bindings,
        final_values,
        clone_values,
      )
      Handle({
        body: self.rewrite_expr(
          handle.body,
          type_bindings,
          value_bindings,
          clone_values,
        ),
        result_binder,
        result_type: self.specialize_type(handle.result_type, type_bindings),
        final_body: self.rewrite_expr(
          handle.final_body,
          type_bindings,
          final_values,
          clone_values,
        ),
        handlers: handle.handlers.map(table => {
          handled_effect: self.specialize_effect(
            table.handled_effect,
            type_bindings,
          ),
          operations: table.operations.map(alternative => {
            let operation_values = value_bindings.copy()
            let payload_binders = alternative.payload_binders.map(value => {
              self.fresh_bound_value(
                value, type_bindings, operation_values, clone_values,
              )
            })
            let resume_binder = self.fresh_bound_value(
              alternative.resume_binder,
              type_bindings,
              operation_values,
              clone_values,
            )
            {
              operation: alternative.operation,
              type_binders: alternative.type_binders,
              payload_binders,
              resume_binder,
              body: self.rewrite_expr(
                alternative.body,
                type_bindings,
                operation_values,
                clone_values,
              ),
            }
          }),
        }),
      })
    }
    Resume(id) =>
      match find_effect_value_binding(value_bindings, id) {
        Some(target) => Resume(target)
        None => Resume(id)
      }
  }
}

///|
fn EffectSpecializer::rewrite_type_application(
  self : EffectSpecializer,
  expression : @buslane.Expr,
  type_bindings : Array[EffectSpecializationBinding],
  value_bindings : Array[EffectValueBinding],
  clone_values : Bool,
) -> @buslane.Expr raise ExecutableElaborationError {
  let groups : Array[Array[@buslane.GenericArgument]] = []
  let base = collect_type_application_groups(expression, groups)
  let arguments = []
  for group in groups {
    for argument in group {
      arguments.push(self.specialize_argument(argument, type_bindings))
    }
  }
  if base is Ref(source) && self.find_definition(source) is Some(definition) {
    if arguments.length() < definition.parameters.length() {
      raise UnsupportedEffectSpecialization(
        detail="a reachable effect-polymorphic value is only partially applied",
      )
    }
    let instance = self.require_instance(definition, arguments)
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
    let rewritten_base = self.rewrite_expr(
      base, type_bindings, value_bindings, clone_values,
    )
    let mut rewritten = rewritten_base
    for group in groups {
      rewritten = TypeApply(
        rewritten,
        group.map(argument => self.specialize_argument(argument, type_bindings)),
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
  for instance in self.instances {
    if instance.source == definition.id && instance.bindings == bindings {
      return instance
    }
  }
  guard self.program.metadata.value_info(definition.id) is Some(info) else {
    raise UnsupportedEffectSpecialization(
      detail="effect-polymorphic value metadata is missing",
    )
  }
  let specialized_type = self.specialize_type_scheme(info.type_, bindings)
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
  self.instances.push(instance)
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
  type_bindings : Array[EffectSpecializationBinding],
  value_bindings : Array[EffectValueBinding],
  clone_values : Bool,
) -> @buslane.ValueId raise ExecutableElaborationError {
  if !clone_values {
    return source
  }
  guard self.program.metadata.value_info(source) is Some(info) else {
    raise UnsupportedEffectSpecialization(
      detail="a specialized local value is missing metadata",
    )
  }
  let target = self.program.metadata.define_value(
    info.name.occurrence,
    info.kind,
    self.specialize_type(info.type_, type_bindings),
  )
  value_bindings.push({ source, target })
  target
}

///|
fn find_effect_value_binding(
  bindings : Array[EffectValueBinding],
  source : @buslane.ValueId,
) -> @buslane.ValueId? {
  for binding in bindings.rev_iter() {
    if binding.source == source {
      return Some(binding.target)
    }
  }
  None
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
    Empty | Singleton(_, _) => false
    Parameter(_) => true
    Union(effects) => effects.any(effect_contains_parameter)
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
