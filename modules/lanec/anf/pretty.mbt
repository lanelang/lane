///|
using @prettyprinter {type Document, empty, space, text}

///|
pub impl @prettyprinter.Pretty for RuntimeEvidenceId with fn pretty(
  id : RuntimeEvidenceId,
) {
  match id {
    Projected(index) => text("evidence#\{index}")
    Synthetic(index) => text("synthetic-evidence#\{index}")
  }
}

///|
pub impl @prettyprinter.Pretty for RuntimeEvidenceParameter with fn pretty(
  parameter : RuntimeEvidenceParameter,
) {
  if parameter.arity == 0 {
    parameter.id.pretty()
  } else {
    parameter.id.pretty() + text("/\{parameter.arity}")
  }
}

///|
pub impl @prettyprinter.Pretty for RuntimeEvidence with fn pretty(
  evidence : RuntimeEvidence,
) {
  match evidence {
    Static(layout) => text("layout(\{Repr(layout)})")
    Parameter(id) => id.pretty()
    Apply(callee, arguments) =>
      callee.pretty() +
      @pretty.parenthesized_inline(arguments.map(RuntimeEvidence::pretty))
    Lambda(parameters, body) =>
      text("layout-fn") +
      @pretty.bracketed_inline(parameters.map(RuntimeEvidenceParameter::pretty)) +
      space +
      body.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for RuntimeArgument with fn pretty(
  argument : RuntimeArgument,
) {
  text("shape#\{argument.type_expression.index}=") + argument.evidence.pretty()
}

///|
pub impl @prettyprinter.Pretty for RuntimeType with fn pretty(
  type_ : RuntimeType,
) {
  match type_ {
    Unit => text("Unit")
    Scalar(kind) => text("\{Repr(kind)}")
    ByteSequence => text("ByteSequence")
    OpaqueReference(owner) => text("opaque#\{owner.index}")
    Data(owner, _) => text("data#\{owner.index}")
    Callable(parameters, result) =>
      @pretty.parenthesized_inline(parameters.map(RuntimeType::pretty)) +
      space +
      text("->") +
      space +
      result.pretty()
    Erased(expression, evidence) =>
      text("erased#\{expression.index}[") + evidence.pretty() + text("]")
    Forall(parameters, body) =>
      text("forall") +
      @pretty.bracketed_inline(parameters.map(RuntimeEvidenceParameter::pretty)) +
      space +
      body.pretty()
  }
}

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
pub impl @prettyprinter.Pretty for AnfAtom with fn pretty(atom : AnfAtom) {
  anf_atom_doc(atom)
}

///|
pub impl @prettyprinter.Pretty for AnfFunction with fn pretty(
  function : AnfFunction,
) {
  text("fn@\{function.id.value}") +
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
  anf_binders_doc(alternative.evidence_binders, alternative.value_binders) +
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
    ApplyEvidence(callee~, arguments~) =>
      anf_atom_doc(callee) + runtime_arguments_doc(arguments)
    Construct(construct) => anf_construct_doc(construct)
    Match(match_) => match_.pretty()
  }
}

///|
fn anf_construct_doc(construct : AnfConstruct) -> Document {
  construct.data_constructor.pretty() +
  runtime_arguments_doc(construct.type_arguments) +
  runtime_hidden_arguments_doc(construct.hidden_arguments) +
  @pretty.parenthesized_inline(construct.payloads.map(anf_atom_doc))
}

///|
fn anf_atom_doc(atom : AnfAtom) -> Document {
  match atom {
    Literal(literal) => literal.pretty()
    Ref(id) => id.pretty()
    Temp(temp) => temp.pretty()
    Function(function) => function.pretty()
    EvidenceLambda(parameters~, body~) =>
      text("fn") +
      runtime_evidence_parameters_doc(parameters) +
      space +
      anf_body_doc(body)
  }
}

///|
fn anf_binders_doc(
  evidence_binders : Array[RuntimeEvidenceParameter],
  value_binders : Array[@buslane.ValueId],
) -> Document {
  let binders = evidence_binders.map(RuntimeEvidenceParameter::pretty) +
    value_binders.map(@buslane.ValueId::pretty)
  if binders.is_empty() {
    empty
  } else {
    @pretty.parenthesized_inline(binders)
  }
}

///|
fn runtime_evidence_parameters_doc(
  parameters : Array[RuntimeEvidenceParameter],
) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(RuntimeEvidenceParameter::pretty))
  }
}

///|
fn runtime_arguments_doc(arguments : Array[RuntimeArgument]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(RuntimeArgument::pretty))
  }
}

///|
fn runtime_hidden_arguments_doc(arguments : Array[RuntimeArgument]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    text(" exists") +
    @pretty.bracketed_inline(arguments.map(RuntimeArgument::pretty))
  }
}
