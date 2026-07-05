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
    Effect(declaration) => declaration.pretty()
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
  declaration.effect.annotation_doc() +
  space +
  @pretty.braced_block([@pretty.section("body", [declaration.body.pretty()])])
}

///|
fn @resolve.ResolvedEffectTerm::annotation_doc(
  self : @resolve.ResolvedEffectTerm,
) -> Document {
  match self {
    Empty(..) => empty
    _ => space + text("!") + space + self.pretty()
  }
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
  let type_doc = match declaration.type_annotation {
    Some(type_) => space + text(":") + space + type_.pretty()
    None => empty
  }
  text("let") +
  space +
  declaration.pattern.pretty() +
  type_doc +
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
pub impl @prettyprinter.Pretty for DesugaredHandlerWithBlock with fn pretty(
  handler : DesugaredHandlerWithBlock,
) {
  text("with") +
  space +
  @pretty.braced_block(handler.arms.map(DesugaredHandlerOperationArm::pretty))
}

///|
pub impl @prettyprinter.Pretty for DesugaredHandlerOperationArm with fn pretty(
  arm : DesugaredHandlerOperationArm,
) {
  let parameters = arm.payload_patterns.map(fn(pattern) { pattern.pretty() })
  parameters.push(arm.resume_symbol.pretty() + space + text(arm.resume_binder))
  arm.name.pretty() +
  type_parameters_doc(arm.type_binders) +
  @pretty.parenthesized_inline(parameters) +
  space +
  text("=>") +
  space +
  arm.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for DesugaredHandlerFinalBranch with fn pretty(
  branch : DesugaredHandlerFinalBranch,
) {
  text("final") +
  space +
  branch.binder_symbol.pretty() +
  space +
  text(branch.binder) +
  space +
  branch.body.pretty()
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
      generic_arguments~,
      variant~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      ..
    ) => {
      let owner = match type_name {
        Some(type_name) =>
          text(type_name) +
          generic_arguments_doc(generic_arguments) +
          text("::")
        None => empty
      }
      reference.pretty() +
      space +
      owner +
      text(variant) +
      generic_arguments_doc(variant_generic_arguments) +
      @pretty.parenthesized_inline(arguments.map(DesugaredExpr::pretty))
    }
    StructLiteral(type_name~, generic_arguments~, fields~, ..) =>
      text(type_name) +
      generic_arguments_doc(generic_arguments) +
      text("::") +
      @pretty.braced_block(fields.map(DesugaredStructLiteralField::pretty))
    Builtin(name, ..) => text("builtin") + text("(") + text(name) + text(")")
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) => {
      let result = match return_type {
        Some(type_) => space + text("->") + space + type_.pretty()
        None => empty
      }
      let effect = match effect {
        Some(effect) => space + text("!") + space + effect.pretty()
        None => empty
      }
      text("fn") +
      type_parameters_doc(type_parameters) +
      function_literal_parameters_doc(parameters) +
      result +
      effect +
      space +
      body.pretty()
    }
    EffectOperationCall(name~, generic_witnesses~, arguments~, ..) =>
      name.pretty() +
      text("!") +
      generic_arguments_doc(generic_witnesses) +
      @pretty.parenthesized_inline(arguments.map(DesugaredExpr::pretty))
    GenericApplication(callee~, arguments~, ..) =>
      callee.pretty() + generic_arguments_doc(arguments)
    Handler(body~, handlers~, final_branch~, ..) => {
      let docs = [text("handle") + space + body.pretty()]
      for handler in handlers {
        docs.push(handler.pretty())
      }
      docs.push(final_branch.pretty())
      @pretty.braced_block(docs)
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
    Positional(value~, ..) => value.pretty()
    Named(name~, value~, ..) => text(name) + text("=") + value.pretty()
  }
}

///|
fn generic_arguments_doc(
  arguments : Array[@resolve.ResolvedGenericArgument],
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(
      arguments.map(@resolve.ResolvedGenericArgument::pretty),
    )
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
