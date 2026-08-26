///|
pub extend AnfAlternative with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfAlternative with Debug::{to_repr}

///|
pub extend AnfAlternative with Eq::{not_equal, equal}

///|
pub extend AnfAtom with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfAtom with Debug::{to_repr}

///|
pub extend AnfAtom with Eq::{not_equal, equal}

///|
pub extend AnfBinding with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfBinding with Debug::{to_repr}

///|
pub extend AnfBinding with Eq::{not_equal, equal}

///|
pub extend AnfConstruct with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfConstruct with Debug::{to_repr}

///|
pub extend AnfConstruct with Eq::{not_equal, equal}

///|
pub extend AnfExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfExpr with Debug::{to_repr}

///|
pub extend AnfExpr with Eq::{not_equal, equal}

///|
pub extend AnfFunction with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfFunction with Debug::{to_repr}

///|
pub extend AnfFunction with Eq::{not_equal, equal}

///|
pub extend AnfFunctionId with Debug::{to_repr}

///|
pub extend AnfFunctionId with Eq::{not_equal, equal}

///|
pub extend AnfFunctionId with Hash::{hash, hash_combine}

///|
pub extend AnfMatch with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfMatch with Debug::{to_repr}

///|
pub extend AnfMatch with Eq::{not_equal, equal}

///|
pub extend AnfProgram with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfProgram with Debug::{to_repr}

///|
pub extend AnfProgram with Eq::{not_equal, equal}

///|
pub extend AnfRecursiveBinding with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfRecursiveBinding with Debug::{to_repr}

///|
pub extend AnfRecursiveBinding with Eq::{not_equal, equal}

///|
pub extend AnfRhs with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfRhs with Debug::{to_repr}

///|
pub extend AnfRhs with Eq::{not_equal, equal}

///|
pub extend AnfTempId with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfTempId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend AnfTempId with Debug::{to_repr}

///|
pub extend AnfTempId with Eq::{not_equal, equal}

///|
pub extend AnfTopTerm with @prettyprinter.Pretty::{pretty}

///|
pub extend AnfTopTerm with Debug::{to_repr}

///|
pub extend AnfTopTerm with Eq::{not_equal, equal}

///|
pub extend RuntimeAnfLoweringError with Debug::{to_repr}

///|
pub extend RuntimeAnfLoweringError with Eq::{not_equal, equal}

///|
pub extend RuntimeArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend RuntimeArgument with Debug::{to_repr}

///|
pub extend RuntimeArgument with Eq::{not_equal, equal}

///|
pub extend RuntimeDataConstructorInfo with Debug::{to_repr}

///|
pub extend RuntimeDataConstructorInfo with Eq::{not_equal, equal}

///|
pub extend RuntimeDataInfo with Debug::{to_repr}

///|
pub extend RuntimeDataInfo with Eq::{not_equal, equal}

///|
pub extend RuntimeEvidence with @prettyprinter.Pretty::{pretty}

///|
pub extend RuntimeEvidence with Debug::{to_repr}

///|
pub extend RuntimeEvidence with Eq::{not_equal, equal}

///|
pub extend RuntimeEvidenceId with @prettyprinter.Pretty::{pretty}

///|
pub extend RuntimeEvidenceId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend RuntimeEvidenceId with Debug::{to_repr}

///|
pub extend RuntimeEvidenceId with Eq::{not_equal, equal}

///|
pub extend RuntimeEvidenceId with Hash::{hash, hash_combine}

///|
pub extend RuntimeEvidenceParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend RuntimeEvidenceParameter with Debug::{to_repr}

///|
pub extend RuntimeEvidenceParameter with Eq::{not_equal, equal}

///|
pub extend RuntimeLayout with Debug::{to_repr}

///|
pub extend RuntimeLayout with Eq::{not_equal, equal}

///|
pub extend RuntimeMetadata with Debug::{to_repr}

///|
pub extend RuntimeMetadata with Eq::{not_equal, equal}

///|
pub extend RuntimeNominalKind with Debug::{to_repr}

///|
pub extend RuntimeNominalKind with Eq::{not_equal, equal}

///|
pub extend RuntimeScalarType with Debug::{to_repr}

///|
pub extend RuntimeScalarType with Eq::{not_equal, equal}

///|
pub extend RuntimeType with @prettyprinter.Pretty::{pretty}

///|
pub extend RuntimeType with Debug::{to_repr}

///|
pub extend RuntimeType with Eq::{not_equal, equal}

///|
pub extend RuntimeTypeExpression with Debug::{to_repr}

///|
pub extend RuntimeTypeExpression with Eq::{not_equal, equal}

///|
pub extend RuntimeTypeExpressionId with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
pub extend RuntimeTypeExpressionId with Debug::{to_repr}

///|
pub extend RuntimeTypeExpressionId with Eq::{not_equal, equal}

///|
pub extend RuntimeTypeExpressionId with Hash::{hash, hash_combine}

///|
pub extend RuntimeValueInfo with Debug::{to_repr}

///|
pub extend RuntimeValueInfo with Eq::{not_equal, equal}
