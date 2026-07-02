///|
using @prettyprinter {type Document, empty, space, text}

///|
pub impl @prettyprinter.Pretty for AnfProgram with fn pretty(
  program : AnfProgram,
) {
  text("anf") +
  space +
  @pretty.braced_block(program.declarations.map(AnfTopLevelDeclaration::pretty))
}

///|
pub impl @prettyprinter.Pretty for AnfTopLevelDeclaration with fn pretty(
  declaration : AnfTopLevelDeclaration,
) {
  match declaration {
    Struct(declaration) => declaration.pretty()
    Enum(declaration) => declaration.pretty()
    Effect(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
    Let(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for AnfFunctionDeclaration with fn pretty(
  declaration : AnfFunctionDeclaration,
) {
  text("fn") +
  type_parameters_doc(declaration.type_parameters) +
  space +
  value_name_doc(declaration.name, declaration.symbol) +
  @pretty.parenthesized_inline(
    declaration.parameters.map(@checked.CheckedValueParameter::pretty),
  ) +
  space +
  text("->") +
  space +
  declaration.return_type.pretty() +
  space +
  anf_body_doc(declaration.body)
}

///|
pub impl @prettyprinter.Pretty for AnfLetDeclaration with fn pretty(
  declaration : AnfLetDeclaration,
) {
  let name = match declaration.name {
    Some(name) => value_name_doc(name, declaration.symbol)
    None => text("_") + value_suffix(declaration.symbol)
  }
  text("let") +
  space +
  name +
  space +
  text(":") +
  space +
  declaration.type_.pretty() +
  space +
  text("=") +
  space +
  anf_expr_doc(declaration.value)
}

///|
pub impl @prettyprinter.Pretty for AnfExpr with fn pretty(expr : AnfExpr) {
  anf_expr_doc(expr) + space + text(":") + space + expr.type_().pretty()
}

///|
pub impl @prettyprinter.Pretty for AnfBinding with fn pretty(
  binding : AnfBinding,
) {
  match binding {
    Value(symbol~, name~, rhs~, type_~, ..) => {
      let name_doc = match name {
        Some(name) => value_name_doc(name, symbol)
        None => text("_") + value_suffix(symbol)
      }
      text("let") +
      space +
      name_doc +
      space +
      text(":") +
      space +
      type_.pretty() +
      space +
      text("=") +
      space +
      anf_rhs_doc(rhs)
    }
    Temp(temp~, rhs~, type_~, ..) =>
      text("let") +
      space +
      temp.pretty() +
      space +
      text(":") +
      space +
      type_.pretty() +
      space +
      text("=") +
      space +
      anf_rhs_doc(rhs)
    Pattern(pattern~, initializer~, ..) =>
      text("let") +
      space +
      pattern.pretty() +
      space +
      text("=") +
      space +
      anf_atom_doc(initializer)
  }
}

///|
pub impl @prettyprinter.Pretty for AnfRhs with fn pretty(rhs : AnfRhs) {
  anf_rhs_doc(rhs)
}

///|
pub impl @prettyprinter.Pretty for AnfStructField with fn pretty(
  field : AnfStructField,
) {
  field_name_doc(field.name, field.symbol) +
  text(":") +
  space +
  anf_atom_doc(field.value)
}

///|
pub impl @prettyprinter.Pretty for AnfAtom with fn pretty(atom : AnfAtom) {
  anf_atom_doc(atom) + space + text(":") + space + atom.type_().pretty()
}

///|
pub impl @prettyprinter.Pretty for AnfMatchArm with fn pretty(arm : AnfMatchArm) {
  arm.pattern.pretty() + space + text("=>") + space + anf_expr_doc(arm.body)
}

///|
pub impl @prettyprinter.Pretty for AnfTempId with fn pretty(id : AnfTempId) {
  text("temp#\{id.index}")
}

///|
fn anf_expr_doc(expr : AnfExpr) -> Document {
  match expr {
    Atom(atom~, ..) => anf_atom_doc(atom)
    Let(..) => {
      let docs : Array[Document] = []
      push_anf_expr_docs(expr, docs)
      @pretty.braced_block(docs)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      text("if") +
      space +
      anf_atom_doc(condition) +
      space +
      anf_expr_doc(then_branch) +
      space +
      text("else") +
      space +
      anf_expr_doc(else_branch)
    Match(scrutinee~, arms~, ..) =>
      text("match") +
      space +
      anf_atom_doc(scrutinee) +
      space +
      @pretty.braced_block(arms.map(AnfMatchArm::pretty))
  }
}

///|
fn push_anf_expr_docs(expr : AnfExpr, docs : Array[Document]) -> Unit {
  match expr {
    Let(binding~, body~, ..) => {
      docs.push(binding.pretty())
      push_anf_expr_docs(body, docs)
    }
    _ => docs.push(anf_expr_doc(expr))
  }
}

///|
fn anf_body_doc(body : AnfExpr) -> Document {
  if body is Let(..) {
    anf_expr_doc(body)
  } else {
    @pretty.braced_block([anf_expr_doc(body)])
  }
}

///|
fn anf_rhs_doc(rhs : AnfRhs) -> Document {
  match rhs {
    Atom(atom) => anf_atom_doc(atom)
    Call(callee~, arguments~, ..) =>
      anf_atom_doc(callee) +
      @pretty.parenthesized_inline(arguments.map(anf_atom_doc))
    OperationCall(operation~, arguments~, ..) =>
      operation.pretty() +
      text("!") +
      @pretty.parenthesized_inline(arguments.map(anf_atom_doc))
    TypeApplication(callee~, arguments~, ..) =>
      anf_atom_doc(callee) + type_arguments_doc(arguments)
    Field(base~, field~, name~, ..) =>
      anf_atom_doc(base) + text(".") + field_name_doc(name, field)
    Struct(symbol~, type_arguments~, type_witnesses~, fields~, ..) =>
      type_symbol_doc(symbol) +
      type_arguments_doc(type_arguments) +
      text("::") +
      @pretty.braced_block(
        type_witnesses.map(@checked.CheckedStructTypeWitness::pretty) +
        fields.map(AnfStructField::pretty),
      )
    Variant(symbol~, type_arguments~, arguments~, ..) =>
      variant_symbol_doc(symbol) +
      type_arguments_doc(type_arguments) +
      @pretty.parenthesized_inline(arguments.map(anf_atom_doc))
  }
}

///|
fn anf_atom_doc(atom : AnfAtom) -> Document {
  match atom {
    Literal(literal~, ..) => literal_doc(literal)
    Value(name~, symbol~, ..) => value_name_doc(name, symbol)
    Temp(temp~, ..) => temp.pretty()
    UnsafeBuiltin(name~, ..) =>
      text("builtin") + text("(") + quoted_doc(name) + text(")")
    Function(parameters~, body~, ..) =>
      text("fn") +
      @pretty.parenthesized_inline(
        parameters.map(@checked.CheckedValueParameter::pretty),
      ) +
      space +
      text("->") +
      space +
      body.type_().pretty() +
      space +
      anf_body_doc(body)
    TypeLambda(type_parameters~, body~, ..) =>
      text("fn") +
      type_parameters_doc(type_parameters) +
      space +
      anf_atom_doc(body)
  }
}

///|
fn literal_doc(literal : @checked.CheckedLiteral) -> Document {
  match literal {
    Int(literal) => text(literal.raw)
    String(value) => quoted_doc(value)
    Bool(value) => text(value.to_string())
    Unit => text("()")
  }
}

///|
fn value_name_doc(name : String, symbol : ValueSymbolId) -> Document {
  text(name) + value_suffix(symbol)
}

///|
fn field_name_doc(name : String, symbol : FieldSymbolId) -> Document {
  text(name) + field_suffix(symbol)
}

///|
fn type_symbol_doc(symbol : TypeSymbolId) -> Document {
  text("type") + type_suffix(symbol)
}

///|
fn variant_symbol_doc(symbol : VariantSymbolId) -> Document {
  text("variant") + variant_suffix(symbol)
}

///|
fn value_suffix(symbol : ValueSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn field_suffix(symbol : FieldSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn type_suffix(symbol : TypeSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn variant_suffix(symbol : VariantSymbolId) -> Document {
  text("#\{symbol.index}")
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
      buslane_anf_atom_doc(callee) + buslane_type_arguments_doc(arguments)
    Construct(construct) => buslane_anf_construct_doc(construct)
  }
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
fn type_parameters_doc(parameters : Array[@types.TypeParameter]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(@types.TypeParameter::pretty))
  }
}

///|
fn type_arguments_doc(arguments : Array[@types.Type]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(@types.Type::pretty))
  }
}

///|
fn buslane_type_arguments_doc(arguments : Array[@buslane.Type]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(@buslane.Type::pretty))
  }
}

///|
fn buslane_hidden_witnesses_doc(arguments : Array[@buslane.Type]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    text(" exists") +
    @pretty.bracketed_inline(arguments.map(@buslane.Type::pretty))
  }
}

///|
fn quoted_doc(value : String) -> Document {
  text("\"") + text(value) + text("\"")
}
