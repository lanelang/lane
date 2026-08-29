///|

///|
pub extend BinaryOperator with @prettyprinter.Pretty::{pretty}

///|
pub extend BinaryOperator with Debug::{to_repr}

///|
pub extend BinaryOperator with Eq::{not_equal, equal}

///|

///|
pub extend CallArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend CallArgument with Debug::{to_repr}

///|
pub extend CallArgument with Eq::{not_equal, equal}

///|
pub extend CallArgumentProvenance with Debug::{to_repr}

///|
pub extend CallArgumentProvenance with Eq::{not_equal, equal}

///|

///|
pub extend EffectDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend EffectDeclaration with Debug::{to_repr}

///|
pub extend EffectDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend EffectOperationDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend EffectOperationDeclaration with Debug::{to_repr}

///|
pub extend EffectOperationDeclaration with Eq::{not_equal, equal}

///|
pub extend EffectOperationName with Debug::{to_repr}

///|
pub extend EffectOperationName with Eq::{not_equal, equal}

///|
pub extend EffectTerm with Debug::{to_repr}

///|
pub extend EffectTerm with Eq::{not_equal, equal}

///|

///|
pub extend EnumDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend EnumDeclaration with Debug::{to_repr}

///|
pub extend EnumDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend EnumVariant with @prettyprinter.Pretty::{pretty}

///|
pub extend EnumVariant with Debug::{to_repr}

///|
pub extend EnumVariant with Eq::{not_equal, equal}

///|

///|
pub extend Expr with @prettyprinter.Pretty::{pretty}

///|
pub extend Expr with Debug::{to_repr}

///|
pub extend Expr with Eq::{not_equal, equal}

///|

///|
pub extend ExternalTypeDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ExternalTypeDeclaration with Debug::{to_repr}

///|
pub extend ExternalTypeDeclaration with Eq::{not_equal, equal}

///|
pub extend ExternalTypeKind with Debug::{to_repr}

///|
pub extend ExternalTypeKind with Eq::{not_equal, equal}

///|

///|
pub extend FieldDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend FieldDeclaration with Debug::{to_repr}

///|
pub extend FieldDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend FunctionDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend FunctionDeclaration with Debug::{to_repr}

///|
pub extend FunctionDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend FunctionLiteralParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend FunctionLiteralParameter with Debug::{to_repr}

///|
pub extend FunctionLiteralParameter with Eq::{not_equal, equal}

///|

///|
pub extend GenericArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend GenericArgument with Debug::{to_repr}

///|
pub extend GenericArgument with Eq::{not_equal, equal}

///|
pub extend HandlerFinalBranch with Debug::{to_repr}

///|
pub extend HandlerFinalBranch with Eq::{not_equal, equal}

///|
pub extend HandlerOperationArm with Debug::{to_repr}

///|
pub extend HandlerOperationArm with Eq::{not_equal, equal}

///|
pub extend HandlerWithBlock with Debug::{to_repr}

///|
pub extend HandlerWithBlock with Eq::{not_equal, equal}

///|

///|
pub extend ImportDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend ImportDeclaration with Debug::{to_repr}

///|
pub extend ImportDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend ImportItem with @prettyprinter.Pretty::{pretty}

///|
pub extend ImportItem with Debug::{to_repr}

///|
pub extend ImportItem with Eq::{not_equal, equal}

///|

///|
pub extend Kind with @prettyprinter.Pretty::{pretty}

///|
pub extend Kind with Debug::{to_repr}

///|
pub extend Kind with Eq::{not_equal, equal}

///|

///|
pub extend LetDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend LetDeclaration with Debug::{to_repr}

///|
pub extend LetDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend LocalItem with @prettyprinter.Pretty::{pretty}

///|
pub extend LocalItem with Debug::{to_repr}

///|
pub extend LocalItem with Eq::{not_equal, equal}

///|

///|
pub extend MatchArm with @prettyprinter.Pretty::{pretty}

///|
pub extend MatchArm with Debug::{to_repr}

///|
pub extend MatchArm with Eq::{not_equal, equal}

///|
pub extend ModuleAlias with Debug::{to_repr}

