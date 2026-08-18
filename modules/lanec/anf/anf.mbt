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
/// Returns the complete callable catalog derived from this closed Runtime ANF
/// program. Function identity, lexical evidence scope, recursive membership,
/// and capture identity are produced together by the Runtime ANF owner.
pub fn AnfProgram::callable_catalog(self : AnfProgram) -> AnfCallableCatalog {
  build_callable_catalog(self)
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
  InvalidRuntimeProjection(detail~ : String)
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
/// Stable identity of an ANF binding and of the computation that produces it.
pub(all) enum AnfBindingId {
  Value(@buslane.ValueId)
  Temp(AnfTempId)
} derive(Debug, Eq)

///|
pub fn AnfBinding::id(self : AnfBinding) -> AnfBindingId {
  match self {
    Value(id~, ..) => Value(id)
    Temp(temp~, ..) => Temp(temp)
  }
}

///|
pub fn AnfBinding::type_(
  self : AnfBinding,
  metadata : RuntimeMetadata,
) -> RuntimeType? {
  match self {
    Value(id~, ..) => metadata.value_info(id).map(info => info.type_)
    Temp(type_~, ..) => Some(type_)
  }
}

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
  Function(AnfFunction)
  EvidenceLambda(parameters~ : Array[RuntimeEvidenceParameter], body~ : AnfExpr)
} derive(Debug, Eq)

///|
pub(all) struct AnfFunction {
  id : AnfFunctionId
  source : @buslane.ValueId?
  parameters : Array[@buslane.ValueId]
  result_type : RuntimeType
  body : AnfExpr
} derive(Debug, Eq)

///|
/// The stable identity of one recursive callable group. Its value is the
/// first function identity in the group, so it is stable under later lowering.
pub(all) struct AnfRecursiveGroupId {
  value : Int
} derive(Debug, Eq, Hash)

///|
/// A value captured by an ANF function allocation site.
pub(all) enum AnfCapture {
  Value(@buslane.ValueId)
  Temp(AnfTempId)
} derive(Debug, Eq)

///|
/// One semantic callable known before VM CFG emission begins. `parameters`
/// are introduced by the callable's own evidence lambda; `lexical_parameters`
/// are evidence binders supplied by an enclosing callable or match arm.
pub(all) struct AnfCallableDefinition {
  function : AnfFunction
  type_ : RuntimeType
  parameters : Array[RuntimeEvidenceParameter]
  lexical_parameters : Array[RuntimeEvidenceParameter]
  captures : Array[AnfCapture]
  owner : AnfFunctionId?
  recursive_group : AnfRecursiveGroupId?
} derive(Debug, Eq)

///|
/// Complete semantic callable inventory of one Runtime ANF program.
pub struct AnfCallableCatalog {
  priv definitions : Array[AnfCallableDefinition]
  priv temp_types : Array[(AnfTempId, RuntimeType)]
} derive(Debug, Eq)

///|
pub fn AnfCallableCatalog::definitions(
  self : AnfCallableCatalog,
) -> ArrayView[AnfCallableDefinition] {
  self.definitions[:]
}

///|
pub fn AnfCallableCatalog::capture_type(
  self : AnfCallableCatalog,
  capture : AnfCapture,
  metadata : RuntimeMetadata,
) -> RuntimeType? {
  match capture {
    Value(value) => metadata.value_info(value).map(info => info.type_)
    Temp(temp) => {
      for entry in self.temp_types {
        if entry.0 == temp {
          return Some(entry.1)
        }
      }
      None
    }
  }
}

///|
pub fn AnfCallableCatalog::find(
  self : AnfCallableCatalog,
  function : AnfFunctionId,
) -> AnfCallableDefinition? {
  for definition in self.definitions {
    if definition.function.id == function {
      return Some(definition)
    }
  }
  None
}

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
