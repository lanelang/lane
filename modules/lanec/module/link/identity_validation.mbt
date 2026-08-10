///|
priv struct ModuleObjectIdentityValidator {
  object : LinkModuleObject
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn validate_buslane_object(
  object : LinkModuleObject,
) -> Array[CompilerDiagnostic] {
  let validator = ModuleObjectIdentityValidator::{ object, diagnostics: [] }
  validator.validate_metadata()
  for term in object.terms {
    validator.validate_top_term(term)
  }
  for import_ in object.externals.runtime_imports {
    validator.validate_type(import_.type_)
  }
  for entry in object.entries {
    validator.validate_type(entry.type_)
  }
  validator.diagnostics
}

///|
fn ModuleObjectIdentityValidator::validate_metadata(
  self : ModuleObjectIdentityValidator,
) -> Unit {
  for info in self.object.metadata.types {
    for parameter in info.parameters {
      self.require_type_parameter(parameter)
    }
    for constructor_id in info.constructors {
      self.require_data_constructor(constructor_id)
    }
  }
  for info in self.object.metadata.values {
    self.validate_type(info.type_)
  }
  for info in self.object.metadata.data_constructors {
    self.require_type(info.owner)
    for parameter in info.hidden_type_parameters {
      self.require_type_parameter(parameter)
    }
    for payload_type in info.payload_types {
      self.validate_type(payload_type)
    }
  }
  for info in self.object.metadata.effects {
    for parameter in info.parameters {
      self.require_type_parameter(parameter)
    }
    for operation in info.operations {
      self.require_operation(operation)
    }
  }
  for info in self.object.metadata.operations {
    self.require_effect(info.owner)
    for parameter in info.hidden_type_parameters {
      self.require_type_parameter(parameter)
    }
    for payload_type in info.payload_types {
      self.validate_type(payload_type)
    }
    self.validate_type(info.result_type)
  }
}

///|
fn ModuleObjectIdentityValidator::validate_top_term(
  self : ModuleObjectIdentityValidator,
  term : @buslane.TopTerm,
) -> Unit {
  match term {
    Let(id, initializer) => {
      self.require_value(id)
      self.validate_expr(initializer)
    }
    LetRec(bindings) =>
      for binding in bindings {
        self.require_value(binding.id)
        self.validate_expr(binding.rhs)
      }
    External(id) => self.require_value(id)
  }
}

///|
fn ModuleObjectIdentityValidator::validate_expr(
  self : ModuleObjectIdentityValidator,
  expr : @buslane.Expr,
) -> Unit {
  match expr {
    Ref(id) | Resume(id) => self.require_value(id)
    Literal(_) => ()
    Function(function) => {
      for parameter in function.parameters {
        self.require_value(parameter)
      }
      self.validate_type(function.result_type)
      self.validate_expr(function.body)
    }
    Call(callee, arguments) => {
      self.validate_expr(callee)
      for argument in arguments {
        self.validate_expr(argument)
      }
    }
    TypeLambda(parameters, body) => {
      for parameter in parameters {
        self.require_type_parameter(parameter)
      }
      self.validate_expr(body)
    }
    TypeApply(callee, arguments) => {
      self.validate_expr(callee)
      for argument in arguments {
        self.validate_generic_argument(argument)
      }
    }
    Construct(construct) => {
      self.require_data_constructor(construct.data_constructor)
      for argument in construct.type_arguments {
        self.validate_generic_argument(argument)
      }
      for witness in construct.hidden_witnesses {
        self.validate_generic_argument(witness)
      }
      for payload in construct.payloads {
        self.validate_expr(payload)
      }
    }
    Let(id, initializer, body) => {
      self.require_value(id)
      self.validate_expr(initializer)
      self.validate_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.require_value(binding.id)
        self.validate_expr(binding.rhs)
      }
      self.validate_expr(body)
    }
    Match(match_) => {
      self.validate_expr(match_.scrutinee)
      self.require_value(match_.binder)
      self.validate_type(match_.result_type)
      for alternative in match_.alternatives {
        if alternative.alt_constructor is DataCon(id) {
          self.require_data_constructor(id)
        }
        for parameter in alternative.type_binders {
          self.require_type_parameter(parameter)
        }
        for binder in alternative.value_binders {
          self.require_value(binder)
        }
        self.validate_expr(alternative.body)
      }
    }
    Perform(perform) => {
      self.require_operation(perform.operation)
      for argument in perform.effect_arguments {
        self.validate_generic_argument(argument)
      }
      for witness in perform.hidden_witnesses {
        self.validate_generic_argument(witness)
      }
      for payload in perform.payloads {
        self.validate_expr(payload)
      }
    }
    Handle(handle) => {
      self.validate_expr(handle.body)
      self.require_value(handle.result_binder)
      self.validate_type(handle.result_type)
      self.validate_expr(handle.final_body)
      for table in handle.handlers {
        self.validate_effect(table.handled_effect)
        for alternative in table.operations {
          self.require_operation(alternative.operation)
          for parameter in alternative.type_binders {
            self.require_type_parameter(parameter)
          }
          for binder in alternative.payload_binders {
            self.require_value(binder)
          }
          self.require_value(alternative.resume_binder)
          self.validate_expr(alternative.body)
        }
      }
    }
  }
}

