///|
pub extend CheckedDeclarationEnvironment with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedDeclarationEnvironment with Debug::{to_repr}

///|
pub extend CheckedDeclarationEnvironment with Eq::{not_equal, equal}

///|
pub extend CheckedEffectDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedEffectDeclaration with Debug::{to_repr}

///|
pub extend CheckedEffectDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedEffectOperationDeclaration with @prettyprinter.Pretty::{
  pretty,
}

///|
pub extend CheckedEffectOperationDeclaration with Debug::{to_repr}

///|
pub extend CheckedEffectOperationDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedEnumDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedEnumDeclaration with Debug::{to_repr}

///|
pub extend CheckedEnumDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedExternalTypeDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedExternalTypeDeclaration with Debug::{to_repr}

///|
pub extend CheckedExternalTypeDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedFieldDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedFieldDeclaration with Debug::{to_repr}

///|
pub extend CheckedFieldDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedFunctionDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedFunctionDeclaration with Debug::{to_repr}

///|
pub extend CheckedFunctionDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedLetDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedLetDeclaration with Debug::{to_repr}

///|
pub extend CheckedLetDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedSourceTypeCheckResult with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedSourceTypeCheckResult with Debug::{to_repr}

///|
pub extend CheckedSourceTypeCheckResult with Eq::{not_equal, equal}

///|
pub extend CheckedStructDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedStructDeclaration with Debug::{to_repr}

///|
pub extend CheckedStructDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedTypeDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedTypeDeclaration with Debug::{to_repr}

///|
pub extend CheckedTypeDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedTypeMemberDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedTypeMemberDeclaration with Debug::{to_repr}

///|
pub extend CheckedTypeMemberDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedValueDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedValueDeclaration with Debug::{to_repr}

///|
pub extend CheckedValueDeclaration with Eq::{not_equal, equal}

///|
pub extend CheckedValueEnvironment with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedValueEnvironment with Debug::{to_repr}

///|
pub extend CheckedValueEnvironment with Eq::{not_equal, equal}

///|
pub extend CheckedVariantDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend CheckedVariantDeclaration with Debug::{to_repr}

///|
pub extend CheckedVariantDeclaration with Eq::{not_equal, equal}

///|
pub extend ContextualOfferDiagnosticCandidate with Debug::{to_repr}

///|
pub extend ContextualOfferDiagnosticCandidate with Eq::{not_equal, equal}

///|
pub extend ContextualOfferRequirementSite with Debug::{to_repr}

///|
pub extend ContextualOfferRequirementSite with Eq::{not_equal, equal}

///|
pub extend DeclarationTypeCheckResult with @prettyprinter.Pretty::{pretty}

///|
pub extend DeclarationTypeCheckResult with Debug::{to_repr}

///|
pub extend DeclarationTypeCheckResult with Eq::{not_equal, equal}

///|
pub extend DisplayedTypeCheckDiagnostic with @compiler_diag.ToCompilerDiagnostic::{
  to_compiler_diagnostic,
}

///|
pub extend ExternTypeRestriction with @prettyprinter.Pretty::{pretty}

///|
pub extend ExternTypeRestriction with Debug::{to_repr}

///|
pub extend ExternTypeRestriction with Eq::{not_equal, equal}

///|
pub extend GenericArgumentInferenceFailure with @prettyprinter.Pretty::{pretty}

///|
pub extend GenericArgumentInferenceFailure with Debug::{to_repr}

///|
pub extend GenericArgumentInferenceFailure with Eq::{not_equal, equal}

///|
pub extend GenericArgumentSubject with @prettyprinter.Pretty::{pretty}

///|
pub extend GenericArgumentSubject with Debug::{to_repr}

///|
pub extend GenericArgumentSubject with Eq::{not_equal, equal}

///|
pub extend TypeCheckDiagnostic with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeCheckDiagnostic with Debug::{to_repr}

///|
pub extend TypeCheckDiagnostic with Eq::{not_equal, equal}

///|
pub extend TypeCheckDiagnosticKind with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeCheckDiagnosticKind with Debug::{to_repr}

///|
pub extend TypeCheckDiagnosticKind with Eq::{not_equal, equal}

///|
pub extend TypeCheckError with Debug::{to_repr}

///|
pub extend TypeCheckError with Eq::{not_equal, equal}

///|
pub extend TypeCheckInputMetadataError with Debug::{to_repr}

///|
pub extend TypeCheckInputMetadataError with Eq::{not_equal, equal}

///|
pub extend TypeCheckResult with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeCheckResult with Debug::{to_repr}

///|
pub extend TypeCheckResult with Eq::{not_equal, equal}
