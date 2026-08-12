///|
fn runtime_buslane_projection(program : @buslane.Program) -> @buslane.Program {
  let metadata = program.metadata.snapshot()
  project_runtime_metadata(metadata)
  { metadata, terms: program.terms.map(project_runtime_top_term) }
}

///|
fn project_runtime_metadata(metadata : @buslane.MetadataRegistry) -> Unit {
  for index in 0..<metadata.values.length() {
    let info = metadata.values[index]
    metadata.values[index] = { ..info, type_: project_runtime_type(info.type_) }
  }
  for index in 0..<metadata.data_constructors.length() {
    let info = metadata.data_constructors[index]
    metadata.data_constructors[index] = {
      ..info,
      payload_types: info.payload_types.map(project_runtime_type),
    }
  }
  for index in 0..<metadata.operations.length() {
    let info = metadata.operations[index]
    metadata.operations[index] = {
      ..info,
      payload_types: info.payload_types.map(project_runtime_type),
      result_type: project_runtime_type(info.result_type),
    }
  }
}

///|
fn project_runtime_top_term(term : @buslane.TopTerm) -> @buslane.TopTerm {
  match term {
    Let(value, expression) => Let(value, project_runtime_expr(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: project_runtime_expr(binding.rhs),
        }),
      )
    External(value) => External(value)
  }
}

///|
fn project_runtime_expr(expression : @buslane.Expr) -> @buslane.Expr {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) =>
      Function({
        parameters: function.parameters,
        result_type: project_runtime_type(function.result_type),
        body: project_runtime_expr(function.body),
      })
    Call(callee, arguments) =>
      Call(project_runtime_expr(callee), arguments.map(project_runtime_expr))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, project_runtime_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(
        project_runtime_expr(callee),
        arguments.map(project_runtime_argument),
      )
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments.map(project_runtime_argument),
        hidden_witnesses: construct.hidden_witnesses.map(
          project_runtime_argument,
        ),
        payloads: construct.payloads.map(project_runtime_expr),
      })
    Let(value, initializer, body) =>
      Let(value, project_runtime_expr(initializer), project_runtime_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: project_runtime_expr(binding.rhs),
        }),
        project_runtime_expr(body),
      )
    Match(match_) =>
      Match({
        scrutinee: project_runtime_expr(match_.scrutinee),
        binder: match_.binder,
        result_type: project_runtime_type(match_.result_type),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: project_runtime_expr(alternative.body),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        effect_arguments: perform.effect_arguments.map(project_runtime_argument),
        hidden_witnesses: perform.hidden_witnesses.map(project_runtime_argument),
        payloads: perform.payloads.map(project_runtime_expr),
      })
    Handle(handle) =>
      Handle({
        body: project_runtime_expr(handle.body),
        result_binder: handle.result_binder,
        result_type: project_runtime_type(handle.result_type),
        final_body: project_runtime_expr(handle.final_body),
        handlers: handle.handlers.map(handler => {
          ..handler,
          operations: handler.operations.map(operation => {
            ..operation,
            body: project_runtime_expr(operation.body),
          }),
        }),
      })
  }
}

///|
fn project_runtime_type(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => type_
    Apply(callee, arguments) =>
      Apply(
        project_runtime_type(callee),
        arguments.map(project_runtime_argument),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, project_runtime_type(body))
    Function(parameters, result, _) =>
      Function(
        parameters.map(project_runtime_type),
        project_runtime_type(result),
        Empty,
      )
    Forall(parameters, body) => Forall(parameters, project_runtime_type(body))
  }
}

///|
fn project_runtime_argument(
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(project_runtime_type(type_))
    EffectArgument(_) => EffectArgument(Empty)
  }
}
