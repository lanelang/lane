///|
pub fn elaborate_handlers(program : @buslane.Program) -> Program {
  { metadata: program.metadata, terms: program.terms.map(elaborate_top_term) }
}

///|
fn elaborate_top_term(term : @buslane.TopTerm) -> TopTerm {
  match term {
    Let(id, expression) => Let(id, elaborate_expr(expression))
    LetRec(bindings) => LetRec(bindings.map(elaborate_recursive_binding))
    External(id) => External(id)
  }
}

///|
fn elaborate_recursive_binding(
  binding : @buslane.RecursiveBinding,
) -> RecursiveBinding {
  { id: binding.id, rhs: elaborate_expr(binding.rhs) }
}

///|
fn elaborate_expr(expression : @buslane.Expr) -> Expr {
  match expression {
    Ref(id) => Ref(id)
    Literal(literal) => Literal(literal)
    Function(function) =>
      Function({
        parameters: function.parameters,
        result_type: function.result_type,
        body: elaborate_expr(function.body),
      })
    Call(callee, arguments) =>
      Call(elaborate_expr(callee), arguments.map(elaborate_expr))
    TypeLambda(parameters, body) => TypeLambda(parameters, elaborate_expr(body))
    TypeApply(callee, arguments) => TypeApply(elaborate_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(elaborate_expr),
      })
    Let(id, initializer, body) =>
      Let(id, elaborate_expr(initializer), elaborate_expr(body))
    LetRec(bindings, body) =>
      LetRec(bindings.map(elaborate_recursive_binding), elaborate_expr(body))
    Match(match_) =>
      Match({
        scrutinee: elaborate_expr(match_.scrutinee),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(elaborate_alternative),
      })
    Perform(perform) =>
      Invoke({
        operation: perform.operation,
        effect_arguments: perform.effect_arguments,
        hidden_witnesses: perform.hidden_witnesses,
        payloads: perform.payloads.map(elaborate_expr),
      })
    Handle(handle) => elaborate_handle(handle)
    Resume(id) => Ref(id)
  }
}

///|
fn elaborate_alternative(alternative : @buslane.Alternative) -> Alternative {
  {
    alt_constructor: alternative.alt_constructor,
    type_binders: alternative.type_binders,
    value_binders: alternative.value_binders,
    body: elaborate_expr(alternative.body),
  }
}

///|
fn elaborate_handle(handle : @buslane.HandleExpr) -> Expr {
  Install({
    body: elaborate_expr(handle.body),
    result_type: handle.result_type,
    dictionaries: handle.handlers.map(table => {
      elaborate_handler_dictionary(table, handle.result_type)
    }),
    final_clause: {
      parameters: [handle.result_binder],
      result_type: handle.result_type,
      body: elaborate_expr(handle.final_body),
    },
  })
}

///|
fn elaborate_handler_dictionary(
  table : @buslane.HandlerTable,
  result_type : @buslane.Type,
) -> HandlerDictionary {
  {
    handled_effect: table.handled_effect,
    operations: table.operations.map(alternative => {
      elaborate_operation_clause(alternative, result_type)
    }),
  }
}

///|
fn elaborate_operation_clause(
  alternative : @buslane.OperationAlternative,
  result_type : @buslane.Type,
) -> OperationClause {
  let parameters = alternative.payload_binders.copy()
  parameters.push(alternative.resume_binder)
  let function : FunctionExpr = {
    parameters,
    result_type,
    body: elaborate_expr(alternative.body),
  }
  {
    operation: alternative.operation,
    callable: if alternative.type_binders.is_empty() {
      Monomorphic(function)
    } else {
      Polymorphic(alternative.type_binders, function)
    },
  }
}
