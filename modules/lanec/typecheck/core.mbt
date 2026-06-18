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
  diagnostics : Array[TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeclarationEnvironment {
  types : Array[CheckedTypeDeclaration]
  type_members : Array[CheckedTypeMemberDeclaration]
  fields : Array[CheckedFieldDeclaration]
  variants : Array[CheckedVariantDeclaration]
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueEnvironment {
  values : Array[CheckedValueDeclaration]
} derive(Debug, Eq)

///|
pub(all) enum CheckedTypeDeclaration {
  Struct(CheckedStructDeclaration)
  Enum(CheckedEnumDeclaration)
} derive(Debug, Eq)

///|
pub(all) enum CheckedValueDeclaration {
  Function(CheckedFunctionDeclaration)
  Let(CheckedLetDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructDeclaration {
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
pub(all) struct CheckedFunctionDeclaration {
  symbol : ValueSymbolId
  name : String
  type_ : @types.Type
  parameters : Array[@checked.CheckedValueParameter]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedLetDeclaration {
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
pub(all) enum TypeCheckDiagnosticKind {
  UnresolvedType(String)
  UnresolvedValue(String)
  MissingTopLevelLetAnnotation
  TypeArgumentArityMismatch(name~ : String, expected~ : Int, actual~ : Int)
  TypeAliasCycle(name~ : String)
  KindMismatch(expected~ : @types.Kind, actual~ : @types.Kind)
  TypeMismatch(expected~ : @types.Type, actual~ : @types.Type)
  NotCallable(@types.Type)
  UnknownField(name~ : String)
  MissingField(name~ : String)
  DuplicateField(name~ : String)
  UnknownTypeMember(name~ : String)
  MissingTypeMember(name~ : String)
  DuplicateTypeMember(name~ : String)
  NotAStruct(@types.Type)
  NonExhaustiveMatch(@types.Type)
  UnreachableMatchArm
  DuplicatePatternBinder(name~ : String)
  PatternArityMismatch(name~ : String, expected~ : Int, actual~ : Int)
  HiddenTypeEscape(type_~ : @types.Type)
  InvalidIntLiteral(String)
  CannotInferExpression(String)
} derive(Debug, Eq)