///|
fn ModuleObjectIdentityValidator::validate_type(
  self : ModuleObjectIdentityValidator,
  type_ : @buslane.Type,
) -> Unit {
  match type_ {
    Primitive(_) => ()
    Parameter(id) => self.require_type_parameter(id)
    Constructor(id) => self.require_type(id)
    Apply(callee, arguments) => {
      self.validate_type(callee)
      for argument in arguments {
        self.validate_generic_argument(argument)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      for parameter in parameters {
        self.require_type_parameter(parameter)
      }
      self.validate_type(body)
    }
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.validate_type(parameter)
      }
      self.validate_type(result)
      self.validate_effect(effect)
    }
  }
}

///|
fn ModuleObjectIdentityValidator::validate_generic_argument(
  self : ModuleObjectIdentityValidator,
  argument : @buslane.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.validate_type(type_)
    EffectArgument(effect) => self.validate_effect(effect)
  }
}

///|
fn ModuleObjectIdentityValidator::validate_effect(
  self : ModuleObjectIdentityValidator,
  effect : @buslane.Effect,
) -> Unit {
  match effect {
    Empty | Builtin(_) => ()
    Singleton(id, arguments) => {
      self.require_effect(id)
      for argument in arguments {
        self.validate_generic_argument(argument)
      }
    }
    Parameter(id) => self.require_type_parameter(id)
    Union(effects) =>
      for effect in effects {
        self.validate_effect(effect)
      }
  }
}

///|
fn ModuleObjectIdentityValidator::require_type(
  self : ModuleObjectIdentityValidator,
  id : @buslane.TypeId,
) -> Unit {
  if self.object.metadata.type_info(id) is None {
    self.report("unknown Buslane type identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::require_type_parameter(
  self : ModuleObjectIdentityValidator,
  id : @buslane.TypeParameterId,
) -> Unit {
  if self.object.metadata.type_parameter_info(id) is None {
    self.report("unknown Buslane type-parameter identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::require_value(
  self : ModuleObjectIdentityValidator,
  id : @buslane.ValueId,
) -> Unit {
  if self.object.metadata.value_info(id) is None {
    self.report("unknown Buslane value identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::require_data_constructor(
  self : ModuleObjectIdentityValidator,
  id : @buslane.DataConId,
) -> Unit {
  if self.object.metadata.data_constructor_info(id) is None {
    self.report("unknown Buslane data-constructor identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::require_effect(
  self : ModuleObjectIdentityValidator,
  id : @buslane.EffectId,
) -> Unit {
  if self.object.metadata.effect_info(id) is None {
    self.report("unknown Buslane effect identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::require_operation(
  self : ModuleObjectIdentityValidator,
  id : @buslane.OperationId,
) -> Unit {
  if self.object.metadata.operation_info(id) is None {
    self.report("unknown Buslane operation identity \{Repr(id)}")
  }
}

///|
fn ModuleObjectIdentityValidator::report(
  self : ModuleObjectIdentityValidator,
  reason : String,
) -> Unit {
  self.diagnostics.push(invalid_module_object(self.object, reason))
}
