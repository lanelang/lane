///|
pub(all) struct SourceFile {
  declarations : Array[TopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum TopLevelDeclaration {
  Struct(StructDeclaration)
  Enum(EnumDeclaration)
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
  Function(parameters~ : Array[Kind], result~ : Kind, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
/// Returns the source span covered by this kind syntax node.
pub fn Kind::loc(self : Kind) -> SourceSpan {
  match self {
    Type(loc~) | Function(loc~, ..) => loc
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
pub(all) struct TypeAliasDeclaration {
  name : String
  body : Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct FunctionDeclaration {
  type_parameters : Array[TypeParameter]
  name : String
  parameters : Array[Parameter]
  return_type : Type
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
  name : String?
  type_annotation : Type?
  initializer : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct OfferDeclaration {
  name : String
  type_annotation : Type
  initializer : Expr
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum Type {
  Name(name~ : String, loc~ : SourceSpan)
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
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
/// Returns the source span covered by this type syntax node.
pub fn Type::loc(self : Type) -> SourceSpan {
  match self {
    Name(loc~, ..)
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
    type_name~ : String,
    type_arguments~ : Array[Type],
    variant~ : String,
    variant_type_arguments~ : Array[Type],
    arguments~ : Array[Expr],
    loc~ : SourceSpan
  )
  StructLiteral(
    type_name~ : String,
    type_arguments~ : Array[Type],
    fields~ : Array[StructLiteralField],
    loc~ : SourceSpan
  )
  Builtin(String, loc~ : SourceSpan)
  FunctionLiteral(
    type_parameters~ : Array[TypeParameter],
    parameters~ : Array[FunctionLiteralParameter],
    return_type~ : Type?,
    body~ : Expr,
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
pub(all) struct PatternLetDeclaration {
  pattern : Pattern
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
  Positional(Expr)
  Named(name~ : String, value~ : Expr, loc~ : SourceSpan)
} derive(Debug, Eq)

///|
/// Returns the source span covered by this call argument.
pub fn CallArgument::loc(self : CallArgument) -> SourceSpan {
  match self {
    Positional(expression) => expression.loc()
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
