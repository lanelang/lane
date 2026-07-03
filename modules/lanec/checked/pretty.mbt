///|
pub impl @prettyprinter.Pretty for CheckedSourceFile with fn pretty(
  source : CheckedSourceFile,
) {
  text("checked") +
  space +
  @pretty.braced_block(
    source.declarations.map(CheckedTopLevelDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for CheckedTopLevelDeclaration with fn pretty(
  declaration : CheckedTopLevelDeclaration,
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
pub impl @prettyprinter.Pretty for CheckedStructDeclaration with fn pretty(
  declaration : CheckedStructDeclaration,
) {
  text("struct") +
  space +
  type_name_doc(declaration.name, declaration.symbol) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(
    declaration.type_members.map(CheckedTypeMemberDeclaration::pretty) +
    declaration.fields.map(CheckedFieldDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for CheckedTypeMemberDeclaration with fn pretty(
  type_member : CheckedTypeMemberDeclaration,
) {
  text("type") +
  space +
  type_member_name_doc(type_member.name, type_member.symbol) +
  space +
  text(":") +
  space +
  type_member.kind.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedFieldDeclaration with fn pretty(
  field : CheckedFieldDeclaration,
) {
  let modifier = if field.is_offered { text("offer") + space } else { empty }
  modifier +
  field_name_doc(field.name, field.symbol) +
  space +
  text(":") +
  space +
  field.type_.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedEnumDeclaration with fn pretty(
  declaration : CheckedEnumDeclaration,
) {
  text("enum") +
  space +
  type_name_doc(declaration.name, declaration.symbol) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(
    declaration.variants.map(CheckedVariantDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for CheckedVariantDeclaration with fn pretty(
  variant : CheckedVariantDeclaration,
) {
  variant_name_doc(variant.name, variant.symbol) +
  type_parameters_doc(variant.type_parameters) +
  payload_doc(variant.payload)
}

///|
pub impl @prettyprinter.Pretty for CheckedEffectDeclaration with fn pretty(
  declaration : CheckedEffectDeclaration,
) {
  text("effect") +
  space +
  effect_name_doc(declaration.name, declaration.symbol) +
  type_parameters_doc(declaration.type_parameters) +
  space +
  @pretty.braced_block(
    declaration.operations.map(CheckedEffectOperationDeclaration::pretty),
  )
}

///|
pub impl @prettyprinter.Pretty for CheckedEffectOperationDeclaration with fn pretty(
  operation : CheckedEffectOperationDeclaration,
) {
  operation_name_doc(operation.name, operation.symbol) +
  type_parameters_doc(operation.type_parameters) +
  payload_doc(operation.payload) +
  space +
  text("->") +
  space +
  operation.result.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedFunctionDeclaration with fn pretty(
  declaration : CheckedFunctionDeclaration,
) {
  text("fn") +
  type_parameters_doc(declaration.type_parameters) +
  space +
  value_name_doc(declaration.name, declaration.symbol) +
  @pretty.parenthesized_inline(
    declaration.parameters.map(CheckedValueParameter::pretty),
  ) +
  space +
  text("->") +
  space +
  declaration.return_type.pretty() +
  space +
  function_body_doc(declaration.body)
}

///|
pub impl @prettyprinter.Pretty for CheckedLetDeclaration with fn pretty(
  declaration : CheckedLetDeclaration,
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
  expression_doc(declaration.initializer)
}

///|
pub impl @prettyprinter.Pretty for CheckedValueParameter with fn pretty(
  parameter : CheckedValueParameter,
) {
  parameter_prefix_doc(parameter) +
  value_name_doc(parameter.name, parameter.symbol) +
  space +
  text(":") +
  space +
  parameter.type_.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedLocalItem with fn pretty(
  item : CheckedLocalItem,
) {
  match item {
    Let(declaration) => declaration.pretty()
    PatternLet(declaration) => declaration.pretty()
    Function(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for CheckedPatternLetDeclaration with fn pretty(
  declaration : CheckedPatternLetDeclaration,
) {
  text("let") +
  space +
  declaration.pattern.pretty() +
  space +
  text("=") +
  space +
  expression_doc(declaration.initializer)
}

///|
pub impl @prettyprinter.Pretty for CheckedExpr with fn pretty(
  expression : CheckedExpr,
) {
  expression_doc(expression) +
  space +
  text(":") +
  space +
  expression.type_().pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedStructTypeWitness with fn pretty(
  witness : CheckedStructTypeWitness,
) {
  text("type") +
  space +
  type_member_name_doc(witness.name, witness.symbol) +
  space +
  text("=") +
  space +
  witness.type_.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedStructLiteralField with fn pretty(
  field : CheckedStructLiteralField,
) {
  field_name_doc(field.name, field.symbol) +
  text(":") +
  space +
  expression_doc(field.value)
}

///|
pub impl @prettyprinter.Pretty for CheckedMatchArm with fn pretty(
  arm : CheckedMatchArm,
) {
  arm.pattern.pretty() + space + text("=>") + space + expression_doc(arm.body)
}

///|
pub impl @prettyprinter.Pretty for CheckedHandlerTable with fn pretty(
  table : CheckedHandlerTable,
) {
  text("with") +
  space +
  table.handled_effect.pretty() +
  space +
  @pretty.braced_block(table.operations.map(CheckedHandlerOperationArm::pretty))
}

///|
pub impl @prettyprinter.Pretty for CheckedHandlerOperationArm with fn pretty(
  arm : CheckedHandlerOperationArm,
) {
  let parameters = arm.payload_patterns.map(CheckedPattern::pretty)
  parameters.push(value_name_doc(arm.resume_binder, arm.resume_symbol))
  let body = match arm.body {
    Some(body) => expression_doc(body)
    None => text("<unchecked>")
  }
  operation_symbol_doc(arm.operation) +
  type_parameters_doc(arm.type_binders) +
  @pretty.parenthesized_inline(parameters) +
  space +
  text("=>") +
  space +
  body
}

///|
pub impl @prettyprinter.Pretty for CheckedHandlerFinalBranch with fn pretty(
  branch : CheckedHandlerFinalBranch,
) {
  let body = match branch.body {
    Some(body) => expression_doc(body)
    None => text("<unchecked>")
  }
  text("final") +
  space +
  value_name_doc(branch.binder, branch.binder_symbol) +
  space +
  body
}

///|
pub impl @prettyprinter.Pretty for CheckedPattern with fn pretty(
  pattern : CheckedPattern,
) {
  match pattern {
    Wildcard(..) => text("_")
    Binding(name~, symbol~, ..) => value_name_doc(name, symbol)
    Literal(literal~, ..) => literal_doc(literal)
    Variant(symbol~, type_arguments~, arguments~, ..) =>
      variant_symbol_doc(symbol) +
      type_arguments_doc(type_arguments) +
      @pretty.parenthesized_inline(arguments.map(CheckedPattern::pretty))
    Struct(symbol~, type_binders~, fields~, ..) =>
      type_symbol_doc(symbol) +
      text("::") +
      @pretty.braced_block(
        type_binders.map(CheckedStructTypeBinder::pretty) +
        fields.map(CheckedStructPatternField::pretty),
      )
  }
}

///|
pub impl @prettyprinter.Pretty for CheckedStructTypeBinder with fn pretty(
  binder : CheckedStructTypeBinder,
) {
  match (binder.type_parameter, binder.name) {
    (Some(parameter), Some(name)) =>
      text("type") +
      space +
      type_member_name_doc(name, binder.symbol) +
      space +
      text("=") +
      space +
      type_parameter_ref_doc(parameter)
    _ =>
      text("type") +
      space +
      binder.symbol.pretty() +
      space +
      text("=") +
      space +
      text("_")
  }
}

///|
pub impl @prettyprinter.Pretty for CheckedStructPatternField with fn pretty(
  field : CheckedStructPatternField,
) {
  field_name_doc(field.name, field.symbol) +
  text(":") +
  space +
  field.pattern.pretty()
}

///|
fn expression_doc(expression : CheckedExpr) -> Document {
  match expression {
    Literal(literal~, ..) => literal_doc(literal)
    Value(name~, symbol~, ..) => value_name_doc(name, symbol)
    UnsafeBuiltin(name~, ..) =>
      text("builtin") + text("(") + quoted_doc(name) + text(")")
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) =>
      text("fn") +
      type_parameters_doc(type_parameters) +
      @pretty.parenthesized_inline(
        parameters.map(CheckedValueParameter::pretty),
      ) +
      space +
      text("->") +
      space +
      return_type.pretty() +
      space +
      function_body_doc(body)
    TypeApplication(callee~, arguments~, ..) =>
      expression_doc(callee) + type_arguments_doc(arguments)
    Block(items~, result~, ..) => block_doc(items, result)
    If(condition~, then_branch~, else_branch~, ..) =>
      text("if") +
      space +
      expression_doc(condition) +
      space +
      expression_doc(then_branch) +
      space +
      text("else") +
      space +
      expression_doc(else_branch)
    Match(scrutinee~, arms~, ..) =>
      text("match") +
      space +
      expression_doc(scrutinee) +
      space +
      @pretty.braced_block(arms.map(CheckedMatchArm::pretty))
    Call(callee~, arguments~, ..) =>
      expression_doc(callee) +
      @pretty.parenthesized_inline(
        arguments.map(fn(argument) { expression_doc(argument.value) }),
      )
    OperationCall(operation~, type_witnesses~, arguments~, ..) =>
      operation.pretty() +
      text("!") +
      type_arguments_doc(type_witnesses) +
      @pretty.parenthesized_inline(arguments.map(expression_doc))
    Handler(body~, handlers~, final_branch~, ..) => {
      let body_doc = match body {
        Some(body) => expression_doc(body)
        None => text("<unchecked>")
      }
      let docs = [text("handle") + space + body_doc]
      for handler in handlers {
        docs.push(handler.pretty())
      }
      docs.push(final_branch.pretty())
      @pretty.braced_block(docs)
    }
    Field(base~, field~, name~, ..) =>
      expression_doc(base) + text(".") + field_name_doc(name, field)
    StructLiteral(symbol~, type_arguments~, type_witnesses~, fields~, ..) =>
      type_symbol_doc(symbol) +
      type_arguments_doc(type_arguments) +
      text("::") +
      @pretty.braced_block(
        type_witnesses.map(CheckedStructTypeWitness::pretty) +
        fields.map(CheckedStructLiteralField::pretty),
      )
    Variant(symbol~, type_arguments~, arguments~, ..) =>
      variant_symbol_doc(symbol) +
      type_arguments_doc(type_arguments) +
      @pretty.parenthesized_inline(arguments.map(expression_doc))
  }
}

///|
fn block_doc(items : Array[CheckedLocalItem], result : CheckedExpr) -> Document {
  let docs = items.map(CheckedLocalItem::pretty)
  docs.push(expression_doc(result))
  @pretty.braced_block(docs)
}

///|
fn function_body_doc(body : CheckedExpr) -> Document {
  if body is Block(..) {
    expression_doc(body)
  } else {
    block_doc([], body)
  }
}

///|
fn parameter_prefix_doc(parameter : CheckedValueParameter) -> Document {
  let auto = if parameter.is_auto { text("auto") + space } else { empty }
  let offer = if parameter.is_offered { text("offer") + space } else { empty }
  auto + offer
}

///|
fn literal_doc(literal : CheckedLiteral) -> Document {
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
fn type_name_doc(name : String, symbol : TypeSymbolId) -> Document {
  text(name) + type_suffix(symbol)
}

///|
fn type_member_name_doc(name : String, symbol : TypeMemberSymbolId) -> Document {
  text(name) + type_member_suffix(symbol)
}

///|
fn field_name_doc(name : String, symbol : FieldSymbolId) -> Document {
  text(name) + field_suffix(symbol)
}

///|
fn variant_name_doc(name : String, symbol : VariantSymbolId) -> Document {
  text(name) + variant_suffix(symbol)
}

///|
fn effect_name_doc(name : String, symbol : EffectSymbolId) -> Document {
  text(name) + effect_suffix(symbol)
}

///|
fn operation_name_doc(name : String, symbol : OperationSymbolId) -> Document {
  text(name) + operation_suffix(symbol)
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
fn operation_symbol_doc(symbol : OperationSymbolId) -> Document {
  text("operation") + operation_suffix(symbol)
}

///|
fn type_parameter_doc(parameter : @types.TypeParameter) -> Document {
  text(parameter.name) +
  type_parameter_suffix(parameter.id) +
  space +
  text(":") +
  space +
  parameter.kind.pretty()
}

///|
fn type_parameter_ref_doc(parameter : @types.TypeParameter) -> Document {
  text(parameter.name) + type_parameter_suffix(parameter.id)
}

///|
fn type_suffix(symbol : TypeSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn type_member_suffix(symbol : TypeMemberSymbolId) -> Document {
  text("#\{symbol.index}")
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
fn variant_suffix(symbol : VariantSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn effect_suffix(symbol : EffectSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn operation_suffix(symbol : OperationSymbolId) -> Document {
  text("#\{symbol.index}")
}

///|
fn type_parameter_suffix(symbol : TypeParameterId) -> Document {
  text("#\{symbol.index}")
}

///|
fn type_parameters_doc(parameters : Array[@types.TypeParameter]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    @pretty.bracketed_inline(parameters.map(type_parameter_doc))
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
fn payload_doc(payload : Array[@types.Type]) -> Document {
  if payload.is_empty() {
    empty
  } else {
    @pretty.parenthesized_inline(payload.map(@types.Type::pretty))
  }
}

///|
fn quoted_doc(value : String) -> Document {
  text("\"") + text(value) + text("\"")
}
