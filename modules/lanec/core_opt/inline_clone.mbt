///|
priv struct GenericBinding {
  parameter : @buslane.TypeParameterId
  argument : @buslane.GenericArgument
}

///|
priv struct ValueClone {
  original : @buslane.ValueId
  cloned : @buslane.ValueId
}

///|
priv struct InlineCloneContext {
  metadata : @buslane.MetadataRegistry
  substitution : @buslane.TypeSubstitution
  generic_bindings : Array[GenericBinding]
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
  let generic_bindings = []
  for index in 0..<parameters.length() {
    substitution.insert_argument(parameters[index], arguments[index])
    generic_bindings.push({
      parameter: parameters[index],
      argument: arguments[index],
    })
  }
  Some({ metadata, substitution, generic_bindings, value_clones: [] })
}

///|
fn InlineCloneContext::clone_function(
  self : InlineCloneContext,
  function : @buslane.FunctionExpr,
) -> @buslane.FunctionExpr {
  let parameters = function.parameters.map(parameter => {
    self.clone_value(parameter)
  })
  {
    parameters,
    result_type: function.result_type.substitute(self.substitution),
    body: self.clone_expr(function.body),
  }
}

///|
fn InlineCloneContext::clone_expr(
  self : InlineCloneContext,
  expression : @buslane.Expr,
) -> @buslane.Expr {
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
      TypeLambda(parameters, self.clone_expr(body))
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
        let value_binders = alternative.value_binders.map(value => {
          self.clone_value(value)
        })
        {
          ..alternative,
          value_binders,
          body: self.clone_expr(alternative.body),
        }
      })
      Match({
        scrutinee,
        binder,
        result_type: match_.result_type.substitute(self.substitution),
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
        handled_effect: self.substitute_effect(table.handled_effect),
        operations: table.operations.map(operation => {
          let payload_binders = operation.payload_binders.map(value => {
            self.clone_value(value)
          })
          let resume_binder = self.clone_value(operation.resume_binder)
          {
            ..operation,
            payload_binders,
            resume_binder,
            body: self.clone_expr(operation.body),
          }
        }),
      })
      Handle({
        body,
        result_binder,
        result_type: handle.result_type.substitute(self.substitution),
        final_body,
        handlers,
      })
    }
    Resume(value) => Resume(self.remap_value(value))
  }
}

///|
fn InlineCloneContext::clone_value(
  self : InlineCloneContext,
  value : @buslane.ValueId,
) -> @buslane.ValueId {
  for clone in self.value_clones {
    if clone.original == value {
      return clone.cloned
    }
  }
  guard self.metadata.value_info(value) is Some(info) else { return value }
  let cloned = self.metadata.define_value(
    info.name.occurrence,
    info.kind,
    info.type_.substitute(self.substitution),
  )
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
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(type_.substitute(self.substitution))
    EffectArgument(effect) =>
      EffectArgument(self.substitute_effect(effect).canonicalize())
  }
}

///|
fn InlineCloneContext::substitute_effect(
  self : InlineCloneContext,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  match effect {
    Empty | Io => effect
    Parameter(parameter) => {
      for binding in self.generic_bindings.rev_iter() {
        if binding.parameter == parameter &&
          binding.argument is EffectArgument(replacement) {
          return replacement
        }
      }
      effect
    }
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(argument => self.substitute_argument(argument)),
      )
    Union(effects) =>
      Union(effects.map(nested => self.substitute_effect(nested)))
  }
}
