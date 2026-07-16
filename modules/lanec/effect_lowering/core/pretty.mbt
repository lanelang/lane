///|
using @prettyprinter {
  type Document,
  char,
  empty,
  line,
  nest,
  space,
  surround,
  text,
}

///|
pub impl @prettyprinter.Pretty for Program with fn pretty(program : Program) {
  text("buslane") +
  space +
  @pretty.braced_block(
    [program.metadata.pretty(), ..program.terms.map(top_term_doc)],
  )
}

///|
fn top_term_doc(term : TopTerm) -> Document {
  match term {
    Let(id, expression) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      expr_doc(expression)
    LetRec(bindings) =>
      text("letrec") +
      space +
      @pretty.braced_block(bindings.map(recursive_binding_doc))
    External(id) => text("external") + space + id.pretty()
  }
}

///|
fn recursive_binding_doc(binding : RecursiveBinding) -> Document {
  binding.id.pretty() + space + text("=") + space + expr_doc(binding.rhs)
}

///|
fn expr_doc(expression : Expr) -> Document {
  match expression {
    Ref(id) => id.pretty()
    Literal(literal) => literal.pretty()
    Function(function) => function_doc(function)
    Call(callee, arguments) =>
      expr_doc(callee) + @pretty.parenthesized_inline(arguments.map(expr_doc))
    TypeLambda(parameters, body) =>
      text("fn") +
      type_parameters_doc(parameters) +
      space +
      @pretty.braced_block([expr_doc(body)])
    TypeApply(callee, arguments) =>
      expr_doc(callee) + generic_arguments_doc(arguments)
    Construct(construct) => construct_doc(construct)
    Let(id, initializer, body) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      expr_doc(initializer) +
      space +
      text("in") +
      line +
      expr_doc(body)
    LetRec(bindings, body) =>
      text("letrec") +
      space +
      @pretty.braced_block(bindings.map(recursive_binding_doc)) +
      space +
      text("in") +
      line +
      expr_doc(body)
    Match(match_) => match_doc(match_)
    Invoke(invoke) => invoke_doc(invoke)
    Install(install) => install_doc(install)
    Bind(bind) => bind_doc(bind)
    OpenContext(context) => open_context_doc(context)
  }
}

///|
fn function_doc(function : FunctionExpr) -> Document {
  text("fn") +
  @pretty.parenthesized_inline(
    function.parameters.map(@buslane.ValueId::pretty),
  ) +
  space +
  text("->") +
  space +
  function.result_type.pretty() +
  space +
  @pretty.braced_block([expr_doc(function.body)])
}

///|
fn polymorphic_function_doc(
  parameters : Array[@buslane.TypeParameterId],
  function : FunctionExpr,
) -> Document {
  text("fn") +
  type_parameters_doc(parameters) +
  @pretty.parenthesized_inline(
    function.parameters.map(@buslane.ValueId::pretty),
  ) +
  space +
  text("->") +
  space +
  function.result_type.pretty() +
  space +
  @pretty.braced_block([expr_doc(function.body)])
}

///|
fn construct_doc(construct : ConstructExpr) -> Document {
  construct.data_constructor.pretty() +
  type_and_witness_arguments_doc(
    construct.type_arguments,
    construct.hidden_witnesses,
  ) +
  @pretty.parenthesized_inline(construct.payloads.map(expr_doc))
}

///|
fn match_doc(match_ : MatchExpr) -> Document {
  text("match") +
  space +
  expr_doc(match_.scrutinee) +
  space +
  text("as") +
  space +
  match_.binder.pretty() +
  space +
  text("->") +
  space +
  match_.result_type.pretty() +
  space +
  @pretty.braced_block(match_.alternatives.map(alternative_doc))
}

///|
fn alternative_doc(alternative : Alternative) -> Document {
  alternative_pattern_doc(alternative) +
  space +
  text("=>") +
  space +
  expr_doc(alternative.body)
}

///|
fn alternative_pattern_doc(alternative : Alternative) -> Document {
  match alternative.alt_constructor {
    Default => text("_")
    Literal(literal) => literal.pretty()
    DataCon(id) =>
      id.pretty() +
      type_parameters_doc(alternative.type_binders) +
      @pretty.parenthesized_inline(
        alternative.value_binders.map(@buslane.ValueId::pretty),
      )
  }
}

///|
fn invoke_doc(invoke : InvokeExpr) -> Document {
  text("invoke") +
  space +
  invoke.operation.pretty() +
  type_and_witness_arguments_doc(
    invoke.effect_arguments,
    invoke.hidden_witnesses,
  ) +
  @pretty.parenthesized_inline(invoke.payloads.map(expr_doc))
}

///|
fn install_doc(install : InstallExpr) -> Document {
  text("install") +
  space +
  expr_doc(install.body) +
  space +
  text("->") +
  space +
  install.result_type.pretty() +
  space +
  @pretty.braced_block(
    install.dictionaries.map(handler_dictionary_doc) +
    [
      text("final") +
      space +
      text("=>") +
      space +
      function_doc(install.final_clause),
    ],
  )
}

///|
fn handler_dictionary_doc(dictionary : HandlerDictionary) -> Document {
  dictionary.handled_effect.pretty() +
  space +
  @pretty.braced_block(dictionary.operations.map(operation_clause_doc))
}

///|
fn operation_clause_doc(clause : OperationClause) -> Document {
  clause.operation.pretty() +
  space +
  text("=>") +
  space +
  clause_callable_doc(clause.callable)
}

///|
fn clause_callable_doc(callable : ClauseCallable) -> Document {
  match callable {
    Monomorphic(function) => function_doc(function)
    Polymorphic(parameters, function) =>
      polymorphic_function_doc(parameters, function)
  }
}

///|
fn bind_doc(bind : BindExpr) -> Document {
  text("bind") +
  space +
  bind.binder.pretty() +
  space +
  text("<-") +
  space +
  expr_doc(bind.computation) +
  space +
  text("in") +
  nest(line + function_doc(bind.continuation))
}

///|
fn open_context_doc(context : OpenContextExpr) -> Document {
  text("open_context") +
  space +
  context.source_effect.pretty() +
  space +
  text("=>") +
  space +
  context.target_effect.pretty() +
  space +
  @pretty.braced_block([expr_doc(context.body)])
}

///|
fn type_parameters_doc(
  parameters : Array[@buslane.TypeParameterId],
) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(@buslane.TypeParameterId::pretty))
  }
}

///|
fn generic_arguments_doc(
  arguments : Array[@buslane.GenericArgument],
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(@buslane.GenericArgument::pretty))
  }
}

///|
fn type_and_witness_arguments_doc(
  arguments : Array[@buslane.GenericArgument],
  witnesses : Array[@buslane.GenericArgument],
) -> Document {
  if arguments.is_empty() && witnesses.is_empty() {
    empty
  } else if witnesses.is_empty() {
    generic_arguments_doc(arguments)
  } else {
    surround(
      char('['),
      char(']'),
      @pretty.join_comma(arguments.map(@buslane.GenericArgument::pretty)) +
      text(";") +
      space +
      @pretty.join_comma(witnesses.map(@buslane.GenericArgument::pretty)),
    )
  }
}
