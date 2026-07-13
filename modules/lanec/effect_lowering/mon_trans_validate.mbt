///|
pub fn validate_mon_trans_output(
  program : Program,
) -> Result[Unit, SynthesisError] {
  Ok(validate_mon_trans_output_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn validate_mon_trans_output_or_raise(
  program : Program,
) -> Unit raise SynthesisError {
  for info in program.metadata.values {
    validate_mon_trans_type(program.metadata, info.type_)
  }
  for info in program.metadata.types {
    for parameter in info.parameters {
      validate_mon_trans_type_parameter(program.metadata, parameter)
    }
  }
  for info in program.metadata.data_constructors {
    for parameter in info.hidden_type_parameters {
      validate_mon_trans_type_parameter(program.metadata, parameter)
    }
    for type_ in info.payload_types {
      validate_mon_trans_type(program.metadata, type_)
    }
  }
  for term in program.terms {
    validate_mon_trans_top_term(program.metadata, term)
  }
}

///|
fn validate_mon_trans_top_term(
  metadata : @buslane.MetadataRegistry,
  term : TopTerm,
) -> Unit raise SynthesisError {
  match term {
    Let(_, expression) => validate_mon_trans_expr(metadata, expression)
    LetRec(bindings) =>
      for binding in bindings {
        validate_mon_trans_expr(metadata, binding.rhs)
      }
    External(_) => ()
  }
}

///|
fn validate_mon_trans_expr(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Unit raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => ()
    Function(function) => {
      validate_mon_trans_type(metadata, function.result_type)
      validate_mon_trans_expr(metadata, function.body)
    }
    Call(callee, arguments) => {
      validate_mon_trans_expr(metadata, callee)
      for argument in arguments {
        validate_mon_trans_expr(metadata, argument)
      }
    }
    TypeLambda(parameters, body) => {
      for parameter in parameters {
        validate_mon_trans_type_parameter(metadata, parameter)
      }
      validate_mon_trans_expr(metadata, body)
    }
    TypeApply(callee, arguments) => {
      validate_mon_trans_expr(metadata, callee)
      for argument in arguments {
        validate_mon_trans_generic_argument(metadata, argument)
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        validate_mon_trans_generic_argument(metadata, argument)
      }
      for witness in construct.hidden_witnesses {
        validate_mon_trans_generic_argument(metadata, witness)
      }
      for payload in construct.payloads {
        validate_mon_trans_expr(metadata, payload)
      }
    }
    Let(_, initializer, body) => {
      validate_mon_trans_expr(metadata, initializer)
      validate_mon_trans_expr(metadata, body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        validate_mon_trans_expr(metadata, binding.rhs)
      }
      validate_mon_trans_expr(metadata, body)
    }
    Match(match_) => {
      validate_mon_trans_type(metadata, match_.result_type)
      validate_mon_trans_expr(metadata, match_.scrutinee)
      for alternative in match_.alternatives {
        for parameter in alternative.type_binders {
          validate_mon_trans_type_parameter(metadata, parameter)
        }
        validate_mon_trans_expr(metadata, alternative.body)
      }
    }
    Invoke(invoke) => raise ResidualInvoke(invoke.operation)
    Install(_) => raise ResidualInstall
    Bind(_) => raise ResidualBind
    OpenContext(open) => {
      if !effect_has_parameter(open.source_effect) &&
        !effect_has_parameter(open.target_effect) {
        raise ConcreteOpenContext(
          source=open.source_effect,
          target=open.target_effect,
        )
      }
      validate_mon_trans_expr(metadata, open.body)
    }
  }
}

///|
fn validate_mon_trans_type(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> Unit raise SynthesisError {
  match type_ {
    Primitive(_) | Constructor(_) => ()
    Parameter(parameter) =>
      validate_mon_trans_type_parameter(metadata, parameter)
    Apply(callee, arguments) => {
      validate_mon_trans_type(metadata, callee)
      for argument in arguments {
        validate_mon_trans_generic_argument(metadata, argument)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      for parameter in parameters {
        validate_mon_trans_type_parameter(metadata, parameter)
      }
      validate_mon_trans_type(metadata, body)
    }
    Function(parameters, result, effect) => {
      if effect.canonicalize() != Empty {
        raise ResidualLatentEffect(effect)
      }
      for parameter in parameters {
        validate_mon_trans_type(metadata, parameter)
      }
      validate_mon_trans_type(metadata, result)
    }
  }
}

///|
fn validate_mon_trans_generic_argument(
  metadata : @buslane.MetadataRegistry,
  argument : @buslane.GenericArgument,
) -> Unit raise SynthesisError {
  match argument {
    TypeArgument(type_) => validate_mon_trans_type(metadata, type_)
    EffectArgument(effect) => raise ResidualEffectArgument(effect)
  }
}

///|
fn validate_mon_trans_type_parameter(
  metadata : @buslane.MetadataRegistry,
  parameter : @buslane.TypeParameterId,
) -> Unit raise SynthesisError {
  if metadata.type_parameter_info(parameter) is Some({ kind: Effect, .. }) {
    raise ResidualEffectParameter(parameter)
  }
}

///|
fn effect_has_parameter(effect : @buslane.Effect) -> Bool {
  effect_terms(effect).any(term => term is Parameter(_))
}
