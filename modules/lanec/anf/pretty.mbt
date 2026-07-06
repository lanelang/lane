///|
using @prettyprinter {type Document, empty, space, text}

///|
pub impl @prettyprinter.Pretty for AnfTempId with fn pretty(id : AnfTempId) {
  text("temp#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfProgram with fn pretty(
  program : BuslaneAnfProgram,
) {
  text("buslane_anf_program") +
  space +
  @pretty.braced_block(program.terms.map(BuslaneAnfTopTerm::pretty))
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfTopTerm with fn pretty(
  term : BuslaneAnfTopTerm,
) {
  match term {
    Let(id, expr) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      buslane_anf_expr_doc(expr)
    LetRec(bindings) =>
      text("letrec") +
      space +
      @pretty.braced_block(bindings.map(BuslaneAnfRecursiveBinding::pretty))
    External(id) => text("external") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfRecursiveBinding with fn pretty(
  binding : BuslaneAnfRecursiveBinding,
) {
  binding.id.pretty() +
  space +
  text("=") +
  space +
  buslane_anf_atom_doc(binding.rhs)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfExpr with fn pretty(
  expr : BuslaneAnfExpr,
) {
  buslane_anf_expr_doc(expr)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfBinding with fn pretty(
  binding : BuslaneAnfBinding,
) {
  match binding {
    Value(id~, rhs~) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      buslane_anf_rhs_doc(rhs)
    Temp(temp~, rhs~) =>
      text("let") +
      space +
      temp.pretty() +
      space +
      text("=") +
      space +
      buslane_anf_rhs_doc(rhs)
  }
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfRhs with fn pretty(
  rhs : BuslaneAnfRhs,
) {
  buslane_anf_rhs_doc(rhs)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfConstruct with fn pretty(
  construct : BuslaneAnfConstruct,
) {
  buslane_anf_construct_doc(construct)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfPerform with fn pretty(
  perform : BuslaneAnfPerform,
) {
  buslane_anf_perform_doc(perform)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfHandle with fn pretty(
  handle : BuslaneAnfHandle,
) {
  buslane_anf_handle_doc(handle)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfHandlerTable with fn pretty(
  table : BuslaneAnfHandlerTable,
) {
  table.handled_effect.pretty() +
  space +
  @pretty.braced_block(
    table.operations.map(BuslaneAnfOperationAlternative::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfOperationAlternative with fn pretty(
  alternative : BuslaneAnfOperationAlternative,
) {
  alternative.operation.pretty() +
  buslane_type_arguments_doc(
    alternative.type_binders.map(fn(parameter) {
      TypeArgument(Parameter(parameter))
    }),
  ) +
  @pretty.parenthesized_inline(
    alternative.payload_binders.map(@buslane.ValueId::pretty),
  ) +
  space +
  text("resume") +
  space +
  alternative.resume_binder.pretty() +
  space +
  text("=>") +
  space +
  buslane_anf_expr_doc(alternative.body)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfAtom with fn pretty(
  atom : BuslaneAnfAtom,
) {
  buslane_anf_atom_doc(atom)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfFunction with fn pretty(
  function : BuslaneAnfFunction,
) {
  text("fn") +
  @pretty.parenthesized_inline(
    function.parameters.map(@buslane.ValueId::pretty),
  ) +
  space +
  text("->") +
  space +
  function.result_type.pretty() +
  space +
  buslane_anf_body_doc(function.body)
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfMatch with fn pretty(
  match_ : BuslaneAnfMatch,
) {
  text("match") +
  space +
  buslane_anf_atom_doc(match_.scrutinee) +
  space +
  text("as") +
  space +
  match_.binder.pretty() +
  space +
  text("->") +
  space +
  match_.result_type.pretty() +
  space +
  @pretty.braced_block(match_.alternatives.map(BuslaneAnfAlternative::pretty))
}

///|
pub impl @prettyprinter.Pretty for BuslaneAnfAlternative with fn pretty(
  alternative : BuslaneAnfAlternative,
) {
  alternative.alt_constructor.pretty() +
  buslane_anf_binders_doc(alternative.type_binders, alternative.value_binders) +
  space +
  text("=>") +
  space +
  buslane_anf_expr_doc(alternative.body)
}

///|
fn buslane_anf_expr_doc(expr : BuslaneAnfExpr) -> Document {
  match expr {
    Atom(atom) => buslane_anf_atom_doc(atom)
    Let(_, _) | LetRec(_, _) => {
      let docs : Array[Document] = []
      push_buslane_anf_expr_docs(expr, docs)
      @pretty.braced_block(docs)
    }
    Match(match_) => match_.pretty()
  }
}

///|
fn push_buslane_anf_expr_docs(
  expr : BuslaneAnfExpr,
  docs : Array[Document],
) -> Unit {
  match expr {
    Let(binding, body) => {
      docs.push(binding.pretty())
      push_buslane_anf_expr_docs(body, docs)
    }
    LetRec(bindings, body) => {
      docs.push(
        text("letrec") +
        space +
        @pretty.braced_block(bindings.map(BuslaneAnfRecursiveBinding::pretty)),
      )
      push_buslane_anf_expr_docs(body, docs)
    }
    _ => docs.push(buslane_anf_expr_doc(expr))
  }
}

///|
fn buslane_anf_body_doc(body : BuslaneAnfExpr) -> Document {
  match body {
    Let(_, _) | LetRec(_, _) => buslane_anf_expr_doc(body)
    _ => @pretty.braced_block([buslane_anf_expr_doc(body)])
  }
}

///|
fn buslane_anf_rhs_doc(rhs : BuslaneAnfRhs) -> Document {
  match rhs {
    Atom(atom) => buslane_anf_atom_doc(atom)
    Call(callee~, arguments~) =>
      buslane_anf_atom_doc(callee) +
      @pretty.parenthesized_inline(arguments.map(buslane_anf_atom_doc))
    TypeApply(callee~, arguments~) =>
      buslane_anf_atom_doc(callee) + buslane_generic_arguments_doc(arguments)
    Construct(construct) => buslane_anf_construct_doc(construct)
    Perform(perform) => buslane_anf_perform_doc(perform)
    Handle(handle) => buslane_anf_handle_doc(handle)
  }
}

///|
fn buslane_anf_perform_doc(perform : BuslaneAnfPerform) -> Document {
  text("perform") +
  space +
  perform.operation.pretty() +
  buslane_type_arguments_doc(perform.effect_arguments) +
  buslane_hidden_witnesses_doc(perform.hidden_witnesses) +
  @pretty.parenthesized_inline(perform.payloads.map(buslane_anf_atom_doc))
}

///|
fn buslane_anf_handle_doc(handle : BuslaneAnfHandle) -> Document {
  text("handle") +
  space +
  buslane_anf_expr_doc(handle.body) +
  space +
  text("as") +
  space +
  handle.result_binder.pretty() +
  space +
  text("->") +
  space +
  handle.result_type.pretty() +
  space +
  @pretty.braced_block(
    handle.handlers.map(BuslaneAnfHandlerTable::pretty) +
    [
      text("final") +
      space +
      text("=>") +
      space +
      buslane_anf_expr_doc(handle.final_body),
    ],
  )
}

///|
fn buslane_anf_construct_doc(construct : BuslaneAnfConstruct) -> Document {
  construct.data_constructor.pretty() +
  buslane_type_arguments_doc(construct.type_arguments) +
  buslane_hidden_witnesses_doc(construct.hidden_witnesses) +
  @pretty.parenthesized_inline(construct.payloads.map(buslane_anf_atom_doc))
}

///|
fn buslane_anf_atom_doc(atom : BuslaneAnfAtom) -> Document {
  match atom {
    Literal(literal) => literal.pretty()
    Ref(id) => id.pretty()
    Temp(temp) => temp.pretty()
    Function(function) => function.pretty()
    TypeLambda(type_parameters~, body~) =>
      text("fn") +
      buslane_type_parameters_doc(type_parameters) +
      space +
      buslane_anf_body_doc(body)
  }
}

///|
fn buslane_anf_binders_doc(
  type_binders : Array[@buslane.TypeParameterId],
  value_binders : Array[@buslane.ValueId],
) -> Document {
  let binders = type_binders.map(@buslane.TypeParameterId::pretty) +
    value_binders.map(@buslane.ValueId::pretty)
  if binders.is_empty() {
    empty
  } else {
    @pretty.parenthesized_inline(binders)
  }
}

///|
fn buslane_type_parameters_doc(
  parameters : Array[@buslane.TypeParameterId],
) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(@buslane.TypeParameterId::pretty))
  }
}

///|
fn buslane_type_arguments_doc(
  arguments : Array[@buslane.GenericArgument],
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(@buslane.GenericArgument::pretty))
  }
}

///|
fn buslane_generic_arguments_doc(
  arguments : Array[@buslane.GenericArgument],
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(@buslane.GenericArgument::pretty))
  }
}

///|
fn buslane_hidden_witnesses_doc(
  arguments : Array[@buslane.GenericArgument],
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    text(" exists") +
    @pretty.bracketed_inline(arguments.map(@buslane.GenericArgument::pretty))
  }
}
