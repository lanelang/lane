///|
pub impl @prettyprinter.Pretty for ExternTypeRestriction with fn pretty(
  restriction : ExternTypeRestriction,
) {
  match restriction {
    FunctionRequired => text("function_required")
    MonomorphicRequired => text("monomorphic_required")
    DirectParameterRequired(index~) =>
      text("direct_parameter_required[") + text(index.to_string()) + text("]")
    DirectResultRequired => text("direct_result_required")
    ExternalEffectRowRequired => text("external_effect_row_required")
  }
}

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
    External(declaration) => declaration.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for CheckedExternalTypeDeclaration with fn pretty(
  declaration : CheckedExternalTypeDeclaration,
) {
  text("extern") +
  space +
  text("type") +
  space +
  type_name_doc(declaration.name, declaration.symbol) +
  space +
  text(":") +
  space +
  text("Type")
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
  (if declaration.flavor is External {
    text("extern") + space + text("type")
  } else {
    text("effect")
  }) +
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
  let name = value_name_doc(declaration.name, declaration.symbol)
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
    UnresolvedEffectOperation(name) =>
      text("unresolved_effect_operation") + space + text(name)
    AmbiguousEffectOperation(name~, candidates~) =>
      text("ambiguous_effect_operation") +
      space +
      text(name) +
      space +
      text("candidates=\{candidates.length()}")
    MissingTopLevelLetAnnotation => text("missing_top_level_let_annotation")
    GenericArgumentArityMismatch(subject~, expected~, actual~) =>
      text("type_arity_mismatch") +
      space +
      subject.pretty() +
      space +
      text("expected=\{expected}") +
      space +
      text("actual=\{actual}")
    ApplicationArityMismatch(label~) =>
      text("application_arity_mismatch") + space + text(label)
    VariantReferenceFailure(label~) =>
      text("variant_reference_failure") + space + text(label)
    InternalTypecheckFailure(label~) =>
      text("internal_typecheck_failure") + space + text(label)
    CallArityMismatch(expected~, actual~) =>
      text("call_arity_mismatch") +
      space +
      text("expected=\{expected}") +
      space +
      text("actual=\{actual}")
    AutoParametersMustBeTrailing => text("auto_parameters_must_be_trailing")
    AutoArgumentMustBeNamed => text("auto_argument_must_be_named")
    DuplicateNamedArgument(name~) =>
      text("duplicate_named_argument") + space + text(name)
    UnknownContextualArgument(name~) =>
      text("unknown_contextual_argument") + space + text(name)
    InvalidNamedArgument(name~) =>
      text("invalid_named_argument") + space + text(name)
    MissingContextualOffer(expected~) =>
      text("missing_contextual_offer") + space + expected.pretty()
    AmbiguousContextualOffer(expected~, candidates~) =>
      text("ambiguous_contextual_offer") +
      space +
      expected.pretty() +
      space +
      text(
        "candidates=[" +
        candidates.map(fn(candidate) { candidate.name }).join(", ") +
        "]",
      )
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
    GenericArgumentsOnNonGeneric(subject~, type_~) =>
      text("generic_arguments_on_non_generic") +
      space +
      subject.pretty() +
      space +
      type_.pretty()
    UnknownField(name~) => text("unknown_field") + space + text(name)
    MissingField(name~) => text("missing_field") + space + text(name)
    DuplicateField(name~) => text("duplicate_field") + space + text(name)
    UnknownTypeMember(name~) => text("unknown_type_member") + space + text(name)
    MissingTypeMember(name~) => text("missing_type_member") + space + text(name)
    DuplicateTypeMember(name~) =>
      text("duplicate_type_member") + space + text(name)
    DuplicateTypeParameter(name~) =>
      text("duplicate_type_parameter") + space + text(name)
    ExternalTypeParametersNotSupported(name~) =>
      text("external_type_parameters_not_supported") + space + text(name)
    NotAStruct(type_) => text("not_a_struct") + space + type_.pretty()
    NonExhaustiveMatch(type_~, witness~) => {
      let doc = text("non_exhaustive_match") + space + type_.pretty()
      match witness {
        Some(witness) => doc + space + text("missing=`\{witness}`")
        None => doc
      }
    }
    UnreachableMatchArm => text("unreachable_match_arm")
    RefutablePatternLet(type_) =>
      text("refutable_pattern_let") + space + type_.pretty()
    MixedHandlerEffects => text("mixed_handler_effects")
    DuplicateHandledEffect(effect) =>
      text("duplicate_handled_effect") + space + effect.pretty()
    MissingHandlerOperation(owner~, name~) =>
      text("missing_handler_operation") +
      space +
      text(owner) +
      text("::") +
      text(name)
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
    InvalidDoubleLiteral(raw) =>
      text("invalid_double_literal") + space + text(raw)
    UnknownBuiltin(name~) => text("unknown_builtin") + space + text(name)
    BuiltinSignatureMismatch(name~, expected~, actual~) =>
      text("builtin_signature_mismatch") +
      space +
      text(name) +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    ExternNeedsExpectedType(name~) =>
      text("extern_needs_expected_type") + space + text(name)
    InvalidExternType(name~, type_~, restriction~) =>
      text("invalid_extern_type") +
      space +
      text(name) +
      space +
      type_.pretty() +
      space +
      restriction.pretty()
    FunctionLiteralParameterNeedsAnnotation(name~) => {
      let name = match name {
        Some(name) => text(name)
        None => text("<anonymous>")
      }
      text("function_literal_parameter_needs_annotation") + space + name
    }
    EmptyMatchNeedsExpectedType => text("empty_match_needs_expected_type")
    UnqualifiedVariantPatternNeedsExpectedEnum(variant~) =>
      text("unqualified_variant_pattern_needs_expected_enum") +
      space +
      text(variant)
    GenericArgumentInferenceFailed(label~, failure~) =>
      text("generic_argument_inference_failed") +
      space +
      text(label) +
      space +
      failure.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for GenericArgumentSubject with fn pretty(
  subject : GenericArgumentSubject,
) {
  match subject {
    Named(name~) => text(name)
    ExplicitExpression(callee=Some(callee), ..) =>
      text("explicit_generic_application") + space + text(callee)
    ExplicitExpression(callee=None, ..) => text("explicit_generic_application")
  }
}

///|
pub impl @prettyprinter.Pretty for GenericArgumentInferenceFailure with fn pretty(
  failure : GenericArgumentInferenceFailure,
) {
  match failure {
    MissingGenericArguments(parameters~) =>
      text("missing") + space + text(generic_parameter_names(parameters))
    ConflictingGenericArgument(parameter~, previous~, actual~) =>
      text("conflict") +
      space +
      text(parameter.name) +
      space +
      text("previous=") +
      previous.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    RecursiveGenericArgument(parameter~, actual~) =>
      text("recursive") + space + text(parameter.name) + space + actual.pretty()
    GenericArgumentConstraintMismatch(expected~, actual~) =>
      text("constraint_mismatch") +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
    AmbiguousEffectRowInference(expected~, actual~) =>
      text("ambiguous_effect_row") +
      space +
      text("expected=") +
      expected.pretty() +
      space +
      text("actual=") +
      actual.pretty()
  }
}

///|
fn generic_parameter_names(parameters : Array[@types.TypeParameter]) -> String {
  parameters.map(fn(parameter) { parameter.name }).join(",")
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
