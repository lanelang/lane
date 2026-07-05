///|
using @basic {type SourceSpan}

///|
using @symbol {
  type FieldSymbolId,
  type OperationSymbolId,
  type TypeSymbolId,
  type ValueSymbolId,
  type VariantSymbolId,
}

///|
pub(all) struct AnfTempId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct AnfProgram {
  declarations : Array[AnfTopLevelDeclaration]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum AnfTopLevelDeclaration {
  Struct(@checked.CheckedStructDeclaration)
  Enum(@checked.CheckedEnumDeclaration)
  Effect(@checked.CheckedEffectDeclaration)
  Function(AnfFunctionDeclaration)
  Let(AnfLetDeclaration)
} derive(Debug, Eq)

///|
pub(all) struct AnfFunctionDeclaration {
  symbol : ValueSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  parameters : Array[@checked.CheckedValueParameter]
  return_type : @types.Type
  body : AnfExpr
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct AnfLetDeclaration {
  symbol : ValueSymbolId
  name : String?
  value : AnfExpr
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum AnfExpr {
  Atom(atom~ : AnfAtom, type_~ : @types.Type, loc~ : SourceSpan)
  Let(
    binding~ : AnfBinding,
    body~ : AnfExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  If(
    condition~ : AnfAtom,
    then_branch~ : AnfExpr,
    else_branch~ : AnfExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Match(
    scrutinee~ : AnfAtom,
    arms~ : Array[AnfMatchArm],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) enum AnfBinding {
  Value(
    symbol~ : ValueSymbolId,
    name~ : String?,
    rhs~ : AnfRhs,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Temp(
    temp~ : AnfTempId,
    rhs~ : AnfRhs,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Pattern(
    pattern~ : @checked.CheckedPattern,
    initializer~ : AnfAtom,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) enum AnfRhs {
  Atom(AnfAtom)
  Call(
    callee~ : AnfAtom,
    arguments~ : Array[AnfAtom],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  OperationCall(
    operation~ : OperationSymbolId,
    type_witnesses~ : Array[@types.GenericArgument],
    arguments~ : Array[AnfAtom],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  TypeApplication(
    callee~ : AnfAtom,
    arguments~ : Array[@types.GenericArgument],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Field(
    base~ : AnfAtom,
    field~ : FieldSymbolId,
    name~ : String,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Struct(
    symbol~ : TypeSymbolId,
    type_arguments~ : Array[@types.GenericArgument],
    type_witnesses~ : Array[@checked.CheckedStructTypeWitness],
    fields~ : Array[AnfStructField],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Variant(
    symbol~ : VariantSymbolId,
    type_arguments~ : Array[@types.GenericArgument],
    arguments~ : Array[AnfAtom],
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct AnfStructField {
  symbol : FieldSymbolId
  name : String
  value : AnfAtom
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum AnfAtom {
  Literal(
    literal~ : @checked.CheckedLiteral,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Value(
    name~ : String,
    symbol~ : ValueSymbolId,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  Temp(temp~ : AnfTempId, type_~ : @types.Type, loc~ : SourceSpan)
  UnsafeBuiltin(name~ : String, type_~ : @types.Type, loc~ : SourceSpan)
  Function(
    parameters~ : Array[@checked.CheckedValueParameter],
    body~ : AnfExpr,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
  TypeLambda(
    type_parameters~ : Array[@types.TypeParameter],
    body~ : AnfAtom,
    type_~ : @types.Type,
    loc~ : SourceSpan
  )
} derive(Debug, Eq)

///|
pub(all) struct AnfMatchArm {
  pattern : @checked.CheckedPattern
  body : AnfExpr
  loc : SourceSpan
} derive(Debug, Eq)

///|
/// Returns the type assigned to this ANF expression.
pub fn AnfExpr::type_(self : AnfExpr) -> @types.Type {
  match self {
    Atom(type_~, ..) | Let(type_~, ..) | If(type_~, ..) | Match(type_~, ..) =>
      type_
  }
}

///|
/// Returns the source span that produced this ANF expression.
pub fn AnfExpr::loc(self : AnfExpr) -> SourceSpan {
  match self {
    Atom(loc~, ..) | Let(loc~, ..) | If(loc~, ..) | Match(loc~, ..) => loc
  }
}

///|
/// Returns the type assigned to this ANF right-hand side.
pub fn AnfRhs::type_(self : AnfRhs) -> @types.Type {
  match self {
    Atom(atom) => atom.type_()
    Call(type_~, ..)
    | OperationCall(type_~, ..)
    | TypeApplication(type_~, ..)
    | Field(type_~, ..)
    | Struct(type_~, ..)
    | Variant(type_~, ..) => type_
  }
}

///|
/// Returns the source span that produced this ANF right-hand side.
pub fn AnfRhs::loc(self : AnfRhs) -> SourceSpan {
  match self {
    Atom(atom) => atom.loc()
    Call(loc~, ..)
    | OperationCall(loc~, ..)
    | TypeApplication(loc~, ..)
    | Field(loc~, ..)
    | Struct(loc~, ..)
    | Variant(loc~, ..) => loc
  }
}

///|
/// Returns the type assigned to this ANF atom.
pub fn AnfAtom::type_(self : AnfAtom) -> @types.Type {
  match self {
    Literal(type_~, ..)
    | Value(type_~, ..)
    | Temp(type_~, ..)
    | UnsafeBuiltin(type_~, ..)
    | Function(type_~, ..)
    | TypeLambda(type_~, ..) => type_
  }
}

///|
/// Returns the source span that produced this ANF atom.
pub fn AnfAtom::loc(self : AnfAtom) -> SourceSpan {
  match self {
    Literal(loc~, ..)
    | Value(loc~, ..)
    | Temp(loc~, ..)
    | UnsafeBuiltin(loc~, ..)
    | Function(loc~, ..)
    | TypeLambda(loc~, ..) => loc
  }
}
