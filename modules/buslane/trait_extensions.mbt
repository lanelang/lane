///|
pub extend AltCon with @prettyprinter.Pretty::{pretty}

///|
pub extend AltCon with Debug::{to_repr}

///|
pub extend AltCon with Eq::{not_equal, equal}

///|
pub extend Alternative with @prettyprinter.Pretty::{pretty}

///|
pub extend Alternative with Debug::{to_repr}

///|
pub extend Alternative with Eq::{not_equal, equal}

///|
pub extend BuiltinEffect with Debug::{to_repr}

///|
pub extend BuiltinEffect with Eq::{not_equal, equal}

///|
pub extend BuslaneName with @prettyprinter.Pretty::{pretty}

///|
pub extend BuslaneName with Debug::{to_repr}

///|
pub extend BuslaneName with Eq::{not_equal, equal}

///|
pub extend BuslaneUnique with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend BuslaneUnique with Debug::{to_repr}

///|
pub extend BuslaneUnique with Eq::{not_equal, equal}

///|
pub extend BuslaneUnique with Hash::{hash, hash_combine}

///|
pub extend ConstructExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend ConstructExpr with Debug::{to_repr}

///|
pub extend ConstructExpr with Eq::{not_equal, equal}

///|
pub extend DataConId with @prettyprinter.Pretty::{pretty}

///|
pub extend DataConId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend DataConId with Debug::{to_repr}

///|
pub extend DataConId with Eq::{not_equal, equal}

///|
pub extend DataConInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend DataConInfo with Debug::{to_repr}

///|
pub extend DataConInfo with Eq::{not_equal, equal}

///|
pub extend Effect with @prettyprinter.Pretty::{pretty}

///|
pub extend Effect with Debug::{to_repr}

///|
pub extend Effect with Eq::{not_equal, equal}

///|
pub extend EffectFlavor with Debug::{to_repr}

///|
pub extend EffectFlavor with Eq::{not_equal, equal}

///|
pub extend EffectId with @prettyprinter.Pretty::{pretty}

///|
pub extend EffectId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend EffectId with Debug::{to_repr}

///|
pub extend EffectId with Eq::{not_equal, equal}

///|
pub extend EffectInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend EffectInfo with Debug::{to_repr}

///|
pub extend EffectInfo with Eq::{not_equal, equal}

///|
pub extend Expr with @prettyprinter.Pretty::{pretty}

///|
pub extend Expr with Debug::{to_repr}

///|
pub extend Expr with Eq::{not_equal, equal}

///|
pub extend ExprChild with @prettyprinter.Pretty::{pretty}

///|
pub extend ExprChild with Debug::{to_repr}

///|
pub extend ExprChild with Eq::{not_equal, equal}

///|
pub extend ExprLabel with @prettyprinter.Pretty::{pretty}

///|
pub extend ExprLabel with Debug::{to_repr}

///|
pub extend ExprLabel with Eq::{not_equal, equal}

///|
pub extend ExpressionFacts with Debug::{to_repr}

///|
pub extend ExpressionFacts with Eq::{not_equal, equal}

///|
pub extend FunctionExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend FunctionExpr with Debug::{to_repr}

///|
pub extend FunctionExpr with Eq::{not_equal, equal}

///|
pub extend GenericArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend GenericArgument with Debug::{to_repr}

///|
pub extend GenericArgument with Eq::{not_equal, equal}

///|
pub extend HandleExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend HandleExpr with Debug::{to_repr}

///|
pub extend HandleExpr with Eq::{not_equal, equal}

///|
pub extend HandlerTable with @prettyprinter.Pretty::{pretty}

///|
pub extend HandlerTable with Debug::{to_repr}

///|
pub extend HandlerTable with Eq::{not_equal, equal}

///|
pub extend Kind with @prettyprinter.Pretty::{pretty}

///|
pub extend Kind with Debug::{to_repr}

///|
pub extend Kind with Eq::{not_equal, equal}

///|
pub extend Literal with @prettyprinter.Pretty::{pretty}

///|
pub extend Literal with Debug::{to_repr}

///|
pub extend Literal with Eq::{not_equal, equal}

///|
pub extend MatchExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend MatchExpr with Debug::{to_repr}

///|
pub extend MatchExpr with Eq::{not_equal, equal}

///|
pub extend MetadataAllocationError with Debug::{to_repr}

///|
pub extend MetadataAllocationError with Eq::{not_equal, equal}

///|
pub extend MetadataAnchor with @prettyprinter.Pretty::{pretty}

///|
pub extend MetadataAnchor with Debug::{to_repr}

///|
pub extend MetadataAnchor with Eq::{not_equal, equal}

///|
pub extend MetadataIdentityError with @prettyprinter.Pretty::{pretty}

///|
pub extend MetadataIdentityError with Debug::{to_repr}

///|
pub extend MetadataIdentityError with Eq::{not_equal, equal}

///|
pub extend MetadataNameAllocator with Debug::{to_repr}

///|
pub extend MetadataNameAllocator with Eq::{not_equal, equal}

///|
pub extend MetadataRegistry with @prettyprinter.Pretty::{pretty}

///|
pub extend MetadataRegistry with Debug::{to_repr}

///|
pub extend MetadataRegistry with Eq::{not_equal, equal}

