///|
pub(all) struct SourceFile {
  module_path : ModulePath
  imports : Array[ImportDeclaration]
  declarations : Array[TopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModulePath {
  components : Array[String]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ImportDeclaration {
  Qualified(module_path~ : ModulePath, loc~ : SourceSpan)
  Open(module_path~ : ModulePath, loc~ : SourceSpan)
  Selective(
    module_path~ : ModulePath,
    items~ : Array[ImportItem],
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct ImportItem {
  name : String
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub fn ImportDeclaration::loc(self : ImportDeclaration) -> SourceSpan {
  match self {
    Qualified(loc~, ..) | Open(loc~, ..) | Selective(loc~, ..) => loc
  }
}

///|
pub(all) enum TopLevelDeclaration {
  Struct(StructDeclaration)
  Enum(EnumDeclaration)
  Effect(EffectDeclaration)
  TypeAlias(TypeAliasDeclaration)
  Function(FunctionDeclaration)
  Let(LetDeclaration)
  Offer(OfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct TypeParameter {
  name : String
  kind : Kind?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct StructDeclaration {
  is_public : Bool
  name : String
  type_parameters : Array[TypeParameter]
  members : Array[StructMember]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum StructMember {
  TypeMember(TypeMemberDeclaration)
  Field(FieldDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct TypeMemberDeclaration {
  name : String
  kind : Kind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum Kind {
  Type(loc~ : SourceSpan)
  Effect(loc~ : SourceSpan)
  Function(parameters~ : Array[Kind], result~ : Kind, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
/// Returns the source span covered by this kind syntax node.
pub fn Kind::loc(self : Kind) -> SourceSpan {
  match self {
    Type(loc~) | Effect(loc~) | Function(loc~, ..) => loc
  }
}

///|
pub(all) struct FieldDeclaration {
  is_offered : Bool
  name : String
  type_ : Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct EnumDeclaration {
  is_public : Bool
  name : String
  type_parameters : Array[TypeParameter]
  variants : Array[EnumVariant]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct EnumVariant {
  name : String
  type_parameters : Array[TypeParameter]
  payload : Array[Type]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct EffectDeclaration {
  is_public : Bool
  name : String
  type_parameters : Array[TypeParameter]
  operations : Array[EffectOperationDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct EffectOperationDeclaration {
  name : String
  type_parameters : Array[TypeParameter]
  payload : Array[Type]
  result : Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct TypeAliasDeclaration {
  is_public : Bool
  name : String
  type_parameters : Array[TypeParameter]
  body : TypeAliasBody
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum TypeAliasBody {
  TypeBody(Type)
  EffectBody(EffectTerm)
} derive(Debug, Eq)

///|
pub fn TypeAliasBody::loc(self : TypeAliasBody) -> SourceSpan {
  match self {
    TypeBody(type_) => type_.loc()
    EffectBody(effect) => effect.loc()
  }
}

///|
pub(all) struct FunctionDeclaration {
  is_public : Bool
  type_parameters : Array[TypeParameter]
  name : String
  name_loc : SourceSpan
  parameters : Array[Parameter]
  return_type : Type
  effect : EffectTerm
  body : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct Parameter {
  is_auto : Bool
  is_offered : Bool
  name : String
  type_ : Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ParameterModifiers {
  is_auto : Bool
  is_offered : Bool
} derive(Debug, Eq)

///|
pub(all) struct LetDeclaration {
  is_public : Bool
  name : String?
  name_loc : SourceSpan?
  type_annotation : Type?
  initializer : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct OfferDeclaration {
  is_public : Bool
  name : String
  name_loc : SourceSpan
  type_annotation : Type
  initializer : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum Type {
  Name(name~ : String, loc~ : SourceSpan)
  QualifiedName(module_path~ : ModulePath, name~ : String, loc~ : SourceSpan)
  Apply(callee~ : Type, arguments~ : Array[Type], loc~ : SourceSpan)
  TypeLambda(
    parameters~ : Array[TypeParameter],
    body~ : Type,
    loc~ : SourceSpan
  )
  Function(
    type_parameters~ : Array[TypeParameter],
    parameters~ : Array[Type],
    result~ : Type,
    effect~ : EffectTerm,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) enum EffectTerm {
  Empty(loc~ : SourceSpan)
  Term(type_~ : Type, loc~ : SourceSpan)
  Union(items~ : Array[Type], loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub fn EffectTerm::loc(self : EffectTerm) -> SourceSpan {
  match self {
    Empty(loc~) | Term(loc~, ..) | Union(loc~, ..) => loc
  }
}

///|
/// Returns the source span covered by this type syntax node.
pub fn Type::loc(self : Type) -> SourceSpan {
  match self {
    Name(loc~, ..)
    | QualifiedName(loc~, ..)
    | Apply(loc~, ..)
    | TypeLambda(loc~, ..)
    | Function(loc~, ..) => loc
  }
}

///|
pub(all) enum Expr {
  IntLiteral(String, loc~ : SourceSpan)
  StringLiteral(String, loc~ : SourceSpan)
  BoolLiteral(Bool, loc~ : SourceSpan)
  UnitLiteral(loc~ : SourceSpan)
  Var(String, loc~ : SourceSpan)
  QualifiedVariant(
    owner~ : Type,
    variant~ : String,
    variant_type_arguments~ : Array[Type],
    arguments~ : Array[Expr],
    loc~ : SourceSpan
  )
  StructLiteral(
    owner~ : Type,
    fields~ : Array[StructLiteralField],
    loc~ : SourceSpan
  )
  Builtin(String, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[TypeParameter],
    parameters~ : Array[FunctionLiteralParameter],
    return_type~ : Type?,
    effect~ : EffectTerm?,
    body~ : Expr,
    loc~ : SourceSpan
  )
  EffectOperationCall(
    name~ : EffectOperationName,
    type_witnesses~ : Array[Type],
    arguments~ : Array[Expr],
    loc~ : SourceSpan
  )
  TypeApplication(callee~ : Expr, arguments~ : Array[Type], loc~ : SourceSpan)
  Handler(
    body~ : Expr,
    handlers~ : Array[HandlerWithBlock],
    final_branch~ : HandlerFinalBranch,
    loc~ : SourceSpan
  )
  Block(items~ : Array[LocalItem], result~ : Expr, loc~ : SourceSpan)
  If(
    condition~ : Expr,
    then_branch~ : Expr,
    else_branch~ : Expr,
    loc~ : SourceSpan
  )
  Match(scrutinee~ : Expr, arms~ : Array[MatchArm], loc~ : SourceSpan)
  Call(callee~ : Expr, arguments~ : Array[CallArgument], loc~ : SourceSpan)
  Field(base~ : Expr, name~ : String, loc~ : SourceSpan)
  Unary(operator~ : UnaryOperator, operand~ : Expr, loc~ : SourceSpan)
  Binary(
    operator~ : BinaryOperator,
    left~ : Expr,
    right~ : Expr,
    loc~ : SourceSpan
  )
  Pipeline(left~ : Expr, right~ : Expr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
/// Returns the source span covered by this expression syntax node.
pub fn Expr::loc(self : Expr) -> SourceSpan {
  match self {
    IntLiteral(_, loc~)
    | StringLiteral(_, loc~)
    | BoolLiteral(_, loc~)
    | UnitLiteral(loc~)
    | Var(_, loc~)
    | QualifiedVariant(loc~, ..)
    | StructLiteral(loc~, ..)
    | Builtin(_, loc~)
    | FunctionLiteral(loc~, ..)
    | EffectOperationCall(loc~, ..)
    | TypeApplication(loc~, ..)
    | Handler(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Call(loc~, ..)
    | Field(loc~, ..)
    | Unary(loc~, ..)
    | Binary(loc~, ..)
    | Pipeline(loc~, ..) => loc
  }
}

///|
pub(all) enum LocalItem {
  Let(LetDeclaration)
  PatternLet(PatternLetDeclaration)
  Function(FunctionDeclaration)
  Offer(OfferDeclaration)
} derive(Debug, Eq)

///|
pub(all) enum EffectOperationName {
  Qualified(owner~ : Type, operation~ : String, loc~ : SourceSpan)
  Shorthand(operation~ : String, loc~ : SourceSpan)
  Unqualified(operation~ : String, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) struct HandlerWithBlock {
  arms : Array[HandlerOperationArm]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct HandlerOperationArm {
  name : EffectOperationName
  type_binders : Array[String]
  payload_patterns : Array[Pattern]
  resume_binder : String
  resume_loc : SourceSpan
  body : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct HandlerFinalBranch {
  binder : String
  binder_loc : SourceSpan
  body : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct PatternLetDeclaration {
  pattern : Pattern
  type_annotation : Type?
  initializer : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct FunctionLiteralParameter {
  is_offered : Bool
  name : String
  type_annotation : Type?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CallArgument {
  Positional(value~ : Expr, loc~ : SourceSpan)
  Named(name~ : String, value~ : Expr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
/// Returns the source span covered by this call argument.
pub fn CallArgument::loc(self : CallArgument) -> SourceSpan {
  match self {
    Positional(loc~, ..) => loc
    Named(loc~, ..) => loc
  }
}

///|
pub(all) enum StructLiteralField {
  Value(name~ : String, value~ : Expr?, loc~ : SourceSpan)
  TypeWitness(name~ : String, witness~ : Type, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) struct MatchArm {
  pattern : Pattern
  body : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum Pattern {
  Wildcard(SourceSpan)
  Binding(String, loc~ : SourceSpan)
  IntLiteral(String, loc~ : SourceSpan)
  StringLiteral(String, loc~ : SourceSpan)
  BoolLiteral(Bool, loc~ : SourceSpan)
  QualifiedVariant(
    type_name~ : String,
    variant~ : String,
    type_binders~ : Array[String],
    arguments~ : Array[Pattern],
    loc~ : SourceSpan
  )
  ShorthandVariant(
    variant~ : String,
    type_binders~ : Array[String],
    arguments~ : Array[Pattern],
    loc~ : SourceSpan
  )
  Struct(
    type_name~ : String,
    fields~ : Array[StructPatternField],
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
/// Returns the source span covered by this pattern syntax node.
pub fn Pattern::loc(self : Pattern) -> SourceSpan {
  match self {
    Wildcard(loc)
    | Binding(_, loc~)
    | IntLiteral(_, loc~)
    | StringLiteral(_, loc~)
    | BoolLiteral(_, loc~)
    | QualifiedVariant(loc~, ..)
    | ShorthandVariant(loc~, ..)
    | Struct(loc~, ..) => loc
  }
}

///|
pub(all) enum StructPatternField {
  Value(name~ : String, pattern~ : Pattern?, loc~ : SourceSpan)
  TypeBinder(name~ : String, loc~ : SourceSpan)
  TypeWildcard(loc~ : SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum UnaryOperator {
  Neg
  Not
} derive(Debug, Eq)

///|
pub(all) enum BinaryOperator {
  Add
  Sub
  Mul
  Div
  Rem
  Equal
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  And
  Or
} derive(Debug, Eq)

///|
/// Returns the lowest precedence level used by binary operators.
pub fn BinaryOperator::minimum_precedence() -> Int {
  2
}

///|
/// Returns the precedence level for this binary operator.
pub fn BinaryOperator::precedence(self : BinaryOperator) -> Int {
  match self {
    Or => 2
    And => 3
    Equal | NotEqual => 4
    Less | LessEqual | Greater | GreaterEqual => 5
    Add | Sub => 6
    Mul | Div | Rem => 7
  }
}
