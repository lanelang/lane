///|
pub impl @prettyprinter.Pretty for ResolvedSourceFile with fn pretty(
  source : ResolvedSourceFile,
) {
  text("resolved") +
  space +
  @pretty.braced_block([
    source.symbols.pretty(),
    @pretty.section(
      "declarations",
      source.declarations.map(ResolvedTopLevelDeclaration::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for ResolvedTopLevelDeclaration with fn pretty(
  declaration : ResolvedTopLevelDeclaration,
) {
  match declaration {
    Struct(declaration) => declaration.pretty()
    Enum(declaration) => declaration.pretty()
    Effect(declaration) => declaration.pretty()
    TypeAlias(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
    Let(declaration) => declaration.pretty()
    Offer(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolveResult with fn pretty(
  result : ResolveResult,
) {
  text("resolve_result") +
  space +
  @pretty.braced_block([
    result.source.pretty(),
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(ResolveDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for ResolveDiagnostic with fn pretty(
  diagnostic : ResolveDiagnostic,
) {
  diagnostic.kind.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolveDiagnosticKind with fn pretty(
  kind : ResolveDiagnosticKind,
) {
  match kind {
    UnresolvedType(name) => text("unresolved_type") + space + text(name)
    UnresolvedValue(name) => text("unresolved_value") + space + text(name)
    UnresolvedField(type_name~, field~) =>
      text("unresolved_field") +
      space +
      text(type_name) +
      text(".") +
      text(field)
    UnresolvedQualifiedVariant(type_name~, variant~) =>
      text("unresolved_variant") +
      space +
      text(type_name) +
      text("::") +
      text(variant)
    PayloadlessVariantCall(name) =>
      text("payloadless_variant_call") + space + text(name)
    ConflictingTopLevelValue(name~, existing~, incoming~) =>
      text("conflicting_top_value") +
      space +
      text(name) +
      space +
      text("existing=") +
      text(existing) +
      space +
      text("incoming=") +
      text(incoming)
    AmbiguousModuleValue(name) =>
      text("ambiguous_module_value") + space + text(name)
    AmbiguousUnqualifiedVariant(name~, candidates~) =>
      text("ambiguous_variant") +
      space +
      text(name) +
      space +
      @pretty.bracketed_inline(candidates.map(ResolveVariantCandidate::pretty))
  }
}

///|
pub impl @prettyprinter.Pretty for ResolveVariantCandidate with fn pretty(
  candidate : ResolveVariantCandidate,
) {
  text(candidate.owner) + text("::") + text(candidate.variant)
}

///|
pub impl @prettyprinter.Pretty for ResolvedStructDeclaration with fn pretty(
  declaration : ResolvedStructDeclaration,
) {
  text("struct") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(declaration.members.map(ResolvedStructMember::pretty))
}

///|
pub impl @prettyprinter.Pretty for ResolvedStructMember with fn pretty(
  item : ResolvedStructMember,
) {
  match item {
    TypeMember(type_member) => type_member.pretty()
    Field(field) => field.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedTypeMemberDeclaration with fn pretty(
  type_member : ResolvedTypeMemberDeclaration,
) {
  text("type") +
  space +
  type_member.symbol.pretty() +
  space +
  type_member.type_parameter.symbol.pretty() +
  space +
  text(type_member.name) +
  space +
  text(":") +
  space +
  type_member.kind.pretty() +
  space +
  text("index=\{type_member.index}")
}

///|
pub impl @prettyprinter.Pretty for ResolvedKind with fn pretty(
  kind : ResolvedKind,
) {
  match kind {
    Type(..) => text("Type")
    Effect(..) => text("Effect")
    Function(parameters~, result~, ..) =>
      @pretty.bracketed_inline(parameters.map(ResolvedKind::pretty)) +
      space +
      text("->") +
      space +
      result.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedFieldDeclaration with fn pretty(
  field : ResolvedFieldDeclaration,
) {
  let modifier = if field.is_offered { text("offer") + space } else { empty }
  text("field") +
  space +
  modifier +
  field.symbol.pretty() +
  space +
  text(field.name) +
  space +
  text(":") +
  space +
  field.type_.pretty() +
  space +
  text("index=\{field.index}")
}

///|
pub impl @prettyprinter.Pretty for ResolvedEnumDeclaration with fn pretty(
  declaration : ResolvedEnumDeclaration,
) {
  text("enum") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(declaration.variants.map(ResolvedEnumVariant::pretty))
}

///|
pub impl @prettyprinter.Pretty for ResolvedEnumVariant with fn pretty(
  variant : ResolvedEnumVariant,
) {
  text("variant") +
  space +
  variant.symbol.pretty() +
  space +
  text(variant.name) +
  space +
  text("index=\{variant.index}") +
  space +
  text("payloads=\{variant.payload.length()}") +
  type_parameters_doc(variant.type_parameters) +
  payload_doc(variant.payload)
}

///|
pub impl @prettyprinter.Pretty for ResolvedTypeAliasDeclaration with fn pretty(
  declaration : ResolvedTypeAliasDeclaration,
) {
  text("type") +
  space +
  text(declaration.name) +
  space +
  text("=") +
  space +
  declaration.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedEffectDeclaration with fn pretty(
  declaration : ResolvedEffectDeclaration,
) {
  text("effect") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(
    declaration.operations.map(ResolvedEffectOperationDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for ResolvedEffectOperationDeclaration with fn pretty(
  operation : ResolvedEffectOperationDeclaration,
) {
  text("operation") +
  space +
  operation.symbol.pretty() +
  space +
  text(operation.name) +
  space +
  text("index=\{operation.index}") +
  type_parameters_doc(operation.type_parameters) +
  payload_doc(operation.payload) +
  space +
  text("->") +
  space +
  operation.result.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedFunctionDeclaration with fn pretty(
  declaration : ResolvedFunctionDeclaration,
) {
  text("fn") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  type_parameters_doc(declaration.type_parameters) +
  parameters_doc(declaration.parameters) +
  space +
  text("->") +
  space +
  declaration.return_type.pretty() +
  space +
  declaration.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedLetDeclaration with fn pretty(
  declaration : ResolvedLetDeclaration,
) {
  let name = match declaration.name {
    Some(name) => text(name)
    None => text("<anonymous>")
  }
  let annotation = match declaration.type_annotation {
    Some(type_) => space + text(":") + space + type_.pretty()
    None => empty
  }
  text("let") +
  space +
  declaration.symbol.pretty() +
  space +
  name +
  annotation +
  space +
  text("=") +
  space +
  declaration.initializer.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedOfferDeclaration with fn pretty(
  declaration : ResolvedOfferDeclaration,
) {
  text("offer") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
  space +
  text(":") +
  space +
  declaration.type_annotation.pretty() +
  space +
  text("=") +
  space +
  declaration.initializer.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedTypeParameter with fn pretty(
  parameter : ResolvedTypeParameter,
) {
  let kind = match parameter.kind {
    Some(kind) => space + text(":") + space + kind.pretty()
    None => empty
  }
  parameter.symbol.pretty() + space + text(parameter.name) + kind
}

///|
pub impl @prettyprinter.Pretty for ResolvedValueParameter with fn pretty(
  parameter : ResolvedValueParameter,
) {
  parameter_modifiers(parameter.is_auto, parameter.is_offered) +
  parameter.symbol.pretty() +
  space +
  text(parameter.name) +
  space +
  text(":") +
  space +
  parameter.type_.pretty()
}

///|
fn parameter_modifiers(is_auto : Bool, is_offered : Bool) -> Document {
  let docs = []
  if is_auto {
    docs.push(text("auto"))
  }
  if is_offered {
    docs.push(text("offer"))
  }
  if docs.is_empty() {
    empty
  } else {
    let mut doc = docs[0]
    for index in 1..<docs.length() {
      doc = doc + space + docs[index]
    }
    doc + space
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedType with fn pretty(
  type_ : ResolvedType,
) {
  match type_ {
    Primitive(primitive, ..) => primitive.pretty()
    Constructor(symbol~, name~, ..) => symbol.pretty() + space + text(name)
    Alias(name~, ..) => text("alias") + space + text(name)
    Apply(callee~, arguments~, ..) =>
      callee.pretty() +
      @pretty.bracketed_inline(arguments.map(ResolvedType::pretty))
    TypeLambda(parameters~, body~, ..) =>
      text("type") +
      type_parameters_doc(parameters) +
      space +
      text("=>") +
      space +
      body.pretty()
    Parameter(symbol~, name~, ..) => symbol.pretty() + space + text(name)
    Function(type_parameters~, parameters~, result~, ..) => {
      let forall = type_parameters_doc(type_parameters)
      forall +
      @pretty.parenthesized_inline(parameters.map(ResolvedType::pretty)) +
      space +
      text("->") +
      space +
      result.pretty()
    }
    Unresolved(name~, arguments~, ..) =>
      if arguments.is_empty() {
        text("?") + text(name)
      } else {
        text("?") +
        text(name) +
        @pretty.bracketed_inline(arguments.map(ResolvedType::pretty))
      }
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedValueReference with fn pretty(
  reference : ResolvedValueReference,
) {
  match reference {
    Symbol(symbol) => symbol.pretty()
    Unresolved(name) => text("?") + text(name)
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedFieldReference with fn pretty(
  reference : ResolvedFieldReference,
) {
  match reference {
    Symbol(symbol) => symbol.pretty()
    Deferred(name) => text("?") + text(name)
    Unresolved(type_name~, field~) =>
      text("?") + text(type_name) + text(".") + text(field)
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedVariantReference with fn pretty(
  reference : ResolvedVariantReference,
) {
  match reference {
    Symbol(symbol) => symbol.pretty()
    Unresolved(type_name~, variant~) =>
      text("?") + text(type_name) + text("::") + text(variant)
    UnresolvedUnqualified(name) => text("?") + text(name)
    Ambiguous(name~, candidates~) =>
      text("?ambiguous") +
      space +
      text(name) +
      space +
      @pretty.bracketed_inline(candidates.map(VariantSymbolId::pretty))
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedFunctionLiteralParameter with fn pretty(
  parameter : ResolvedFunctionLiteralParameter,
) {
  let annotation = match parameter.type_annotation {
    Some(type_) => space + text(":") + space + type_.pretty()
    None => empty
  }
  let prefix = if parameter.is_offered { text("offer") + space } else { empty }
  prefix + parameter.symbol.pretty() + space + text(parameter.name) + annotation
}

///|
pub impl @prettyprinter.Pretty for ResolvedCallArgument with fn pretty(
  argument : ResolvedCallArgument,
) {
  match argument {
    Positional(expression) => expression.pretty()
    Named(name~, value~, ..) => text(name) + text("=") + value.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedStructLiteralField with fn pretty(
  field : ResolvedStructLiteralField,
) {
  match field {
    Value(name~, value~, ..) =>
      match value {
        Some(value) => text(name) + text(":") + space + value.pretty()
        None => text(name)
      }
    TypeWitness(name~, witness~, ..) =>
      text(name) + space + text("=") + space + witness.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedLocalItem with fn pretty(
  item : ResolvedLocalItem,
) {
  match item {
    Let(declaration) => declaration.pretty()
    PatternLet(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
    Offer(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedPatternLetDeclaration with fn pretty(
  declaration : ResolvedPatternLetDeclaration,
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
pub impl @prettyprinter.Pretty for ResolvedMatchArm with fn pretty(
  arm : ResolvedMatchArm,
) {
  arm.pattern.pretty() + space + text("=>") + space + arm.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for ResolvedStructPatternField with fn pretty(
  field : ResolvedStructPatternField,
) {
  match field {
    Value(name~, pattern~, ..) =>
      text(name) + text(":") + space + pattern.pretty()
    TypeBinder(name~, type_parameter~, ..) =>
      text("type") + space + type_parameter.symbol.pretty() + space + text(name)
    TypeWildcard(type_parameter~, ..) =>
      text("type") + space + type_parameter.symbol.pretty() + space + text("_")
  }
}

///|
pub impl @prettyprinter.Pretty for ResolvedExpr with fn pretty(
  expr : ResolvedExpr,
) {
  match expr {
    IntLiteral(value, ..) => text(value)
    StringLiteral(value, ..) => text("\"") + text(value) + text("\"")
    BoolLiteral(value, ..) => text(value.to_string())
    UnitLiteral(..) => text("()")
    Var(name~, reference~, ..) =>
      text("var") + space + reference.pretty() + space + text(name)
    QualifiedVariant(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      ..
    ) =>
      reference.pretty() +
      space +
      text(type_name) +
      type_arguments_doc(type_arguments) +
      text("::") +
      text(variant) +
      type_arguments_doc(variant_type_arguments) +
      @pretty.parenthesized_inline(arguments.map(ResolvedExpr::pretty))
    UnqualifiedVariant(variant~, reference~, arguments~, ..) =>
      reference.pretty() +
      space +
      text(variant) +
      @pretty.parenthesized_inline(arguments.map(ResolvedExpr::pretty))
    StructLiteral(type_name~, type_arguments~, fields~, ..) =>
      text(type_name) +
      type_arguments_doc(type_arguments) +
      text("::") +
      @pretty.braced_block(fields.map(ResolvedStructLiteralField::pretty))
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
      let docs = items.map(ResolvedLocalItem::pretty)
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
      @pretty.braced_block(arms.map(ResolvedMatchArm::pretty))
    Call(callee~, arguments~, ..) =>
      callee.pretty() +
      @pretty.parenthesized_inline(arguments.map(ResolvedCallArgument::pretty))
    Field(base~, name~, reference~, ..) =>
      base.pretty() + text(".") + reference.pretty() + space + text(name)
    Unary(operator~, reference~, operand~, ..) =>
      operator.pretty() +
      operator_reference_doc(reference) +
      space +
      operand.pretty()
    Binary(operator~, reference~, left~, right~, ..) =>
      left.pretty() +
      space +
      operator.pretty() +
      operator_reference_doc(reference) +
      space +
      right.pretty()
    Pipeline(left~, right~, ..) =>
      left.pretty() + space + text("|>") + space + right.pretty()
  }
}

///|
fn operator_reference_doc(reference : ResolvedValueReference) -> Document {
  text("[") + reference.pretty() + text("]")
}

///|
pub impl @prettyprinter.Pretty for ResolvedPattern with fn pretty(
  pattern : ResolvedPattern,
) {
  match pattern {
    Wildcard(_) => text("_")
    Binding(name~, symbol~, ..) =>
      text("bind") + space + symbol.pretty() + space + text(name)
    IntLiteral(value, ..) => text(value)
    StringLiteral(value, ..) => text("\"") + text(value) + text("\"")
    BoolLiteral(value, ..) => text(value.to_string())
    QualifiedVariant(
      type_name~,
      variant~,
      type_binders~,
      reference~,
      arguments~,
      ..
    ) => {
      let head = reference.pretty() +
        space +
        text(type_name) +
        text("::") +
        text(variant) +
        type_parameters_doc(type_binders)
      if arguments.is_empty() {
        head
      } else {
        head +
        @pretty.parenthesized_inline(arguments.map(ResolvedPattern::pretty))
      }
    }
    ShorthandVariant(variant~, type_binders~, arguments~, ..) => {
      let head = text("::") + text(variant) + type_parameters_doc(type_binders)
      if arguments.is_empty() {
        head
      } else {
        head +
        @pretty.parenthesized_inline(arguments.map(ResolvedPattern::pretty))
      }
    }
    Struct(type_name~, fields~, ..) =>
      text(type_name) +
      @pretty.braced_block(fields.map(ResolvedStructPatternField::pretty))
  }
}

///|
fn type_parameters_doc(parameters : Array[ResolvedTypeParameter]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(ResolvedTypeParameter::pretty))
  }
}

///|
fn parameters_doc(parameters : Array[ResolvedValueParameter]) -> Document {
  @pretty.parenthesized_inline(parameters.map(ResolvedValueParameter::pretty))
}

///|
fn function_literal_parameters_doc(
  parameters : Array[ResolvedFunctionLiteralParameter],
) -> Document {
  @pretty.parenthesized_inline(
    parameters.map(ResolvedFunctionLiteralParameter::pretty),
  )
}

///|
fn payload_doc(payload : Array[ResolvedType]) -> Document {
  if payload.is_empty() {
    empty
  } else {
    @pretty.parenthesized_inline(payload.map(ResolvedType::pretty))
  }
}

///|
fn type_arguments_doc(arguments : Array[ResolvedType]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(arguments.map(ResolvedType::pretty))
  }
}
