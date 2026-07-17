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
priv struct SpecializationContext {
  metadata : @buslane.MetadataRegistry
  substitution : @buslane.TypeSubstitution
  generic_bindings : Array[GenericBinding]
  value_clones : Array[ValueClone]
}

///|
fn try_specialize_generic_call(
  program : @buslane.Program,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr? {
  guard callee is TypeApply(Ref(value), generic_arguments) &&
    generic_arguments.all(generic_argument_is_concrete) &&
    arguments.all(is_substitutable_atom) else {
    return None
  }
  guard find_top_definition(program, value)
    is Some(TypeLambda(parameters, Function(function))) &&
    parameters.length() == generic_arguments.length() &&
    function.parameters.length() == arguments.length() &&
    function_has_product_nominal(program.metadata, function) &&
    expression_supports_specialization(function.body) &&
    expression_size(function.body) <= 32 &&
    count_value_uses(function.body, value) == 0 else {
    return None
  }
  let substitution = @buslane.TypeSubstitution::TypeSubstitution()
  let generic_bindings = []
  for index in 0..<parameters.length() {
    substitution.insert_argument(parameters[index], generic_arguments[index])
    generic_bindings.push({
      parameter: parameters[index],
      argument: generic_arguments[index],
    })
  }
  if !specialization_result_is_scalar_or_product(
      program.metadata,
      function.result_type.substitute(substitution),
    ) {
    return None
  }
  let context : SpecializationContext = {
    metadata: program.metadata,
    substitution,
    generic_bindings,
    value_clones: [],
  }
  Some(Call(Function(context.clone_function(function)), arguments))
}

///|
fn specialization_result_is_scalar_or_product(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> Bool {
  match type_ {
    Primitive(_) => true
    Parameter(_) => false
    Constructor(id) =>
      match metadata.type_info(id) {
        Some(info) => info.constructors.length() == 1
        None => false
      }
    Apply(callee, _) =>
      specialization_result_is_scalar_or_product(metadata, callee)
    TypeLambda(_, body) | Forall(_, body) =>
      specialization_result_is_scalar_or_product(metadata, body)
    Function(_, result, _) =>
      specialization_result_is_scalar_or_product(metadata, result)
  }
}

///|
fn function_has_product_nominal(
  metadata : @buslane.MetadataRegistry,
  function : @buslane.FunctionExpr,
) -> Bool {
  function.parameters.any(value => {
    match metadata.value_info(value) {
      Some(info) => type_has_product_nominal(metadata, info.type_)
      None => false
    }
  }) ||
  type_has_product_nominal(metadata, function.result_type)
}

///|
fn type_has_product_nominal(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> Bool {
  match type_ {
    Primitive(_) | Parameter(_) => false
    Constructor(id) => nominal_is_binary_operation_dictionary(metadata, id)
    Apply(callee, arguments) =>
      type_has_product_nominal(metadata, callee) ||
      arguments.any(argument => {
        generic_argument_has_product_nominal(metadata, argument)
      })
    TypeLambda(_, body) | Forall(_, body) =>
      type_has_product_nominal(metadata, body)
    Function(parameters, result, _) =>
      parameters.any(type_ => type_has_product_nominal(metadata, type_)) ||
      type_has_product_nominal(metadata, result)
  }
}

///|
fn nominal_is_binary_operation_dictionary(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.TypeId,
) -> Bool {
  guard metadata.type_info(id) is Some({ constructors: [data_constructor], .. }) &&
    metadata.data_constructor_info(data_constructor)
    is Some({ payload_types: [left, right], .. }) else {
    return false
  }
  left is Function(_, _, _) && right is Function(_, _, _) && left.equals(right)
}

///|
fn generic_argument_has_product_nominal(
  metadata : @buslane.MetadataRegistry,
  argument : @buslane.GenericArgument,
) -> Bool {
  match argument {
    TypeArgument(type_) => type_has_product_nominal(metadata, type_)
    EffectArgument(effect) => effect_has_product_nominal(metadata, effect)
  }
}

///|
fn effect_has_product_nominal(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Bool {
  match effect {
    Empty | Io | Parameter(_) => false
    Singleton(_, arguments) =>
      arguments.any(argument => {
        generic_argument_has_product_nominal(metadata, argument)
      })
    Union(effects) =>
      effects.any(effect => effect_has_product_nominal(metadata, effect))
  }
}

///|
fn find_top_definition(
  program : @buslane.Program,
  value : @buslane.ValueId,
) -> @buslane.Expr? {
  for term in program.terms {
    match term {
      Let(id, rhs) if id == value => return Some(rhs)
      LetRec(bindings) =>
        for binding in bindings {
          if binding.id == value {
            return Some(binding.rhs)
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn generic_argument_is_concrete(argument : @buslane.GenericArgument) -> Bool {
  match argument {
    TypeArgument(type_) => type_is_concrete(type_)
    EffectArgument(effect) => effect_is_concrete(effect)
  }
}

///|
fn type_is_concrete(type_ : @buslane.Type) -> Bool {
  match type_ {
    Primitive(_) | Constructor(_) => true
    Parameter(_) => false
    Apply(callee, arguments) =>
      type_is_concrete(callee) && arguments.all(generic_argument_is_concrete)
    Function(parameters, result, effect) =>
      parameters.all(type_is_concrete) &&
      type_is_concrete(result) &&
      effect_is_concrete(effect)
    TypeLambda(_, _) | Forall(_, _) => false
  }
}

///|
fn effect_is_concrete(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty | Io => true
    Parameter(_) => false
    Singleton(_, arguments) => arguments.all(generic_argument_is_concrete)
    Union(effects) => effects.all(effect_is_concrete)
  }
}

///|
fn expression_supports_specialization(expression : @buslane.Expr) -> Bool {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => true
    Function(function) => expression_supports_specialization(function.body)
    Call(callee, arguments) =>
      expression_supports_specialization(callee) &&
      arguments.all(expression_supports_specialization)
    TypeLambda(_, _) => false
    TypeApply(callee, _) => expression_supports_specialization(callee)
    Construct(construct) =>
      construct.payloads.all(expression_supports_specialization)
    Let(_, initializer, body) =>
      expression_supports_specialization(initializer) &&
      expression_supports_specialization(body)
    LetRec(bindings, body) =>
      bindings.all(binding => expression_supports_specialization(binding.rhs)) &&
      expression_supports_specialization(body)
    Match(match_) =>
      match_.alternatives.all(alternative => {
        alternative.type_binders.is_empty() &&
        expression_supports_specialization(alternative.body)
      }) &&
      expression_supports_specialization(match_.scrutinee)
    Perform(_) | Handle(_) => false
  }
}

///|
fn expression_size(expression : @buslane.Expr) -> Int {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => 1
    Function(function) => 1 + expression_size(function.body)
    Call(callee, arguments) =>
      1 +
      expression_size(callee) +
      arguments.fold(init=0, fn(size, argument) {
        size + expression_size(argument)
      })
    TypeLambda(_, body) | TypeApply(body, _) => 1 + expression_size(body)
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(size, payload) {
        size + expression_size(payload)
      })
    Let(_, initializer, body) =>
      1 + expression_size(initializer) + expression_size(body)
    LetRec(bindings, body) => {
      let mut size = 1 + expression_size(body)
      for binding in bindings {
        size = size + expression_size(binding.rhs)
      }
      size
    }
    Match(match_) => {
      let mut size = 1 + expression_size(match_.scrutinee)
      for alternative in match_.alternatives {
        size = size + expression_size(alternative.body)
      }
      size
    }
    Perform(perform) =>
      1 +
      perform.payloads.fold(init=0, fn(size, payload) {
        size + expression_size(payload)
      })
    Handle(handle) => {
      let mut size = 1 +
        expression_size(handle.body) +
        expression_size(handle.final_body)
      for table in handle.handlers {
        for operation in table.operations {
          size = size + expression_size(operation.body)
        }
      }
      size
    }
  }
}

///|
fn SpecializationContext::clone_function(
  self : SpecializationContext,
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
fn SpecializationContext::clone_expr(
  self : SpecializationContext,
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
    TypeLambda(_, _) => abort("unsupported nested generic specialization")
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
    Perform(_) | Handle(_) => abort("unsupported effect specialization body")
    Resume(value) => Resume(self.remap_value(value))
  }
}

///|
fn SpecializationContext::clone_value(
  self : SpecializationContext,
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
fn SpecializationContext::remap_value(
  self : SpecializationContext,
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
fn SpecializationContext::substitute_argument(
  self : SpecializationContext,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(type_.substitute(self.substitution))
    EffectArgument(effect) =>
      EffectArgument(self.substitute_effect(effect).canonicalize())
  }
}

///|
fn SpecializationContext::substitute_effect(
  self : SpecializationContext,
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
