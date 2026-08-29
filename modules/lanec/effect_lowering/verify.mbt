///|
fn verify_program_or_raise(
  program : Program,
) -> @buslane.VerifyResult raise SynthesisError {
  let metadata = program.metadata.snapshot()
  let terms = program.terms.map(term => verification_top_term(metadata, term))
  @buslane.verify_program({ metadata, terms, })
}

///|
fn verification_top_term(
  metadata : @buslane.MetadataRegistry,
  term : TopTerm,
) -> @buslane.TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => Let(id, verification_expr(metadata, expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: verification_expr(metadata, binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn verification_expr(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> @buslane.Expr raise SynthesisError {
  match expression {
    Ref(id) => Ref(id)
    Literal(literal) => Literal(literal)
    Function(function) => Function(verification_function(metadata, function))
    Call(callee, arguments) =>
      Call(
        verification_expr(metadata, callee),
        arguments.map(argument => verification_expr(metadata, argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, verification_expr(metadata, body))
    TypeApply(callee, arguments) =>
      TypeApply(verification_expr(metadata, callee), arguments)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(payload => {
          verification_expr(metadata, payload)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        id,
        verification_expr(metadata, initializer),
        verification_expr(metadata, body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: verification_expr(metadata, binding.rhs),
        }),
        verification_expr(metadata, body),
      )
    Match(match_) =>
      Match({
        scrutinee: verification_expr(metadata, match_.scrutinee),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders,
          value_binders: alternative.value_binders,
          body: verification_expr(metadata, alternative.body),
        }),
      })
    Invoke(invoke) =>
      Perform({
        operation: invoke.operation,
        effect_arguments: invoke.effect_arguments,
        hidden_witnesses: invoke.hidden_witnesses,
        payloads: invoke.payloads.map(payload => {
          verification_expr(metadata, payload)
        }),
      })
    Install(install) => verification_install(metadata, install)
    Bind(bind) =>
      Call(Function(verification_function(metadata, bind.continuation)), [
        verification_expr(metadata, bind.computation),
      ])
    OpenContext(open) => verification_open_context(metadata, open)
  }
}

///|
fn verification_function(
  metadata : @buslane.MetadataRegistry,
  function : FunctionExpr,
) -> @buslane.FunctionExpr raise SynthesisError {
  {
    parameters: function.parameters,
    result_type: function.result_type,
    body: verification_expr(metadata, function.body),
  }
}

///|
fn verification_install(
  metadata : @buslane.MetadataRegistry,
  install : InstallExpr,
) -> @buslane.Expr raise SynthesisError {
  if install.final_clause.parameters.length() != 1 {
    raise ArityMismatch(
      expected=1,
      actual=install.final_clause.parameters.length(),
    )
  }
  let result_binder = install.final_clause.parameters[0]
  Handle({
    body: verification_expr(metadata, install.body),
    result_binder,
    result_type: install.result_type,
    final_body: verification_function_call(metadata, install.final_clause),
    handlers: install.dictionaries.map(dictionary => {
      handled_effect: dictionary.handled_effect,
      operations: dictionary.operations.map(operation => {
        verification_operation(metadata, operation)
      }),
    }),
  })
}

///|
fn verification_operation(
  metadata : @buslane.MetadataRegistry,
  operation : OperationClause,
) -> @buslane.OperationAlternative raise SynthesisError {
  let (type_binders, function) = match operation.callable {
    Monomorphic(function) => ([], function)
    Polymorphic(parameters, function) => (parameters, function)
  }
  let parameters = function.parameters.copy()
  guard parameters.pop() is Some(resume_binder) else {
    raise ArityMismatch(expected=1, actual=0)
  }
  {
    operation: operation.operation,
    type_binders,
    payload_binders: parameters,
    resume_binder,
    body: verification_function_call(metadata, function),
  }
}

///|
fn verification_function_call(
  metadata : @buslane.MetadataRegistry,
  function : FunctionExpr,
) -> @buslane.Expr raise SynthesisError {
  Call(
    Function(verification_function(metadata, function)),
    function.parameters.map(parameter => Ref(parameter)),
  )
}

///|
fn verification_open_context(
  metadata : @buslane.MetadataRegistry,
  open : OpenContextExpr,
) -> @buslane.Expr raise SynthesisError {
  require_open_contexts(metadata, open.source_effect, open.target_effect)
  verification_effect_annotation(
    metadata,
    open.source_effect,
    verification_effect_annotation(
      metadata,
      open.target_effect,
      verification_expr(metadata, open.body),
    ),
  )
}

///|
// A function result annotation is checked in the lexical type scope where the
// OpenContext occurs. Returning the annotated parameter makes the expression
// pure and definitionally exact even when the annotation contains algebraic
// effects, so this wrapper observes the annotation without changing the body.
fn verification_effect_annotation(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  body : @buslane.Expr,
) -> @buslane.Expr raise SynthesisError {
  let unit_type = @buslane.Type::Primitive(Unit)
  let annotated_type = @buslane.Type::Function([], unit_type, effect)
  let parameter = define_synthetic_value(
    metadata,
    "%verify-effect-parameter",
    Parameter,
    annotated_type,
  )
  let validator_type = @buslane.Type::Function(
    [annotated_type],
    annotated_type,
    Empty,
  )
  let validator = define_synthetic_value(
    metadata,
    "%verify-effect-annotation",
    Local,
    validator_type,
  )
  Let(
    validator,
    Function({
      parameters: [parameter],
      result_type: annotated_type,
      body: Ref(parameter),
    }),
    body,
  )
}
