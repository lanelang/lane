///|
using @basic {type SourceSpan}

///|
using @syntax {
  type EnumDeclaration,
  type EnumVariant,
  type Expr,
  type FieldDeclaration,
  type FunctionDeclaration,
  type FunctionLiteralParameter,
  type Kind,
  type LetDeclaration,
  type LocalItem,
  type MatchArm,
  type CallArgument,
  type OfferDeclaration,
  type Parameter,
  type ParameterModifiers,
  type Pattern,
  type PatternLetDeclaration,
  type SourceFile,
  type StructDeclaration,
  type StructLiteralField,
  type StructMember,
  type StructPatternField,
  type TypeAliasDeclaration,
  type TypeMemberDeclaration,
  type TypeParameter,
  type TopLevelDeclaration,
  type Type,
}

///|
fn span(loc : (SourceSpan, SourceSpan)) -> SourceSpan {
  SourceSpan::join(loc.0, loc.1)
}

///|
fn[T] comma_push(items : Array[T], item : T) -> Array[T] {
  items.push(item)
  items
}
