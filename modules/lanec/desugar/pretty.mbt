///|
pub impl @prettyprinter.Pretty for DesugaredSourceFile with fn pretty(
  source : DesugaredSourceFile,
) {
  text("desugared_source") +
  space +
  @pretty.braced_block(
    source.declarations.map(DesugaredTopLevelDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for DesugaredTopLevelDeclaration with fn pretty(
  declaration : DesugaredTopLevelDeclaration,
) {
  match declaration {
    Struct(declaration) => declaration.pretty()
    Enum(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
    Let(declaration) => declaration.pretty()
    Offer(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for DesugaredFunctionDeclaration with fn pretty(
  declaration : DesugaredFunctionDeclaration,
) {
  text("fn") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  space +
  @pretty.braced_block([@pretty.section("body", [declaration.body.pretty()])])
}

///|
pub impl @prettyprinter.Pretty for DesugaredLetDeclaration with fn pretty(
  declaration : DesugaredLetDeclaration,
) {
  let name = match declaration.name {
    Some(name) => text(name)
    None => text("<anonymous>")
  }
  text("let") +
  space +
  declaration.symbol.pretty() +
  space +
  name +
  space +
  @pretty.braced_block([declaration.initializer.pretty()])
}

///|
pub impl @prettyprinter.Pretty for DesugaredOfferDeclaration with fn pretty(
  declaration : DesugaredOfferDeclaration,
) {
  text("offer") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  space +
  @pretty.braced_block([declaration.initializer.pretty()])
}

///|
pub impl @prettyprinter.Pretty for DesugaredLocalItem with fn pretty(
  item : DesugaredLocalItem,
) {
  match item {
    Let(declaration) => declaration.pretty()
    PatternLet(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
    Offer(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for DesugaredPatternLetDeclaration with fn pretty(
  declaration : DesugaredPatternLetDeclaration,
) {
  text("let") +
  space +
  declaration.pattern.pretty() +
  space +
  text("=") +
  space +
  declaration.initializer.pretty()
}

///|
pub impl @prettyprinter.Pretty for DesugaredStructLiteralField with fn pretty(
  field : DesugaredStructLiteralField,
) {
  match field {
    Value(name~, value~, ..) => text(name) + text(":") + space + value.pretty()
    TypeWitness(name~, witness~, ..) =>
      text(name) + space + text("=") + space + witness.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for DesugaredMatchArm with fn pretty(
  arm : DesugaredMatchArm,
) {
  arm.pattern.pretty() + space + text("=>") + space + arm.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for DesugaredLiteral with fn pretty(
  literal : DesugaredLiteral,
) {
  match literal {
    Int(value) => text(value)
    String(value) => text("\"") + text(value) + text("\"")
    Bool(value) => text(value.to_string())
    Unit => text("()")
  }
}

///|
pub impl @prettyprinter.Pretty for DesugaredExpr with fn pretty(
  expr : DesugaredExpr,
) {
  match expr {
    Literal(literal~, ..) => literal.pretty()
    Var(name~, reference~, ..) =>
      text("var") + space + reference.pretty() + space + text(name)
    VariantCall(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      ..
    ) => {
      let owner = match type_name {
        Some(type_name) =>
          text(type_name) + type_arguments_doc(type_arguments) + text("::")
        None => empty
      }
      reference.pretty() +
      space +
      owner +
      text(variant) +
      type_arguments_doc(variant_type_arguments) +
      @pretty.parenthesized_inline(arguments.map(DesugaredExpr::pretty))
    }
    StructLiteral(type_name~, type_arguments~, fields~, ..) =>
      text(type_name) +
      type_arguments_doc(type_arguments) +
      text("::") +
      @pretty.braced_block(fields.map(DesugaredStructLiteralField::pretty))
    Builtin(name, ..) => text("builtin") + text("(") + text(name) + text(")")
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) => {
      let result = match return_type {
        Some(type_) => space + text("->") + space + type_.pretty()
        None => empty
      }
      text("fn") +
      type_parameters_doc(type_parameters) +
      function_literal_parameters_doc(parameters) +
      result +
      space +
      body.pretty()
    }
    Block(items~, result~, ..) => {
      let docs = items.map(DesugaredLocalItem::pretty)
      docs.push(result.pretty())
      @pretty.braced_block(docs)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      text("if") +
      space +
      condition.pretty() +
      space +
      then_branch.pretty() +
      space +
      text("else") +
      space +
      else_branch.pretty()
    Match(scrutinee~, arms~, ..) =>
      text("match") +
      space +
      scrutinee.pretty() +
      space +
      @pretty.braced_block(arms.map(DesugaredMatchArm::pretty))
    Call(callee~, arguments~, ..) =>
      callee.pretty() +
      @pretty.parenthesized_inline(arguments.map(DesugaredCallArgument::pretty))
    Field(base~, name~, reference~, ..) =>
      base.pretty() + text(".") + reference.pretty() + space + text(name)
  }
}

///|
pub impl @prettyprinter.Pretty for DesugaredCallArgument with fn pretty(
  argument : DesugaredCallArgument,
) {
  match argument {
    Positional(expression) => expression.pretty()
    Named(name~, value~, ..) => text(name) + text("=") + value.pretty()
  }
}

///|
fn type_arguments_doc(types : Array[@resolve.ResolvedType]) -> Document {
  if types.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(types.map(@resolve.ResolvedType::pretty))
  }
}

///|
fn type_parameters_doc(
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(
      parameters.map(@resolve.ResolvedTypeParameter::pretty),
    )
  }
}

///|
fn function_literal_parameters_doc(
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
) -> Document {
  @pretty.parenthesized_inline(
    parameters.map(@resolve.ResolvedFunctionLiteralParameter::pretty),
  )
}
