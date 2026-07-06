///|
using @prettyprinter {type Document, empty, space, text}

///|
pub impl @prettyprinter.Pretty for AnfTempId with fn pretty(id : AnfTempId) {
  text("temp#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for AnfProgram with fn pretty(
  program : AnfProgram,
) {
  text("anf") +
  space +
  @pretty.braced_block(program.terms.map(AnfTopTerm::pretty))
}

///|
pub impl @prettyprinter.Pretty for AnfTopTerm with fn pretty(term : AnfTopTerm) {
  match term {
    Let(id, expr) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      anf_expr_doc(expr)
    LetRec(bindings) =>
      text("letrec") +
      space +
      @pretty.braced_block(bindings.map(AnfRecursiveBinding::pretty))
    External(id) => text("external") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for AnfRecursiveBinding with fn pretty(
  binding : AnfRecursiveBinding,
) {
  binding.id.pretty() + space + text("=") + space + anf_atom_doc(binding.rhs)
}

///|
pub impl @prettyprinter.Pretty for AnfExpr with fn pretty(expr : AnfExpr) {
  anf_expr_doc(expr)
}

///|
pub impl @prettyprinter.Pretty for AnfBinding with fn pretty(
  binding : AnfBinding,
) {
  match binding {
    Value(id~, rhs~) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      anf_rhs_doc(rhs)
    Temp(temp~, rhs~) =>
      text("let") +
      space +
      temp.pretty() +
      space +
      text("=") +
      space +
      anf_rhs_doc(rhs)
  }
}

///|
pub impl @prettyprinter.Pretty for AnfRhs with fn pretty(rhs : AnfRhs) {
  anf_rhs_doc(rhs)
}

///|
pub impl @prettyprinter.Pretty for AnfConstruct with fn pretty(
  construct : AnfConstruct,
) {
  anf_construct_doc(construct)
}

///|
pub impl @prettyprinter.Pretty for AnfPerform with fn pretty(
  perform : AnfPerform,
) {
  anf_perform_doc(perform)
}

///|
pub impl @prettyprinter.Pretty for AnfHandle with fn pretty(handle : AnfHandle) {
  anf_handle_doc(handle)
}

///|
pub impl @prettyprinter.Pretty for AnfHandlerTable with fn pretty(
  table : AnfHandlerTable,
) {
  table.handled_effect.pretty() +
  space +
  @pretty.braced_block(table.operations.map(AnfOperationAlternative::pretty))
}

///|
pub impl @prettyprinter.Pretty for AnfOperationAlternative with fn pretty(
  alternative : AnfOperationAlternative,
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
  anf_expr_doc(alternative.body)
}

///|
pub impl @prettyprinter.Pretty for AnfAtom with fn pretty(atom : AnfAtom) {
  anf_atom_doc(atom)
}

///|
pub impl @prettyprinter.Pretty for AnfFunction with fn pretty(
  function : AnfFunction,
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
  anf_body_doc(function.body)
}

///|
pub impl @prettyprinter.Pretty for AnfMatch with fn pretty(match_ : AnfMatch) {
  text("match") +
  space +
  anf_atom_doc(match_.scrutinee) +
  space +
  text("as") +
  space +
  match_.binder.pretty() +
  space +
  text("->") +
  space +
  match_.result_type.pretty() +
  space +
  @pretty.braced_block(match_.alternatives.map(AnfAlternative::pretty))
}

///|
pub impl @prettyprinter.Pretty for AnfAlternative with fn pretty(
  alternative : AnfAlternative,
) {
  alternative.alt_constructor.pretty() +
  anf_binders_doc(alternative.type_binders, alternative.value_binders) +
  space +
  text("=>") +
  space +
  anf_expr_doc(alternative.body)
}

///|
fn anf_expr_doc(expr : AnfExpr) -> Document {
  match expr {
    Atom(atom) => anf_atom_doc(atom)
    Let(_, _) | LetRec(_, _) => {
      let docs : Array[Document] = []
      push_anf_expr_docs(expr, docs)
      @pretty.braced_block(docs)
    }
    Match(match_) => match_.pretty()
  }
}

///|
fn push_anf_expr_docs(expr : AnfExpr, docs : Array[Document]) -> Unit {
  match expr {
    Let(binding, body) => {
      docs.push(binding.pretty())
      push_anf_expr_docs(body, docs)
    }
    LetRec(bindings, body) => {
      docs.push(
        text("letrec") +
        space +
        @pretty.braced_block(bindings.map(AnfRecursiveBinding::pretty)),
      )
      push_anf_expr_docs(body, docs)
    }
    _ => docs.push(anf_expr_doc(expr))
  }
}

///|
fn anf_body_doc(body : AnfExpr) -> Document {
  match body {
    Let(_, _) | LetRec(_, _) => anf_expr_doc(body)
    _ => @pretty.braced_block([anf_expr_doc(body)])
  }
}

///|
fn anf_rhs_doc(rhs : AnfRhs) -> Document {
  match rhs {
    Atom(atom) => anf_atom_doc(atom)
    Call(callee~, arguments~) =>
      anf_atom_doc(callee) +
      @pretty.parenthesized_inline(arguments.map(anf_atom_doc))
    TypeApply(callee~, arguments~) =>
      anf_atom_doc(callee) + buslane_generic_arguments_doc(arguments)
    Construct(construct) => anf_construct_doc(construct)
    Perform(perform) => anf_perform_doc(perform)
    Handle(handle) => anf_handle_doc(handle)
  }
}

///|
fn anf_perform_doc(perform : AnfPerform) -> Document {
  text("perform") +
  space +
  perform.operation.pretty() +
  buslane_type_arguments_doc(perform.effect_arguments) +
  buslane_hidden_witnesses_doc(perform.hidden_witnesses) +
  @pretty.parenthesized_inline(perform.payloads.map(anf_atom_doc))
}

///|
fn anf_handle_doc(handle : AnfHandle) -> Document {
  text("handle") +
  space +
  anf_expr_doc(handle.body) +
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
    handle.handlers.map(AnfHandlerTable::pretty) +
    [
      text("final") +
      space +
      text("=>") +
      space +
      anf_expr_doc(handle.final_body),
    ],
  )
}

///|
fn anf_construct_doc(construct : AnfConstruct) -> Document {
  construct.data_constructor.pretty() +
  buslane_type_arguments_doc(construct.type_arguments) +
  buslane_hidden_witnesses_doc(construct.hidden_witnesses) +
  @pretty.parenthesized_inline(construct.payloads.map(anf_atom_doc))
}

///|
fn anf_atom_doc(atom : AnfAtom) -> Document {
  match atom {
    Literal(literal) => literal.pretty()
    Ref(id) => id.pretty()
    Temp(temp) => temp.pretty()
    Function(function) => function.pretty()
    TypeLambda(type_parameters~, body~) =>
      text("fn") +
      buslane_type_parameters_doc(type_parameters) +
      space +
      anf_body_doc(body)
  }
}

///|
fn anf_binders_doc(
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
