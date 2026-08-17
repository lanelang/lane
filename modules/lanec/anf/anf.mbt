///|
/// Runtime ANF is the closed, backend-lowerable result of projecting verified
/// effect-aware CPS Core. Only this package constructs values of this type.
pub struct AnfProgram {
  priv metadata : @buslane.MetadataRegistry
  priv terms : Array[AnfTopTerm]
  priv projection_scale : RuntimeAnfProjectionScale
} derive(Debug, Eq)

///|
pub(all) struct RuntimeAnfProjectionScale {
  source_generic_binders : Int
  runtime_generic_binders : Int
  source_type_applications : Int
  runtime_type_applications : Int
} derive(Debug, Eq)

///|
pub fn AnfProgram::metadata(self : AnfProgram) -> @buslane.MetadataRegistry {
  self.metadata
}

///|
pub fn AnfProgram::terms(self : AnfProgram) -> ArrayView[AnfTopTerm] {
  self.terms[:]
}

///|
pub fn AnfProgram::projection_scale(
  self : AnfProgram,
) -> RuntimeAnfProjectionScale {
  self.projection_scale
}

///|
pub(all) suberror RuntimeAnfLoweringError {
  InvalidCpsCore(@buslane.VerifyResult)
  InvalidExpressionMetadata(@buslane.VerifyResult)
  TypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  MissingType(@buslane.TypeId)
  MissingDataConstructor(@buslane.DataConId)
  ResidualPerform(@buslane.OperationId)
  ResidualHandle
} derive(Debug, Eq)

///|
pub(all) struct AnfFunctionId {
  value : Int
} derive(Debug, Eq, Hash)

///|
pub(all) enum AnfTopTerm {
  Let(@buslane.ValueId, AnfExpr)
  LetRec(Array[AnfRecursiveBinding])
  External(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct AnfRecursiveBinding {
  id : @buslane.ValueId
  rhs : AnfAtom
} derive(Debug, Eq)

///|
pub(all) enum AnfExpr {
  Atom(AnfAtom)
  Let(AnfBinding, AnfExpr)
  LetRec(Array[AnfRecursiveBinding], AnfExpr)
} derive(Debug, Eq)

///|
pub(all) enum AnfBinding {
  Value(id~ : @buslane.ValueId, rhs~ : AnfRhs)
  Temp(temp~ : AnfTempId, rhs~ : AnfRhs)
} derive(Debug, Eq)

///|
pub(all) enum AnfRhs {
  Atom(AnfAtom)
  Call(callee~ : AnfAtom, arguments~ : Array[AnfAtom])
  TypeApply(callee~ : AnfAtom, arguments~ : Array[@buslane.GenericArgument])
  Construct(AnfConstruct)
  Match(AnfMatch)
} derive(Debug, Eq)

///|
pub(all) struct AnfConstruct {
  data_constructor : @buslane.DataConId
  type_arguments : Array[@buslane.GenericArgument]
  hidden_witnesses : Array[@buslane.GenericArgument]
  payloads : Array[AnfAtom]
} derive(Debug, Eq)

///|
pub(all) enum AnfAtom {
  Literal(@buslane.Literal)
  Ref(@buslane.ValueId)
  Temp(AnfTempId)
  Function(AnfFunction)
  TypeLambda(
    type_parameters~ : Array[@buslane.TypeParameterId],
    body~ : AnfExpr
  )
} derive(Debug, Eq)

///|
pub(all) struct AnfFunction {
  id : AnfFunctionId
  source : @buslane.ValueId?
  parameters : Array[@buslane.ValueId]
  result_type : @buslane.Type
  body : AnfExpr
} derive(Debug, Eq)

///|
pub(all) struct AnfMatch {
  scrutinee : AnfAtom
  binder : @buslane.ValueId
  result_type : @buslane.Type
  alternatives : Array[AnfAlternative]
} derive(Debug, Eq)

///|
pub(all) struct AnfAlternative {
  alt_constructor : @buslane.AltCon
  type_binders : Array[@buslane.TypeParameterId]
  value_binders : Array[@buslane.ValueId]
  body : AnfExpr
} derive(Debug, Eq)
