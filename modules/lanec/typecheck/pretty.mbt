///|
pub impl @prettyprinter.Pretty for DeclarationTypeCheckResult with fn pretty(
  result : DeclarationTypeCheckResult,
) {
  text("declaration_typecheck_result") +
  space +
  @pretty.braced_block([
    result.declarations.pretty(),
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for TypeCheckResult with fn pretty(
  source : TypeCheckResult,
) {
  text("typecheck_result") +
  space +
  @pretty.braced_block([
    source.declarations.pretty(),
    source.values.pretty(),
    @pretty.section(
      "diagnostics",
      source.diagnostics.map(TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for CheckedSourceTypeCheckResult with fn pretty(
  result : CheckedSourceTypeCheckResult,
) {
  let source = match result.source {
    Some(source) => source.pretty()
    None => text("<no checked source>")
  }
  text("checked_source_typecheck_result") +
  space +
  @pretty.braced_block([
    source,
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for CheckedDeclarationEnvironment with fn pretty(
  environment : CheckedDeclarationEnvironment,
) {
  let sections = [
    @pretty.section(
      "types",
      environment.types.map(CheckedTypeDeclaration::pretty),
    ),
    @pretty.section(
      "type_members",
      environment.type_members.map(CheckedTypeMemberDeclaration::pretty),
    ),
    @pretty.section(
      "fields",
      environment.fields.map(CheckedFieldDeclaration::pretty),
    ),
    @pretty.section(
      "variants",
      environment.variants.map(CheckedVariantDeclaration::pretty),
    ),
  ]
  if !environment.effects.is_empty() {
    sections.push(
      @pretty.section(
        "effects",
        environment.effects.map(CheckedEffectDeclaration::pretty),
      ),
    )
  }
  if !environment.operations.is_empty() {
    sections.push(
      @pretty.section(
        "operations",
        environment.operations.map(CheckedEffectOperationDeclaration::pretty),
      ),
    )
  }
  text("checked_declarations") + space + @pretty.braced_block(sections)
}

///|
pub impl @prettyprinter.Pretty for CheckedValueEnvironment with fn pretty(
  environment : CheckedValueEnvironment,
) {
  text("checked_values") +
  space +
  @pretty.braced_block(environment.values.map(CheckedValueDeclaration::pretty))
}

///|
pub impl @prettyprinter.Pretty for CheckedTypeDeclaration with fn pretty(
  declaration : CheckedTypeDeclaration,
) {
  match declaration {
    Struct(declaration) => declaration.pretty()
    Enum(declaration) => declaration.pretty()
    Effect(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for CheckedValueDeclaration with fn pretty(
  declaration : CheckedValueDeclaration,
) {
  match declaration {
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
pub impl @prettyprinter.Pretty for CheckedFunctionDeclaration with fn pretty(
  declaration : CheckedFunctionDeclaration,
) {
  text("fn") +
  space +
  value_name_doc(declaration.name, declaration.symbol) +
  space +
  text(":") +
  space +
  declaration.type_.pretty()
}

///|
pub impl @prettyprinter.Pretty for CheckedEffectDeclaration with fn pretty(
  declaration : CheckedEffectDeclaration,
) {
  text("effect") +
  space +
  declaration.symbol.pretty() +
  space +
  text(declaration.name) +
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
  text("operation") +
  space +
  operation.symbol.pretty() +
  space +
  text(operation.name) +
  type_parameters_doc(operation.type_parameters) +
  payload_doc(operation.payload) +
  space +
  text("->") +
  space +
  operation.result.pretty()
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
  declaration.type_.pretty()
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
pub impl @prettyprinter.Pretty for TypeCheckDiagnostic with fn pretty(
  diagnostic : TypeCheckDiagnostic,
) {
  diagnostic.kind.pretty() +
  space +
  text("@") +
  space +
  @pretty.source_span(diagnostic.loc)
}

///|
pub impl @prettyprinter.Pretty for TypeCheckDiagnosticKind with fn pretty(
  kind : TypeCheckDiagnosticKind,
) {
  match kind {
    UnresolvedType(name) => text("unresolved_type") + space + text(name)
    UnresolvedValue(name) => text("unresolved_value") + space + text(name)
    MissingTopLevelLetAnnotation => text("missing_top_level_let_annotation")
    TypeArgumentArityMismatch(name~, expected~, actual~) =>
      text("type_arity_mismatch") +
      space +
      text(name) +
      space +
      text("expected=\{expected}") +
      space +
      text("actual=\{actual}")
    TypeAliasCycle(name~) => text("type_alias_cycle") + space + text(name)
    KindMismatch(expected~, actual~) =>
      text("kind_mismatch") +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    TypeMismatch(expected~, actual~) =>
      text("type_mismatch") +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    EffectMismatch(expected~, actual~) =>
      text("effect_mismatch") +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    NotCallable(type_) => text("not_callable") + space + type_.pretty()
    UnknownField(name~) => text("unknown_field") + space + text(name)
    MissingField(name~) => text("missing_field") + space + text(name)
    DuplicateField(name~) => text("duplicate_field") + space + text(name)
    UnknownTypeMember(name~) => text("unknown_type_member") + space + text(name)
    MissingTypeMember(name~) => text("missing_type_member") + space + text(name)
    DuplicateTypeMember(name~) =>
      text("duplicate_type_member") + space + text(name)
    DuplicateTypeParameter(name~) =>
      text("duplicate_type_parameter") + space + text(name)
    NotAStruct(type_) => text("not_a_struct") + space + type_.pretty()
    NonExhaustiveMatch(type_) =>
      text("non_exhaustive_match") + space + type_.pretty()
    UnreachableMatchArm => text("unreachable_match_arm")
    MixedHandlerEffects => text("mixed_handler_effects")
    DuplicateHandledEffect(effect) =>
      text("duplicate_handled_effect") + space + effect.pretty()
    MissingHandlerOperation(operation) =>
      text("missing_handler_operation") + space + operation.pretty()
    DuplicatePatternBinder(name~) =>
      text("duplicate_pattern_binder") + space + text(name)
    PatternArityMismatch(name~, expected~, actual~) =>
      text("pattern_arity_mismatch") +
      space +
      text(name) +
      space +
      text("expected=\{expected}") +
      space +
      text("actual=\{actual}")
    HiddenTypeEscape(type_~) =>
      text("hidden_type_escape") + space + type_.pretty()
    PrivateTypeEscape(name~) =>
      text("private type `") + text(name) + text("` in public interface")
    PrivateEffectEscape(name~) =>
      text("private effect `") + text(name) + text("` in public interface")
    InvalidIntLiteral(raw) => text("invalid_int_literal") + space + text(raw)
    CannotInferExpression(label~, ..) =>
      text("cannot_infer") + space + text(label)
  }
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
fn type_parameter_doc(parameter : @types.TypeParameter) -> Document {
  text(parameter.name) +
  type_parameter_suffix(parameter.id) +
  space +
  text(":") +
  space +
  parameter.kind.pretty()
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
fn value_suffix(symbol : ValueSymbolId) -> Document {
  text("#\{symbol.index}")
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
fn type_parameter_suffix(symbol : TypeParameterId) -> Document {
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
fn payload_doc(payload : Array[@types.Type]) -> Document {
  if payload.is_empty() {
    empty
  } else {
    @pretty.parenthesized_inline(payload.map(@types.Type::pretty))
  }
}
