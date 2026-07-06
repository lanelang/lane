///|
pub(all) struct DeclarationTypeCheckResult {
  declarations : CheckedDeclarationEnvironment
  diagnostics : Array[TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct TypeCheckResult {
  declarations : CheckedDeclarationEnvironment
  values : CheckedValueEnvironment
  diagnostics : Array[TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CheckedSourceTypeCheckResult {
  source : @checked.CheckedSourceFile?
  module_interface : @module_interface.ModuleInterface?
  diagnostics : Array[TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeclarationEnvironment {
  types : Array[CheckedTypeDeclaration]
  type_members : Array[CheckedTypeMemberDeclaration]
  fields : Array[CheckedFieldDeclaration]
  variants : Array[CheckedVariantDeclaration]
  effects : Array[CheckedEffectDeclaration]
  operations : Array[CheckedEffectOperationDeclaration]
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueEnvironment {
  values : Array[CheckedValueDeclaration]
} derive(Debug, Eq)

///|
pub(all) struct ContextualOfferDiagnosticCandidate {
  name : String
  type_ : @types.Type
  source_id : String?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CheckedTypeDeclaration {
  Struct(CheckedStructDeclaration)
  Enum(CheckedEnumDeclaration)
  Effect(CheckedEffectDeclaration)
} derive(Debug, Eq)

///|
pub(all) enum CheckedValueDeclaration {
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
  type_ : @types.Type
  parameters : Array[@checked.CheckedValueParameter]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedLetDeclaration {
  is_public : Bool
  symbol : ValueSymbolId
  name : String?
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct TypeCheckDiagnostic {
  kind : TypeCheckDiagnosticKind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum GenericArgumentSubject {
  Named(name~ : String)
  ExplicitExpression(callee~ : String?, callee_loc~ : SourceSpan?)
} derive(Debug, Eq)

///|
pub(all) enum GenericArgumentInferenceFailure {
  MissingGenericArguments(parameters~ : Array[@types.TypeParameter])
  ConflictingGenericArgument(
    parameter~ : @types.TypeParameter,
    previous~ : @types.GenericArgument,
    actual~ : @types.GenericArgument
  )
  RecursiveGenericArgument(
    parameter~ : @types.TypeParameter,
    actual~ : @types.GenericArgument
  )
  GenericArgumentConstraintMismatch(
    expected~ : @types.GenericArgument,
    actual~ : @types.GenericArgument
  )
} derive(Debug, Eq)

///|
pub(all) enum TypeCheckDiagnosticKind {
  UnresolvedType(String)
  UnresolvedValue(String)
  MissingTopLevelLetAnnotation
  GenericArgumentArityMismatch(
    subject~ : GenericArgumentSubject,
    expected~ : Int,
    actual~ : Int
  )
  ApplicationArityMismatch(label~ : String)
  VariantReferenceFailure(label~ : String)
  InternalTypecheckFailure(label~ : String)
  CallArityMismatch(expected~ : Int, actual~ : Int)
  AutoParametersMustBeTrailing
  AutoArgumentMustBeNamed
  DuplicateNamedArgument(name~ : String)
  UnknownContextualArgument(name~ : String)
  InvalidNamedArgument(name~ : String)
  InvalidNamedBuiltinArgument(name~ : String)
  MissingContextualOffer(expected~ : @types.Type)
  AmbiguousContextualOffer(
    expected~ : @types.Type,
    candidates~ : Array[ContextualOfferDiagnosticCandidate]
  )
  TypeAliasCycle(name~ : String)
  KindMismatch(expected~ : @types.Kind, actual~ : @types.Kind)
  TypeMismatch(expected~ : @types.Type, actual~ : @types.Type)
  EffectMismatch(expected~ : @types.Effect, actual~ : @types.Effect)
  NotCallable(@types.Type)
  GenericArgumentsOnNonGeneric(
    subject~ : GenericArgumentSubject,
    type_~ : @types.Type
  )
  UnknownField(name~ : String)
  MissingField(name~ : String)
  DuplicateField(name~ : String)
  UnknownTypeMember(name~ : String)
  MissingTypeMember(name~ : String)
  DuplicateTypeMember(name~ : String)
  DuplicateTypeParameter(name~ : String)
  NotAStruct(@types.Type)
  NonExhaustiveMatch(type_~ : @types.Type, witness~ : String?)
  UnreachableMatchArm
  RefutablePatternLet(@types.Type)
  MixedHandlerEffects
  DuplicateHandledEffect(@types.Effect)
  MissingHandlerOperation(OperationSymbolId)
  DuplicatePatternBinder(name~ : String)
  PatternArityMismatch(name~ : String, expected~ : Int, actual~ : Int)
  HiddenTypeEscape(type_~ : @types.Type)
  PrivateTypeEscape(name~ : String)
  PrivateEffectEscape(name~ : String)
  InvalidIntLiteral(String)
  BuiltinNeedsExpectedType(name~ : String)
  FunctionLiteralParameterNeedsAnnotation(name~ : String?)
  EmptyMatchNeedsExpectedType
  UnqualifiedVariantPatternNeedsExpectedEnum(variant~ : String)
  GenericArgumentInferenceFailed(
    label~ : String,
    failure~ : GenericArgumentInferenceFailure
  )
} derive(Debug, Eq)
