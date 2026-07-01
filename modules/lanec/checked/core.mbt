///|
pub(all) struct CheckedSourceFile {
  module_path : @syntax.ModulePath
  declarations : Array[CheckedTopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CheckedTopLevelDeclaration {
  Struct(CheckedStructDeclaration)
  Enum(CheckedEnumDeclaration)
  Effect(CheckedEffectDeclaration)
  Function(CheckedFunctionDeclaration)
  Let(CheckedLetDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  type_members : Array[CheckedTypeMemberDeclaration]
  fields : Array[CheckedFieldDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedTypeMemberDeclaration {
  symbol : TypeMemberSymbolId
  type_parameter : @types.TypeParameter
  name : String
  kind : @types.Kind
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedFieldDeclaration {
  symbol : FieldSymbolId
  is_offered : Bool
  name : String
  index : Int
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedEnumDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  variants : Array[CheckedVariantDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedVariantDeclaration {
  symbol : VariantSymbolId
  name : String
  index : Int
  type_parameters : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedEffectDeclaration {
  is_public : Bool
  symbol : EffectSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  operations : Array[CheckedEffectOperationDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedEffectOperationDeclaration {
  symbol : OperationSymbolId
  name : String
  index : Int
  type_parameters : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  result : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedFunctionDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  parameters : Array[CheckedValueParameter]
  return_type : @types.Type
  body : CheckedExpr
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedLetDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String?
  initializer : CheckedExpr
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueParameter {
  symbol : ValueSymbolId
  is_auto : Bool
  is_offered : Bool
  name : String
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CheckedLocalItem {
  Let(CheckedLetDeclaration)
  PatternLet(CheckedPatternLetDeclaration)
  Function(CheckedFunctionDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct CheckedPatternLetDeclaration {
  pattern : CheckedPattern
  initializer : CheckedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
/// A checked integer literal keeps the source spelling for diagnostics and
/// pretty printing, while `value` is the compiler's semantic i64 value.
pub(all) struct CheckedIntLiteral {
  raw : String
  value : Int64
} derive(Debug, Eq)

///|
pub(all) enum CheckedLiteral {
  Int(CheckedIntLiteral)
  String(String)
  Bool(Bool)
  Unit
} derive(Debug, Eq)

///|
pub(all) enum CheckedExpr {
  Literal(literal~ : CheckedLiteral, type_~ : @types.Type, loc~ : SourceSpan)
  Value(
    name~ : String,
    symbol~ : ValueSymbolId,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  UnsafeBuiltin(name~ : String, type_~ : @types.Type, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[@types.TypeParameter],
    parameters~ : Array[CheckedValueParameter],
    return_type~ : @types.Type,
    body~ : CheckedExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  TypeApplication(
    callee~ : CheckedExpr,
    arguments~ : Array[@types.Type],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Block(
    items~ : Array[CheckedLocalItem],
    result~ : CheckedExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  If(
    condition~ : CheckedExpr,
    then_branch~ : CheckedExpr,
    else_branch~ : CheckedExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Match(
    scrutinee~ : CheckedExpr,
    arms~ : Array[CheckedMatchArm],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Call(
    callee~ : CheckedExpr,
    arguments~ : Array[CheckedExpr],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Field(
    base~ : CheckedExpr,
    field~ : FieldSymbolId,
    name~ : String,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  StructLiteral(
    symbol~ : TypeSymbolId,
    type_arguments~ : Array[@types.Type],
    type_witnesses~ : Array[CheckedStructTypeWitness],
    fields~ : Array[CheckedStructLiteralField],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Variant(
    symbol~ : VariantSymbolId,
    type_arguments~ : Array[@types.Type],
    arguments~ : Array[CheckedExpr],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructTypeWitness {
  symbol : TypeMemberSymbolId
  name : String
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructLiteralField {
  symbol : FieldSymbolId
  name : String
  value : CheckedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedMatchArm {
  pattern : CheckedPattern
  body : CheckedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CheckedPattern {
  Wildcard(type_~ : @types.Type, loc~ : SourceSpan)
  Binding(
    name~ : String,
    symbol~ : ValueSymbolId,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Literal(literal~ : CheckedLiteral, type_~ : @types.Type, loc~ : SourceSpan)
  Variant(
    symbol~ : VariantSymbolId,
    type_arguments~ : Array[@types.Type],
    arguments~ : Array[CheckedPattern],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Struct(
    symbol~ : TypeSymbolId,
    type_binders~ : Array[CheckedStructTypeBinder],
    fields~ : Array[CheckedStructPatternField],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructTypeBinder {
  symbol : TypeMemberSymbolId
  type_parameter : @types.TypeParameter?
  name : String?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructPatternField {
  symbol : FieldSymbolId
  name : String
  pattern : CheckedPattern
  loc : SourceSpan
} derive(Debug, Eq)

///|
/// Returns the type assigned to this checked expression.
pub fn CheckedExpr::type_(self : CheckedExpr) -> @types.Type {
  match self {
    Literal(type_~, ..)
    | Value(type_~, ..)
    | UnsafeBuiltin(type_~, ..)
    | FunctionLiteral(type_~, ..)
    | TypeApplication(type_~, ..)
    | Block(type_~, ..)
    | If(type_~, ..)
    | Match(type_~, ..)
    | Call(type_~, ..)
    | Field(type_~, ..)
    | StructLiteral(type_~, ..)
    | Variant(type_~, ..) => type_
  }
}

///|
/// Returns the source span that produced this checked expression.
pub fn CheckedExpr::loc(self : CheckedExpr) -> SourceSpan {
  match self {
    Literal(loc~, ..)
    | Value(loc~, ..)
    | UnsafeBuiltin(loc~, ..)
    | FunctionLiteral(loc~, ..)
    | TypeApplication(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Call(loc~, ..)
    | Field(loc~, ..)
    | StructLiteral(loc~, ..)
    | Variant(loc~, ..) => loc
  }
}

///|
/// Returns the type covered by this checked pattern.
pub fn CheckedPattern::type_(self : CheckedPattern) -> @types.Type {
  match self {
    Wildcard(type_~, ..)
    | Binding(type_~, ..)
    | Literal(type_~, ..)
    | Variant(type_~, ..)
    | Struct(type_~, ..) => type_
  }
}

///|
/// Returns the source span that produced this checked pattern.
pub fn CheckedPattern::loc(self : CheckedPattern) -> SourceSpan {
  match self {
    Wildcard(loc~, ..)
    | Binding(loc~, ..)
    | Literal(loc~, ..)
    | Variant(loc~, ..)
    | Struct(loc~, ..) => loc
  }
}
