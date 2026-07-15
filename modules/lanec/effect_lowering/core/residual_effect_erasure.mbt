///|
pub fn erase_residual_effects(program : @buslane.Program) -> @buslane.Program {
  erase_residual_effect_metadata(program.metadata)
  {
    metadata: program.metadata,
    terms: program.terms.map(erase_residual_effect_top_term),
  }
}

///|
fn erase_residual_effect_metadata(metadata : @buslane.MetadataRegistry) -> Unit {
  for index in 0..<metadata.values.length() {
    let info = metadata.values[index]
    metadata.values[index] = {
      ..info,
      type_: erase_residual_effect_type(info.type_),
    }
  }
  for index in 0..<metadata.data_constructors.length() {
    let info = metadata.data_constructors[index]
    metadata.data_constructors[index] = {
      ..info,
      payload_types: info.payload_types.map(erase_residual_effect_type),
    }
  }
  for index in 0..<metadata.operations.length() {
    let info = metadata.operations[index]
    metadata.operations[index] = {
      ..info,
      payload_types: info.payload_types.map(erase_residual_effect_type),
      result_type: erase_residual_effect_type(info.result_type),
    }
  }
}

///|
fn erase_residual_effect_top_term(term : @buslane.TopTerm) -> @buslane.TopTerm {
  match term {
    Let(value, expression) => Let(value, erase_residual_effect_expr(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: erase_residual_effect_expr(binding.rhs),
        }),
      )
    External(value) => External(value)
  }
}

///|
fn erase_residual_effect_expr(expression : @buslane.Expr) -> @buslane.Expr {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) =>
      Function({
        parameters: function.parameters,
        result_type: erase_residual_effect_type(function.result_type),
        body: erase_residual_effect_expr(function.body),
      })
    Call(callee, arguments) =>
      Call(
        erase_residual_effect_expr(callee),
        arguments.map(erase_residual_effect_expr),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, erase_residual_effect_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(
        erase_residual_effect_expr(callee),
        arguments.map(erase_residual_effect_argument),
      )
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments.map(
          erase_residual_effect_argument,
        ),
        hidden_witnesses: construct.hidden_witnesses.map(
          erase_residual_effect_argument,
        ),
        payloads: construct.payloads.map(erase_residual_effect_expr),
      })
    Let(value, initializer, body) =>
      Let(
        value,
        erase_residual_effect_expr(initializer),
        erase_residual_effect_expr(body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: erase_residual_effect_expr(binding.rhs),
        }),
        erase_residual_effect_expr(body),
      )
    Match(match_) =>
      Match({
        scrutinee: erase_residual_effect_expr(match_.scrutinee),
        binder: match_.binder,
        result_type: erase_residual_effect_type(match_.result_type),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: erase_residual_effect_expr(alternative.body),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        hidden_witnesses: perform.hidden_witnesses.map(
          erase_residual_effect_argument,
        ),
        payloads: perform.payloads.map(erase_residual_effect_expr),
      })
    Handle(handle) =>
      Handle({
        body: erase_residual_effect_expr(handle.body),
        result_binder: handle.result_binder,
        result_type: erase_residual_effect_type(handle.result_type),
        final_body: erase_residual_effect_expr(handle.final_body),
        handlers: handle.handlers.map(handler => {
          ..handler,
          operations: handler.operations.map(operation => {
            ..operation,
            body: erase_residual_effect_expr(operation.body),
          }),
        }),
      })
  }
}

///|
fn erase_residual_effect_type(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => type_
    Apply(callee, arguments) =>
      Apply(
        erase_residual_effect_type(callee),
        arguments.map(erase_residual_effect_argument),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, erase_residual_effect_type(body))
    Function(parameters, result, _) =>
      Function(
        parameters.map(erase_residual_effect_type),
        erase_residual_effect_type(result),
        Empty,
      )
    Forall(parameters, body) =>
      Forall(parameters, erase_residual_effect_type(body))
  }
}

///|
fn erase_residual_effect_argument(
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(erase_residual_effect_type(type_))
    EffectArgument(_) => EffectArgument(Empty)
  }
}