///|
pub extend ModuleAlias with Eq::{not_equal, equal}

///|

///|
pub extend ModulePath with @prettyprinter.Pretty::{pretty}

///|
pub extend ModulePath with Debug::{to_repr}

///|
pub extend ModulePath with Eq::{not_equal, equal}

///|
pub extend NumericLiteralSuffix with Debug::{to_repr}

///|
pub extend NumericLiteralSuffix with Eq::{not_equal, equal}

///|
pub extend NumericLiteralSuffixParseError with Debug::{to_repr}

///|
pub extend NumericLiteralSuffixParseError with Eq::{not_equal, equal}

///|
pub extend NumericLiteralToken with Debug::{to_repr}

///|
pub extend NumericLiteralToken with Eq::{not_equal, equal}

///|

///|
pub extend Parameter with @prettyprinter.Pretty::{pretty}

///|
pub extend Parameter with Debug::{to_repr}

///|
pub extend Parameter with Eq::{not_equal, equal}

///|
pub extend ParameterModifiers with Debug::{to_repr}

///|
pub extend ParameterModifiers with Eq::{not_equal, equal}

///|

///|
pub extend Pattern with @prettyprinter.Pretty::{pretty}

///|
pub extend Pattern with Debug::{to_repr}

///|
pub extend Pattern with Eq::{not_equal, equal}

///|

///|
pub extend PatternLetDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend PatternLetDeclaration with Debug::{to_repr}

///|
pub extend PatternLetDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend SourceFile with @prettyprinter.Pretty::{pretty}

///|
pub extend SourceFile with Debug::{to_repr}

///|
pub extend SourceFile with Eq::{not_equal, equal}

///|

///|
pub extend StructDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend StructDeclaration with Debug::{to_repr}

///|
pub extend StructDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend StructLiteralField with @prettyprinter.Pretty::{pretty}

///|
pub extend StructLiteralField with Debug::{to_repr}

///|
pub extend StructLiteralField with Eq::{not_equal, equal}

///|

///|
pub extend StructMember with @prettyprinter.Pretty::{pretty}

///|
pub extend StructMember with Debug::{to_repr}

///|
pub extend StructMember with Eq::{not_equal, equal}

///|

///|
pub extend StructPatternField with @prettyprinter.Pretty::{pretty}

///|
pub extend StructPatternField with Debug::{to_repr}

///|
pub extend StructPatternField with Eq::{not_equal, equal}

///|
pub extend SyntacticIdentifierIndex with Debug::{to_repr}

///|
pub extend SyntacticIdentifierIndex with Eq::{not_equal, equal}

///|
pub extend SyntacticIdentifierRole with Debug::{to_repr}

///|
pub extend SyntacticIdentifierRole with Eq::{not_equal, equal}

///|

///|
pub extend TopLevelDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend TopLevelDeclaration with Debug::{to_repr}

///|
pub extend TopLevelDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend Type with @prettyprinter.Pretty::{pretty}

///|
pub extend Type with Debug::{to_repr}

///|
pub extend Type with Eq::{not_equal, equal}

///|

///|
pub extend TypeAliasBody with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeAliasBody with Debug::{to_repr}

///|
pub extend TypeAliasBody with Eq::{not_equal, equal}

///|

///|
pub extend TypeAliasDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeAliasDeclaration with Debug::{to_repr}

///|
pub extend TypeAliasDeclaration with Eq::{not_equal, equal}

///|
pub extend TypeBinder with Debug::{to_repr}

///|
pub extend TypeBinder with Eq::{not_equal, equal}

///|

///|
pub extend TypeMemberDeclaration with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeMemberDeclaration with Debug::{to_repr}

///|
pub extend TypeMemberDeclaration with Eq::{not_equal, equal}

///|

///|
pub extend TypeParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeParameter with Debug::{to_repr}

///|
pub extend TypeParameter with Eq::{not_equal, equal}

///|

///|
pub extend UnaryOperator with @prettyprinter.Pretty::{pretty}

///|
pub extend UnaryOperator with Debug::{to_repr}

///|
pub extend UnaryOperator with Eq::{not_equal, equal}
