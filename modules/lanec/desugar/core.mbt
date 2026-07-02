///|
pub(all) struct DesugaredSourceFile {
  module_path : @syntax.ModulePath
  symbols : SymbolRegistry
  declarations : Array[DesugaredTopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum DesugaredTopLevelDeclaration {
  Struct(@resolve.ResolvedStructDeclaration)
  Enum(@resolve.ResolvedEnumDeclaration)
  Effect(@resolve.ResolvedEffectDeclaration)
  Function(DesugaredFunctionDeclaration)
  Let(DesugaredLetDeclaration)
  Offer(DesugaredOfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct DesugaredFunctionDeclaration {
  is_public : Bool
  symbol : @symbol.ValueSymbolId
  name : String
  type_parameters : Array[@resolve.ResolvedTypeParameter]
  parameters : Array[@resolve.ResolvedValueParameter]
  return_type : @resolve.ResolvedType
  effect : @resolve.ResolvedEffectTerm
  body : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredLetDeclaration {
  is_public : Bool
  symbol : @symbol.ValueSymbolId
  name : String?
  type_annotation : @resolve.ResolvedType?
  initializer : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredPatternLetDeclaration {
  pattern : @resolve.ResolvedPattern
  initializer : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredOfferDeclaration {
  is_public : Bool
  symbol : @symbol.ValueSymbolId
  name : String
  type_annotation : @resolve.ResolvedType
  initializer : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum DesugaredLocalItem {
  Let(DesugaredLetDeclaration)
  PatternLet(DesugaredPatternLetDeclaration)
  Function(DesugaredFunctionDeclaration)
  Offer(DesugaredOfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) enum DesugaredStructLiteralField {
  Value(name~ : String, value~ : DesugaredExpr, loc~ : SourceSpan)
  TypeWitness(
    name~ : String,
    witness~ : @resolve.ResolvedType,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct DesugaredMatchArm {
  pattern : @resolve.ResolvedPattern
  body : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredHandlerWithBlock {
  arms : Array[DesugaredHandlerOperationArm]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredHandlerOperationArm {
  name : @resolve.ResolvedEffectOperationName
  type_binders : Array[@resolve.ResolvedTypeParameter]
  payload_patterns : Array[@resolve.ResolvedPattern]
  resume_symbol : @symbol.ValueSymbolId
  resume_binder : String
  resume_loc : SourceSpan
  body : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct DesugaredHandlerFinalBranch {
  binder_symbol : @symbol.ValueSymbolId
  binder : String
  binder_loc : SourceSpan
  body : DesugaredExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum DesugaredCallArgument {
  Positional(DesugaredExpr)
  Named(name~ : String, value~ : DesugaredExpr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum DesugaredLiteral {
  Int(String)
  String(String)
  Bool(Bool)
  Unit
} derive(Debug, Eq)

///|
pub(all) enum DesugaredExpr {
  Literal(literal~ : DesugaredLiteral, loc~ : SourceSpan)
  Var(
    name~ : String,
    reference~ : @resolve.ResolvedValueReference,
    loc~ : SourceSpan
  )
  VariantCall(
    type_name~ : String?,
    type_arguments~ : Array[@resolve.ResolvedType],
    variant~ : String,
    variant_type_arguments~ : Array[@resolve.ResolvedType],
    reference~ : @resolve.ResolvedVariantReference,
    arguments~ : Array[DesugaredExpr],
    loc~ : SourceSpan
  )
  StructLiteral(
    type_name~ : String,
    type_arguments~ : Array[@resolve.ResolvedType],
    fields~ : Array[DesugaredStructLiteralField],
    loc~ : SourceSpan
  )
  Builtin(String, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[@resolve.ResolvedTypeParameter],
    parameters~ : Array[@resolve.ResolvedFunctionLiteralParameter],
    return_type~ : @resolve.ResolvedType?,
    effect~ : @resolve.ResolvedEffectTerm?,
    body~ : DesugaredExpr,
    loc~ : SourceSpan
  )
  EffectOperationCall(
    name~ : @resolve.ResolvedEffectOperationName,
    type_witnesses~ : Array[@resolve.ResolvedType],
    arguments~ : Array[DesugaredExpr],
    loc~ : SourceSpan
  )
  Handler(
    body~ : DesugaredExpr,
    handlers~ : Array[DesugaredHandlerWithBlock],
    final_branch~ : DesugaredHandlerFinalBranch,
    loc~ : SourceSpan
  )
  Block(
    items~ : Array[DesugaredLocalItem],
    result~ : DesugaredExpr,
    loc~ : SourceSpan
  )
  If(
    condition~ : DesugaredExpr,
    then_branch~ : DesugaredExpr,
    else_branch~ : DesugaredExpr,
    loc~ : SourceSpan
  )
  Match(
    scrutinee~ : DesugaredExpr,
    arms~ : Array[DesugaredMatchArm],
    loc~ : SourceSpan
  )
  Call(
    callee~ : DesugaredExpr,
    arguments~ : Array[DesugaredCallArgument],
    loc~ : SourceSpan
  )
  Field(
    base~ : DesugaredExpr,
    name~ : String,
    reference~ : @resolve.ResolvedFieldReference,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
/// Returns the original source span represented by a desugared expression.
pub fn DesugaredExpr::loc(self : DesugaredExpr) -> SourceSpan {
  match self {
    Literal(loc~, ..)
    | Var(loc~, ..)
    | VariantCall(loc~, ..)
    | StructLiteral(loc~, ..)
    | Builtin(_, loc~)
    | FunctionLiteral(loc~, ..)
    | EffectOperationCall(loc~, ..)
    | Handler(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Call(loc~, ..)
    | Field(loc~, ..) => loc
  }
}