///|
pub extend NameNamespace with Debug::{to_repr}

///|
pub extend NameNamespace with Eq::{not_equal, equal}

///|
pub extend OperationAlternative with @prettyprinter.Pretty::{pretty}

///|
pub extend OperationAlternative with Debug::{to_repr}

///|
pub extend OperationAlternative with Eq::{not_equal, equal}

///|
pub extend OperationId with @prettyprinter.Pretty::{pretty}

///|
pub extend OperationId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend OperationId with Debug::{to_repr}

///|
pub extend OperationId with Eq::{not_equal, equal}

///|
pub extend OperationInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend OperationInfo with Debug::{to_repr}

///|
pub extend OperationInfo with Eq::{not_equal, equal}

///|
pub extend PerformExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend PerformExpr with Debug::{to_repr}

///|
pub extend PerformExpr with Eq::{not_equal, equal}

///|
pub extend PrimitiveType with @prettyprinter.Pretty::{pretty}

///|
pub extend PrimitiveType with Debug::{to_repr}

///|
pub extend PrimitiveType with Eq::{not_equal, equal}

///|
pub extend Program with @prettyprinter.Pretty::{pretty}

///|
pub extend Program with Debug::{to_repr}

///|
pub extend Program with Eq::{not_equal, equal}

///|
pub extend ProgramScale with Debug::{to_repr}

///|
pub extend ProgramScale with Eq::{not_equal, equal}

///|
pub extend RecursiveBinding with @prettyprinter.Pretty::{pretty}

///|
pub extend RecursiveBinding with Debug::{to_repr}

///|
pub extend RecursiveBinding with Eq::{not_equal, equal}

///|
pub extend TopTerm with @prettyprinter.Pretty::{pretty}

///|
pub extend TopTerm with Debug::{to_repr}

///|
pub extend TopTerm with Eq::{not_equal, equal}

///|
pub extend Type with @prettyprinter.Pretty::{pretty}

///|
pub extend Type with Debug::{to_repr}

///|
pub extend Type with Eq::{not_equal, equal}

///|
pub extend TypeFlavor with Debug::{to_repr}

///|
pub extend TypeFlavor with Eq::{not_equal, equal}

///|
pub extend TypeId with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TypeId with Debug::{to_repr}

///|
pub extend TypeId with Eq::{not_equal, equal}

///|
pub extend TypeInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeInfo with Debug::{to_repr}

///|
pub extend TypeInfo with Eq::{not_equal, equal}

///|
pub extend TypeNormalizationError with Debug::{to_repr}

///|
pub extend TypeNormalizationError with Eq::{not_equal, equal}

///|
pub extend TypeParameterId with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeParameterId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TypeParameterId with Debug::{to_repr}

///|
pub extend TypeParameterId with Eq::{not_equal, equal}

///|
pub extend TypeParameterInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeParameterInfo with Debug::{to_repr}

///|
pub extend TypeParameterInfo with Eq::{not_equal, equal}

///|
pub extend TypeSubstitution with Debug::{to_repr}

///|
pub extend TypeSubstitution with Eq::{not_equal, equal}

///|
pub extend TypeSubstitutionEntry with Debug::{to_repr}

///|
pub extend TypeSubstitutionEntry with Eq::{not_equal, equal}

///|
pub extend TypeSubstitutionError with Debug::{to_repr}

///|
pub extend TypeSubstitutionError with Eq::{not_equal, equal}

///|
pub extend ValueAnchor with @prettyprinter.Pretty::{pretty}

///|
pub extend ValueAnchor with Debug::{to_repr}

///|
pub extend ValueAnchor with Eq::{not_equal, equal}

///|
pub extend ValueId with @prettyprinter.Pretty::{pretty}

///|
pub extend ValueId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ValueId with Debug::{to_repr}

///|
pub extend ValueId with Eq::{not_equal, equal}

///|
pub extend ValueInfo with @prettyprinter.Pretty::{pretty}

///|
pub extend ValueInfo with Debug::{to_repr}

///|
pub extend ValueInfo with Eq::{not_equal, equal}

///|
pub extend ValueKind with @prettyprinter.Pretty::{pretty}

///|
pub extend ValueKind with Debug::{to_repr}

///|
pub extend ValueKind with Eq::{not_equal, equal}

///|
pub extend VerifyDiagnostic with @prettyprinter.Pretty::{pretty}

///|
pub extend VerifyDiagnostic with Debug::{to_repr}

///|
pub extend VerifyDiagnostic with Eq::{not_equal, equal}

///|
pub extend VerifyDiagnosticKind with @prettyprinter.Pretty::{pretty}

///|
pub extend VerifyDiagnosticKind with Debug::{to_repr}

///|
pub extend VerifyDiagnosticKind with Eq::{not_equal, equal}

///|
pub extend VerifyFrame with @prettyprinter.Pretty::{pretty}

///|
pub extend VerifyFrame with Debug::{to_repr}

///|
pub extend VerifyFrame with Eq::{not_equal, equal}

///|
pub extend VerifyResult with @prettyprinter.Pretty::{pretty}

///|
pub extend VerifyResult with Debug::{to_repr}

///|
pub extend VerifyResult with Eq::{not_equal, equal}
