///|
fn[A : @prettyprinter.Pretty] generic_pretty(
  value : A,
) -> @generic_prettyprinter.Document {
  @prettyprinter.pretty(value).to_generic()
}

///|
pub impl @generic_prettyprinter.Pretty for SourceFile with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for ModulePath with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for ImportDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for ImportItem with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for TopLevelDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for ExternalTypeDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for TypeParameter with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for StructDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for StructMember with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for TypeMemberDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for Kind with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for EffectDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for EffectOperationDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for FieldDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for EnumDeclaration with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for EnumVariant with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for TypeAliasDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for TypeAliasBody with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for FunctionDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for Parameter with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for LetDeclaration with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for OfferDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for Type with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for GenericArgument with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for Expr with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for StructLiteralField with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for LocalItem with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for PatternLetDeclaration with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for FunctionLiteralParameter with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for CallArgument with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for MatchArm with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for Pattern with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for StructPatternField with fn pretty(
  value,
) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for UnaryOperator with fn pretty(value) {
  generic_pretty(value)
}

///|
pub impl @generic_prettyprinter.Pretty for BinaryOperator with fn pretty(value) {
  generic_pretty(value)
}
