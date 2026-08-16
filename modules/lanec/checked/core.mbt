///|
pub(all) struct CheckedSourceFile {
  module_path : @syntax.ModulePath
  canonical_basic_abi : CheckedCanonicalBasicAbi
  declarations : Array[CheckedTopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedCanonicalBasicAbi {
  types : Array[CheckedCanonicalBasicType]
} derive(Debug, Eq)

///|
pub(all) struct CheckedCanonicalBasicType {
  provider : @abi.BasicTypeProvider
  symbol : TypeSymbolId
} derive(Debug, Eq)

///|
pub fn CheckedCanonicalBasicAbi::type_symbol(
  self : CheckedCanonicalBasicAbi,
  provider : @abi.BasicTypeProvider,
) -> TypeSymbolId? {
  for type_ in self.types {
    if type_.provider == provider {
      return Some(type_.symbol)
    }
  }
  None
}

///|
pub(all) enum CheckedTopLevelDeclaration {
  Struct(CheckedStructDeclaration)
  Enum(CheckedEnumDeclaration)
  Effect(CheckedEffectDeclaration)
  ExternalType(CheckedExternalTypeDeclaration)
  Function(CheckedFunctionDeclaration)
  Let(CheckedLetDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct CheckedExternalTypeDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  name_loc : SourceSpan
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  name_loc : SourceSpan
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
  name_loc : SourceSpan
  kind : @types.Kind
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedFieldDeclaration {
  symbol : FieldSymbolId
  name : String
  name_loc : SourceSpan
  index : Int
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedEnumDeclaration {
  is_public : Bool
  symbol : TypeSymbolId
  name : String
  name_loc : SourceSpan
  type_parameters : Array[@types.TypeParameter]
  variants : Array[CheckedVariantDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedVariantDeclaration {
  symbol : VariantSymbolId
  name : String
  name_loc : SourceSpan
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
  name_loc : SourceSpan
  flavor : EffectFlavor
  type_parameters : Array[@types.TypeParameter]
  operations : Array[CheckedEffectOperationDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedEffectOperationDeclaration {
  symbol : OperationSymbolId
  name : String
  name_loc : SourceSpan
  index : Int
  type_parameters : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  result : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedFunctionDeclaration {
  is_public : Bool
  is_offered : Bool
  symbol : ValueSymbolId
  name : String
  name_loc : SourceSpan
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
  is_offered : Bool
  symbol : ValueSymbolId
  name : String
  name_loc : SourceSpan
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
  name_loc : SourceSpan
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CheckedLocalItem {
  Let(CheckedLetDeclaration)
  PatternLet(CheckedPatternLetDeclaration)
  Function(CheckedFunctionDeclaration)
  Expression(CheckedExpr)
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
pub(all) struct CheckedI64Literal {
  raw : String
  value : Int64
} derive(Debug, Eq)

///|
/// A checked S32 literal keeps the source spelling for diagnostics and pretty
/// printing, while `value` is the compiler's semantic signed 32-bit value.
pub(all) struct CheckedI32Literal {
  raw : String
  value : Int
} derive(Debug, Eq)

///|
/// A checked double literal keeps the source spelling for diagnostics and
/// pretty printing, while `value` is the compiler's semantic binary64 value.
pub(all) struct CheckedF64Literal {
  raw : String
  value : Double
} derive(Debug, Eq)

///|
pub(all) struct CheckedF32Literal {
  raw : String
  value : Float
} derive(Debug, Eq)

///|
pub(all) enum CheckedLiteral {
  I64(CheckedI64Literal)
  I32(CheckedI32Literal)
  F64(CheckedF64Literal)
  F32(CheckedF32Literal)
  String(String)
  Char(Int)
  Bool(Bool)
  Unit
} derive(Debug, Eq)

///|
pub(all) struct CheckedCallArgument {
  value : CheckedExpr
  loc : SourceSpan
  provenance : @syntax.CallArgumentProvenance
} derive(Debug, Eq)

///|
pub(all) struct CheckedContextualSelection {
  symbol : ValueSymbolId
  name : String
  type_ : @types.Type
  value : CheckedExpr
} derive(Debug, Eq)

///|
pub(all) enum CheckedDeriveDeriver {
  Explicit(CheckedExpr)
  Contextual(CheckedContextualSelection)
} derive(Debug, Eq)

///|
pub fn CheckedDeriveDeriver::value(self : CheckedDeriveDeriver) -> CheckedExpr {
  match self {
    Explicit(value) => value
    Contextual(selection) => selection.value
  }
}

///|
pub(all) struct CheckedDeriveEvidence {
  path : String
  required_type : @types.Type
  selection : CheckedContextualSelection
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveMetadata {
  name : String
  qualified_name : String
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveAbi {
  deriver : TypeSymbolId
  deriver_unit : FieldSymbolId
  deriver_product : FieldSymbolId
  deriver_void : FieldSymbolId
  deriver_sum : FieldSymbolId
  deriver_field : FieldSymbolId
  deriver_variant : FieldSymbolId
  deriver_record : FieldSymbolId
  deriver_enumeration : FieldSymbolId
  product : TypeSymbolId
  product_head : FieldSymbolId
  product_tail : FieldSymbolId
  sum : TypeSymbolId
  sum_here : VariantSymbolId
  sum_there : VariantSymbolId
  iso : TypeSymbolId
  type_info : TypeSymbolId
  field_info : TypeSymbolId
  variant_info : TypeSymbolId
  void_type : TypeSymbolId
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveField {
  symbol : FieldSymbolId
  name : String
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveProductStep[A] {
  head : A
  head_type : @types.Type
  tail_type : @types.Type
  evidence : CheckedDeriveEvidence
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveProduct[A] {
  representation : @types.Type
  steps : Array[CheckedDeriveProductStep[A]]
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveVariant {
  symbol : VariantSymbolId
  name : String
  payload : CheckedDeriveProduct[Unit]
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveSumStep {
  head : CheckedDeriveVariant
  tail_type : @types.Type
} derive(Debug, Eq)

///|
pub(all) struct CheckedDeriveSum {
  representation : @types.Type
  steps : Array[CheckedDeriveSumStep]
} derive(Debug, Eq)

///|
pub(all) enum CheckedDeriveShape {
  Record(product~ : CheckedDeriveProduct[CheckedDeriveField])
  Enumeration(sum~ : CheckedDeriveSum)
} derive(Debug, Eq)

///|
pub(all) struct CheckedDerivePlan {
  capability : @types.Type
  target : @types.Type
  abi : CheckedDeriveAbi
  shape : CheckedDeriveShape
  deriver : CheckedDeriveDeriver
  metadata : CheckedDeriveMetadata
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
  CompilerIntrinsic(
    intrinsic~ : @abi.Intrinsic,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  ExternBinding(
    name~ : String,
    signature~ : @abi.HostSignature,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  ErrorRecovery(type_~ : @types.Type, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[@types.TypeParameter],
    parameters~ : Array[CheckedValueParameter],
    return_type~ : @types.Type,
    body~ : CheckedExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  FunctionEffectWiden(
    value~ : CheckedExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  GenericApplication(
    callee~ : CheckedExpr,
    arguments~ : Array[@types.GenericArgument],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Derive(
    plan~ : CheckedDerivePlan,
    type_~ : @types.Type,
    source~ : @basic.DeriveSourceSite
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
    arguments~ : Array[CheckedCallArgument],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  OperationCall(
    operation~ : OperationSymbolId,
    operation_loc~ : SourceSpan,
    generic_witnesses~ : Array[@types.GenericArgument],
    arguments~ : Array[CheckedExpr],
    effect~ : @types.Effect,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Handler(
    body~ : CheckedExpr?,
    handlers~ : Array[CheckedHandlerTable],
    final_branch~ : CheckedHandlerFinalBranch,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Field(
    base~ : CheckedExpr,
    field~ : FieldSymbolId,
    name~ : String,
    name_loc~ : SourceSpan,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  StructLiteral(
    symbol~ : TypeSymbolId,
    type_name_loc~ : SourceSpan,
    generic_arguments~ : Array[@types.GenericArgument],
    type_witnesses~ : Array[CheckedStructTypeWitness],
    fields~ : Array[CheckedStructLiteralField],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Variant(
    symbol~ : VariantSymbolId,
    variant_loc~ : SourceSpan,
    generic_arguments~ : Array[@types.GenericArgument],
    arguments~ : Array[CheckedExpr],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct CheckedStructTypeWitness {
  symbol : TypeMemberSymbolId
  name : String
  argument : @types.GenericArgument
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
pub(all) struct CheckedHandlerTable {
  handled_effect : @types.Effect
  operations : Array[CheckedHandlerOperationArm]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedHandlerOperationArm {
  operation : OperationSymbolId
  operation_loc : SourceSpan
  type_binders : Array[@types.TypeParameter]
  payload_types : Array[@types.Type]
  payload_patterns : Array[CheckedPattern]
  resume_symbol : ValueSymbolId
  resume_type : @types.Type
  resume_binder : String
  resume_loc : SourceSpan
  body : CheckedExpr?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedHandlerFinalBranch {
  binder_symbol : ValueSymbolId
  binder : String
  binder_type : @types.Type
  binder_loc : SourceSpan
  body : CheckedExpr?
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
    variant_loc~ : SourceSpan,
    generic_arguments~ : Array[@types.GenericArgument],
    arguments~ : Array[CheckedPattern],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Struct(
    symbol~ : TypeSymbolId,
    type_name_loc~ : SourceSpan,
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
    | CompilerIntrinsic(type_~, ..)
    | ExternBinding(type_~, ..)
    | ErrorRecovery(type_~, ..)
    | FunctionLiteral(type_~, ..)
    | FunctionEffectWiden(type_~, ..)
    | GenericApplication(type_~, ..)
    | Derive(type_~, ..)
    | Block(type_~, ..)
    | If(type_~, ..)
    | Match(type_~, ..)
    | Call(type_~, ..)
    | OperationCall(type_~, ..)
    | Handler(type_~, ..)
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
    | CompilerIntrinsic(loc~, ..)
    | ExternBinding(loc~, ..)
    | ErrorRecovery(loc~, ..)
    | FunctionLiteral(loc~, ..)
    | FunctionEffectWiden(loc~, ..)
    | GenericApplication(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Call(loc~, ..)
    | OperationCall(loc~, ..)
    | Handler(loc~, ..)
    | Field(loc~, ..)
    | StructLiteral(loc~, ..)
    | Variant(loc~, ..) => loc
    Derive(source~, ..) => source.loc
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
