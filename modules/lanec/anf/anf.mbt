///|
/// Runtime ANF is the closed, backend-lowerable result of projecting verified
/// effect-aware CPS Core. Only this package constructs values of this type.
pub struct AnfProgram {
  priv metadata : RuntimeMetadata
  priv terms : Array[AnfTopTerm]
} derive(Debug, Eq)

///|
/// The verified CPS Core program and the exact top-level values retained by
/// executable reachability. Runtime ANF construction projects only these
/// terms; backend consumers never recompute source-program occurrence facts.
pub(all) struct RuntimeAnfInput {
  program : @buslane.Program
  retained_values : Array[@buslane.ValueId]
  function_origins : @function_origin.FunctionOriginCatalog
}

///|
pub fn AnfProgram::metadata(self : AnfProgram) -> RuntimeMetadata {
  self.metadata.snapshot()
}

///|
pub fn AnfProgram::terms(self : AnfProgram) -> ArrayView[AnfTopTerm] {
  self.terms[:]
}

///|
pub(all) suberror RuntimeAnfLoweringError {
  InvalidCpsCore(@buslane.VerifyResult)
  InvalidRetention(@buslane.VerifyResult)
  DuplicateRetainedValue(@buslane.ValueId)
  UnknownRetainedValue(@buslane.ValueId)
  InvalidExpressionMetadata(@buslane.VerifyResult)
  TypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  MissingType(@buslane.TypeId)
  MissingDataConstructor(@buslane.DataConId)
  MissingFunctionOrigin
  InvalidRuntimeProjection(detail~ : String)
  InvalidCallableDisposition(detail~ : String)
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
  Temp(temp~ : AnfTempId, type_~ : RuntimeType, rhs~ : AnfRhs)
} derive(Debug, Eq)

///|
pub(all) enum AnfRhs {
  Atom(AnfAtom)
  Call(callee~ : AnfAtom, arguments~ : Array[AnfAtom])
  ApplyEvidence(callee~ : AnfAtom, arguments~ : Array[RuntimeArgument])
  Construct(AnfConstruct)
  Match(AnfMatch)
} derive(Debug, Eq)

///|
pub(all) struct AnfConstruct {
  data_constructor : @buslane.DataConId
  type_arguments : Array[RuntimeArgument]
  hidden_arguments : Array[RuntimeArgument]
  payloads : Array[AnfAtom]
} derive(Debug, Eq)

///|
pub(all) enum AnfAtom {
  Literal(@buslane.Literal)
  Ref(@buslane.ValueId)
  Temp(AnfTempId)
  /// A retained top-level function or a lexical function that requires
  /// first-class closure semantics.
  Function(AnfFunction)
  /// A lexical function used only by saturated direct calls. Captures are
  /// physical inputs rather than members of a closure environment.
  DirectFunction(AnfFunction)
  /// A saturated tail-only lexical function owned by its enclosing function.
  JoinPoint(AnfFunction)
  EvidenceLambda(parameters~ : Array[RuntimeEvidenceParameter], body~ : AnfExpr)
} derive(Debug, Eq)

///|
pub(all) struct AnfFunction {
  id : AnfFunctionId
  source : @buslane.ValueId?
  origin : @function_origin.FunctionOrigin
  parameters : Array[@buslane.ValueId]
  result_type : RuntimeType
  body : AnfExpr
} derive(Debug, Eq)

///|
pub(all) struct AnfMatch {
  scrutinee : AnfAtom
  binder : @buslane.ValueId
  result_type : RuntimeType
  alternatives : Array[AnfAlternative]
} derive(Debug, Eq)

///|
pub(all) struct AnfAlternative {
  alt_constructor : @buslane.AltCon
  evidence_binders : Array[RuntimeEvidenceParameter]
  value_binders : Array[@buslane.ValueId]
  body : AnfExpr
} derive(Debug, Eq)
