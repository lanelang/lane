///|
priv struct ValueClone {
  original : @buslane.ValueId
  cloned : @buslane.ValueId
}

///|
priv struct TypeParameterClone {
  original : @buslane.TypeParameterId
  cloned : @buslane.TypeParameterId
}

///|
priv struct InlineCloneContext {
  metadata : @buslane.MetadataRegistry
  substitution : @buslane.TypeSubstitution
  type_parameter_clones : Array[TypeParameterClone]
  value_clones : Array[ValueClone]
}

///|
fn InlineCloneContext::from_application(
  metadata : @buslane.MetadataRegistry,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> InlineCloneContext? {
  if parameters.length() != arguments.length() {
    return None
  }
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  for index in 0..<parameters.length() {
    substitution.insert_argument(parameters[index], arguments[index])
  }
  Some({ metadata, substitution, type_parameter_clones: [], value_clones: [] })
}

///|
fn InlineCloneContext::clone_function(
  self : InlineCloneContext,
  function : @buslane.FunctionExpr,
) -> @buslane.FunctionExpr raise CoreOptimizeError {
  let parameters = function.parameters.map(parameter => {
    self.clone_value(parameter)
  })
  {
    parameters,
    result_type: self.rewrite_type(function.result_type),
    body: self.clone_expr(function.body),
  }
}

///|
fn InlineCloneContext::clone_expr(
  self : InlineCloneContext,
  expression : @buslane.Expr,
) -> @buslane.Expr raise CoreOptimizeError {
  match expression {
    Ref(value) => Ref(self.remap_value(value))
    Literal(_) => expression
    Function(function) => Function(self.clone_function(function))
    Call(callee, arguments) =>
      Call(
        self.clone_expr(callee),
        arguments.map(argument => self.clone_expr(argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(parameter => self.clone_type_parameter(parameter)),
        self.clone_expr(body),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        self.clone_expr(callee),
        arguments.map(argument => self.substitute_argument(argument)),
      )
    Construct(construct) =>
      Construct({
        ..construct,
        type_arguments: construct.type_arguments.map(argument => {
          self.substitute_argument(argument)
        }),
        hidden_witnesses: construct.hidden_witnesses.map(argument => {
          self.substitute_argument(argument)
        }),
        payloads: construct.payloads.map(payload => self.clone_expr(payload)),
      })
    Let(value, initializer, body) => {
      let initializer = self.clone_expr(initializer)
      let cloned = self.clone_value(value)
      Let(cloned, initializer, self.clone_expr(body))
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.clone_callable_type_binders(binding.rhs)
      }
      for binding in bindings {
        ignore(self.clone_value(binding.id))
      }
      LetRec(
        bindings.map(binding => {
          id: self.remap_value(binding.id),
          rhs: self.clone_expr(binding.rhs),
        }),
        self.clone_expr(body),
      )
    }
    Match(match_) => {
      let scrutinee = self.clone_expr(match_.scrutinee)
      let binder = self.clone_value(match_.binder)
      let alternatives = match_.alternatives.map(alternative => {
        let type_binders = alternative.type_binders.map(parameter => {
          self.clone_type_parameter(parameter)
        })
        let value_binders = alternative.value_binders.map(value => {
          self.clone_value(value)
        })
        {
          ..alternative,
          type_binders,
          value_binders,
          body: self.clone_expr(alternative.body),
        }
      })
      Match({
        scrutinee,
        binder,
        result_type: self.rewrite_type(match_.result_type),
        alternatives,
      })
    }
    Perform(perform) =>
      Perform({
        ..perform,
        effect_arguments: perform.effect_arguments.map(argument => {
          self.substitute_argument(argument)
        }),
        hidden_witnesses: perform.hidden_witnesses.map(argument => {
          self.substitute_argument(argument)
        }),
        payloads: perform.payloads.map(payload => self.clone_expr(payload)),
      })
    Handle(handle) => {
      let body = self.clone_expr(handle.body)
      let result_binder = self.clone_value(handle.result_binder)
      let final_body = self.clone_expr(handle.final_body)
      let handlers : Array[@buslane.HandlerTable] = handle.handlers.map(table => {
        handled_effect: self.rewrite_effect(table.handled_effect),
        operations: table.operations.map(operation => {
          let type_binders = operation.type_binders.map(parameter => {
            self.clone_type_parameter(parameter)
          })
          let payload_binders = operation.payload_binders.map(value => {
            self.clone_value(value)
          })
          let resume_binder = self.clone_value(operation.resume_binder)
          {
            ..operation,
            type_binders,
            payload_binders,
            resume_binder,
            body: self.clone_expr(operation.body),
          }
        }),
      })
      Handle({
        body,
        result_binder,
        result_type: self.rewrite_type(handle.result_type),
        final_body,
        handlers,
      })
    }
    Resume(value) => Resume(self.remap_value(value))
  }
}

///|
/// Registers the binders that form a recursive callable's metadata type before
/// cloning its value identity. Recursive values must be in scope throughout
/// their group, so their metadata is allocated before their RHS is traversed.
fn InlineCloneContext::clone_callable_type_binders(
  self : InlineCloneContext,
  expression : @buslane.Expr,
) -> Unit raise CoreOptimizeError {
  match expression {
    TypeLambda(parameters, body) => {
      for parameter in parameters {
        ignore(self.clone_type_parameter(parameter))
      }
      self.clone_callable_type_binders(body)
    }
    _ => ()
  }
}

///|
fn InlineCloneContext::clone_type_parameter(
  self : InlineCloneContext,
  parameter : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId raise CoreOptimizeError {
  for clone in self.type_parameter_clones {
    if clone.original == parameter {
      return clone.cloned
    }
  }
  guard self.metadata.type_parameter_info(parameter) is Some(info) else {
    return parameter
  }
  let cloned = self.metadata.define_type_parameter(
    info.name.occurrence,
    info.kind,
    flavor=info.flavor,
  ) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
  let argument = match info.kind {
    Effect => @buslane.GenericArgument::EffectArgument(Parameter(cloned))
    Type | Function(_) => TypeArgument(Parameter(cloned))
  }
  self.substitution.insert_argument(parameter, argument)
  self.type_parameter_clones.push({ original: parameter, cloned })
  cloned
}

///|
fn InlineCloneContext::clone_value(
  self : InlineCloneContext,
  value : @buslane.ValueId,
) -> @buslane.ValueId raise CoreOptimizeError {
  for clone in self.value_clones {
    if clone.original == value {
      return clone.cloned
    }
  }
  guard self.metadata.value_info(value) is Some(info) else { return value }
  let cloned = self.metadata.define_value(
    info.name.occurrence,
    info.kind,
    self.rewrite_type(info.type_),
  ) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
  self.value_clones.push({ original: value, cloned })
  cloned
}

///|
fn InlineCloneContext::remap_value(
  self : InlineCloneContext,
  value : @buslane.ValueId,
) -> @buslane.ValueId {
  for clone in self.value_clones.rev_iter() {
    if clone.original == value {
      return clone.cloned
    }
  }
  value
}

///|
fn InlineCloneContext::substitute_argument(
  self : InlineCloneContext,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise CoreOptimizeError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.rewrite_type(type_))
    EffectArgument(effect) => EffectArgument(self.rewrite_effect(effect))
  }
}

///|
fn InlineCloneContext::rewrite_type(
  self : InlineCloneContext,
  type_ : @buslane.Type,
) -> @buslane.Type {
  self.rename_type_parameters(type_).substitute(self.substitution)
}

///|
fn InlineCloneContext::rewrite_effect(
  self : InlineCloneContext,
  effect : @buslane.Effect,
) -> @buslane.Effect raise CoreOptimizeError {
  core_canonicalize_effect(
    self.metadata,
    self.rename_effect_parameters(effect).substitute(self.substitution),
  )
}

///|
fn InlineCloneContext::rename_type_parameters(
  self : InlineCloneContext,
  type_ : @buslane.Type,
) -> @buslane.Type {
  match type_ {
    Primitive(_) | Constructor(_) => type_
    Parameter(parameter) => Parameter(self.renamed_type_parameter(parameter))
    Apply(callee, arguments) =>
      Apply(
        self.rename_type_parameters(callee),
        arguments.map(argument => self.rename_generic_argument(argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(parameter => self.renamed_type_parameter(parameter)),
        self.rename_type_parameters(body),
      )
    Function(parameters, result, effect) =>
      Function(
        parameters.map(parameter => self.rename_type_parameters(parameter)),
        self.rename_type_parameters(result),
        self.rename_effect_parameters(effect),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(parameter => self.renamed_type_parameter(parameter)),
        self.rename_type_parameters(body),
      )
  }
}

///|
fn InlineCloneContext::rename_generic_argument(
  self : InlineCloneContext,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(self.rename_type_parameters(type_))
    EffectArgument(effect) =>
      EffectArgument(self.rename_effect_parameters(effect))
  }
}

///|
fn InlineCloneContext::rename_effect_parameters(
  self : InlineCloneContext,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  match effect {
    Empty | Builtin(_) => effect
    Parameter(parameter) => Parameter(self.renamed_type_parameter(parameter))
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(argument => self.rename_generic_argument(argument)),
      )
    Union(effects) =>
      Union(effects.map(nested => self.rename_effect_parameters(nested)))
  }
}

///|
fn InlineCloneContext::renamed_type_parameter(
  self : InlineCloneContext,
  parameter : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  for clone in self.type_parameter_clones.rev_iter() {
    if clone.original == parameter {
      return clone.cloned
    }
  }
  parameter
}
