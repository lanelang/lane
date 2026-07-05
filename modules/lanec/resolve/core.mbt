///|
pub(all) struct ResolvedSourceFile {
  module_path : @syntax.ModulePath
  symbols : SymbolRegistry
  declarations : Array[ResolvedTopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolveResult {
  source : ResolvedSourceFile
  diagnostics : Array[ResolveDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct ResolveDiagnostic {
  kind : ResolveDiagnosticKind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolveVariantCandidate {
  owner : String
  variant : String
} derive(Debug, Eq)

///|
pub(all) enum ResolveDiagnosticKind {
  UnresolvedType(String)
  UnresolvedValue(String)
  UnresolvedField(type_name~ : String, field~ : String)
  UnresolvedQualifiedVariant(type_name~ : String, variant~ : String)
  PayloadlessVariantWithoutParens(String)
  ConflictingTopLevelValue(
    name~ : String,
    existing~ : String,
    incoming~ : String,
    existing_source_id~ : String?,
    existing_loc~ : SourceSpan?,
    existing_origin~ : String?
  )
  ConflictingTopLevelTypeAndEffectName(
    name~ : String,
    type_kind~ : String,
    effect_kind~ : String
  )
  AmbiguousModuleValue(String)
  AmbiguousUnqualifiedVariant(
    name~ : String,
    candidates~ : Array[ResolveVariantCandidate]
  )
} derive(Debug, Eq)

///|
pub(all) enum ResolvedTopLevelDeclaration {
  Struct(ResolvedStructDeclaration)
  Enum(ResolvedEnumDeclaration)
  Effect(ResolvedEffectDeclaration)
  TypeAlias(ResolvedTypeAliasDeclaration)
  Function(ResolvedFunctionDeclaration)
  Let(ResolvedLetDeclaration)
  Offer(ResolvedOfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedStructDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[ResolvedTypeParameter]
  members : Array[ResolvedStructMember]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedStructMember {
  TypeMember(ResolvedTypeMemberDeclaration)
  Field(ResolvedFieldDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedTypeMemberDeclaration {
  symbol : TypeMemberSymbolId
  type_parameter : ResolvedTypeParameter
  name : String
  kind : ResolvedKind
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedFieldDeclaration {
  symbol : FieldSymbolId
  is_offered : Bool
  name : String
  type_ : ResolvedType
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedEnumDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[ResolvedTypeParameter]
  variants : Array[ResolvedEnumVariant]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedEnumVariant {
  symbol : VariantSymbolId
  name : String
  index : Int
  type_parameters : Array[ResolvedTypeParameter]
  payload : Array[ResolvedType]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedEffectDeclaration {
  is_public : Bool
  symbol : EffectSymbolId
  name : String
  type_parameters : Array[ResolvedTypeParameter]
  operations : Array[ResolvedEffectOperationDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedEffectOperationDeclaration {
  symbol : OperationSymbolId
  name : String
  index : Int
  type_parameters : Array[ResolvedTypeParameter]
  payload : Array[ResolvedType]
  result : ResolvedType
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedTypeAliasDeclaration {
  is_public : Bool
  name : String
  type_parameters : Array[ResolvedTypeParameter]
  body : ResolvedTypeAliasBody
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedTypeAliasBody {
  TypeBody(ResolvedType)
  EffectBody(ResolvedEffectTerm)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedFunctionDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String
  type_parameters : Array[ResolvedTypeParameter]
  parameters : Array[ResolvedValueParameter]
  return_type : ResolvedType
  effect : ResolvedEffectTerm
  body : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedLetDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String?
  type_annotation : ResolvedType?
  initializer : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedOfferDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String
  type_annotation : ResolvedType
  initializer : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedTypeParameter {
  symbol : TypeParameterId
  name : String
  kind : ResolvedKind?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedKind {
  Type(loc~ : SourceSpan)
  Effect(loc~ : SourceSpan)
  Function(
    parameters~ : Array[ResolvedKind],
    result~ : ResolvedKind,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct ResolvedValueParameter {
  symbol : ValueSymbolId
  is_auto : Bool
  is_offered : Bool
  name : String
  type_ : ResolvedType
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedType {
  Primitive(@types.PrimitiveType, loc~ : SourceSpan)
  Constructor(symbol~ : TypeSymbolId, name~ : String, loc~ : SourceSpan)
  Alias(name~ : String, loc~ : SourceSpan)
  Apply(
    callee~ : ResolvedType,
    arguments~ : Array[ResolvedGenericArgument],
    loc~ : SourceSpan
  )
  TypeLambda(
    parameters~ : Array[ResolvedTypeParameter],
    body~ : ResolvedType,
    loc~ : SourceSpan
  )
  Parameter(symbol~ : TypeParameterId, name~ : String, loc~ : SourceSpan)
  Function(
    type_parameters~ : Array[ResolvedTypeParameter],
    parameters~ : Array[ResolvedType],
    result~ : ResolvedType,
    effect~ : ResolvedEffectTerm,
    loc~ : SourceSpan
  )
  Unresolved(
    name~ : String,
    arguments~ : Array[ResolvedGenericArgument],
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) enum ResolvedEffectTerm {
  Empty(loc~ : SourceSpan)
  Singleton(
    symbol~ : EffectSymbolId,
    name~ : String,
    arguments~ : Array[ResolvedGenericArgument],
    loc~ : SourceSpan
  )
  Parameter(symbol~ : TypeParameterId, name~ : String, loc~ : SourceSpan)
  Alias(
    name~ : String,
    arguments~ : Array[ResolvedEffectAliasArgument],
    loc~ : SourceSpan
  )
  Union(items~ : Array[ResolvedEffectTerm], loc~ : SourceSpan)
  Unresolved(
    name~ : String,
    arguments~ : Array[ResolvedGenericArgument],
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) enum ResolvedEffectAliasArgument {
  TypeArgument(ResolvedType)
  EffectArgument(ResolvedEffectTerm)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedGenericArgument {
  TypeArgument(ResolvedType)
  EffectArgument(ResolvedEffectTerm)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedValueReference {
  Symbol(ValueSymbolId)
  Unresolved(String)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedFieldReference {
  Symbol(FieldSymbolId)
  Deferred(String)
  Unresolved(type_name~ : String, field~ : String)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedVariantReference {
  Symbol(VariantSymbolId)
  Unresolved(type_name~ : String, variant~ : String)
  UnresolvedUnqualified(String)
  Ambiguous(name~ : String, candidates~ : Array[VariantSymbolId])
} derive(Debug, Eq)

///|
pub(all) enum ResolvedOperationReference {
  Symbol(OperationSymbolId)
  Unresolved(String)
  Ambiguous(name~ : String, candidates~ : Array[OperationSymbolId])
} derive(Debug, Eq)

///|
pub(all) enum ResolvedEffectOperationName {
  Qualified(
    owner~ : ResolvedEffectTerm,
    operation~ : String,
    reference~ : ResolvedOperationReference,
    loc~ : SourceSpan
  )
  Shorthand(
    operation~ : String,
    reference~ : ResolvedOperationReference,
    loc~ : SourceSpan
  )
  Unqualified(
    operation~ : String,
    reference~ : ResolvedOperationReference,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct ResolvedFunctionLiteralParameter {
  symbol : ValueSymbolId
  is_offered : Bool
  name : String
  type_annotation : ResolvedType?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedCallArgument {
  Positional(value~ : ResolvedExpr, loc~ : SourceSpan)
  Named(name~ : String, value~ : ResolvedExpr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedStructLiteralField {
  Value(
    name~ : String,
    value~ : ResolvedExpr?,
    punned_reference~ : ResolvedValueReference?,
    loc~ : SourceSpan
  )
  TypeWitness(name~ : String, witness~ : ResolvedType, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedMatchArm {
  pattern : ResolvedPattern
  body : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedHandlerWithBlock {
  arms : Array[ResolvedHandlerOperationArm]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedHandlerOperationArm {
  name : ResolvedEffectOperationName
  type_binders : Array[ResolvedTypeParameter]
  payload_patterns : Array[ResolvedPattern]
  resume_symbol : ValueSymbolId
  resume_binder : String
  resume_loc : SourceSpan
  body : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ResolvedHandlerFinalBranch {
  binder_symbol : ValueSymbolId
  binder : String
  binder_loc : SourceSpan
  body : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedStructPatternField {
  Value(name~ : String, pattern~ : ResolvedPattern, loc~ : SourceSpan)
  TypeBinder(
    name~ : String,
    type_parameter~ : ResolvedTypeParameter,
    loc~ : SourceSpan
  )
  TypeWildcard(type_parameter~ : ResolvedTypeParameter, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedLocalItem {
  Let(ResolvedLetDeclaration)
  PatternLet(ResolvedPatternLetDeclaration)
  Function(ResolvedFunctionDeclaration)
  Offer(ResolvedOfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedPatternLetDeclaration {
  pattern : ResolvedPattern
  initializer : ResolvedExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ResolvedExpr {
  IntLiteral(String, loc~ : SourceSpan)
  StringLiteral(String, loc~ : SourceSpan)
  BoolLiteral(Bool, loc~ : SourceSpan)
  UnitLiteral(loc~ : SourceSpan)
  Var(name~ : String, reference~ : ResolvedValueReference, loc~ : SourceSpan)
  QualifiedVariant(
    type_name~ : String,
    type_arguments~ : Array[ResolvedGenericArgument],
    variant~ : String,
    variant_type_arguments~ : Array[ResolvedGenericArgument],
    reference~ : ResolvedVariantReference,
    arguments~ : Array[ResolvedExpr],
    loc~ : SourceSpan
  )
  UnqualifiedVariant(
    variant~ : String,
    reference~ : ResolvedVariantReference,
    arguments~ : Array[ResolvedExpr],
    loc~ : SourceSpan
  )
  StructLiteral(
    type_name~ : String,
    type_arguments~ : Array[ResolvedGenericArgument],
    fields~ : Array[ResolvedStructLiteralField],
    loc~ : SourceSpan
  )
  Builtin(String, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[ResolvedTypeParameter],
    parameters~ : Array[ResolvedFunctionLiteralParameter],
    return_type~ : ResolvedType?,
    effect~ : ResolvedEffectTerm?,
    body~ : ResolvedExpr,
    loc~ : SourceSpan
  )
  EffectOperationCall(
    name~ : ResolvedEffectOperationName,
    type_witnesses~ : Array[ResolvedGenericArgument],
    arguments~ : Array[ResolvedExpr],
    loc~ : SourceSpan
  )
  Handler(
    body~ : ResolvedExpr,
    handlers~ : Array[ResolvedHandlerWithBlock],
    final_branch~ : ResolvedHandlerFinalBranch,
    loc~ : SourceSpan
  )
  Block(
    items~ : Array[ResolvedLocalItem],
    result~ : ResolvedExpr,
    loc~ : SourceSpan
  )
  If(
    condition~ : ResolvedExpr,
    then_branch~ : ResolvedExpr,
    else_branch~ : ResolvedExpr,
    loc~ : SourceSpan
  )
  Match(
    scrutinee~ : ResolvedExpr,
    arms~ : Array[ResolvedMatchArm],
    loc~ : SourceSpan
  )
  Call(
    callee~ : ResolvedExpr,
    arguments~ : Array[ResolvedCallArgument],
    loc~ : SourceSpan
  )
  Field(
    base~ : ResolvedExpr,
    name~ : String,
    reference~ : ResolvedFieldReference,
    loc~ : SourceSpan
  )
  Unary(
    operator~ : @syntax.UnaryOperator,
    reference~ : ResolvedValueReference,
    operand~ : ResolvedExpr,
    loc~ : SourceSpan
  )
  Binary(
    operator~ : @syntax.BinaryOperator,
    reference~ : ResolvedValueReference,
    left~ : ResolvedExpr,
    right~ : ResolvedExpr,
    loc~ : SourceSpan
  )
  Pipeline(left~ : ResolvedExpr, right~ : ResolvedExpr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum ResolvedPattern {
  Wildcard(SourceSpan)
  Binding(name~ : String, symbol~ : ValueSymbolId, loc~ : SourceSpan)
  IntLiteral(String, loc~ : SourceSpan)
  StringLiteral(String, loc~ : SourceSpan)
  BoolLiteral(Bool, loc~ : SourceSpan)
  QualifiedVariant(
    type_name~ : String,
    variant~ : String,
    type_binders~ : Array[ResolvedTypeParameter],
    reference~ : ResolvedVariantReference,
    arguments~ : Array[ResolvedPattern],
    loc~ : SourceSpan
  )
  ShorthandVariant(
    variant~ : String,
    type_binders~ : Array[ResolvedTypeParameter],
    arguments~ : Array[ResolvedPattern],
    loc~ : SourceSpan
  )
  Struct(
    type_name~ : String,
    fields~ : Array[ResolvedStructPatternField],
    loc~ : SourceSpan
  )
} derive(Debug, Eq)
