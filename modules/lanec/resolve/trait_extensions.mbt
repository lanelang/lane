///|
pub extend ResolveDiagnostic with @compiler_diag.ToCompilerDiagnostic::{
  to_compiler_diagnostic,
}

///|
pub extend ResolveDiagnostic with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolveDiagnostic with Debug::{to_repr}

///|
pub extend ResolveDiagnostic with Eq::{not_equal, equal}

///|
pub extend ResolveDiagnosticKind with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolveDiagnosticKind with Debug::{to_repr}

///|
pub extend ResolveDiagnosticKind with Eq::{not_equal, equal}

///|
pub extend ResolveResult with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolveResult with Debug::{to_repr}

///|
pub extend ResolveResult with Eq::{not_equal, equal}

///|
pub extend ResolveVariantCandidate with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolveVariantCandidate with Debug::{to_repr}

///|
pub extend ResolveVariantCandidate with Eq::{not_equal, equal}

///|
pub extend ResolvedCallArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedCallArgument with Debug::{to_repr}

///|
pub extend ResolvedCallArgument with Eq::{not_equal, equal}

///|
pub extend ResolvedEffectAliasArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEffectAliasArgument with Debug::{to_repr}

///|
pub extend ResolvedEffectAliasArgument with Eq::{not_equal, equal}

///|
pub extend ResolvedEffectDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEffectDeclaration with Debug::{to_repr}

///|
pub extend ResolvedEffectDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedEffectOperationDeclaration with @prettyprinter.Pretty::{
  pretty,
}

///|
pub extend ResolvedEffectOperationDeclaration with Debug::{to_repr}

///|
pub extend ResolvedEffectOperationDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedEffectOperationName with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEffectOperationName with Debug::{to_repr}

///|
pub extend ResolvedEffectOperationName with Eq::{not_equal, equal}

///|
pub extend ResolvedEffectTerm with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEffectTerm with Debug::{to_repr}

///|
pub extend ResolvedEffectTerm with Eq::{not_equal, equal}

///|
pub extend ResolvedEnumDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEnumDeclaration with Debug::{to_repr}

///|
pub extend ResolvedEnumDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedEnumVariant with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedEnumVariant with Debug::{to_repr}

///|
pub extend ResolvedEnumVariant with Eq::{not_equal, equal}

///|
pub extend ResolvedExpr with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedExpr with Debug::{to_repr}

///|
pub extend ResolvedExpr with Eq::{not_equal, equal}

///|
pub extend ResolvedExternalTypeDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedExternalTypeDeclaration with Debug::{to_repr}

///|
pub extend ResolvedExternalTypeDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedFieldDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedFieldDeclaration with Debug::{to_repr}

///|
pub extend ResolvedFieldDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedFieldReference with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedFieldReference with Debug::{to_repr}

///|
pub extend ResolvedFieldReference with Eq::{not_equal, equal}

///|
pub extend ResolvedFunctionDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedFunctionDeclaration with Debug::{to_repr}

///|
pub extend ResolvedFunctionDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedFunctionLiteralParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedFunctionLiteralParameter with Debug::{to_repr}

///|
pub extend ResolvedFunctionLiteralParameter with Eq::{not_equal, equal}

///|
pub extend ResolvedGenericArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedGenericArgument with Debug::{to_repr}

///|
pub extend ResolvedGenericArgument with Eq::{not_equal, equal}

///|
pub extend ResolvedHandlerFinalBranch with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedHandlerFinalBranch with Debug::{to_repr}

///|
pub extend ResolvedHandlerFinalBranch with Eq::{not_equal, equal}

///|
pub extend ResolvedHandlerOperationArm with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedHandlerOperationArm with Debug::{to_repr}

///|
pub extend ResolvedHandlerOperationArm with Eq::{not_equal, equal}

///|
pub extend ResolvedHandlerWithBlock with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedHandlerWithBlock with Debug::{to_repr}

///|
pub extend ResolvedHandlerWithBlock with Eq::{not_equal, equal}

///|
pub extend ResolvedImportExposure with Debug::{to_repr}

///|
pub extend ResolvedImportExposure with Eq::{not_equal, equal}

///|
pub extend ResolvedImportExposureKind with Debug::{to_repr}

///|
pub extend ResolvedImportExposureKind with Eq::{not_equal, equal}

///|
pub extend ResolvedImportExposureSymbol with Debug::{to_repr}

///|
pub extend ResolvedImportExposureSymbol with Eq::{not_equal, equal}

///|
pub extend ResolvedImportSymbol with Debug::{to_repr}

///|
pub extend ResolvedImportSymbol with Eq::{not_equal, equal}

///|
pub extend ResolvedImportUse with Debug::{to_repr}

///|
pub extend ResolvedImportUse with Eq::{not_equal, equal}

///|
pub extend ResolvedKind with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedKind with Debug::{to_repr}

///|
pub extend ResolvedKind with Eq::{not_equal, equal}

///|
pub extend ResolvedLetDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedLetDeclaration with Debug::{to_repr}

///|
pub extend ResolvedLetDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedLocalItem with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedLocalItem with Debug::{to_repr}

///|
pub extend ResolvedLocalItem with Eq::{not_equal, equal}

///|
pub extend ResolvedMatchArm with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedMatchArm with Debug::{to_repr}

///|
pub extend ResolvedMatchArm with Eq::{not_equal, equal}

///|
pub extend ResolvedModuleBindingReference with Debug::{to_repr}

///|
pub extend ResolvedModuleBindingReference with Eq::{not_equal, equal}

///|
pub extend ResolvedNominalName with Debug::{to_repr}

///|
pub extend ResolvedNominalName with Eq::{not_equal, equal}

///|
pub extend ResolvedOperationReference with Debug::{to_repr}

///|
pub extend ResolvedOperationReference with Eq::{not_equal, equal}

///|
pub extend ResolvedOperatorTarget with Debug::{to_repr}

///|
pub extend ResolvedOperatorTarget with Eq::{not_equal, equal}

///|
pub extend ResolvedPattern with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedPattern with Debug::{to_repr}

///|
pub extend ResolvedPattern with Eq::{not_equal, equal}

///|
pub extend ResolvedPatternLetDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedPatternLetDeclaration with Debug::{to_repr}

///|
pub extend ResolvedPatternLetDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedPublicExport with Debug::{to_repr}

///|
pub extend ResolvedPublicExport with Eq::{not_equal, equal}

///|
pub extend ResolvedQualifiedName with Debug::{to_repr}

///|
pub extend ResolvedQualifiedName with Eq::{not_equal, equal}

///|
pub extend ResolvedSourceFile with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedSourceFile with Debug::{to_repr}

///|
pub extend ResolvedSourceFile with Eq::{not_equal, equal}

///|
pub extend ResolvedStructDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedStructDeclaration with Debug::{to_repr}

///|
pub extend ResolvedStructDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedStructLiteralField with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedStructLiteralField with Debug::{to_repr}

///|
pub extend ResolvedStructLiteralField with Eq::{not_equal, equal}

///|
pub extend ResolvedStructMember with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedStructMember with Debug::{to_repr}

///|
pub extend ResolvedStructMember with Eq::{not_equal, equal}

///|
pub extend ResolvedStructPatternField with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedStructPatternField with Debug::{to_repr}

///|
pub extend ResolvedStructPatternField with Eq::{not_equal, equal}

///|
pub extend ResolvedTopLevelDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedTopLevelDeclaration with Debug::{to_repr}

///|
pub extend ResolvedTopLevelDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedType with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedType with Debug::{to_repr}

///|
pub extend ResolvedType with Eq::{not_equal, equal}

///|
pub extend ResolvedTypeAliasBody with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedTypeAliasBody with Debug::{to_repr}

///|
pub extend ResolvedTypeAliasBody with Eq::{not_equal, equal}

///|
pub extend ResolvedTypeAliasDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedTypeAliasDeclaration with Debug::{to_repr}

///|
pub extend ResolvedTypeAliasDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedTypeMemberDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedTypeMemberDeclaration with Debug::{to_repr}

///|
pub extend ResolvedTypeMemberDeclaration with Eq::{not_equal, equal}

///|
pub extend ResolvedTypeParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedTypeParameter with Debug::{to_repr}

///|
pub extend ResolvedTypeParameter with Eq::{not_equal, equal}

///|
pub extend ResolvedTypeReference with Debug::{to_repr}

///|
pub extend ResolvedTypeReference with Eq::{not_equal, equal}

///|
pub extend ResolvedValueParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedValueParameter with Debug::{to_repr}

///|
pub extend ResolvedValueParameter with Eq::{not_equal, equal}

///|
pub extend ResolvedValueReference with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedValueReference with Debug::{to_repr}

///|
pub extend ResolvedValueReference with Eq::{not_equal, equal}

///|
pub extend ResolvedVariantReference with @prettyprinter.Pretty::{pretty}

///|
pub extend ResolvedVariantReference with Debug::{to_repr}

///|
pub extend ResolvedVariantReference with Eq::{not_equal, equal}
