
pub(all) enum Token {
  INT(NumericLiteralToken)
  DOUBLE(NumericLiteralToken)
  STRING(String)
  CHAR(Int)
  IDENT(String)
  RESERVED(String)
  EOF
  FALSE
  TRUE
  STRUCT
  ENUM
  EFFECT
  FN
  LET
  TYPE
  KIND_TYPE
  KIND_EFFECT
  OFFER
  AUTO
  IF
  ELSE
  MATCH
  HANDLE
  WITH
  FINAL
  DERIVE
  BUILTIN
  EXTERN
  MODULE
  IMPORT
  AS
  PUB
  PLUS
  MINUS
  STAR
  SLASH
  PERCENT
  EQEQ
  BANGEQ
  LT
  LTEQ
  GT
  GTEQ
  AMPAMP
  BARBAR
  BANG
  PIPE
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  LBRACKET
  OWNER_LBRACKET
  RBRACKET
  EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  EMPTY_TYPE_PARAMETER_LIST_ERROR
  TYPE_IDENTIFIER_SLOT
  EFFECT_IDENTIFIER_SLOT
  VALUE_IDENTIFIER_SLOT
  PATTERN_IDENTIFIER_SLOT
  MISSING_TUPLE_TYPE_ITEM_ERROR
  MISSING_TUPLE_EXPRESSION_ITEM_ERROR
  MISSING_TUPLE_PATTERN_ITEM_ERROR
  COMMA
  SEMICOLON
  LAYOUT_NEWLINE(LayoutNewlineClaim)
  DOTSTAR
  DOTLBRACE
  DOT
  COLON
  COLONCOLON
  TIGHT_COLONCOLON
  THIN_ARROW
  FAT_ARROW
  EQUAL
  UNDERSCORE
} derive(Debug)

pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    INT(_) => TK_INT
    DOUBLE(_) => TK_DOUBLE
    STRING(_) => TK_STRING
    CHAR(_) => TK_CHAR
    IDENT(_) => TK_IDENT
    RESERVED(_) => TK_RESERVED
    EOF => TK_EOF
    FALSE => TK_FALSE
    TRUE => TK_TRUE
    STRUCT => TK_STRUCT
    ENUM => TK_ENUM
    EFFECT => TK_EFFECT
    FN => TK_FN
    LET => TK_LET
    TYPE => TK_TYPE
    KIND_TYPE => TK_KIND_TYPE
    KIND_EFFECT => TK_KIND_EFFECT
    OFFER => TK_OFFER
    AUTO => TK_AUTO
    IF => TK_IF
    ELSE => TK_ELSE
    MATCH => TK_MATCH
    HANDLE => TK_HANDLE
    WITH => TK_WITH
    FINAL => TK_FINAL
    DERIVE => TK_DERIVE
    BUILTIN => TK_BUILTIN
    EXTERN => TK_EXTERN
    MODULE => TK_MODULE
    IMPORT => TK_IMPORT
    AS => TK_AS
    PUB => TK_PUB
    PLUS => TK_PLUS
    MINUS => TK_MINUS
    STAR => TK_STAR
    SLASH => TK_SLASH
    PERCENT => TK_PERCENT
    EQEQ => TK_EQEQ
    BANGEQ => TK_BANGEQ
    LT => TK_LT
    LTEQ => TK_LTEQ
    GT => TK_GT
    GTEQ => TK_GTEQ
    AMPAMP => TK_AMPAMP
    BARBAR => TK_BARBAR
    BANG => TK_BANG
    PIPE => TK_PIPE
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
    LBRACKET => TK_LBRACKET
    OWNER_LBRACKET => TK_OWNER_LBRACKET
    RBRACKET => TK_RBRACKET
    EMPTY_GENERIC_ARGUMENT_LIST_ERROR => TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
    EMPTY_TYPE_PARAMETER_LIST_ERROR => TK_EMPTY_TYPE_PARAMETER_LIST_ERROR
    TYPE_IDENTIFIER_SLOT => TK_TYPE_IDENTIFIER_SLOT
    EFFECT_IDENTIFIER_SLOT => TK_EFFECT_IDENTIFIER_SLOT
    VALUE_IDENTIFIER_SLOT => TK_VALUE_IDENTIFIER_SLOT
    PATTERN_IDENTIFIER_SLOT => TK_PATTERN_IDENTIFIER_SLOT
    MISSING_TUPLE_TYPE_ITEM_ERROR => TK_MISSING_TUPLE_TYPE_ITEM_ERROR
    MISSING_TUPLE_EXPRESSION_ITEM_ERROR => TK_MISSING_TUPLE_EXPRESSION_ITEM_ERROR
    MISSING_TUPLE_PATTERN_ITEM_ERROR => TK_MISSING_TUPLE_PATTERN_ITEM_ERROR
    COMMA => TK_COMMA
    SEMICOLON => TK_SEMICOLON
    LAYOUT_NEWLINE(_) => TK_LAYOUT_NEWLINE
    DOTSTAR => TK_DOTSTAR
    DOTLBRACE => TK_DOTLBRACE
    DOT => TK_DOT
    COLON => TK_COLON
    COLONCOLON => TK_COLONCOLON
    TIGHT_COLONCOLON => TK_TIGHT_COLONCOLON
    THIN_ARROW => TK_THIN_ARROW
    FAT_ARROW => TK_FAT_ARROW
    EQUAL => TK_EQUAL
    UNDERSCORE => TK_UNDERSCORE
  }
}

pub(all) enum TokenKind {
  TK_INT
  TK_DOUBLE
  TK_STRING
  TK_CHAR
  TK_IDENT
  TK_RESERVED
  TK_EOF
  TK_FALSE
  TK_TRUE
  TK_STRUCT
  TK_ENUM
  TK_EFFECT
  TK_FN
  TK_LET
  TK_TYPE
  TK_KIND_TYPE
  TK_KIND_EFFECT
  TK_OFFER
  TK_AUTO
  TK_IF
  TK_ELSE
  TK_MATCH
  TK_HANDLE
  TK_WITH
  TK_FINAL
  TK_DERIVE
  TK_BUILTIN
  TK_EXTERN
  TK_MODULE
  TK_IMPORT
  TK_AS
  TK_PUB
  TK_PLUS
  TK_MINUS
  TK_STAR
  TK_SLASH
  TK_PERCENT
  TK_EQEQ
  TK_BANGEQ
  TK_LT
  TK_LTEQ
  TK_GT
  TK_GTEQ
  TK_AMPAMP
  TK_BARBAR
  TK_BANG
  TK_PIPE
  TK_LPAREN
  TK_RPAREN
  TK_LBRACE
  TK_RBRACE
  TK_LBRACKET
  TK_OWNER_LBRACKET
  TK_RBRACKET
  TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  TK_EMPTY_TYPE_PARAMETER_LIST_ERROR
  TK_TYPE_IDENTIFIER_SLOT
  TK_EFFECT_IDENTIFIER_SLOT
  TK_VALUE_IDENTIFIER_SLOT
  TK_PATTERN_IDENTIFIER_SLOT
  TK_MISSING_TUPLE_TYPE_ITEM_ERROR
  TK_MISSING_TUPLE_EXPRESSION_ITEM_ERROR
  TK_MISSING_TUPLE_PATTERN_ITEM_ERROR
  TK_COMMA
  TK_SEMICOLON
  TK_LAYOUT_NEWLINE
  TK_DOTSTAR
  TK_DOTLBRACE
  TK_DOT
  TK_COLON
  TK_COLONCOLON
  TK_TIGHT_COLONCOLON
  TK_THIN_ARROW
  TK_FAT_ARROW
  TK_EQUAL
  TK_UNDERSCORE
} derive(Eq, Hash, Compare)

pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_INT => "INT"
      TK_DOUBLE => "DOUBLE"
      TK_STRING => "STRING"
      TK_CHAR => "CHAR"
      TK_IDENT => "IDENT"
      TK_RESERVED => "RESERVED"
      TK_EOF => "EOF"
      TK_FALSE => "\"false\""
      TK_TRUE => "\"true\""
      TK_STRUCT => "\"struct\""
      TK_ENUM => "\"enum\""
      TK_EFFECT => "\"effect\""
      TK_FN => "\"fn\""
      TK_LET => "\"let\""
      TK_TYPE => "\"type\""
      TK_KIND_TYPE => "\"Type\""
      TK_KIND_EFFECT => "\"Effect\""
      TK_OFFER => "\"offer\""
      TK_AUTO => "\"auto\""
      TK_IF => "\"if\""
      TK_ELSE => "\"else\""
      TK_MATCH => "\"match\""
      TK_HANDLE => "\"handle\""
      TK_WITH => "\"with\""
      TK_FINAL => "\"final\""
      TK_DERIVE => "\"derive\""
      TK_BUILTIN => "\"builtin\""
      TK_EXTERN => "\"extern\""
      TK_MODULE => "\"module\""
      TK_IMPORT => "\"import\""
      TK_AS => "\"as\""
      TK_PUB => "\"pub\""
      TK_PLUS => "\"+\""
      TK_MINUS => "\"-\""
      TK_STAR => "\"*\""
      TK_SLASH => "\"/\""
      TK_PERCENT => "\"%\""
      TK_EQEQ => "\"==\""
      TK_BANGEQ => "\"!=\""
      TK_LT => "\"<\""
      TK_LTEQ => "\"<=\""
      TK_GT => "\">\""
      TK_GTEQ => "\">=\""
      TK_AMPAMP => "\"&&\""
      TK_BARBAR => "\"||\""
      TK_BANG => "\"!\""
      TK_PIPE => "\"|>\""
      TK_LPAREN => "\"(\""
      TK_RPAREN => "\")\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_LBRACKET => "\"[\""
      TK_OWNER_LBRACKET => "\"owner [\""
      TK_RBRACKET => "\"]\""
      TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => "EMPTY_GENERIC_ARGUMENT_LIST_ERROR"
      TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => "EMPTY_TYPE_PARAMETER_LIST_ERROR"
      TK_TYPE_IDENTIFIER_SLOT => "TYPE_IDENTIFIER_SLOT"
      TK_EFFECT_IDENTIFIER_SLOT => "EFFECT_IDENTIFIER_SLOT"
      TK_VALUE_IDENTIFIER_SLOT => "VALUE_IDENTIFIER_SLOT"
      TK_PATTERN_IDENTIFIER_SLOT => "PATTERN_IDENTIFIER_SLOT"
      TK_MISSING_TUPLE_TYPE_ITEM_ERROR => "MISSING_TUPLE_TYPE_ITEM_ERROR"
      TK_MISSING_TUPLE_EXPRESSION_ITEM_ERROR => "MISSING_TUPLE_EXPRESSION_ITEM_ERROR"
      TK_MISSING_TUPLE_PATTERN_ITEM_ERROR => "MISSING_TUPLE_PATTERN_ITEM_ERROR"
      TK_COMMA => "\",\""
      TK_SEMICOLON => "\";\""
      TK_LAYOUT_NEWLINE => "LAYOUT_NEWLINE"
      TK_DOTSTAR => "\".*\""
      TK_DOTLBRACE => "\".{\""
      TK_DOT => "\".\""
      TK_COLON => "\":\""
      TK_COLONCOLON => "\"::\""
      TK_TIGHT_COLONCOLON => "\"tight ::\""
      TK_THIN_ARROW => "\"->\""
      TK_FAT_ARROW => "\"=>\""
      TK_EQUAL => "\"=\""
      TK_UNDERSCORE => "\"_\""
    }
  )
}

pub impl Debug for TokenKind with fn to_repr(self) {
    match self {
      TK_INT => Repr("INT")
      TK_DOUBLE => Repr("DOUBLE")
      TK_STRING => Repr("STRING")
      TK_CHAR => Repr("CHAR")
      TK_IDENT => Repr("IDENT")
      TK_RESERVED => Repr("RESERVED")
      TK_EOF => Repr("EOF")
      TK_FALSE => Repr("false")
      TK_TRUE => Repr("true")
      TK_STRUCT => Repr("struct")
      TK_ENUM => Repr("enum")
      TK_EFFECT => Repr("effect")
      TK_FN => Repr("fn")
      TK_LET => Repr("let")
      TK_TYPE => Repr("type")
      TK_KIND_TYPE => Repr("Type")
      TK_KIND_EFFECT => Repr("Effect")
      TK_OFFER => Repr("offer")
      TK_AUTO => Repr("auto")
      TK_IF => Repr("if")
      TK_ELSE => Repr("else")
      TK_MATCH => Repr("match")
      TK_HANDLE => Repr("handle")
      TK_WITH => Repr("with")
      TK_FINAL => Repr("final")
      TK_DERIVE => Repr("derive")
      TK_BUILTIN => Repr("builtin")
      TK_EXTERN => Repr("extern")
      TK_MODULE => Repr("module")
      TK_IMPORT => Repr("import")
      TK_AS => Repr("as")
      TK_PUB => Repr("pub")
      TK_PLUS => Repr("+")
      TK_MINUS => Repr("-")
      TK_STAR => Repr("*")
      TK_SLASH => Repr("/")
      TK_PERCENT => Repr("%")
      TK_EQEQ => Repr("==")
      TK_BANGEQ => Repr("!=")
      TK_LT => Repr("<")
      TK_LTEQ => Repr("<=")
      TK_GT => Repr(">")
      TK_GTEQ => Repr(">=")
      TK_AMPAMP => Repr("&&")
      TK_BARBAR => Repr("||")
      TK_BANG => Repr("!")
      TK_PIPE => Repr("|>")
      TK_LPAREN => Repr("(")
      TK_RPAREN => Repr(")")
      TK_LBRACE => Repr("{")
      TK_RBRACE => Repr("}")
      TK_LBRACKET => Repr("[")
      TK_OWNER_LBRACKET => Repr("owner [")
      TK_RBRACKET => Repr("]")
      TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Repr("EMPTY_GENERIC_ARGUMENT_LIST_ERROR")
      TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => Repr("EMPTY_TYPE_PARAMETER_LIST_ERROR")
      TK_TYPE_IDENTIFIER_SLOT => Repr("TYPE_IDENTIFIER_SLOT")
      TK_EFFECT_IDENTIFIER_SLOT => Repr("EFFECT_IDENTIFIER_SLOT")
      TK_VALUE_IDENTIFIER_SLOT => Repr("VALUE_IDENTIFIER_SLOT")
      TK_PATTERN_IDENTIFIER_SLOT => Repr("PATTERN_IDENTIFIER_SLOT")
      TK_MISSING_TUPLE_TYPE_ITEM_ERROR => Repr("MISSING_TUPLE_TYPE_ITEM_ERROR")
      TK_MISSING_TUPLE_EXPRESSION_ITEM_ERROR => Repr("MISSING_TUPLE_EXPRESSION_ITEM_ERROR")
      TK_MISSING_TUPLE_PATTERN_ITEM_ERROR => Repr("MISSING_TUPLE_PATTERN_ITEM_ERROR")
      TK_COMMA => Repr(",")
      TK_SEMICOLON => Repr(";")
      TK_LAYOUT_NEWLINE => Repr("LAYOUT_NEWLINE")
      TK_DOTSTAR => Repr(".*")
      TK_DOTLBRACE => Repr(".{")
      TK_DOT => Repr(".")
      TK_COLON => Repr(":")
      TK_COLONCOLON => Repr("::")
      TK_TIGHT_COLONCOLON => Repr("tight ::")
      TK_THIN_ARROW => Repr("->")
      TK_FAT_ARROW => Repr("=>")
      TK_EQUAL => Repr("=")
      TK_UNDERSCORE => Repr("_")
    }
}

pub suberror ParseError {
  UnexpectedToken(Token, (SourceSpan, SourceSpan), Array[TokenKind])
  UnexpectedEndOfInput(SourceSpan, Array[TokenKind])
} derive(Debug)

type YYObj = Error

priv suberror YYObj_Void

priv suberror YYObj_Int {
  YYObj_Int(Int)
}

priv suberror YYObj_Bool {
  YYObj_Bool(Bool)
}

priv suberror YYObj_Expr {
  YYObj_Expr(Expr)
}

priv suberror YYObj_Kind {
  YYObj_Kind(Kind)
}

priv suberror YYObj_Type {
  YYObj_Type(Type)
}

priv suberror YYObj_Unit {
  YYObj_Unit(Unit)
}

priv suberror YYObj_Array_Expr_ {
  YYObj_Array_Expr_(Array[Expr])
}

priv suberror YYObj_Array_Kind_ {
  YYObj_Array_Kind_(Array[Kind])
}

priv suberror YYObj_Array_Type_ {
  YYObj_Array_Type_(Array[Type])
}

priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
}

priv suberror YYObj_Array_Pattern_ {
  YYObj_Array_Pattern_(Array[Pattern])
}

priv suberror YYObj_Array_MatchArm_ {
  YYObj_Array_MatchArm_(Array[MatchArm])
}

priv suberror YYObj_Array_LocalItem_ {
  YYObj_Array_LocalItem_(Array[LocalItem])
}

priv suberror YYObj_Array_Parameter_ {
  YYObj_Array_Parameter_(Array[Parameter])
}

priv suberror YYObj_Array_ImportItem_ {
  YYObj_Array_ImportItem_(Array[ImportItem])
}

priv suberror YYObj_Array_TypeBinder_ {
  YYObj_Array_TypeBinder_(Array[TypeBinder])
}

priv suberror YYObj_Array_EnumVariant_ {
  YYObj_Array_EnumVariant_(Array[EnumVariant])
}

priv suberror YYObj_Array_CallArgument_ {
  YYObj_Array_CallArgument_(Array[CallArgument])
}

priv suberror YYObj_Array_StructMember_ {
  YYObj_Array_StructMember_(Array[StructMember])
}

priv suberror YYObj_Array_TypeParameter_ {
  YYObj_Array_TypeParameter_(Array[TypeParameter])
}

priv suberror YYObj_Array_GenericArgument_ {
  YYObj_Array_GenericArgument_(Array[GenericArgument])
}

priv suberror YYObj_Array_HandlerWithBlock_ {
  YYObj_Array_HandlerWithBlock_(Array[HandlerWithBlock])
}

priv suberror YYObj_Array_StructLiteralField_ {
  YYObj_Array_StructLiteralField_(Array[StructLiteralField])
}

priv suberror YYObj_Array_StructPatternField_ {
  YYObj_Array_StructPatternField_(Array[StructPatternField])
}

priv suberror YYObj_Array_HandlerOperationArm_ {
  YYObj_Array_HandlerOperationArm_(Array[HandlerOperationArm])
}

priv suberror YYObj_Array_TopLevelDeclaration_ {
  YYObj_Array_TopLevelDeclaration_(Array[TopLevelDeclaration])
}

priv suberror YYObj_Array_FunctionLiteralParameter_ {
  YYObj_Array_FunctionLiteralParameter_(Array[FunctionLiteralParameter])
}

priv suberror YYObj_Array_EffectOperationDeclaration_ {
  YYObj_Array_EffectOperationDeclaration_(Array[EffectOperationDeclaration])
}

priv suberror YYObj_String {
  YYObj_String(String)
}

priv suberror YYObj_Pattern {
  YYObj_Pattern(Pattern)
}

priv suberror YYObj_MatchArm {
  YYObj_MatchArm(MatchArm)
}

priv suberror YYObj_LocalItem {
  YYObj_LocalItem(LocalItem)
}

priv suberror YYObj_Parameter {
  YYObj_Parameter(Parameter)
}

priv suberror YYObj_EffectTerm {
  YYObj_EffectTerm(EffectTerm)
}

priv suberror YYObj_Identifier {
  YYObj_Identifier(Identifier)
}

priv suberror YYObj_ImportItem {
  YYObj_ImportItem(ImportItem)
}

priv suberror YYObj_ModuleBody {
  YYObj_ModuleBody(ModuleBody)
}

priv suberror YYObj_ModulePath {
  YYObj_ModulePath(ModulePath)
}

priv suberror YYObj_SourceFile {
  YYObj_SourceFile(SourceFile)
}

priv suberror YYObj_EnumVariant {
  YYObj_EnumVariant(EnumVariant)
}

priv suberror YYObj_ModuleAlias {
  YYObj_ModuleAlias(ModuleAlias)
}

priv suberror YYObj_CallArgument {
  YYObj_CallArgument(CallArgument)
}

priv suberror YYObj_StructMember {
  YYObj_StructMember(StructMember)
}

priv suberror YYObj_TypeAliasBody {
  YYObj_TypeAliasBody(TypeAliasBody)
}

priv suberror YYObj_TypeParameter {
  YYObj_TypeParameter(TypeParameter)
}

priv suberror YYObj_LetDeclaration {
  YYObj_LetDeclaration(LetDeclaration)
}

priv suberror YYObj_EnumDeclaration {
  YYObj_EnumDeclaration(EnumDeclaration)
}

priv suberror YYObj_GenericArgument {
  YYObj_GenericArgument(GenericArgument)
}

priv suberror YYObj_NominalTypeName {
  YYObj_NominalTypeName(NominalTypeName)
}

priv suberror YYObj_OwnerExpression {
  YYObj_OwnerExpression(OwnerExpression)
}

priv suberror YYObj_ExternalTypeKind {
  YYObj_ExternalTypeKind(ExternalTypeKind)
}

priv suberror YYObj_FieldDeclaration {
  YYObj_FieldDeclaration(FieldDeclaration)
}

priv suberror YYObj_HandlerWithBlock {
  YYObj_HandlerWithBlock(HandlerWithBlock)
}

priv suberror YYObj_ReturnAnnotation {
  YYObj_ReturnAnnotation(ReturnAnnotation)
}

priv suberror YYObj_EffectDeclaration {
  YYObj_EffectDeclaration(EffectDeclaration)
}

priv suberror YYObj_ImportDeclaration {
  YYObj_ImportDeclaration(ImportDeclaration)
}

priv suberror YYObj_StructDeclaration {
  YYObj_StructDeclaration(StructDeclaration)
}

priv suberror YYObj_HandlerFinalBranch {
  YYObj_HandlerFinalBranch(HandlerFinalBranch)
}

priv suberror YYObj_LayoutNewlineClaim {
  YYObj_LayoutNewlineClaim(LayoutNewlineClaim)
}

priv suberror YYObj_ParameterModifiers {
  YYObj_ParameterModifiers(ParameterModifiers)
}

priv suberror YYObj_StructLiteralField {
  YYObj_StructLiteralField(StructLiteralField)
}

priv suberror YYObj_StructPatternField {
  YYObj_StructPatternField(StructPatternField)
}

priv suberror YYObj_DeriveTypeArguments {
  YYObj_DeriveTypeArguments(DeriveTypeArguments)
}

priv suberror YYObj_EffectOperationName {
  YYObj_EffectOperationName(EffectOperationName)
}

priv suberror YYObj_FunctionDeclaration {
  YYObj_FunctionDeclaration(FunctionDeclaration)
}

priv suberror YYObj_GenericArgumentList {
  YYObj_GenericArgumentList(GenericArgumentList)
}

priv suberror YYObj_HandlerOperationArm {
  YYObj_HandlerOperationArm(HandlerOperationArm)
}

priv suberror YYObj_NumericLiteralToken {
  YYObj_NumericLiteralToken(NumericLiteralToken)
}

priv suberror YYObj_OwnerPathExpression {
  YYObj_OwnerPathExpression(OwnerPathExpression)
}

priv suberror YYObj_TopLevelDeclaration {
  YYObj_TopLevelDeclaration(TopLevelDeclaration)
}

priv suberror YYObj_HandlerOperationHead {
  YYObj_HandlerOperationHead(HandlerOperationHead)
}

priv suberror YYObj_TypeAliasDeclaration {
  YYObj_TypeAliasDeclaration(TypeAliasDeclaration)
}

priv suberror YYObj_TypeMemberDeclaration {
  YYObj_TypeMemberDeclaration(TypeMemberDeclaration)
}

priv suberror YYObj_ExternalTypeDeclaration {
  YYObj_ExternalTypeDeclaration(ExternalTypeDeclaration)
}

priv suberror YYObj_VariantPatternArguments {
  YYObj_VariantPatternArguments(VariantPatternArguments)
}

priv suberror YYObj_FunctionLiteralParameter {
  YYObj_FunctionLiteralParameter(FunctionLiteralParameter)
}

priv suberror YYObj_EffectOperationDeclaration {
  YYObj_EffectOperationDeclaration(EffectOperationDeclaration)
}

priv suberror YYObj_HandlerOperationArmParameters {
  YYObj_HandlerOperationArmParameters(HandlerOperationArmParameters)
}

priv suberror YYObj_Expr_ {
  YYObj_Expr_(Expr?)
}

priv suberror YYObj_Kind_ {
  YYObj_Kind_(Kind?)
}

priv suberror YYObj_Type_ {
  YYObj_Type_(Type?)
}

priv suberror YYObj_EffectTerm_ {
  YYObj_EffectTerm_(EffectTerm?)
}

priv suberror YYObj_GenericArgumentList_ {
  YYObj_GenericArgumentList_(GenericArgumentList?)
}

type YYState = (YYSymbol) -> YYDecision

type YYAction = (SourceSpan, ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj

priv enum YYDecision {
  Accept
  Shift(YYState)
  Reduce(Int, YYSymbol, YYAction)
  ReduceNoLookahead(Int, YYSymbol, YYAction)
  Error
}

priv enum YYSymbol {
  T_INT
  T_DOUBLE
  T_STRING
  T_CHAR
  T_IDENT
  T_RESERVED
  T_EOF
  T_FALSE
  T_TRUE
  T_STRUCT
  T_ENUM
  T_EFFECT
  T_FN
  T_LET
  T_TYPE
  T_KIND_TYPE
  T_KIND_EFFECT
  T_OFFER
  T_AUTO
  T_IF
  T_ELSE
  T_MATCH
  T_HANDLE
  T_WITH
  T_FINAL
  T_DERIVE
  T_BUILTIN
  T_EXTERN
  T_MODULE
  T_IMPORT
  T_AS
  T_PUB
  T_PLUS
  T_MINUS
  T_STAR
  T_SLASH
  T_PERCENT
  T_EQEQ
  T_BANGEQ
  T_LT
  T_LTEQ
  T_GT
  T_GTEQ
  T_AMPAMP
  T_BARBAR
  T_BANG
  T_PIPE
  T_LPAREN
  T_RPAREN
  T_LBRACE
  T_RBRACE
  T_LBRACKET
  T_OWNER_LBRACKET
  T_RBRACKET
  T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  T_EMPTY_TYPE_PARAMETER_LIST_ERROR
  T_TYPE_IDENTIFIER_SLOT
  T_EFFECT_IDENTIFIER_SLOT
  T_VALUE_IDENTIFIER_SLOT
  T_PATTERN_IDENTIFIER_SLOT
  T_MISSING_TUPLE_TYPE_ITEM_ERROR
  T_MISSING_TUPLE_EXPRESSION_ITEM_ERROR
  T_MISSING_TUPLE_PATTERN_ITEM_ERROR
  T_COMMA
  T_SEMICOLON
  T_LAYOUT_NEWLINE
  T_DOTSTAR
  T_DOTLBRACE
  T_DOT
  T_COLON
  T_COLONCOLON
  T_TIGHT_COLONCOLON
  T_THIN_ARROW
  T_FAT_ARROW
  T_EQUAL
  T_UNDERSCORE
  NT_source_file
  NT_layout_semicolons
  NT_item_semicolon
  NT_layout_list_separator
  NT_layout_continuation_opt
  NT_module_declaration
  NT_module_path
  NT_non_empty_module_path
  NT_module_body
  NT_public_import_declaration
  NT_import_declaration
  NT_module_alias
  NT_import_item_list
  NT_non_empty_import_item_list
  NT_import_item
  NT_identifier
  NT_top_level_declarations
  NT_top_level_declaration
  NT_non_public_top_level_declaration
  NT_public_top_level_declaration
  NT_external_type_declaration
  NT_public_external_type_declaration
  NT_external_type_result_kind
  NT_type_alias_declaration
  NT_public_type_alias_declaration
  NT_type_alias_body
  NT_struct_declaration
  NT_public_struct_declaration
  NT_struct_members
  NT_non_empty_struct_members
  NT_struct_member
  NT_type_member_declaration
  NT_kind
  NT_kind_list
  NT_non_empty_kind_list
  NT_field_declaration
  NT_enum_declaration
  NT_public_enum_declaration
  NT_enum_variants
  NT_non_empty_enum_variants
  NT_enum_variant
  NT_effect_declaration
  NT_public_effect_declaration
  NT_effect_operations
  NT_non_empty_effect_operations
  NT_effect_operation
  NT_function_declaration
  NT_public_function_declaration
  NT_parameters
  NT_non_empty_parameter_list
  NT_parameter
  NT_parameter_modifiers
  NT_top_level_let_declaration
  NT_public_top_level_let_declaration
  NT_local_let_item
  NT_local_type_annotation
  NT_offer_value_declaration
  NT_public_offer_value_declaration
  NT_type_parameters
  NT_nominal_body_open
  NT_type_parameter_bracket_list
  NT_non_empty_type_parameter_list
  NT_type_parameter
  NT_type
  NT_type_lambda
  NT_type_application
  NT_type_primary
  NT_tuple_type_tail
  NT_qualified_type_name
  NT_function_type
  NT_effect_annotation_opt
  NT_effect_annotation
  NT_effect_set
  NT_type_list
  NT_non_empty_type_list
  NT_expression
  NT_unary_expression
  NT_postfix_expression
  NT_value_postfix_expression
  NT_member_expression
  NT_owner_path_expression
  NT_owner_expression
  NT_owner_type_arguments
  NT_non_owner_primary_expression
  NT_list_literal_items
  NT_tuple_expression_tail
  NT_derive_expression
  NT_derive_type_arguments
  NT_operation_type_witnesses
  NT_type_arguments
  NT_type_argument_bracket_list
  NT_generic_argument
  NT_non_empty_generic_argument_list
  NT_nominal_type_name
  NT_variant_type_arguments
  NT_struct_literal_fields
  NT_non_empty_struct_literal_fields
  NT_struct_literal_field
  NT_variant_arguments
  NT_positional_argument_list
  NT_argument_list
  NT_non_empty_argument_list
  NT_call_argument
  NT_non_empty_positional_argument_list
  NT_block_expression
  NT_local_items
  NT_local_item
  NT_if_expression
  NT_optional_else_branch
  NT_else_branch_expression
  NT_match_expression
  NT_match_arms
  NT_non_empty_match_arms
  NT_match_arm
  NT_handler_expression
  NT_handler_with_blocks
  NT_handler_with_block
  NT_handler_operation_arms
  NT_non_empty_handler_operation_arms
  NT_handler_operation_arm
  NT_handler_operation_name
  NT_handler_operation_signature_open
  NT_handler_operation_signature_after_newline
  NT_ident_bracket_list
  NT_handler_operation_owner_arguments
  NT_handler_operation_generic_arguments
  NT_handler_operation_arm_parameters
  NT_handler_payload_patterns
  NT_handler_final_branch
  NT_function_literal
  NT_function_literal_open
  NT_function_literal_parameters
  NT_non_empty_function_literal_parameters
  NT_function_literal_parameter
  NT_function_literal_parameter_modifiers
  NT_return_annotation
  NT_builtin_expression
  NT_extern_expression
  NT_pattern
  NT_tuple_pattern_tail
  NT_struct_pattern
  NT_variant_pattern_arguments
  NT_variant_pattern_arguments_after_newline
  NT_non_empty_ident_list
  NT_pattern_list
  NT_non_empty_pattern_list
  NT_struct_pattern_fields
  NT_non_empty_struct_pattern_fields
  NT_struct_pattern_field
  NT_type_alias_result_kind_opt
  EOI
}

// Workaround for EOI unused warning
fn init {
  match (EOI : YYSymbol) {
    EOI => ()
    _ => ()
  }
}

// file:///./parser.mbty
// 105|    module_declaration layout_semicolons module_body EOF {
// 106|    { module_path: $1, imports: $3.imports, declarations: $3.declarations, loc: span($sloc) }
// 107|  }
fn yy_action_0(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePath(_dollar1)
  guard _args[2].0 is YYObj_ModuleBody(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_SourceFile({(); 
    { module_path: _dollar1, imports: _dollar3.imports, declarations: _dollar3.declarations, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 145|    import_declaration layout_semicolons module_body {
// 146|    { imports: prepend($1, $3.imports), declarations: $3.declarations }
// 147|  }
fn yy_action_1(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportDeclaration(_dollar1)
  guard _args[2].0 is YYObj_ModuleBody(_dollar3)
  YYObj_ModuleBody({(); 
    { imports: prepend(_dollar1, _dollar3.imports), declarations: _dollar3.declarations }
  })
}

// file:///./parser.mbty
// 148|    public_import_declaration layout_semicolons module_body {
// 149|    { imports: prepend($1, $3.imports), declarations: $3.declarations }
// 150|  }
fn yy_action_2(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportDeclaration(_dollar1)
  guard _args[2].0 is YYObj_ModuleBody(_dollar3)
  YYObj_ModuleBody({(); 
    { imports: prepend(_dollar1, _dollar3.imports), declarations: _dollar3.declarations }
  })
}

// file:///./parser.mbty
// 204|    top_level_declarations top_level_declaration layout_semicolons { comma_push($1, $2) }
fn yy_action_3(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopLevelDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_Array_TopLevelDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 151|    top_level_declaration layout_semicolons top_level_declarations {
// 152|    { imports: [], declarations: prepend($1, $3) }
// 153|  }
fn yy_action_4(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TopLevelDeclaration(_dollar1)
  guard _args[2].0 is YYObj_Array_TopLevelDeclaration_(_dollar3)
  YYObj_ModuleBody({(); 
    { imports: [], declarations: prepend(_dollar1, _dollar3) }
  })
}

// file:///./parser.mbty
// 203|    { [] }
fn yy_action_5(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TopLevelDeclaration_({();  [] })
}

// file:///./parser.mbty
// 157|    "pub" "import" module_path ".{" import_item_list "}" {
// 158|    Selective(module_path=$3, items=$5, is_public=true, loc=span($sloc))
// 159|  }
fn yy_action_6(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_ModulePath(_dollar3)
  guard _args[4].0 is YYObj_Array_ImportItem_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Selective(module_path=_dollar3, items=_dollar5, is_public=true, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 209|    "pub" public_top_level_declaration { with_public_loc($2, span($sloc)) }
fn yy_action_7(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TopLevelDeclaration({();  with_public_loc(_dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 224|    public_struct_declaration { Struct($1) }
fn yy_action_8(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 225|    public_enum_declaration { Enum($1) }
fn yy_action_9(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 226|    public_effect_declaration { Effect($1) }
fn yy_action_10(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 227|    public_external_type_declaration { ExternalType($1) }
fn yy_action_11(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ExternalTypeDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  ExternalType(_dollar1) })
}

// file:///./parser.mbty
// 228|    public_type_alias_declaration { TypeAlias($1) }
fn yy_action_12(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 229|    public_function_declaration { Function($1) }
fn yy_action_13(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 230|    public_top_level_let_declaration { Let($1) }
fn yy_action_14(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 231|    public_offer_value_declaration { Let($1) }
fn yy_action_15(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 239|    "extern" "type" identifier type_parameters ":" external_type_result_kind { make_external_type(true, $3, $4, $6, span($sloc)) }
fn yy_action_16(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeParameter_(_dollar4)
  guard _args[5].0 is YYObj_ExternalTypeKind(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeDeclaration({();  make_external_type(true, _dollar3, _dollar4, _dollar6, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 254|    "type" identifier type_parameters type_alias_result_kind_opt "=" type_alias_body {
// 255|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, result_kind: $4, body: $6, loc: span($sloc) }
// 256|  }
fn yy_action_17(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[3].0 is YYObj_Kind_(_dollar4)
  guard _args[5].0 is YYObj_TypeAliasBody(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, result_kind: _dollar4, body: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 273|    "struct" identifier nominal_body_open layout_semicolons struct_members "}" {
// 274|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, members: $5, loc: span($sloc) }
// 275|  }
fn yy_action_18(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, members: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 336|    "enum" identifier nominal_body_open layout_semicolons enum_variants "}" {
// 337|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, variants: $5, loc: span($sloc) }
// 338|  }
fn yy_action_19(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, variants: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 368|    "effect" identifier nominal_body_open layout_semicolons effect_operations "}" {
// 369|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, operations: $5, loc: span($sloc) }
// 370|  }
fn yy_action_20(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EffectOperationDeclaration_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, operations: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 411|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt layout_continuation_opt block_expression {
// 412|    {
// 413|      is_public: true,
// 414|      is_offered: $1,
// 415|      type_parameters: $2,
// 416|      name: $3.name,
// 417|      name_loc: $3.loc,
// 418|      parameters: $4,
// 419|      return_type: $6,
// 420|      effect: effect_or_empty($7, $6),
// 421|      body: $9,
// 422|      loc: span($sloc),
// 423|    }
// 424|  }
fn yy_action_21(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_22(_last_pos, _args[0:1])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionDeclaration({(); 
    {
      is_public: true,
      is_offered: _dollar1,
      type_parameters: _dollar2,
      name: _dollar3.name,
      name_loc: _dollar3.loc,
      parameters: _dollar4,
      return_type: _dollar6,
      effect: effect_or_empty(_dollar7, _dollar6),
      body: _dollar9,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 411|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt layout_continuation_opt block_expression {
// 412|    {
// 413|      is_public: true,
// 414|      is_offered: $1,
// 415|      type_parameters: $2,
// 416|      name: $3.name,
// 417|      name_loc: $3.loc,
// 418|      parameters: $4,
// 419|      return_type: $6,
// 420|      effect: effect_or_empty($7, $6),
// 421|      body: $9,
// 422|      loc: span($sloc),
// 423|    }
// 424|  }
fn yy_action_23(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_24(_last_pos, _args[0:2])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar3)
  guard _args[4].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[9].0 is YYObj_Expr(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionDeclaration({(); 
    {
      is_public: true,
      is_offered: _dollar1,
      type_parameters: _dollar2,
      name: _dollar3.name,
      name_loc: _dollar3.loc,
      parameters: _dollar4,
      return_type: _dollar6,
      effect: effect_or_empty(_dollar7, _dollar6),
      body: _dollar9,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 484|    "offer" identifier ":" type "=" expression {
// 485|    { is_public: true, is_offered: true, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 486|  }
fn yy_action_25(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: true, is_offered: true, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 463|    "let" identifier ":" type "=" expression {
// 464|    { is_public: true, is_offered: false, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 465|  }
fn yy_action_26(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: true, is_offered: false, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 166|    "import" module_path module_alias {
// 167|    Qualified(module_path=$2, module_alias=Some($3), loc=span($sloc))
// 168|  }
fn yy_action_27(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  guard _args[2].0 is YYObj_ModuleAlias(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Qualified(module_path=_dollar2, module_alias=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 169|    "import" module_path ".*" {
// 170|    Open(module_path=$2, loc=span($sloc))
// 171|  }
fn yy_action_28(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Open(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 172|    "import" module_path ".{" import_item_list "}" {
// 173|    Selective(module_path=$2, items=$4, is_public=false, loc=span($sloc))
// 174|  }
fn yy_action_29(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  guard _args[3].0 is YYObj_Array_ImportItem_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Selective(module_path=_dollar2, items=_dollar4, is_public=false, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 190|    non_empty_import_item_list layout_list_separator import_item { comma_push($1, $3) }
fn yy_action_30(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  guard _args[2].0 is YYObj_ImportItem(_dollar3)
  YYObj_Array_ImportItem_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 191|    non_empty_import_item_list layout_list_separator { $1 }
fn yy_action_31(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 185|    non_empty_import_item_list { $1 }
fn yy_action_32(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 189|    import_item { [ $1 ] }
fn yy_action_33(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportItem(_dollar1)
  YYObj_Array_ImportItem_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 195|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_34(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportItem({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 184|    { [] }
fn yy_action_35(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ImportItem_({();  [] })
}

// file:///./parser.mbty
// 178|    "as" identifier {
// 179|    { name: $2.name, name_loc: $2.loc, loc: span($sloc) }
// 180|  }
fn yy_action_36(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ModuleAlias({(); 
    { name: _dollar2.name, name_loc: _dollar2.loc, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 163|    "import" module_path {
// 164|    Qualified(module_path=$2, module_alias=None, loc=span($sloc))
// 165|  }
fn yy_action_37(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Qualified(module_path=_dollar2, module_alias=None, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 208|    non_public_top_level_declaration { $1 }
fn yy_action_38(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TopLevelDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  _dollar1 })
}

// file:///./parser.mbty
// 213|    struct_declaration { Struct($1) }
fn yy_action_39(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 214|    enum_declaration { Enum($1) }
fn yy_action_40(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 215|    effect_declaration { Effect($1) }
fn yy_action_41(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 216|    external_type_declaration { ExternalType($1) }
fn yy_action_42(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ExternalTypeDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  ExternalType(_dollar1) })
}

// file:///./parser.mbty
// 217|    type_alias_declaration { TypeAlias($1) }
fn yy_action_43(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 218|    function_declaration { Function($1) }
fn yy_action_44(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 219|    top_level_let_declaration { Let($1) }
fn yy_action_45(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 220|    offer_value_declaration { Let($1) }
fn yy_action_46(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 235|    "extern" "type" identifier type_parameters ":" external_type_result_kind { make_external_type(false, $3, $4, $6, span($sloc)) }
fn yy_action_47(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeParameter_(_dollar4)
  guard _args[5].0 is YYObj_ExternalTypeKind(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeDeclaration({();  make_external_type(false, _dollar3, _dollar4, _dollar6, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 243|    "Type" { Type(loc=span($sloc)) }
fn yy_action_48(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeKind({();  Type(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 244|    "Effect" { Effect(loc=span($sloc)) }
fn yy_action_49(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeKind({();  Effect(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 248|    "type" identifier type_parameters type_alias_result_kind_opt "=" type_alias_body {
// 249|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, result_kind: $4, body: $6, loc: span($sloc) }
// 250|  }
fn yy_action_50(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[3].0 is YYObj_Kind_(_dollar4)
  guard _args[5].0 is YYObj_TypeAliasBody(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, result_kind: _dollar4, body: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 260|    type { TypeBody($1) }
fn yy_action_51(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_TypeAliasBody({();  TypeBody(_dollar1) })
}

// file:///./parser.mbty
// 261|    "{" type_list "}" {
// 262|    EffectBody(effect_set($2, span($sloc)))
// 263|  }
fn yy_action_52(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasBody({(); 
    EffectBody(effect_set(_dollar2, span((_symbol_start_pos, _end_pos))))
  })
}

// file:///./parser.mbty
// 1173|    ":" kind { Some($2) }
fn yy_action_53(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  YYObj_Kind_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 1172|    { None }
fn yy_action_54(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind_({();  None })
}

// file:///./parser.mbty
// 267|    "struct" identifier nominal_body_open layout_semicolons struct_members "}" {
// 268|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, members: $5, loc: span($sloc) }
// 269|  }
fn yy_action_55(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, members: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 285|    non_empty_struct_members item_semicolon struct_member { comma_push($1, $3) }
fn yy_action_56(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  guard _args[2].0 is YYObj_StructMember(_dollar3)
  YYObj_Array_StructMember_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 286|    non_empty_struct_members item_semicolon { $1 }
fn yy_action_57(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  YYObj_Array_StructMember_({();  _dollar1 })
}

// file:///./parser.mbty
// 280|    non_empty_struct_members { $1 }
fn yy_action_58(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  YYObj_Array_StructMember_({();  _dollar1 })
}

// file:///./parser.mbty
// 284|    struct_member { [ $1 ] }
fn yy_action_59(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructMember(_dollar1)
  YYObj_Array_StructMember_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 290|    type_member_declaration { TypeMember($1) }
fn yy_action_60(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeMemberDeclaration(_dollar1)
  YYObj_StructMember({();  TypeMember(_dollar1) })
}

// file:///./parser.mbty
// 291|    field_declaration { Field($1) }
fn yy_action_61(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FieldDeclaration(_dollar1)
  YYObj_StructMember({();  Field(_dollar1) })
}

// file:///./parser.mbty
// 298|    "type" identifier ":" kind {
// 299|    { name: $2.name, name_loc: $2.loc, kind: Some($4), loc: span($sloc) }
// 300|  }
fn yy_action_62(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Kind(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeMemberDeclaration({(); 
    { name: _dollar2.name, name_loc: _dollar2.loc, kind: Some(_dollar4), loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 295|    "type" identifier {
// 296|    { name: $2.name, name_loc: $2.loc, kind: None, loc: span($sloc) }
// 297|  }
fn yy_action_63(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeMemberDeclaration({(); 
    { name: _dollar2.name, name_loc: _dollar2.loc, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 324|    identifier ":" type {
// 325|    { name: $1.name, name_loc: $1.loc, type_: $3, loc: span($sloc) }
// 326|  }
fn yy_action_64(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FieldDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 279|    { [] }
fn yy_action_65(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructMember_({();  [] })
}

// file:///./parser.mbty
// 330|    "enum" identifier nominal_body_open layout_semicolons enum_variants "}" {
// 331|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, variants: $5, loc: span($sloc) }
// 332|  }
fn yy_action_66(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, variants: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 348|    non_empty_enum_variants item_semicolon enum_variant { comma_push($1, $3) }
fn yy_action_67(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  guard _args[2].0 is YYObj_EnumVariant(_dollar3)
  YYObj_Array_EnumVariant_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 349|    non_empty_enum_variants item_semicolon { $1 }
fn yy_action_68(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  YYObj_Array_EnumVariant_({();  _dollar1 })
}

// file:///./parser.mbty
// 343|    non_empty_enum_variants { $1 }
fn yy_action_69(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  YYObj_Array_EnumVariant_({();  _dollar1 })
}

// file:///./parser.mbty
// 347|    enum_variant { [ $1 ] }
fn yy_action_70(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumVariant(_dollar1)
  YYObj_Array_EnumVariant_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 353|    identifier layout_continuation_opt "(" type_list ")" {
// 354|    { name: $1.name, name_loc: $1.loc, type_parameters: [], payload: $4, loc: span($sloc) }
// 355|  }
fn yy_action_71(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: [], payload: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 356|    identifier layout_continuation_opt type_parameter_bracket_list layout_continuation_opt "(" type_list ")" {
// 357|    { name: $1.name, name_loc: $1.loc, type_parameters: $3, payload: $6, loc: span($sloc) }
// 358|  }
fn yy_action_72(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_Type_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: _dollar3, payload: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 342|    { [] }
fn yy_action_73(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EnumVariant_({();  [] })
}

// file:///./parser.mbty
// 362|    "effect" identifier nominal_body_open layout_semicolons effect_operations "}" {
// 363|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, operations: $5, loc: span($sloc) }
// 364|  }
fn yy_action_74(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EffectOperationDeclaration_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, operations: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 380|    non_empty_effect_operations item_semicolon effect_operation { comma_push($1, $3) }
fn yy_action_75(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  guard _args[2].0 is YYObj_EffectOperationDeclaration(_dollar3)
  YYObj_Array_EffectOperationDeclaration_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 381|    non_empty_effect_operations item_semicolon { $1 }
fn yy_action_76(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  _dollar1 })
}

// file:///./parser.mbty
// 375|    non_empty_effect_operations { $1 }
fn yy_action_77(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  _dollar1 })
}

// file:///./parser.mbty
// 379|    effect_operation { [ $1 ] }
fn yy_action_78(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationDeclaration(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 385|    identifier layout_continuation_opt "(" type_list ")" "->" type {
// 386|    { name: $1.name, name_loc: $1.loc, type_parameters: [], payload: $4, result: $7, loc: span($sloc) }
// 387|  }
fn yy_action_79(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: [], payload: _dollar4, result: _dollar7, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 388|    identifier layout_continuation_opt type_parameter_bracket_list layout_continuation_opt "(" type_list ")" "->" type {
// 389|    { name: $1.name, name_loc: $1.loc, type_parameters: $3, payload: $6, result: $9, loc: span($sloc) }
// 390|  }
fn yy_action_80(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_Type_(_dollar6)
  guard _args[8].0 is YYObj_Type(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: _dollar3, payload: _dollar6, result: _dollar9, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 374|    { [] }
fn yy_action_81(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EffectOperationDeclaration_({();  [] })
}

// file:///./parser.mbty
// 496|    "{" { [] }
fn yy_action_82(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 497|    LAYOUT_NEWLINE "{" { [] }
fn yy_action_83(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 500|    LAYOUT_NEWLINE type_parameter_bracket_list "{" { $2 }
fn yy_action_84(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 501|    LAYOUT_NEWLINE type_parameter_bracket_list LAYOUT_NEWLINE "{" { $2 }
fn yy_action_85(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 498|    type_parameter_bracket_list "{" { $1 }
fn yy_action_86(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 499|    type_parameter_bracket_list LAYOUT_NEWLINE "{" { $1 }
fn yy_action_87(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 457|    "let" identifier ":" type "=" expression {
// 458|    { is_public: false, is_offered: false, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 459|  }
fn yy_action_88(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: false, is_offered: false, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 394|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt layout_continuation_opt block_expression {
// 395|    {
// 396|      is_public: false,
// 397|      is_offered: $1,
// 398|      type_parameters: $2,
// 399|      name: $3.name,
// 400|      name_loc: $3.loc,
// 401|      parameters: $4,
// 402|      return_type: $6,
// 403|      effect: effect_or_empty($7, $6),
// 404|      body: $9,
// 405|      loc: span($sloc),
// 406|    }
// 407|  }
fn yy_action_89(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_22(_last_pos, _args[0:1])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionDeclaration({(); 
    {
      is_public: false,
      is_offered: _dollar1,
      type_parameters: _dollar2,
      name: _dollar3.name,
      name_loc: _dollar3.loc,
      parameters: _dollar4,
      return_type: _dollar6,
      effect: effect_or_empty(_dollar7, _dollar6),
      body: _dollar9,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 428|    "fn" { false }
fn yy_action_22(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 394|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt layout_continuation_opt block_expression {
// 395|    {
// 396|      is_public: false,
// 397|      is_offered: $1,
// 398|      type_parameters: $2,
// 399|      name: $3.name,
// 400|      name_loc: $3.loc,
// 401|      parameters: $4,
// 402|      return_type: $6,
// 403|      effect: effect_or_empty($7, $6),
// 404|      body: $9,
// 405|      loc: span($sloc),
// 406|    }
// 407|  }
fn yy_action_90(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_24(_last_pos, _args[0:2])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar3)
  guard _args[4].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[9].0 is YYObj_Expr(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionDeclaration({(); 
    {
      is_public: false,
      is_offered: _dollar1,
      type_parameters: _dollar2,
      name: _dollar3.name,
      name_loc: _dollar3.loc,
      parameters: _dollar4,
      return_type: _dollar6,
      effect: effect_or_empty(_dollar7, _dollar6),
      body: _dollar9,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 429|    "offer" "fn" { true }
fn yy_action_24(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 433|    layout_continuation_opt "(" ")" { [] }
fn yy_action_91(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Parameter_({();  [] })
}

// file:///./parser.mbty
// 434|    layout_continuation_opt "(" non_empty_parameter_list ")" { $3 }
fn yy_action_92(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Parameter_(_dollar3)
  YYObj_Array_Parameter_({();  _dollar3 })
}

// file:///./parser.mbty
// 439|    non_empty_parameter_list "," parameter { comma_push($1, $3) }
fn yy_action_93(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Parameter_(_dollar1)
  guard _args[2].0 is YYObj_Parameter(_dollar3)
  YYObj_Array_Parameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 438|    parameter { [ $1 ] }
fn yy_action_94(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Parameter(_dollar1)
  YYObj_Array_Parameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 443|    parameter_modifiers identifier ":" type {
// 444|    { is_auto: $1.is_auto, is_offered: $1.is_offered, name: $2.name, name_loc: $2.loc, type_: $4, loc: span($sloc) }
// 445|  }
fn yy_action_95(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParameterModifiers(_dollar1)
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Parameter({(); 
    { is_auto: _dollar1.is_auto, is_offered: _dollar1.is_offered, name: _dollar2.name, name_loc: _dollar2.loc, type_: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 452|    "auto" "offer" { { is_auto: true, is_offered: true } }
fn yy_action_96(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 450|    "auto" { { is_auto: true, is_offered: false } }
fn yy_action_97(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: false } })
}

// file:///./parser.mbty
// 453|    "offer" "auto" { { is_auto: true, is_offered: true } }
fn yy_action_98(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 451|    "offer" { { is_auto: false, is_offered: true } }
fn yy_action_99(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: true } })
}

// file:///./parser.mbty
// 449|    { { is_auto: false, is_offered: false } }
fn yy_action_100(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: false } })
}

// file:///./parser.mbty
// 491|    type_parameter_bracket_list { $1 }
fn yy_action_101(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 492|    LAYOUT_NEWLINE type_parameter_bracket_list { $2 }
fn yy_action_102(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 490|    { [] }
fn yy_action_103(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 478|    "offer" identifier ":" type "=" expression {
// 479|    { is_public: false, is_offered: true, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 480|  }
fn yy_action_104(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: false, is_offered: true, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 469|    "let" pattern local_type_annotation "=" expression { local_let_item($2, $3, $5, span($sloc)) }
fn yy_action_105(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Pattern(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LocalItem({();  local_let_item(_dollar2, _dollar3, _dollar5, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 877|    "{" layout_semicolons local_items expression "}" {
// 878|    Block(items=$3, result=$4, loc=span($sloc))
// 879|  }
fn yy_action_106(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_LocalItem_(_dollar3)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Block(items=_dollar3, result=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 891|    expression { Expression(expression=$1) }
fn yy_action_107(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_LocalItem({();  Expression(expression=_dollar1) })
}

// file:///./parser.mbty
// 884|    local_items local_item item_semicolon { comma_push($1, $2) }
fn yy_action_108(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_LocalItem_(_dollar1)
  guard _args[1].0 is YYObj_LocalItem(_dollar2)
  YYObj_Array_LocalItem_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 888|    local_let_item { $1 }
fn yy_action_109(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LocalItem(_dollar1)
  YYObj_LocalItem({();  _dollar1 })
}

// file:///./parser.mbty
// 889|    function_declaration { Function($1) }
fn yy_action_110(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_LocalItem({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 890|    offer_value_declaration { Let($1) }
fn yy_action_111(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_LocalItem({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 934|    "handle" expression handler_with_blocks handler_final_branch {
// 935|    Handler(body=$2, handlers=$3, final_branch=$4, loc=span($sloc))
// 936|  }
fn yy_action_112(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[2].0 is YYObj_Array_HandlerWithBlock_(_dollar3)
  guard _args[3].0 is YYObj_HandlerFinalBranch(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Handler(body=_dollar2, handlers=_dollar3, final_branch=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 941|    handler_with_blocks handler_with_block { comma_push($1, $2) }
fn yy_action_113(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerWithBlock_(_dollar1)
  guard _args[1].0 is YYObj_HandlerWithBlock(_dollar2)
  YYObj_Array_HandlerWithBlock_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 1025|    "final" identifier layout_continuation_opt block_expression { { binder: $2.name, binder_loc: $2.loc, body: $4, loc: span($sloc) } }
fn yy_action_114(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerFinalBranch({();  { binder: _dollar2.name, binder_loc: _dollar2.loc, body: _dollar4, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 940|    handler_with_block { [ $1 ] }
fn yy_action_115(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerWithBlock(_dollar1)
  YYObj_Array_HandlerWithBlock_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 945|    "with" "{" layout_semicolons handler_operation_arms "}" {
// 946|    { arms: $4, loc: span($sloc) }
// 947|  }
fn yy_action_116(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Array_HandlerOperationArm_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerWithBlock({(); 
    { arms: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 978|    qualified_type_name handler_operation_owner_arguments "tight ::" identifier { qualified_handler_operation_name($1.to_type(), $2, $4) }
fn yy_action_117(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  guard _args[1].0 is YYObj_GenericArgumentList_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar4)
  YYObj_EffectOperationName({();  qualified_handler_operation_name(_dollar1.to_type(), _dollar2, _dollar4) })
}

// file:///./parser.mbty
// 1007|    handler_operation_generic_arguments { Some($1) }
fn yy_action_118(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgumentList(_dollar1)
  YYObj_GenericArgumentList_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1006|    { None }
fn yy_action_119(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_GenericArgumentList_({();  None })
}

// file:///./parser.mbty
// 956|    non_empty_handler_operation_arms item_semicolon handler_operation_arm { comma_push($1, $3) }
fn yy_action_120(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  guard _args[2].0 is YYObj_HandlerOperationArm(_dollar3)
  YYObj_Array_HandlerOperationArm_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 957|    non_empty_handler_operation_arms item_semicolon { $1 }
fn yy_action_121(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 951|    non_empty_handler_operation_arms { $1 }
fn yy_action_122(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 955|    handler_operation_arm { [ $1 ] }
fn yy_action_123(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerOperationArm(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 961|    handler_operation_signature_open handler_operation_arm_parameters ")" "=>" expression {
// 962|    {
// 963|      name: $1.name,
// 964|      type_binders: $1.type_binders,
// 965|      payload_patterns: $2.payload_patterns,
// 966|      resume_binder: $2.resume_binder,
// 967|      resume_loc: $2.resume_loc,
// 968|      body: $5,
// 969|      loc: span($sloc)
// 970|    }
// 971|  }
fn yy_action_124(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerOperationHead(_dollar1)
  guard _args[1].0 is YYObj_HandlerOperationArmParameters(_dollar2)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerOperationArm({(); 
    {
      name: _dollar1.name,
      type_binders: _dollar1.type_binders,
      payload_patterns: _dollar2.payload_patterns,
      resume_binder: _dollar2.resume_binder,
      resume_loc: _dollar2.resume_loc,
      body: _dollar5,
      loc: span((_symbol_start_pos, _end_pos))
    }
  })
}

// file:///./parser.mbty
// 1015|    identifier { { payload_patterns: [], resume_binder: $1.name, resume_loc: $1.loc } }
fn yy_action_125(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: [], resume_binder: _dollar1.name, resume_loc: _dollar1.loc } })
}

// file:///./parser.mbty
// 1016|    handler_payload_patterns "," identifier { { payload_patterns: $1, resume_binder: $3.name, resume_loc: $3.loc } }
fn yy_action_126(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: _dollar1, resume_binder: _dollar3.name, resume_loc: _dollar3.loc } })
}

// file:///./parser.mbty
// 1021|    handler_payload_patterns "," pattern { comma_push($1, $3) }
fn yy_action_127(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1020|    pattern { [ $1 ] }
fn yy_action_128(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 976|    identifier "tight ::" identifier { qualified_handler_operation_name(Name(name=$1.name, loc=$1.loc), None, $3) }
fn yy_action_129(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_EffectOperationName({();  qualified_handler_operation_name(Name(name=_dollar1.name, loc=_dollar1.loc), None, _dollar3) })
}

// file:///./parser.mbty
// 977|    identifier handler_operation_generic_arguments "tight ::" identifier { qualified_handler_operation_name(Name(name=$1.name, loc=$1.loc), Some($2), $4) }
fn yy_action_130(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[1].0 is YYObj_GenericArgumentList(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar4)
  YYObj_EffectOperationName({();  qualified_handler_operation_name(Name(name=_dollar1.name, loc=_dollar1.loc), Some(_dollar2), _dollar4) })
}

// file:///./parser.mbty
// 1011|    "owner [" non_empty_generic_argument_list "]" { { arguments: $2, loc: span($sloc) } }
fn yy_action_131(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_GenericArgumentList({();  { arguments: _dollar2, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 975|    identifier { Unqualified(operation=$1.name, operation_loc=$1.loc) }
fn yy_action_132(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_EffectOperationName({();  Unqualified(operation=_dollar1.name, operation_loc=_dollar1.loc) })
}

// file:///./parser.mbty
// 982|    handler_operation_name "(" { { name: $1, type_binders: [] } }
fn yy_action_133(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationName(_dollar1)
  YYObj_HandlerOperationHead({();  { name: _dollar1, type_binders: [] } })
}

// file:///./parser.mbty
// 983|    handler_operation_name ident_bracket_list "(" {
// 984|    { name: $1, type_binders: $2 }
// 985|  }
fn yy_action_134(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationName(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_HandlerOperationHead({(); 
    { name: _dollar1, type_binders: _dollar2 }
  })
}

// file:///./parser.mbty
// 986|    handler_operation_name ident_bracket_list LAYOUT_NEWLINE "(" {
// 987|    { name: $1, type_binders: $2 }
// 988|  }
fn yy_action_135(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationName(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_HandlerOperationHead({(); 
    { name: _dollar1, type_binders: _dollar2 }
  })
}

// file:///./parser.mbty
// 989|    handler_operation_name LAYOUT_NEWLINE handler_operation_signature_after_newline {
// 990|    { name: $1, type_binders: $3 }
// 991|  }
fn yy_action_136(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationName(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeBinder_(_dollar3)
  YYObj_HandlerOperationHead({(); 
    { name: _dollar1, type_binders: _dollar3 }
  })
}

// file:///./parser.mbty
// 995|    "(" { [] }
fn yy_action_137(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeBinder_({();  [] })
}

// file:///./parser.mbty
// 996|    ident_bracket_list "(" { $1 }
fn yy_action_138(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  YYObj_Array_TypeBinder_({();  _dollar1 })
}

// file:///./parser.mbty
// 997|    ident_bracket_list LAYOUT_NEWLINE "(" { $1 }
fn yy_action_139(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  YYObj_Array_TypeBinder_({();  _dollar1 })
}

// file:///./parser.mbty
// 1001|    "[" non_empty_ident_list "]" { $2 }
fn yy_action_140(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_Array_TypeBinder_({();  _dollar2 })
}

// file:///./parser.mbty
// 1002|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_141(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeBinder_({();  [] })
}

// file:///./parser.mbty
// 112|    layout_semicolons LAYOUT_NEWLINE { claim_layout_separator($2) }
fn yy_action_142(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_LayoutNewlineClaim(_dollar2)
  YYObj_Unit({();  claim_layout_separator(_dollar2) })
}

// file:///./parser.mbty
// 911|    "match" expression layout_continuation_opt "{" layout_semicolons match_arms "}" {
// 912|    Match(scrutinee=$2, arms=$6, loc=span($sloc))
// 913|  }
fn yy_action_143(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[5].0 is YYObj_Array_MatchArm_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Match(scrutinee=_dollar2, arms=_dollar6, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 116|    ";" { () }
fn yy_action_144(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 117|    LAYOUT_NEWLINE { claim_layout_separator($1) }
fn yy_action_145(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LayoutNewlineClaim(_dollar1)
  YYObj_Unit({();  claim_layout_separator(_dollar1) })
}

// file:///./parser.mbty
// 923|    non_empty_match_arms item_semicolon match_arm { comma_push($1, $3) }
fn yy_action_146(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  guard _args[2].0 is YYObj_MatchArm(_dollar3)
  YYObj_Array_MatchArm_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 924|    non_empty_match_arms item_semicolon { $1 }
fn yy_action_147(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  YYObj_Array_MatchArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 918|    non_empty_match_arms { $1 }
fn yy_action_148(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  YYObj_Array_MatchArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 922|    match_arm { [ $1 ] }
fn yy_action_149(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_MatchArm(_dollar1)
  YYObj_Array_MatchArm_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 928|    pattern "=>" expression {
// 929|    { pattern: $1, body: $3, loc: span($sloc) }
// 930|  }
fn yy_action_150(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_MatchArm({(); 
    { pattern: _dollar1, body: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 1095|    nominal_type_name "tight ::" IDENT variant_pattern_arguments { QualifiedVariant(owner=$1, variant=$3, variant_loc=$1.loc().ascii_after(2, $3.length()), type_binders=$4.type_binders, arguments=$4.arguments, loc=span(($startpos, $endpos))) }
fn yy_action_151(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_VariantPatternArguments(_dollar4)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  QualifiedVariant(owner=_dollar1, variant=_dollar3, variant_loc=_dollar1.loc().ascii_after(2, _dollar3.length()), type_binders=_dollar4.type_binders, arguments=_dollar4.arguments, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1105|    nominal_type_name "tight ::" "{" struct_pattern_fields "}" {
// 1106|    Struct(owner=$1, fields=$4, loc=span($sloc))
// 1107|  }
fn yy_action_152(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[3].0 is YYObj_Array_StructPatternField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({(); 
    Struct(owner=_dollar1, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1155|    non_empty_struct_pattern_fields layout_list_separator struct_pattern_field { comma_push($1, $3) }
fn yy_action_153(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  guard _args[2].0 is YYObj_StructPatternField(_dollar3)
  YYObj_Array_StructPatternField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1156|    non_empty_struct_pattern_fields layout_list_separator { $1 }
fn yy_action_154(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 1150|    non_empty_struct_pattern_fields { $1 }
fn yy_action_155(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 1154|    struct_pattern_field { [ $1 ] }
fn yy_action_156(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructPatternField(_dollar1)
  YYObj_Array_StructPatternField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 1089|    "(" pattern "," tuple_pattern_tail ")" {
// 1090|    Tuple(items=[$2] + $4, loc=span($sloc))
// 1091|  }
fn yy_action_157(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Pattern(_dollar2)
  guard _args[3].0 is YYObj_Array_Pattern_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({(); 
    Tuple(items=[_dollar2] + _dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1093|    IDENT variant_pattern_arguments { UnqualifiedVariant(variant=$1, variant_loc=span(($startpos, $endpos)).ascii_prefix($1.length()), type_binders=$2.type_binders, arguments=$2.arguments, loc=span(($startpos, $endpos))) }
fn yy_action_158(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_VariantPatternArguments(_dollar2)
  YYObj_Pattern({();  UnqualifiedVariant(variant=_dollar1, variant_loc=span((_start_pos, _end_pos)).ascii_prefix(_dollar1.length()), type_binders=_dollar2.type_binders, arguments=_dollar2.arguments, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1111|    "(" pattern_list ")" { { type_binders: [], arguments: $2 } }
fn yy_action_159(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Pattern_(_dollar2)
  YYObj_VariantPatternArguments({();  { type_binders: [], arguments: _dollar2 } })
}

// file:///./parser.mbty
// 1112|    "[" non_empty_ident_list "]" "(" pattern_list ")" {
// 1113|    { type_binders: $2, arguments: $5 }
// 1114|  }
fn yy_action_160(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  guard _args[4].0 is YYObj_Array_Pattern_(_dollar5)
  YYObj_VariantPatternArguments({(); 
    { type_binders: _dollar2, arguments: _dollar5 }
  })
}

// file:///./parser.mbty
// 1115|    "[" non_empty_ident_list "]" LAYOUT_NEWLINE "(" pattern_list ")" {
// 1116|    { type_binders: $2, arguments: $6 }
// 1117|  }
fn yy_action_161(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  guard _args[5].0 is YYObj_Array_Pattern_(_dollar6)
  YYObj_VariantPatternArguments({(); 
    { type_binders: _dollar2, arguments: _dollar6 }
  })
}

// file:///./parser.mbty
// 1118|    LAYOUT_NEWLINE variant_pattern_arguments_after_newline { $2 }
fn yy_action_162(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_VariantPatternArguments(_dollar2)
  YYObj_VariantPatternArguments({();  _dollar2 })
}

// file:///./parser.mbty
// 1122|    "(" pattern_list ")" { { type_binders: [], arguments: $2 } }
fn yy_action_163(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Pattern_(_dollar2)
  YYObj_VariantPatternArguments({();  { type_binders: [], arguments: _dollar2 } })
}

// file:///./parser.mbty
// 1123|    "[" non_empty_ident_list "]" "(" pattern_list ")" {
// 1124|    { type_binders: $2, arguments: $5 }
// 1125|  }
fn yy_action_164(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  guard _args[4].0 is YYObj_Array_Pattern_(_dollar5)
  YYObj_VariantPatternArguments({(); 
    { type_binders: _dollar2, arguments: _dollar5 }
  })
}

// file:///./parser.mbty
// 1126|    "[" non_empty_ident_list "]" LAYOUT_NEWLINE "(" pattern_list ")" {
// 1127|    { type_binders: $2, arguments: $6 }
// 1128|  }
fn yy_action_165(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  guard _args[5].0 is YYObj_Array_Pattern_(_dollar6)
  YYObj_VariantPatternArguments({(); 
    { type_binders: _dollar2, arguments: _dollar6 }
  })
}

// file:///./parser.mbty
// 1144|    non_empty_pattern_list "," pattern { comma_push($1, $3) }
fn yy_action_166(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1145|    non_empty_pattern_list "," { $1 }
fn yy_action_167(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 1139|    non_empty_pattern_list { $1 }
fn yy_action_168(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 1143|    pattern { [ $1 ] }
fn yy_action_169(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 1138|    { [] }
fn yy_action_170(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Pattern_({();  [] })
}

// file:///./parser.mbty
// 1133|    non_empty_ident_list "," identifier { comma_push($1, { name: $3.name, loc: $3.loc }) }
fn yy_action_171(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_Array_TypeBinder_({();  comma_push(_dollar1, { name: _dollar3.name, loc: _dollar3.loc }) })
}

// file:///./parser.mbty
// 1134|    non_empty_ident_list "," { $1 }
fn yy_action_172(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  YYObj_Array_TypeBinder_({();  _dollar1 })
}

// file:///./parser.mbty
// 1132|    identifier { [ { name: $1.name, loc: $1.loc } ] }
fn yy_action_173(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_Array_TypeBinder_({();  [ { name: _dollar1.name, loc: _dollar1.loc } ] })
}

// file:///./parser.mbty
// 819|    IDENT { Name(name=$1, loc=span($sloc)) }
fn yy_action_174(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({();  Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1092|    IDENT %prec PATTERN_BINDING { Binding($1, loc=span($sloc)) }
fn yy_action_175(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Binding(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 820|    qualified_type_name { $1.to_type() }
fn yy_action_176(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  YYObj_Type({();  _dollar1.to_type() })
}

// file:///./parser.mbty
// 1079|    PATTERN_IDENTIFIER_SLOT { abort("pattern completion slot token must not be shifted") }
fn yy_action_177(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Pattern({();  abort("pattern completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 1080|    "_" { Wildcard(span($sloc)) }
fn yy_action_178(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Wildcard(span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1081|    INT { integer_pattern_literal($1, span($sloc), negative=false) }
fn yy_action_179(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NumericLiteralToken(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  integer_pattern_literal(_dollar1, span((_symbol_start_pos, _end_pos)), negative=false) })
}

// file:///./parser.mbty
// 1082|    "-" INT { integer_pattern_literal($2, span($sloc), negative=true) }
fn yy_action_180(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_NumericLiteralToken(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  integer_pattern_literal(_dollar2, span((_symbol_start_pos, _end_pos)), negative=true) })
}

// file:///./parser.mbty
// 1084|    "-" DOUBLE { floating_pattern_literal($2, span($sloc), negative=true) }
fn yy_action_181(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_NumericLiteralToken(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  floating_pattern_literal(_dollar2, span((_symbol_start_pos, _end_pos)), negative=true) })
}

// file:///./parser.mbty
// 1083|    DOUBLE { floating_pattern_literal($1, span($sloc), negative=false) }
fn yy_action_182(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NumericLiteralToken(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  floating_pattern_literal(_dollar1, span((_symbol_start_pos, _end_pos)), negative=false) })
}

// file:///./parser.mbty
// 1085|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_183(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1086|    CHAR { CharLiteral($1, loc=span($sloc)) }
fn yy_action_184(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  CharLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1087|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_185(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1088|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_186(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 1101|    tuple_pattern_tail "," pattern { comma_push($1, $3) }
fn yy_action_187(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1099|    MISSING_TUPLE_PATTERN_ITEM_ERROR { abort("missing tuple pattern item token must not be shifted") }
fn yy_action_188(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Pattern_({();  abort("missing tuple pattern item token must not be shifted") })
}

// file:///./parser.mbty
// 1100|    pattern { [ $1 ] }
fn yy_action_189(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 1094|    struct_pattern { $1 }
fn yy_action_190(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Pattern({();  _dollar1 })
}

// file:///./parser.mbty
// 1166|    IDENT ":" pattern {
// 1167|    Value(name=$1, pattern=Some($3), loc=span($sloc))
// 1168|  }
fn yy_action_191(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1160|    IDENT {
// 1161|    Value(name=$1, pattern=None, loc=span($sloc))
// 1162|  }
fn yy_action_192(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=None, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1163|    "_" {
// 1164|    TypeWildcard(loc=span($sloc))
// 1165|  }
fn yy_action_193(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    TypeWildcard(loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1149|    { [] }
fn yy_action_194(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructPatternField_({();  [] })
}

// file:///./parser.mbty
// 917|    { [] }
fn yy_action_195(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_MatchArm_({();  [] })
}

// file:///./parser.mbty
// 895|    "if" expression layout_continuation_opt block_expression optional_else_branch {
// 896|    If(condition=$2, then_branch=$4, else_branch=$5, loc=span($sloc))
// 897|  }
fn yy_action_196(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  guard _args[4].0 is YYObj_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    If(condition=_dollar2, then_branch=_dollar4, else_branch=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 902|    "else" else_branch_expression { Some($2) }
fn yy_action_197(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  YYObj_Expr_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 906|    block_expression { $1 }
fn yy_action_198(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 907|    if_expression { $1 }
fn yy_action_199(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 901|    { None }
fn yy_action_200(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Expr_({();  None })
}

// file:///./parser.mbty
// 775|    "derive" "[" derive_type_arguments "]" "(" argument_list ")" {
// 776|    Derive(
// 777|      capability=$3.capability,
// 778|      target=$3.target,
// 779|      arguments=$6,
// 780|      source=derive_source_site(span($sloc)),
// 781|    )
// 782|  }
fn yy_action_201(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_DeriveTypeArguments(_dollar3)
  guard _args[5].0 is YYObj_Array_CallArgument_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Derive(
      capability=_dollar3.capability,
      target=_dollar3.target,
      arguments=_dollar6,
      source=derive_source_site(span((_symbol_start_pos, _end_pos))),
    )
  })
}

// file:///./parser.mbty
// 757|    "[" list_literal_items "]" { ListLiteral(items=$2, loc=span($sloc)) }
fn yy_action_202(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  ListLiteral(items=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 872|    non_empty_positional_argument_list "," expression { comma_push($1, $3) }
fn yy_action_203(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 770|    expression { [ $1 ] }
fn yy_action_204(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 748|    "(" expression "," tuple_expression_tail ")" {
// 749|    TupleLiteral(items=[$2] + $4, loc=span($sloc))
// 750|  }
fn yy_action_205(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_Array_Expr_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    TupleLiteral(items=[_dollar2] + _dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 771|    tuple_expression_tail "," expression { comma_push($1, $3) }
fn yy_action_206(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 769|    MISSING_TUPLE_EXPRESSION_ITEM_ERROR { abort("missing tuple expression item token must not be shifted") }
fn yy_action_207(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  abort("missing tuple expression item token must not be shifted") })
}

// file:///./parser.mbty
// 751|    "(" expression ")" { Grouped(expression=$2, loc=span($sloc)) }
fn yy_action_208(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Grouped(expression=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 688|    identifier "!" "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1.name, operation_loc=$1.loc), type_witnesses=[], arguments=$4, loc=span($sloc)) }
fn yy_action_209(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[3].0 is YYObj_Array_Expr_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1.name, operation_loc=_dollar1.loc), type_witnesses=[], arguments=_dollar4, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 720|    owner_expression "tight ::" IDENT variant_type_arguments variant_arguments %prec VARIANT_EXPR {
// 721|    QualifiedVariant(owner=$1.owner, variant=$3, variant_loc=$1.owner.loc().ascii_after(2, $3.length()), variant_type_arguments=$4, arguments=$5, loc=span($sloc))
// 722|  }
fn yy_action_210(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_GenericArgument_(_dollar4)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    QualifiedVariant(owner=_dollar1.owner, variant=_dollar3, variant_loc=_dollar1.owner.loc().ascii_after(2, _dollar3.length()), variant_type_arguments=_dollar4, arguments=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 846|    layout_continuation_opt "(" positional_argument_list ")" { $3 }
fn yy_action_211(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Expr_(_dollar3)
  YYObj_Array_Expr_({();  _dollar3 })
}

// file:///./parser.mbty
// 825|    type_arguments { $1 }
fn yy_action_212(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 824|    %prec VARIANT_EXPR { [] }
fn yy_action_213(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 693|    owner_expression "tight ::" identifier "!" "(" positional_argument_list ")" %prec "tight ::" {
// 694|    EffectOperationCall(
// 695|      name=Qualified(
// 696|        owner=$1.owner,
// 697|        operation=$3.name,
// 698|        operation_loc=$3.loc
// 699|      ),
// 700|      type_witnesses=[],
// 701|      arguments=$6,
// 702|      loc=span($sloc)
// 703|    )
// 704|  }
fn yy_action_214(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[5].0 is YYObj_Array_Expr_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    EffectOperationCall(
      name=Qualified(
        owner=_dollar1.owner,
        operation=_dollar3.name,
        operation_loc=_dollar3.loc
      ),
      type_witnesses=[],
      arguments=_dollar6,
      loc=span((_symbol_start_pos, _end_pos))
    )
  })
}

// file:///./parser.mbty
// 871|    expression { [ $1 ] }
fn yy_action_215(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 705|    owner_expression "tight ::" identifier "!" operation_type_witnesses "(" positional_argument_list ")" %prec "tight ::" {
// 706|    EffectOperationCall(
// 707|      name=Qualified(
// 708|        owner=$1.owner,
// 709|        operation=$3.name,
// 710|        operation_loc=$3.loc
// 711|      ),
// 712|      type_witnesses=$5,
// 713|      arguments=$7,
// 714|      loc=span($sloc)
// 715|    )
// 716|  }
fn yy_action_216(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  guard _args[6].0 is YYObj_Array_Expr_(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    EffectOperationCall(
      name=Qualified(
        owner=_dollar1.owner,
        operation=_dollar3.name,
        operation_loc=_dollar3.loc
      ),
      type_witnesses=_dollar5,
      arguments=_dollar7,
      loc=span((_symbol_start_pos, _end_pos))
    )
  })
}

// file:///./parser.mbty
// 717|    owner_expression "tight ::" "{" struct_literal_fields "}" %prec "tight ::" {
// 718|    StructLiteral(owner=$1.owner, fields=$4, loc=span($sloc))
// 719|  }
fn yy_action_217(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[3].0 is YYObj_Array_StructLiteralField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    StructLiteral(owner=_dollar1.owner, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 835|    non_empty_struct_literal_fields layout_list_separator struct_literal_field { comma_push($1, $3) }
fn yy_action_218(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  guard _args[2].0 is YYObj_StructLiteralField(_dollar3)
  YYObj_Array_StructLiteralField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 836|    non_empty_struct_literal_fields layout_list_separator { $1 }
fn yy_action_219(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 830|    non_empty_struct_literal_fields { $1 }
fn yy_action_220(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 834|    struct_literal_field { [ $1 ] }
fn yy_action_221(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructLiteralField(_dollar1)
  YYObj_Array_StructLiteralField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 841|    IDENT ":" expression { Value(name=$1, value=Some($3), loc=span($sloc)) }
fn yy_action_222(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 867|    IDENT "=" expression { Named(name=$1, value=$3, loc=span($sloc)) }
fn yy_action_223(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Named(name=_dollar1, value=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 621|    VALUE_IDENTIFIER_SLOT { abort("value completion slot token must not be shifted") }
fn yy_action_224(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Expr({();  abort("value completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 622|    expression "|>" expression {
// 623|    Pipeline(left=$1, right=$3, loc=span($sloc))
// 624|  }
fn yy_action_225(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Pipeline(left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 625|    expression "||" expression {
// 626|    Binary(operator=Or, left=$1, right=$3, loc=span($sloc))
// 627|  }
fn yy_action_226(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Or, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 628|    expression "&&" expression {
// 629|    Binary(operator=And, left=$1, right=$3, loc=span($sloc))
// 630|  }
fn yy_action_227(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=And, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 631|    expression "==" expression {
// 632|    Binary(operator=Equal, left=$1, right=$3, loc=span($sloc))
// 633|  }
fn yy_action_228(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Equal, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 634|    expression "!=" expression {
// 635|    Binary(operator=NotEqual, left=$1, right=$3, loc=span($sloc))
// 636|  }
fn yy_action_229(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=NotEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 637|    expression "<" expression {
// 638|    Binary(operator=Less, left=$1, right=$3, loc=span($sloc))
// 639|  }
fn yy_action_230(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Less, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 640|    expression "<=" expression {
// 641|    Binary(operator=LessEqual, left=$1, right=$3, loc=span($sloc))
// 642|  }
fn yy_action_231(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=LessEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 643|    expression ">" expression {
// 644|    Binary(operator=Greater, left=$1, right=$3, loc=span($sloc))
// 645|  }
fn yy_action_232(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Greater, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 646|    expression ">=" expression {
// 647|    Binary(operator=GreaterEqual, left=$1, right=$3, loc=span($sloc))
// 648|  }
fn yy_action_233(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=GreaterEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 649|    expression "+" expression {
// 650|    Binary(operator=Add, left=$1, right=$3, loc=span($sloc))
// 651|  }
fn yy_action_234(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Add, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 652|    expression "-" expression {
// 653|    Binary(operator=Sub, left=$1, right=$3, loc=span($sloc))
// 654|  }
fn yy_action_235(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Sub, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 655|    expression "*" expression {
// 656|    Binary(operator=Mul, left=$1, right=$3, loc=span($sloc))
// 657|  }
fn yy_action_236(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Mul, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 658|    expression "/" expression {
// 659|    Binary(operator=Div, left=$1, right=$3, loc=span($sloc))
// 660|  }
fn yy_action_237(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Div, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 661|    expression "%" expression {
// 662|    Binary(operator=Rem, left=$1, right=$3, loc=span($sloc))
// 663|  }
fn yy_action_238(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Rem, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 866|    expression { Positional(value=$1, loc=span($sloc)) }
fn yy_action_239(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Positional(value=_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 664|    unary_expression { $1 }
fn yy_action_240(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 726|    IDENT { { expr: Var($1, loc=span($sloc)), owner: { module_path: None, name: $1, loc: span($sloc) } } }
fn yy_action_241(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerPathExpression({();  { expr: Var(_dollar1, loc=span((_symbol_start_pos, _end_pos))), owner: { module_path: None, name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } } })
}

// file:///./parser.mbty
// 668|    "-" unary_expression %prec UNARY {
// 669|    negated_expression($2, span($sloc))
// 670|  }
fn yy_action_242(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    negated_expression(_dollar2, span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 671|    "!" unary_expression %prec UNARY {
// 672|    Unary(operator=Not, operand=$2, loc=span($sloc))
// 673|  }
fn yy_action_243(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Unary(operator=Not, operand=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 674|    postfix_expression { $1 }
fn yy_action_244(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 685|    value_postfix_expression "(" argument_list ")" { Call(callee=$1, arguments=$3, loc=span($sloc)) }
fn yy_action_245(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_CallArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Call(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 686|    value_postfix_expression type_arguments %prec "[" { TypeApplication(callee=$1, arguments=$2, loc=span($sloc)) }
fn yy_action_246(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  TypeApplication(callee=_dollar1, arguments=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 687|    value_postfix_expression "." IDENT { Field(base=$1, name=$3, name_loc=span($sloc).ascii_suffix($3.length()), loc=span($sloc)) }
fn yy_action_247(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Field(base=_dollar1, name=_dollar3, name_loc=span((_symbol_start_pos, _end_pos)).ascii_suffix(_dollar3.length()), loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 678|    value_postfix_expression { $1 }
fn yy_action_248(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 682|    member_expression { $1 }
fn yy_action_249(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 842|    IDENT "=" generic_argument { TypeWitness(name=$1, witness=$3, loc=span($sloc)) }
fn yy_action_250(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_GenericArgument(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  TypeWitness(name=_dollar1, witness=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 840|    IDENT { Value(name=$1, value=None, loc=span($sloc)) }
fn yy_action_251(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=None, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 829|    { [] }
fn yy_action_252(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructLiteralField_({();  [] })
}

// file:///./parser.mbty
// 683|    owner_expression { $1.expr }
fn yy_action_253(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  YYObj_Expr({();  _dollar1.expr })
}

// file:///./parser.mbty
// 684|    non_owner_primary_expression { $1 }
fn yy_action_254(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 689|    identifier "!" operation_type_witnesses "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1.name, operation_loc=$1.loc), type_witnesses=$3, arguments=$5, loc=span($sloc)) }
fn yy_action_255(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1.name, operation_loc=_dollar1.loc), type_witnesses=_dollar3, arguments=_dollar5, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 851|    non_empty_positional_argument_list { $1 }
fn yy_action_256(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 850|    { [] }
fn yy_action_257(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 795|    type_arguments { $1 }
fn yy_action_258(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 799|    type_argument_bracket_list { $1 }
fn yy_action_259(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 803|    "[" non_empty_generic_argument_list "]" { $2 }
fn yy_action_260(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj_Array_GenericArgument_({();  _dollar2 })
}

// file:///./parser.mbty
// 804|    "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" { [] }
fn yy_action_261(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 727|    owner_path_expression "." IDENT { owner_path_field($1, $3, span($sloc).ascii_suffix($3.length()), span($sloc)) }
fn yy_action_262(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerPathExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerPathExpression({();  owner_path_field(_dollar1, _dollar3, span((_symbol_start_pos, _end_pos)).ascii_suffix(_dollar3.length()), span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 732|    owner_path_expression owner_type_arguments %prec "owner [" { owner_expression_with_arguments($1, $2, span($sloc)) }
fn yy_action_263(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerPathExpression(_dollar1)
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  owner_expression_with_arguments(_dollar1, _dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 736|    "owner [" non_empty_generic_argument_list "]" { $2 }
fn yy_action_264(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj_Array_GenericArgument_({();  _dollar2 })
}

// file:///./parser.mbty
// 737|    "owner [" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" { [] }
fn yy_action_265(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 731|    owner_path_expression { { expr: $1.expr, owner: $1.owner.to_type() } }
fn yy_action_266(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerPathExpression(_dollar1)
  YYObj_OwnerExpression({();  { expr: _dollar1.expr, owner: _dollar1.owner.to_type() } })
}

// file:///./parser.mbty
// 741|    INT { integer_expression_literal($1, span($sloc)) }
fn yy_action_267(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NumericLiteralToken(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  integer_expression_literal(_dollar1, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 742|    DOUBLE { floating_expression_literal($1, span($sloc)) }
fn yy_action_268(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NumericLiteralToken(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  floating_expression_literal(_dollar1, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 743|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_269(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 744|    CHAR { CharLiteral($1, loc=span($sloc)) }
fn yy_action_270(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  CharLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 745|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_271(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 746|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_272(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 747|    "(" ")" { UnitLiteral(loc=span($sloc)) }
fn yy_action_273(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  UnitLiteral(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 752|    block_expression { $1 }
fn yy_action_274(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 753|    if_expression { $1 }
fn yy_action_275(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 754|    match_expression { $1 }
fn yy_action_276(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 755|    handler_expression { $1 }
fn yy_action_277(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 756|    function_literal { $1 }
fn yy_action_278(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 873|    non_empty_positional_argument_list "," { $1 }
fn yy_action_279(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 765|    non_empty_positional_argument_list { $1 }
fn yy_action_280(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 764|    { [] }
fn yy_action_281(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 758|    derive_expression { $1 }
fn yy_action_282(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 759|    builtin_expression { $1 }
fn yy_action_283(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 760|    extern_expression { $1 }
fn yy_action_284(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 861|    non_empty_argument_list "," call_argument { comma_push($1, $3) }
fn yy_action_285(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  guard _args[2].0 is YYObj_CallArgument(_dollar3)
  YYObj_Array_CallArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 862|    non_empty_argument_list "," { $1 }
fn yy_action_286(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 856|    non_empty_argument_list { $1 }
fn yy_action_287(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 860|    call_argument { [ $1 ] }
fn yy_action_288(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_CallArgument(_dollar1)
  YYObj_Array_CallArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 855|    { [] }
fn yy_action_289(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_CallArgument_({();  [] })
}

// file:///./parser.mbty
// 789|    type layout_list_separator type layout_list_separator {
// 790|    { capability: $1, target: $3 }
// 791|  }
fn yy_action_290(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_DeriveTypeArguments({(); 
    { capability: _dollar1, target: _dollar3 }
  })
}

// file:///./parser.mbty
// 786|    type layout_list_separator type {
// 787|    { capability: $1, target: $3 }
// 788|  }
fn yy_action_291(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_DeriveTypeArguments({(); 
    { capability: _dollar1, target: _dollar3 }
  })
}

// file:///./parser.mbty
// 883|    { [] }
fn yy_action_292(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_LocalItem_({();  [] })
}

// file:///./parser.mbty
// 1029|    function_literal_open function_literal_parameters ")" return_annotation layout_continuation_opt block_expression {
// 1030|    FunctionLiteral(type_parameters=$1, parameters=$2, return_type=$4.return_type, effect=$4.effect, body=$6, loc=span($sloc))
// 1031|  }
fn yy_action_293(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[1].0 is YYObj_Array_FunctionLiteralParameter_(_dollar2)
  guard _args[3].0 is YYObj_ReturnAnnotation(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    FunctionLiteral(type_parameters=_dollar1, parameters=_dollar2, return_type=_dollar4.return_type, effect=_dollar4.effect, body=_dollar6, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1063|    "->" type effect_annotation_opt {
// 1064|    { return_type: Some($2), effect: $3 }
// 1065|  }
fn yy_action_294(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[2].0 is YYObj_EffectTerm_(_dollar3)
  YYObj_ReturnAnnotation({(); 
    { return_type: Some(_dollar2), effect: _dollar3 }
  })
}

// file:///./parser.mbty
// 1062|    { { return_type: None, effect: None } }
fn yy_action_295(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ReturnAnnotation({();  { return_type: None, effect: None } })
}

// file:///./parser.mbty
// 1047|    non_empty_function_literal_parameters "," function_literal_parameter { comma_push($1, $3) }
fn yy_action_296(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  guard _args[2].0 is YYObj_FunctionLiteralParameter(_dollar3)
  YYObj_Array_FunctionLiteralParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1042|    non_empty_function_literal_parameters { $1 }
fn yy_action_297(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 1046|    function_literal_parameter { [ $1 ] }
fn yy_action_298(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionLiteralParameter(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 474|    ":" type { Some($2) }
fn yy_action_299(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 1051|    function_literal_parameter_modifiers identifier local_type_annotation {
// 1052|    { is_offered: $1, name: $2.name, name_loc: $2.loc, type_annotation: $3, loc: span($sloc) }
// 1053|  }
fn yy_action_300(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionLiteralParameter({(); 
    { is_offered: _dollar1, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 473|    { None }
fn yy_action_301(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Type_({();  None })
}

// file:///./parser.mbty
// 1058|    "offer" { true }
fn yy_action_302(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 1041|    { [] }
fn yy_action_303(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_FunctionLiteralParameter_({();  [] })
}

// file:///./parser.mbty
// 1057|    { false }
fn yy_action_304(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 1035|    "fn" "(" { [] }
fn yy_action_305(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 1036|    "fn" type_parameter_bracket_list "(" { $2 }
fn yy_action_306(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 1037|    "fn" type_parameter_bracket_list LAYOUT_NEWLINE "(" { $2 }
fn yy_action_307(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 1069|    "builtin" "(" STRING ")" {
// 1070|    Builtin($3, loc=span($sloc))
// 1071|  }
fn yy_action_308(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Builtin(_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1075|    "extern" "(" STRING ")" { Extern($3, loc=span($sloc)) }
fn yy_action_309(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Extern(_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 127|    LAYOUT_NEWLINE { () }
fn yy_action_310(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 589|    type_parameter_bracket_list layout_continuation_opt "(" type_list ")" "->" type effect_annotation_opt {
// 590|    Function(type_parameters=$1, parameters=$4, result=$7, effect=effect_or_empty($8, $7), loc=span($sloc))
// 591|  }
fn yy_action_311(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar7)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=_dollar1, parameters=_dollar4, result=_dollar7, effect=effect_or_empty(_dollar8, _dollar7), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 586|    "(" type "," tuple_type_tail ")" "->" type effect_annotation_opt {
// 587|    Function(type_parameters=[], parameters=[$2] + $4, result=$7, effect=effect_or_empty($8, $7), loc=span($sloc))
// 588|  }
fn yy_action_312(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar7)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[_dollar2] + _dollar4, result=_dollar7, effect=effect_or_empty(_dollar8, _dollar7), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 583|    "(" type ")" "->" type effect_annotation_opt {
// 584|    Function(type_parameters=[], parameters=[$2], result=$5, effect=effect_or_empty($6, $5), loc=span($sloc))
// 585|  }
fn yy_action_313(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[4].0 is YYObj_Type(_dollar5)
  guard _args[5].0 is YYObj_EffectTerm_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[_dollar2], result=_dollar5, effect=effect_or_empty(_dollar6, _dollar5), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 580|    "(" ")" "->" type effect_annotation_opt {
// 581|    Function(type_parameters=[], parameters=[], result=$4, effect=effect_or_empty($5, $4), loc=span($sloc))
// 582|  }
fn yy_action_314(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[4].0 is YYObj_EffectTerm_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[], result=_dollar4, effect=effect_or_empty(_dollar5, _dollar4), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 596|    effect_annotation { Some($1) }
fn yy_action_315(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectTerm(_dollar1)
  YYObj_EffectTerm_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 605|    type_application { Term(type_=$1, loc=$1.loc()) }
fn yy_action_316(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_EffectTerm({();  Term(type_=_dollar1, loc=_dollar1.loc()) })
}

// file:///./parser.mbty
// 552|    "(" type "," tuple_type_tail ")" {
// 553|    Tuple(items=[$2] + $4, loc=span($sloc))
// 554|  }
fn yy_action_317(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Tuple(items=[_dollar2] + _dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 561|    tuple_type_tail "," type { comma_push($1, $3) }
fn yy_action_318(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 559|    MISSING_TUPLE_TYPE_ITEM_ERROR { abort("missing tuple type item token must not be shifted") }
fn yy_action_319(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  abort("missing tuple type item token must not be shifted") })
}

// file:///./parser.mbty
// 560|    type { [ $1 ] }
fn yy_action_320(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 555|    "(" type ")" %prec PAREN_TYPE { Grouped(type_=$2, loc=span($sloc)) }
fn yy_action_321(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({();  Grouped(type_=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 600|    "!" effect_set { $2 }
fn yy_action_322(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_EffectTerm(_dollar2)
  YYObj_EffectTerm({();  _dollar2 })
}

// file:///./parser.mbty
// 604|    EFFECT_IDENTIFIER_SLOT { abort("effect completion slot token must not be shifted") }
fn yy_action_323(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_EffectTerm({();  abort("effect completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 121|    "," { () }
fn yy_action_324(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 122|    LAYOUT_NEWLINE { claim_layout_separator($1) }
fn yy_action_325(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LayoutNewlineClaim(_dollar1)
  YYObj_Unit({();  claim_layout_separator(_dollar1) })
}

// file:///./parser.mbty
// 539|    type_application "[" non_empty_generic_argument_list "]" {
// 540|    Apply(callee=$1, arguments=$3, loc=span($sloc))
// 541|  }
fn yy_action_326(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 814|    non_empty_generic_argument_list layout_list_separator generic_argument { comma_push($1, $3) }
fn yy_action_327(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  guard _args[2].0 is YYObj_GenericArgument(_dollar3)
  YYObj_Array_GenericArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 815|    non_empty_generic_argument_list layout_list_separator { $1 }
fn yy_action_328(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 542|    type_application "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" {
// 543|    Apply(callee=$1, arguments=[], loc=span($sloc))
// 544|  }
fn yy_action_329(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=[], loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 808|    type { TypeTerm($1) }
fn yy_action_330(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_GenericArgument({();  TypeTerm(_dollar1) })
}

// file:///./parser.mbty
// 505|    "[" non_empty_type_parameter_list "]" { $2 }
fn yy_action_331(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 199|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_332(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Identifier({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 511|    non_empty_type_parameter_list "," type_parameter { comma_push($1, $3) }
fn yy_action_333(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameter(_dollar3)
  YYObj_Array_TypeParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 512|    non_empty_type_parameter_list "," { $1 }
fn yy_action_334(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 506|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_335(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 510|    type_parameter { [ $1 ] }
fn yy_action_336(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameter(_dollar1)
  YYObj_Array_TypeParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 306|    "[" kind_list "]" "->" kind {
// 307|    Function(parameters=$2, result=$5, loc=span($sloc))
// 308|  }
fn yy_action_337(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({(); 
    Function(parameters=_dollar2, result=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 304|    "Type" { Type(loc=span($sloc)) }
fn yy_action_338(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Type(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 305|    "Effect" { Effect(loc=span($sloc)) }
fn yy_action_339(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Effect(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 319|    non_empty_kind_list "," kind { comma_push($1, $3) }
fn yy_action_340(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 320|    non_empty_kind_list "," { $1 }
fn yy_action_341(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 314|    non_empty_kind_list { $1 }
fn yy_action_342(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 318|    kind { [ $1 ] }
fn yy_action_343(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 313|    { [] }
fn yy_action_344(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Kind_({();  [] })
}

// file:///./parser.mbty
// 309|    "(" kind ")" { Grouped(kind=$2, loc=span($sloc)) }
fn yy_action_345(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Grouped(kind=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 519|    identifier ":" kind {
// 520|    { name: $1.name, name_loc: $1.loc, kind: Some($3), loc: span($sloc) }
// 521|  }
fn yy_action_346(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, kind: Some(_dollar3), loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 516|    identifier {
// 517|    { name: $1.name, name_loc: $1.loc, kind: None, loc: span($sloc) }
// 518|  }
fn yy_action_347(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 525|    TYPE_IDENTIFIER_SLOT { abort("type completion slot token must not be shifted") }
fn yy_action_348(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Type({();  abort("type completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 526|    type_lambda { $1 }
fn yy_action_349(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 527|    function_type { $1 }
fn yy_action_350(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 809|    "{" type_list "}" { EffectTerm(effect_set($2, span($sloc))) }
fn yy_action_351(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_GenericArgument({();  EffectTerm(effect_set(_dollar2, span((_symbol_start_pos, _end_pos)))) })
}

// file:///./parser.mbty
// 813|    generic_argument { [ $1 ] }
fn yy_action_352(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgument(_dollar1)
  YYObj_Array_GenericArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 528|    type_application %prec PAREN_TYPE { $1 }
fn yy_action_353(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 532|    "type" type_parameter_bracket_list "=>" type {
// 533|    TypeLambda(parameters=$2, body=$4, loc=span($sloc))
// 534|  }
fn yy_action_354(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    TypeLambda(parameters=_dollar2, body=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 538|    type_primary { $1 }
fn yy_action_355(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 576|    qualified_type_name "." IDENT { $1.extended($3, span($sloc)) }
fn yy_action_356(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_NominalTypeName({();  _dollar1.extended(_dollar3, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 548|    qualified_type_name { $1.to_type() }
fn yy_action_357(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  YYObj_Type({();  _dollar1.to_type() })
}

// file:///./parser.mbty
// 565|    IDENT "." IDENT {
// 566|    let loc = span($sloc)
// 567|    {
// 568|      module_path: Some({
// 569|        components: [ $1 ],
// 570|        loc: loc.ascii_prefix($1.length()),
// 571|      }),
// 572|      name: $3,
// 573|      loc,
// 574|    }
// 575|  }
fn yy_action_358(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_NominalTypeName({(); 
    let loc = span((_symbol_start_pos, _end_pos))
    {
      module_path: Some({
        components: [ _dollar1 ],
        loc: loc.ascii_prefix(_dollar1.length()),
      }),
      name: _dollar3,
      loc,
    }
  })
}

// file:///./parser.mbty
// 549|    IDENT {
// 550|    Name(name=$1, loc=span($sloc))
// 551|  }
fn yy_action_359(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 606|    "{" type_list "}" { effect_set($2, span($sloc)) }
fn yy_action_360(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectTerm({();  effect_set(_dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 595|    { None }
fn yy_action_361(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_EffectTerm_({();  None })
}

// file:///./parser.mbty
// 616|    non_empty_type_list layout_list_separator type { comma_push($1, $3) }
fn yy_action_362(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 617|    non_empty_type_list layout_list_separator { $1 }
fn yy_action_363(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 611|    non_empty_type_list { $1 }
fn yy_action_364(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 615|    type { [ $1 ] }
fn yy_action_365(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 610|    { [] }
fn yy_action_366(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 126|    { () }
fn yy_action_367(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 144|    { { imports: [], declarations: [] } }
fn yy_action_368(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ModuleBody({();  { imports: [], declarations: [] } })
}

// file:///./parser.mbty
// 111|    { () }
fn yy_action_369(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 131|    "module" module_path { $2 }
fn yy_action_370(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  YYObj_ModulePath({();  _dollar2 })
}

// file:///./parser.mbty
// 140|    non_empty_module_path "." IDENT { comma_push($1, $3) }
fn yy_action_371(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 135|    non_empty_module_path { { components: $1, loc: span($sloc) } }
fn yy_action_372(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ModulePath({();  { components: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 139|    IDENT { [ $1 ] }
fn yy_action_373(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_({();  [ _dollar1 ] })
}

fn yy_input(token : Token, _start_pos : SourceSpan, _end_pos : SourceSpan) -> (YYSymbol, YYObj) {
  match token {
    INT(data) => (T_INT, YYObj_NumericLiteralToken(data))
    DOUBLE(data) => (T_DOUBLE, YYObj_NumericLiteralToken(data))
    STRING(data) => (T_STRING, YYObj_String(data))
    CHAR(data) => (T_CHAR, YYObj_Int(data))
    IDENT(data) => (T_IDENT, YYObj_String(data))
    RESERVED(data) => (T_RESERVED, YYObj_String(data))
    EOF => (T_EOF, YYObj_Void)
    FALSE => (T_FALSE, YYObj_Void)
    TRUE => (T_TRUE, YYObj_Void)
    STRUCT => (T_STRUCT, YYObj_Void)
    ENUM => (T_ENUM, YYObj_Void)
    EFFECT => (T_EFFECT, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    KIND_TYPE => (T_KIND_TYPE, YYObj_Void)
    KIND_EFFECT => (T_KIND_EFFECT, YYObj_Void)
    OFFER => (T_OFFER, YYObj_Void)
    AUTO => (T_AUTO, YYObj_Void)
    IF => (T_IF, YYObj_Void)
    ELSE => (T_ELSE, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
    HANDLE => (T_HANDLE, YYObj_Void)
    WITH => (T_WITH, YYObj_Void)
    FINAL => (T_FINAL, YYObj_Void)
    DERIVE => (T_DERIVE, YYObj_Void)
    BUILTIN => (T_BUILTIN, YYObj_Void)
    EXTERN => (T_EXTERN, YYObj_Void)
    MODULE => (T_MODULE, YYObj_Void)
    IMPORT => (T_IMPORT, YYObj_Void)
    AS => (T_AS, YYObj_Void)
    PUB => (T_PUB, YYObj_Void)
    PLUS => (T_PLUS, YYObj_Void)
    MINUS => (T_MINUS, YYObj_Void)
    STAR => (T_STAR, YYObj_Void)
    SLASH => (T_SLASH, YYObj_Void)
    PERCENT => (T_PERCENT, YYObj_Void)
    EQEQ => (T_EQEQ, YYObj_Void)
    BANGEQ => (T_BANGEQ, YYObj_Void)
    LT => (T_LT, YYObj_Void)
    LTEQ => (T_LTEQ, YYObj_Void)
    GT => (T_GT, YYObj_Void)
    GTEQ => (T_GTEQ, YYObj_Void)
    AMPAMP => (T_AMPAMP, YYObj_Void)
    BARBAR => (T_BARBAR, YYObj_Void)
    BANG => (T_BANG, YYObj_Void)
    PIPE => (T_PIPE, YYObj_Void)
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    LBRACKET => (T_LBRACKET, YYObj_Void)
    OWNER_LBRACKET => (T_OWNER_LBRACKET, YYObj_Void)
    RBRACKET => (T_RBRACKET, YYObj_Void)
    EMPTY_GENERIC_ARGUMENT_LIST_ERROR => (T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR, YYObj_Void)
    EMPTY_TYPE_PARAMETER_LIST_ERROR => (T_EMPTY_TYPE_PARAMETER_LIST_ERROR, YYObj_Void)
    TYPE_IDENTIFIER_SLOT => (T_TYPE_IDENTIFIER_SLOT, YYObj_Void)
    EFFECT_IDENTIFIER_SLOT => (T_EFFECT_IDENTIFIER_SLOT, YYObj_Void)
    VALUE_IDENTIFIER_SLOT => (T_VALUE_IDENTIFIER_SLOT, YYObj_Void)
    PATTERN_IDENTIFIER_SLOT => (T_PATTERN_IDENTIFIER_SLOT, YYObj_Void)
    MISSING_TUPLE_TYPE_ITEM_ERROR => (T_MISSING_TUPLE_TYPE_ITEM_ERROR, YYObj_Void)
    MISSING_TUPLE_EXPRESSION_ITEM_ERROR => (T_MISSING_TUPLE_EXPRESSION_ITEM_ERROR, YYObj_Void)
    MISSING_TUPLE_PATTERN_ITEM_ERROR => (T_MISSING_TUPLE_PATTERN_ITEM_ERROR, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    SEMICOLON => (T_SEMICOLON, YYObj_Void)
    LAYOUT_NEWLINE(data) => (T_LAYOUT_NEWLINE, YYObj_LayoutNewlineClaim(data))
    DOTSTAR => (T_DOTSTAR, YYObj_Void)
    DOTLBRACE => (T_DOTLBRACE, YYObj_Void)
    DOT => (T_DOT, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    COLONCOLON => (T_COLONCOLON, YYObj_Void)
    TIGHT_COLONCOLON => (T_TIGHT_COLONCOLON, YYObj_Void)
    THIN_ARROW => (T_THIN_ARROW, YYObj_Void)
    FAT_ARROW => (T_FAT_ARROW, YYObj_Void)
    EQUAL => (T_EQUAL, YYObj_Void)
    UNDERSCORE => (T_UNDERSCORE, YYObj_Void)
  }
}

fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_file => Shift(yy_state_1)
    T_MODULE => Shift(yy_state_2)
    NT_module_declaration => Shift(yy_state_8)
    _ => Error
  }
}

fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_7)
    _ => Error
  }
}

fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_module_path, yy_action_373)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_5)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_AS | T_PUB | T_LAYOUT_NEWLINE | T_DOTSTAR | T_DOTLBRACE => Reduce(1, NT_module_path, yy_action_372)
    _ => Error
  }
}

fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_6)
    _ => Error
  }
}

fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_module_path, yy_action_371)
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_declaration, yy_action_370)
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_9)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_10)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_OFFER => Shift(yy_state_482)
    T_FN => Shift(yy_state_527)
    T_EFFECT => Shift(yy_state_528)
    T_ENUM => Shift(yy_state_563)
    T_STRUCT => Shift(yy_state_583)
    T_TYPE => Shift(yy_state_602)
    T_EXTERN => Shift(yy_state_614)
    NT_offer_value_declaration => Shift(yy_state_622)
    NT_top_level_let_declaration => Shift(yy_state_623)
    NT_function_declaration => Shift(yy_state_624)
    NT_type_alias_declaration => Shift(yy_state_625)
    NT_external_type_declaration => Shift(yy_state_626)
    NT_effect_declaration => Shift(yy_state_627)
    NT_enum_declaration => Shift(yy_state_628)
    NT_struct_declaration => Shift(yy_state_629)
    NT_non_public_top_level_declaration => Shift(yy_state_630)
    T_IMPORT => Shift(yy_state_631)
    T_PUB => Shift(yy_state_645)
    NT_top_level_declaration => Shift(yy_state_720)
    NT_public_import_declaration => Shift(yy_state_726)
    NT_import_declaration => Shift(yy_state_729)
    NT_module_body => Shift(yy_state_732)
    T_EOF => Reduce(0, NT_module_body, yy_action_368)
    _ => Error
  }
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_11)
    T_IDENT => Shift(yy_state_72)
    _ => Error
  }
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_12)
    _ => Error
  }
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_115)
    _ => Error
  }
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_continuation_opt => Shift(yy_state_14)
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_15)
    _ => Error
  }
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_109)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_365)
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_18)
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    T_RPAREN | T_RBRACE => Reduce(1, NT_type_list, yy_action_364)
    _ => Error
  }
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_19)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    T_RPAREN | T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_type_list, yy_action_363)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_362)
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_RPAREN => Shift(yy_state_21)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_98)
    _ => Error
  }
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_22)
    _ => Error
  }
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    NT_type => Shift(yy_state_23)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    _ => Error
  }
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_97)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_25)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_EFFECT_IDENTIFIER_SLOT => Shift(yy_state_83)
    NT_effect_set => Shift(yy_state_84)
    T_LPAREN => Shift(yy_state_85)
    NT_type_application => Shift(yy_state_95)
    _ => Error
  }
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    NT_type_list => Shift(yy_state_26)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_27)
    _ => Error
  }
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_effect_set, yy_action_360)
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_29)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(1, NT_type_primary, yy_action_359)
    _ => Error
  }
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_30)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_358)
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_32)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(1, NT_type_primary, yy_action_357)
    _ => Error
  }
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_33)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_356)
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_application, yy_action_355)
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_36)
    T_LBRACKET => Shift(yy_state_48)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_37)
    _ => Error
  }
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type => Shift(yy_state_38)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    _ => Error
  }
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_lambda, yy_action_354)
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_40)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(1, NT_type, yy_action_353)
    _ => Error
  }
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_generic_argument => Shift(yy_state_41)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_75)
    NT_non_empty_generic_argument_list => Shift(yy_state_77)
    _ => Error
  }
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_generic_argument_list, yy_action_352)
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_type_list => Shift(yy_state_43)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_44)
    _ => Error
  }
}

fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_generic_argument, yy_action_351)
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_350)
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_349)
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_348)
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_49)
    NT_type_parameter => Shift(yy_state_66)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_67)
    NT_non_empty_type_parameter_list => Shift(yy_state_69)
    T_IDENT => Shift(yy_state_72)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_50)
    T_RBRACKET | T_COMMA => Reduce(1, NT_type_parameter, yy_action_347)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_kind => Shift(yy_state_51)
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    _ => Error
  }
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter, yy_action_346)
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    NT_kind => Shift(yy_state_53)
    T_LBRACKET => Shift(yy_state_55)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    _ => Error
  }
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_54)
    _ => Error
  }
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind, yy_action_345)
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    NT_kind => Shift(yy_state_56)
    NT_non_empty_kind_list => Shift(yy_state_57)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    NT_kind_list => Shift(yy_state_62)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_344)
    _ => Error
  }
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_343)
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_58)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_342)
    _ => Error
  }
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    NT_kind => Shift(yy_state_59)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_kind_list, yy_action_341)
    _ => Error
  }
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_340)
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_339)
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_338)
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_63)
    _ => Error
  }
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    NT_kind => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_337)
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_list, yy_action_336)
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_68)
    _ => Error
  }
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_335)
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_70)
    T_RBRACKET => Shift(yy_state_73)
    _ => Error
  }
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_49)
    NT_type_parameter => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_type_parameter_list, yy_action_334)
    _ => Error
  }
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_list, yy_action_333)
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_identifier, yy_action_332)
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_331)
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_generic_argument, yy_action_330)
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_329)
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_78)
    T_RBRACKET => Shift(yy_state_80)
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    NT_generic_argument => Shift(yy_state_79)
    T_RBRACKET | T_COMMA | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_generic_argument_list, yy_action_328)
    _ => Error
  }
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_generic_argument_list, yy_action_327)
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_326)
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_layout_list_separator, yy_action_325)
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_layout_list_separator, yy_action_324)
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_set, yy_action_323)
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect_annotation, yy_action_322)
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_86)
    _ => Error
  }
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_87)
    T_COMMA => Shift(yy_state_88)
    _ => Error
  }
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_primary, yy_action_321)
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_89)
    T_MISSING_TUPLE_TYPE_ITEM_ERROR => Shift(yy_state_90)
    NT_tuple_type_tail => Shift(yy_state_91)
    _ => Error
  }
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tuple_type_tail, yy_action_320)
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tuple_type_tail, yy_action_319)
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_92)
    T_RPAREN => Shift(yy_state_94)
    _ => Error
  }
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_93)
    _ => Error
  }
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_tuple_type_tail, yy_action_318)
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_type_primary, yy_action_317)
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_40)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(1, NT_effect_set, yy_action_316)
    _ => Error
  }
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_annotation_opt, yy_action_315)
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_type, yy_action_314)
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_99)
    T_COMMA => Shift(yy_state_103)
    _ => Error
  }
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_100)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(3, NT_type_primary, yy_action_321)
    _ => Error
  }
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_101)
    _ => Error
  }
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_102)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_function_type, yy_action_313)
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_89)
    T_MISSING_TUPLE_TYPE_ITEM_ERROR => Shift(yy_state_90)
    NT_tuple_type_tail => Shift(yy_state_104)
    _ => Error
  }
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_92)
    T_RPAREN => Shift(yy_state_105)
    _ => Error
  }
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_106)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(5, NT_type_primary, yy_action_317)
    _ => Error
  }
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_107)
    _ => Error
  }
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_108)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_312)
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_110)
    _ => Error
  }
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_111)
    _ => Error
  }
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_112)
    _ => Error
  }
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_113)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_311)
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_layout_continuation_opt, yy_action_310)
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_116)
    _ => Error
  }
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_526)
    _ => Error
  }
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_118)
    _ => Error
  }
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_119)
    _ => Error
  }
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_120)
    _ => Error
  }
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_extern_expression, yy_action_309)
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_122)
    _ => Error
  }
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_123)
    _ => Error
  }
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_124)
    _ => Error
  }
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_builtin_expression, yy_action_308)
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_126)
    T_LPAREN => Shift(yy_state_130)
    _ => Error
  }
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_127)
    T_LPAREN => Shift(yy_state_129)
    _ => Error
  }
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_128)
    _ => Error
  }
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_literal_open, yy_action_307)
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_open, yy_action_306)
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_function_literal_open, yy_action_305)
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_132)
    NT_function_literal_parameter_modifiers => Shift(yy_state_133)
    NT_function_literal_parameter => Shift(yy_state_138)
    NT_non_empty_function_literal_parameters => Shift(yy_state_139)
    NT_function_literal_parameters => Shift(yy_state_142)
    T_RPAREN => Reduce(0, NT_function_literal_parameters, yy_action_303)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_304)
    _ => Error
  }
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_literal_parameter_modifiers, yy_action_302)
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_134)
    _ => Error
  }
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_type_annotation => Shift(yy_state_135)
    T_COLON => Shift(yy_state_136)
    T_RPAREN | T_COMMA => Reduce(0, NT_local_type_annotation, yy_action_301)
    _ => Error
  }
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_parameter, yy_action_300)
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_137)
    _ => Error
  }
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_type_annotation, yy_action_299)
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_function_literal_parameters, yy_action_298)
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_140)
    T_RPAREN => Reduce(1, NT_function_literal_parameters, yy_action_297)
    _ => Error
  }
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_132)
    NT_function_literal_parameter_modifiers => Shift(yy_state_133)
    NT_function_literal_parameter => Shift(yy_state_141)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_304)
    _ => Error
  }
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_function_literal_parameters, yy_action_296)
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_143)
    _ => Error
  }
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_144)
    NT_return_annotation => Shift(yy_state_147)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_return_annotation, yy_action_295)
    _ => Error
  }
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_145)
    _ => Error
  }
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_146)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_return_annotation, yy_action_294)
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_148)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block_expression => Shift(yy_state_149)
    T_LBRACE => Shift(yy_state_150)
    _ => Error
  }
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_function_literal, yy_action_293)
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_151)
    T_INT | T_DOUBLE | T_STRING | T_CHAR | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_DERIVE | T_BUILTIN | T_EXTERN | T_MINUS | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET | T_VALUE_IDENTIFIER_SLOT | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_items => Shift(yy_state_152)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_INT | T_DOUBLE | T_STRING | T_CHAR | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_DERIVE | T_BUILTIN | T_EXTERN | T_MINUS | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET | T_VALUE_IDENTIFIER_SLOT => Reduce(0, NT_local_items, yy_action_292)
    _ => Error
  }
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_offer_value_declaration => Shift(yy_state_470)
    NT_function_declaration => Shift(yy_state_471)
    NT_local_let_item => Shift(yy_state_472)
    NT_local_item => Shift(yy_state_473)
    NT_expression => Shift(yy_state_475)
    T_LET => Shift(yy_state_477)
    T_OFFER => Shift(yy_state_482)
    T_FN => Shift(yy_state_516)
    _ => Error
  }
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_407)
    _ => Error
  }
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_317)
    _ => Error
  }
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_309)
    _ => Error
  }
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_157)
    _ => Error
  }
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_158)
    NT_derive_type_arguments => Shift(yy_state_162)
    _ => Error
  }
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    NT_layout_list_separator => Shift(yy_state_159)
    _ => Error
  }
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_160)
    _ => Error
  }
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    NT_layout_list_separator => Shift(yy_state_161)
    T_RBRACKET => Reduce(3, NT_derive_type_arguments, yy_action_291)
    _ => Error
  }
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_derive_type_arguments, yy_action_290)
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_163)
    _ => Error
  }
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_164)
    _ => Error
  }
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_call_argument => Shift(yy_state_165)
    NT_non_empty_argument_list => Shift(yy_state_166)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_234)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    T_IDENT => Shift(yy_state_264)
    NT_argument_list => Shift(yy_state_307)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_289)
    _ => Error
  }
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_argument_list, yy_action_288)
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_167)
    T_RPAREN => Reduce(1, NT_argument_list, yy_action_287)
    _ => Error
  }
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_call_argument => Shift(yy_state_168)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_234)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    T_IDENT => Shift(yy_state_264)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_argument_list, yy_action_286)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_argument_list, yy_action_285)
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_284)
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_283)
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_282)
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_non_empty_positional_argument_list => Shift(yy_state_173)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_280)
    NT_list_literal_items => Shift(yy_state_305)
    T_RBRACKET => Reduce(0, NT_list_literal_items, yy_action_281)
    _ => Error
  }
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_174)
    T_RBRACKET => Reduce(1, NT_list_literal_items, yy_action_280)
    _ => Error
  }
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_304)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_positional_argument_list, yy_action_279)
    _ => Error
  }
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_278)
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_277)
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_276)
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_275)
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_274)
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_RPAREN => Shift(yy_state_181)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_295)
    _ => Error
  }
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_non_owner_primary_expression, yy_action_273)
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_272)
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_271)
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_270)
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_269)
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_268)
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_267)
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER_LBRACKET => Shift(yy_state_189)
    NT_owner_type_arguments => Shift(yy_state_194)
    T_DOT => Shift(yy_state_195)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_expression, yy_action_266)
    _ => Error
  }
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_generic_argument => Shift(yy_state_41)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_190)
    NT_non_empty_generic_argument_list => Shift(yy_state_192)
    _ => Error
  }
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_191)
    _ => Error
  }
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_type_arguments, yy_action_265)
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_78)
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    T_RBRACKET => Shift(yy_state_193)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_type_arguments, yy_action_264)
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_owner_expression, yy_action_263)
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_196)
    _ => Error
  }
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_path_expression, yy_action_262)
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_198)
    _ => Error
  }
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_199)
    NT_type_argument_bracket_list => Shift(yy_state_204)
    NT_type_arguments => Shift(yy_state_205)
    NT_operation_type_witnesses => Shift(yy_state_206)
    T_LPAREN => Shift(yy_state_292)
    _ => Error
  }
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_generic_argument => Shift(yy_state_41)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_200)
    NT_non_empty_generic_argument_list => Shift(yy_state_202)
    _ => Error
  }
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_201)
    _ => Error
  }
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_261)
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_78)
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    T_RBRACKET => Shift(yy_state_203)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_260)
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_arguments, yy_action_259)
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_operation_type_witnesses, yy_action_258)
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_207)
    _ => Error
  }
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_empty_positional_argument_list => Shift(yy_state_208)
    NT_positional_argument_list => Shift(yy_state_209)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_280)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_257)
    _ => Error
  }
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_174)
    T_RPAREN => Reduce(1, NT_positional_argument_list, yy_action_256)
    _ => Error
  }
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_210)
    _ => Error
  }
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_value_postfix_expression, yy_action_255)
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_254)
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_213)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_DOT => Reduce(1, NT_value_postfix_expression, yy_action_253)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_214)
    NT_identifier => Shift(yy_state_274)
    T_IDENT => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_215)
    NT_struct_literal_field => Shift(yy_state_268)
    NT_non_empty_struct_literal_fields => Shift(yy_state_269)
    NT_struct_literal_fields => Shift(yy_state_272)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_252)
    _ => Error
  }
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_216)
    T_COLON => Shift(yy_state_218)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(1, NT_struct_literal_field, yy_action_251)
    _ => Error
  }
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    NT_generic_argument => Shift(yy_state_217)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_literal_field, yy_action_250)
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_267)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_249)
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_199)
    NT_type_argument_bracket_list => Shift(yy_state_204)
    T_DOT => Shift(yy_state_221)
    NT_type_arguments => Shift(yy_state_223)
    T_LPAREN => Shift(yy_state_224)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(1, NT_postfix_expression, yy_action_248)
    _ => Error
  }
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_222)
    _ => Error
  }
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_value_postfix_expression, yy_action_247)
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value_postfix_expression, yy_action_246)
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_call_argument => Shift(yy_state_165)
    NT_non_empty_argument_list => Shift(yy_state_166)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_argument_list => Shift(yy_state_225)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_234)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    T_IDENT => Shift(yy_state_264)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_289)
    _ => Error
  }
}

fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_226)
    _ => Error
  }
}

fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_value_postfix_expression, yy_action_245)
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_unary_expression, yy_action_244)
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    NT_unary_expression => Shift(yy_state_229)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    _ => Error
  }
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_243)
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    NT_unary_expression => Shift(yy_state_231)
    T_IDENT => Shift(yy_state_232)
    _ => Error
  }
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_242)
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Reduce(1, NT_identifier, yy_action_332)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_OWNER_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_DOT | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_path_expression, yy_action_241)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_240)
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_COMMA => Reduce(1, NT_call_argument, yy_action_239)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_236)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_238)
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_238)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_237)
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_240)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_236)
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_242)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_235)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_244)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_234)
    _ => Error
  }
}

fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_246)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_233)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_248)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_232)
    _ => Error
  }
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_250)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_231)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_252)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_230)
    _ => Error
  }
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_254)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_229)
    _ => Error
  }
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_256)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_228)
    _ => Error
  }
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_258)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_227)
    _ => Error
  }
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_260)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_226)
    _ => Error
  }
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    NT_expression => Shift(yy_state_262)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_expression, yy_action_225)
    _ => Error
  }
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_224)
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_265)
    T_BANG => Reduce(1, NT_identifier, yy_action_332)
    T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACKET | T_OWNER_LBRACKET | T_COMMA | T_DOT | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_path_expression, yy_action_241)
    _ => Error
  }
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_266)
    _ => Error
  }
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_COMMA => Reduce(3, NT_call_argument, yy_action_223)
    _ => Error
  }
}

fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(3, NT_struct_literal_field, yy_action_222)
    _ => Error
  }
}

fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_literal_fields, yy_action_221)
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    NT_layout_list_separator => Shift(yy_state_270)
    T_RBRACE => Reduce(1, NT_struct_literal_fields, yy_action_220)
    _ => Error
  }
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_215)
    NT_struct_literal_field => Shift(yy_state_271)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_struct_literal_fields, yy_action_219)
    _ => Error
  }
}

fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_literal_fields, yy_action_218)
}

fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_273)
    _ => Error
  }
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_217)
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_275)
    _ => Error
  }
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_199)
    NT_type_argument_bracket_list => Shift(yy_state_204)
    NT_type_arguments => Shift(yy_state_205)
    NT_operation_type_witnesses => Shift(yy_state_276)
    T_LPAREN => Shift(yy_state_281)
    _ => Error
  }
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_277)
    _ => Error
  }
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_empty_positional_argument_list => Shift(yy_state_208)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_positional_argument_list => Shift(yy_state_278)
    NT_expression => Shift(yy_state_280)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_257)
    _ => Error
  }
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_279)
    _ => Error
  }
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_member_expression, yy_action_216)
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(1, NT_non_empty_positional_argument_list, yy_action_215)
    _ => Error
  }
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_empty_positional_argument_list => Shift(yy_state_208)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_280)
    NT_positional_argument_list => Shift(yy_state_282)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_257)
    _ => Error
  }
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_283)
    _ => Error
  }
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_member_expression, yy_action_214)
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_199)
    NT_type_argument_bracket_list => Shift(yy_state_204)
    NT_type_arguments => Shift(yy_state_285)
    NT_variant_type_arguments => Shift(yy_state_286)
    T_LPAREN | T_LAYOUT_NEWLINE => Reduce(0, NT_variant_type_arguments, yy_action_213)
    T_BANG => Reduce(1, NT_identifier, yy_action_332)
    _ => Error
  }
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_variant_type_arguments, yy_action_212)
}

fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_287)
    NT_variant_arguments => Shift(yy_state_291)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_288)
    _ => Error
  }
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_empty_positional_argument_list => Shift(yy_state_208)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_280)
    NT_positional_argument_list => Shift(yy_state_289)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_257)
    _ => Error
  }
}

fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_290)
    _ => Error
  }
}

fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_variant_arguments, yy_action_211)
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_210)
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_empty_positional_argument_list => Shift(yy_state_208)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_280)
    NT_positional_argument_list => Shift(yy_state_293)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_257)
    _ => Error
  }
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_294)
    _ => Error
  }
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_value_postfix_expression, yy_action_209)
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN => Shift(yy_state_296)
    T_COMMA => Shift(yy_state_297)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_208)
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    T_MISSING_TUPLE_EXPRESSION_ITEM_ERROR => Shift(yy_state_298)
    NT_tuple_expression_tail => Shift(yy_state_299)
    NT_expression => Shift(yy_state_303)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tuple_expression_tail, yy_action_207)
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_300)
    T_RPAREN => Shift(yy_state_302)
    _ => Error
  }
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_301)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_COMMA => Reduce(3, NT_tuple_expression_tail, yy_action_206)
    _ => Error
  }
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_non_owner_primary_expression, yy_action_205)
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_COMMA => Reduce(1, NT_tuple_expression_tail, yy_action_204)
    _ => Error
  }
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(3, NT_non_empty_positional_argument_list, yy_action_203)
    _ => Error
  }
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_306)
    _ => Error
  }
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_202)
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_308)
    _ => Error
  }
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_derive_expression, yy_action_201)
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    NT_layout_continuation_opt => Shift(yy_state_310)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_311)
    _ => Error
  }
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_312)
    NT_optional_else_branch => Shift(yy_state_316)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_NEWLINE | T_DOT => Reduce(0, NT_optional_else_branch, yy_action_200)
    _ => Error
  }
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    T_IF => Shift(yy_state_155)
    NT_if_expression => Shift(yy_state_313)
    NT_block_expression => Shift(yy_state_314)
    NT_else_branch_expression => Shift(yy_state_315)
    _ => Error
  }
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_199)
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_198)
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_optional_else_branch, yy_action_197)
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_if_expression, yy_action_196)
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    NT_layout_continuation_opt => Shift(yy_state_318)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_319)
    _ => Error
  }
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_320)
    T_INT | T_DOUBLE | T_STRING | T_CHAR | T_IDENT | T_FALSE | T_TRUE | T_MINUS | T_LPAREN | T_RBRACE | T_PATTERN_IDENTIFIER_SLOT | T_LAYOUT_NEWLINE | T_UNDERSCORE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_395)
    NT_match_arm => Shift(yy_state_398)
    NT_non_empty_match_arms => Shift(yy_state_399)
    NT_match_arms => Shift(yy_state_404)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_RBRACE => Reduce(0, NT_match_arms, yy_action_195)
    _ => Error
  }
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_322)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_323)
    T_IDENT => Shift(yy_state_393)
    _ => Error
  }
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_324)
    T_IDENT => Shift(yy_state_325)
    NT_struct_pattern_field => Shift(yy_state_387)
    NT_non_empty_struct_pattern_fields => Shift(yy_state_388)
    NT_struct_pattern_fields => Shift(yy_state_391)
    T_RBRACE => Reduce(0, NT_struct_pattern_fields, yy_action_194)
    _ => Error
  }
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_pattern_field, yy_action_193)
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_326)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(1, NT_struct_pattern_field, yy_action_192)
    _ => Error
  }
}

fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_pattern => Shift(yy_state_327)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_pattern_field, yy_action_191)
}

fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_190)
}

fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    NT_pattern => Shift(yy_state_330)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_331)
    _ => Error
  }
}

fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    NT_pattern => Shift(yy_state_332)
    T_MISSING_TUPLE_PATTERN_ITEM_ERROR => Shift(yy_state_333)
    NT_tuple_pattern_tail => Shift(yy_state_334)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tuple_pattern_tail, yy_action_189)
}

fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tuple_pattern_tail, yy_action_188)
}

fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_335)
    T_RPAREN => Shift(yy_state_386)
    _ => Error
  }
}

fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    NT_pattern => Shift(yy_state_336)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_tuple_pattern_tail, yy_action_187)
}

fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_186)
}

fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_185)
}

fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_184)
}

fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_183)
}

fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_182)
}

fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE => Shift(yy_state_343)
    T_INT => Shift(yy_state_344)
    _ => Error
  }
}

fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_pattern, yy_action_181)
}

fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_pattern, yy_action_180)
}

fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_179)
}

fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_178)
}

fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_177)
}

fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_32)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_176)
    _ => Error
  }
}

fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_29)
    T_LAYOUT_NEWLINE => Shift(yy_state_350)
    T_LBRACKET => Shift(yy_state_372)
    T_LPAREN => Shift(yy_state_382)
    NT_variant_pattern_arguments => Shift(yy_state_385)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_174)
    T_RPAREN | T_RBRACE | T_COMMA | T_COLON | T_FAT_ARROW | T_EQUAL => Reduce(1, NT_pattern, yy_action_175)
    _ => Error
  }
}

fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_351)
    T_LPAREN => Shift(yy_state_368)
    NT_variant_pattern_arguments_after_newline => Shift(yy_state_371)
    _ => Error
  }
}

fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_352)
    NT_non_empty_ident_list => Shift(yy_state_353)
    _ => Error
  }
}

fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_ident_list, yy_action_173)
}

fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_354)
    T_RBRACKET => Shift(yy_state_356)
    _ => Error
  }
}

fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_355)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_ident_list, yy_action_172)
    _ => Error
  }
}

fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_ident_list, yy_action_171)
}

fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_357)
    T_LPAREN => Shift(yy_state_365)
    _ => Error
  }
}

fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_358)
    _ => Error
  }
}

fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_363)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_pattern_list, yy_action_169)
}

fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_361)
    T_RPAREN => Reduce(1, NT_pattern_list, yy_action_168)
    _ => Error
  }
}

fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_362)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_pattern_list, yy_action_167)
    _ => Error
  }
}

fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_pattern_list, yy_action_166)
}

fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_364)
    _ => Error
  }
}

fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_variant_pattern_arguments_after_newline, yy_action_165)
}

fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_366)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_variant_pattern_arguments_after_newline, yy_action_164)
}

fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_369)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_370)
    _ => Error
  }
}

fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_pattern_arguments_after_newline, yy_action_163)
}

fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_variant_pattern_arguments, yy_action_162)
}

fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_352)
    NT_non_empty_ident_list => Shift(yy_state_373)
    _ => Error
  }
}

fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_354)
    T_RBRACKET => Shift(yy_state_374)
    _ => Error
  }
}

fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_375)
    T_LPAREN => Shift(yy_state_379)
    _ => Error
  }
}

fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_376)
    _ => Error
  }
}

fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_377)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_378)
    _ => Error
  }
}

fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_variant_pattern_arguments, yy_action_161)
}

fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_380)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_381)
    _ => Error
  }
}

fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_variant_pattern_arguments, yy_action_160)
}

fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_359)
    NT_non_empty_pattern_list => Shift(yy_state_360)
    NT_pattern_list => Shift(yy_state_383)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_384)
    _ => Error
  }
}

fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_pattern_arguments, yy_action_159)
}

fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_pattern, yy_action_158)
}

fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_pattern, yy_action_157)
}

fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_pattern_fields, yy_action_156)
}

fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    NT_layout_list_separator => Shift(yy_state_389)
    T_RBRACE => Reduce(1, NT_struct_pattern_fields, yy_action_155)
    _ => Error
  }
}

fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_324)
    T_IDENT => Shift(yy_state_325)
    NT_struct_pattern_field => Shift(yy_state_390)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_struct_pattern_fields, yy_action_154)
    _ => Error
  }
}

fn yy_state_390(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_pattern_fields, yy_action_153)
}

fn yy_state_391(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_392)
    _ => Error
  }
}

fn yy_state_392(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_pattern, yy_action_152)
}

fn yy_state_393(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_350)
    T_LBRACKET => Shift(yy_state_372)
    T_LPAREN => Shift(yy_state_382)
    NT_variant_pattern_arguments => Shift(yy_state_394)
    _ => Error
  }
}

fn yy_state_394(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_pattern, yy_action_151)
}

fn yy_state_395(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_396)
    _ => Error
  }
}

fn yy_state_396(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_397)
    _ => Error
  }
}

fn yy_state_397(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(3, NT_match_arm, yy_action_150)
    _ => Error
  }
}

fn yy_state_398(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_match_arms, yy_action_149)
}

fn yy_state_399(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_item_semicolon => Shift(yy_state_400)
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    T_RBRACE => Reduce(1, NT_match_arms, yy_action_148)
    _ => Error
  }
}

fn yy_state_400(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_395)
    NT_match_arm => Shift(yy_state_401)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_match_arms, yy_action_147)
    _ => Error
  }
}

fn yy_state_401(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_match_arms, yy_action_146)
}

fn yy_state_402(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_item_semicolon, yy_action_145)
}

fn yy_state_403(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_item_semicolon, yy_action_144)
}

fn yy_state_404(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_405)
    _ => Error
  }
}

fn yy_state_405(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_match_expression, yy_action_143)
}

fn yy_state_406(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_layout_semicolons, yy_action_142)
}

fn yy_state_407(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_WITH => Shift(yy_state_408)
    NT_handler_with_block => Shift(yy_state_462)
    NT_handler_with_blocks => Shift(yy_state_463)
    _ => Error
  }
}

fn yy_state_408(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_409)
    _ => Error
  }
}

fn yy_state_409(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_410)
    T_IDENT | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_410(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_handler_operation_name => Shift(yy_state_411)
    NT_identifier => Shift(yy_state_429)
    NT_handler_operation_signature_open => Shift(yy_state_438)
    NT_handler_operation_arm => Shift(yy_state_450)
    NT_non_empty_handler_operation_arms => Shift(yy_state_451)
    NT_qualified_type_name => Shift(yy_state_454)
    T_IDENT => Shift(yy_state_459)
    NT_handler_operation_arms => Shift(yy_state_460)
    _ => Error
  }
}

fn yy_state_411(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_412)
    T_LAYOUT_NEWLINE => Shift(yy_state_417)
    NT_ident_bracket_list => Shift(yy_state_424)
    T_LPAREN => Shift(yy_state_428)
    _ => Error
  }
}

fn yy_state_412(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_352)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_413)
    NT_non_empty_ident_list => Shift(yy_state_415)
    _ => Error
  }
}

fn yy_state_413(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_414)
    _ => Error
  }
}

fn yy_state_414(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_141)
}

fn yy_state_415(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_354)
    T_RBRACKET => Shift(yy_state_416)
    _ => Error
  }
}

fn yy_state_416(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_140)
}

fn yy_state_417(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_412)
    NT_ident_bracket_list => Shift(yy_state_418)
    T_LPAREN => Shift(yy_state_422)
    NT_handler_operation_signature_after_newline => Shift(yy_state_423)
    _ => Error
  }
}

fn yy_state_418(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_419)
    T_LPAREN => Shift(yy_state_421)
    _ => Error
  }
}

fn yy_state_419(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_420)
    _ => Error
  }
}

fn yy_state_420(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_signature_after_newline, yy_action_139)
}

fn yy_state_421(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_operation_signature_after_newline, yy_action_138)
}

fn yy_state_422(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_signature_after_newline, yy_action_137)
}

fn yy_state_423(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_signature_open, yy_action_136)
}

fn yy_state_424(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_425)
    T_LPAREN => Shift(yy_state_427)
    _ => Error
  }
}

fn yy_state_425(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_426)
    _ => Error
  }
}

fn yy_state_426(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_operation_signature_open, yy_action_135)
}

fn yy_state_427(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_signature_open, yy_action_134)
}

fn yy_state_428(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_operation_signature_open, yy_action_133)
}

fn yy_state_429(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER_LBRACKET => Shift(yy_state_430)
    NT_handler_operation_generic_arguments => Shift(yy_state_433)
    T_TIGHT_COLONCOLON => Shift(yy_state_436)
    T_LPAREN | T_LBRACKET | T_LAYOUT_NEWLINE => Reduce(1, NT_handler_operation_name, yy_action_132)
    _ => Error
  }
}

fn yy_state_430(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_generic_argument => Shift(yy_state_41)
    T_LBRACE => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    NT_non_empty_generic_argument_list => Shift(yy_state_431)
    _ => Error
  }
}

fn yy_state_431(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_78)
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    T_RBRACKET => Shift(yy_state_432)
    _ => Error
  }
}

fn yy_state_432(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_generic_arguments, yy_action_131)
}

fn yy_state_433(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_434)
    _ => Error
  }
}

fn yy_state_434(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_435)
    _ => Error
  }
}

fn yy_state_435(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_operation_name, yy_action_130)
}

fn yy_state_436(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_437)
    _ => Error
  }
}

fn yy_state_437(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_name, yy_action_129)
}

fn yy_state_438(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    NT_pattern => Shift(yy_state_439)
    NT_handler_payload_patterns => Shift(yy_state_440)
    T_IDENT => Shift(yy_state_444)
    NT_identifier => Shift(yy_state_445)
    NT_handler_operation_arm_parameters => Shift(yy_state_446)
    _ => Error
  }
}

fn yy_state_439(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_payload_patterns, yy_action_128)
}

fn yy_state_440(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_441)
    _ => Error
  }
}

fn yy_state_441(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    NT_pattern => Shift(yy_state_442)
    NT_identifier => Shift(yy_state_443)
    T_IDENT => Shift(yy_state_444)
    _ => Error
  }
}

fn yy_state_442(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_payload_patterns, yy_action_127)
}

fn yy_state_443(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_arm_parameters, yy_action_126)
}

fn yy_state_444(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_29)
    T_LAYOUT_NEWLINE => Shift(yy_state_350)
    T_LBRACKET => Shift(yy_state_372)
    T_LPAREN => Shift(yy_state_382)
    NT_variant_pattern_arguments => Shift(yy_state_385)
    T_RPAREN => Reduce(1, NT_identifier, yy_action_332)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_174)
    T_COMMA => Reduce(1, NT_pattern, yy_action_175)
    _ => Error
  }
}

fn yy_state_445(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_arm_parameters, yy_action_125)
}

fn yy_state_446(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_447)
    _ => Error
  }
}

fn yy_state_447(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_448)
    _ => Error
  }
}

fn yy_state_448(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_449)
    _ => Error
  }
}

fn yy_state_449(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(5, NT_handler_operation_arm, yy_action_124)
    _ => Error
  }
}

fn yy_state_450(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_handler_operation_arms, yy_action_123)
}

fn yy_state_451(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    NT_item_semicolon => Shift(yy_state_452)
    T_RBRACE => Reduce(1, NT_handler_operation_arms, yy_action_122)
    _ => Error
  }
}

fn yy_state_452(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_handler_operation_name => Shift(yy_state_411)
    NT_identifier => Shift(yy_state_429)
    NT_handler_operation_signature_open => Shift(yy_state_438)
    NT_handler_operation_arm => Shift(yy_state_453)
    NT_qualified_type_name => Shift(yy_state_454)
    T_IDENT => Shift(yy_state_459)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_handler_operation_arms, yy_action_121)
    _ => Error
  }
}

fn yy_state_453(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_handler_operation_arms, yy_action_120)
}

fn yy_state_454(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_32)
    T_OWNER_LBRACKET => Shift(yy_state_430)
    NT_handler_operation_generic_arguments => Shift(yy_state_455)
    NT_handler_operation_owner_arguments => Shift(yy_state_456)
    T_TIGHT_COLONCOLON => Reduce(0, NT_handler_operation_owner_arguments, yy_action_119)
    _ => Error
  }
}

fn yy_state_455(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_owner_arguments, yy_action_118)
}

fn yy_state_456(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_457)
    _ => Error
  }
}

fn yy_state_457(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_458)
    _ => Error
  }
}

fn yy_state_458(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_operation_name, yy_action_117)
}

fn yy_state_459(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_29)
    T_LPAREN | T_LBRACKET | T_OWNER_LBRACKET | T_LAYOUT_NEWLINE | T_TIGHT_COLONCOLON => Reduce(1, NT_identifier, yy_action_332)
    _ => Error
  }
}

fn yy_state_460(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_461)
    _ => Error
  }
}

fn yy_state_461(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_handler_with_block, yy_action_116)
}

fn yy_state_462(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_with_blocks, yy_action_115)
}

fn yy_state_463(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_WITH => Shift(yy_state_408)
    T_FINAL => Shift(yy_state_464)
    NT_handler_with_block => Shift(yy_state_468)
    NT_handler_final_branch => Shift(yy_state_469)
    _ => Error
  }
}

fn yy_state_464(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_465)
    _ => Error
  }
}

fn yy_state_465(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_466)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_466(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_467)
    _ => Error
  }
}

fn yy_state_467(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_final_branch, yy_action_114)
}

fn yy_state_468(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_with_blocks, yy_action_113)
}

fn yy_state_469(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_expression, yy_action_112)
}

fn yy_state_470(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_111)
}

fn yy_state_471(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_110)
}

fn yy_state_472(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_109)
}

fn yy_state_473(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    NT_item_semicolon => Shift(yy_state_474)
    _ => Error
  }
}

fn yy_state_474(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_local_items, yy_action_108)
}

fn yy_state_475(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_RBRACE => Shift(yy_state_476)
    T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(1, NT_local_item, yy_action_107)
    _ => Error
  }
}

fn yy_state_476(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_block_expression, yy_action_106)
}

fn yy_state_477(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_321)
    NT_struct_pattern => Shift(yy_state_328)
    T_LPAREN => Shift(yy_state_329)
    T_FALSE => Shift(yy_state_337)
    T_TRUE => Shift(yy_state_338)
    T_CHAR => Shift(yy_state_339)
    T_STRING => Shift(yy_state_340)
    T_DOUBLE => Shift(yy_state_341)
    T_MINUS => Shift(yy_state_342)
    T_INT => Shift(yy_state_345)
    T_UNDERSCORE => Shift(yy_state_346)
    T_PATTERN_IDENTIFIER_SLOT => Shift(yy_state_347)
    NT_qualified_type_name => Shift(yy_state_348)
    T_IDENT => Shift(yy_state_349)
    NT_pattern => Shift(yy_state_478)
    _ => Error
  }
}

fn yy_state_478(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_136)
    NT_local_type_annotation => Shift(yy_state_479)
    T_EQUAL => Reduce(0, NT_local_type_annotation, yy_action_301)
    _ => Error
  }
}

fn yy_state_479(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_480)
    _ => Error
  }
}

fn yy_state_480(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_481)
    _ => Error
  }
}

fn yy_state_481(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(5, NT_local_let_item, yy_action_105)
    _ => Error
  }
}

fn yy_state_482(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_483)
    T_FN => Shift(yy_state_488)
    _ => Error
  }
}

fn yy_state_483(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_484)
    _ => Error
  }
}

fn yy_state_484(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_485)
    _ => Error
  }
}

fn yy_state_485(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_486)
    _ => Error
  }
}

fn yy_state_486(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_487)
    _ => Error
  }
}

fn yy_state_487(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(6, NT_offer_value_declaration, yy_action_104)
    _ => Error
  }
}

fn yy_state_488(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_492)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_489(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_490)
    _ => Error
  }
}

fn yy_state_490(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_parameters, yy_action_102)
}

fn yy_state_491(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameters, yy_action_101)
}

fn yy_state_492(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_493)
    _ => Error
  }
}

fn yy_state_493(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_494)
    NT_parameters => Shift(yy_state_510)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_494(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_495)
    _ => Error
  }
}

fn yy_state_495(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_496)
    T_AUTO => Shift(yy_state_498)
    NT_parameter_modifiers => Shift(yy_state_500)
    NT_parameter => Shift(yy_state_504)
    NT_non_empty_parameter_list => Shift(yy_state_505)
    T_RPAREN => Shift(yy_state_509)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_100)
    _ => Error
  }
}

fn yy_state_496(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AUTO => Shift(yy_state_497)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_99)
    _ => Error
  }
}

fn yy_state_497(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_98)
}

fn yy_state_498(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_499)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_97)
    _ => Error
  }
}

fn yy_state_499(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_96)
}

fn yy_state_500(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_501)
    _ => Error
  }
}

fn yy_state_501(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_502)
    _ => Error
  }
}

fn yy_state_502(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_503)
    _ => Error
  }
}

fn yy_state_503(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameter, yy_action_95)
}

fn yy_state_504(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_parameter_list, yy_action_94)
}

fn yy_state_505(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_506)
    T_RPAREN => Shift(yy_state_508)
    _ => Error
  }
}

fn yy_state_506(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_496)
    T_AUTO => Shift(yy_state_498)
    NT_parameter_modifiers => Shift(yy_state_500)
    NT_parameter => Shift(yy_state_507)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_100)
    _ => Error
  }
}

fn yy_state_507(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_parameter_list, yy_action_93)
}

fn yy_state_508(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameters, yy_action_92)
}

fn yy_state_509(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parameters, yy_action_91)
}

fn yy_state_510(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_511)
    _ => Error
  }
}

fn yy_state_511(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_512)
    _ => Error
  }
}

fn yy_state_512(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_513)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_513(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_514)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_514(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_515)
    _ => Error
  }
}

fn yy_state_515(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_function_declaration, yy_action_90)
}

fn yy_state_516(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LPAREN => Shift(yy_state_130)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_517)
    NT_type_parameters => Shift(yy_state_518)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_517(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_127)
    T_LPAREN => Shift(yy_state_129)
    T_IDENT => Reduce(1, NT_type_parameters, yy_action_101)
    _ => Error
  }
}

fn yy_state_518(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_519)
    _ => Error
  }
}

fn yy_state_519(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_494)
    NT_parameters => Shift(yy_state_520)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_520(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_521)
    _ => Error
  }
}

fn yy_state_521(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_522)
    _ => Error
  }
}

fn yy_state_522(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_523)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_523(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_524)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_524(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_525)
    _ => Error
  }
}

fn yy_state_525(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_function_declaration, yy_action_89)
}

fn yy_state_526(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_NEWLINE => Reduce(6, NT_top_level_let_declaration, yy_action_88)
    _ => Error
  }
}

fn yy_state_527(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_518)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_528(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_529)
    _ => Error
  }
}

fn yy_state_529(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_541)
    _ => Error
  }
}

fn yy_state_530(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_531)
    T_LBRACE => Shift(yy_state_533)
    _ => Error
  }
}

fn yy_state_531(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_532)
    _ => Error
  }
}

fn yy_state_532(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_nominal_body_open, yy_action_87)
}

fn yy_state_533(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_nominal_body_open, yy_action_86)
}

fn yy_state_534(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_535)
    T_LBRACE => Shift(yy_state_539)
    _ => Error
  }
}

fn yy_state_535(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_536)
    T_LBRACE => Shift(yy_state_538)
    _ => Error
  }
}

fn yy_state_536(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_537)
    _ => Error
  }
}

fn yy_state_537(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_nominal_body_open, yy_action_85)
}

fn yy_state_538(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_nominal_body_open, yy_action_84)
}

fn yy_state_539(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_nominal_body_open, yy_action_83)
}

fn yy_state_540(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_nominal_body_open, yy_action_82)
}

fn yy_state_541(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_542)
    T_IDENT | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_542(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_543)
    NT_effect_operation => Shift(yy_state_557)
    NT_non_empty_effect_operations => Shift(yy_state_558)
    NT_effect_operations => Shift(yy_state_561)
    T_RBRACE => Reduce(0, NT_effect_operations, yy_action_81)
    _ => Error
  }
}

fn yy_state_543(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_544)
    T_LPAREN | T_LBRACKET => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_544(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_545)
    T_LPAREN => Shift(yy_state_552)
    _ => Error
  }
}

fn yy_state_545(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_546)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_546(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_547)
    _ => Error
  }
}

fn yy_state_547(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_548)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_548(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_549)
    _ => Error
  }
}

fn yy_state_549(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_550)
    _ => Error
  }
}

fn yy_state_550(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_551)
    _ => Error
  }
}

fn yy_state_551(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_effect_operation, yy_action_80)
}

fn yy_state_552(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_553)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_553(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_554)
    _ => Error
  }
}

fn yy_state_554(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_555)
    _ => Error
  }
}

fn yy_state_555(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_556)
    _ => Error
  }
}

fn yy_state_556(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_effect_operation, yy_action_79)
}

fn yy_state_557(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_effect_operations, yy_action_78)
}

fn yy_state_558(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    NT_item_semicolon => Shift(yy_state_559)
    T_RBRACE => Reduce(1, NT_effect_operations, yy_action_77)
    _ => Error
  }
}

fn yy_state_559(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_543)
    NT_effect_operation => Shift(yy_state_560)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_effect_operations, yy_action_76)
    _ => Error
  }
}

fn yy_state_560(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_effect_operations, yy_action_75)
}

fn yy_state_561(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_562)
    _ => Error
  }
}

fn yy_state_562(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_effect_declaration, yy_action_74)
}

fn yy_state_563(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_564)
    _ => Error
  }
}

fn yy_state_564(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_565)
    _ => Error
  }
}

fn yy_state_565(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_566)
    T_IDENT | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_566(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_567)
    NT_enum_variant => Shift(yy_state_577)
    NT_non_empty_enum_variants => Shift(yy_state_578)
    NT_enum_variants => Shift(yy_state_581)
    T_RBRACE => Reduce(0, NT_enum_variants, yy_action_73)
    _ => Error
  }
}

fn yy_state_567(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_568)
    T_LPAREN | T_LBRACKET => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_568(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_569)
    T_LPAREN => Shift(yy_state_574)
    _ => Error
  }
}

fn yy_state_569(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_570)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_570(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_571)
    _ => Error
  }
}

fn yy_state_571(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_572)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_572(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_573)
    _ => Error
  }
}

fn yy_state_573(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_enum_variant, yy_action_72)
}

fn yy_state_574(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_575)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_575(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_576)
    _ => Error
  }
}

fn yy_state_576(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_enum_variant, yy_action_71)
}

fn yy_state_577(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_enum_variants, yy_action_70)
}

fn yy_state_578(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    NT_item_semicolon => Shift(yy_state_579)
    T_RBRACE => Reduce(1, NT_enum_variants, yy_action_69)
    _ => Error
  }
}

fn yy_state_579(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_567)
    NT_enum_variant => Shift(yy_state_580)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_enum_variants, yy_action_68)
    _ => Error
  }
}

fn yy_state_580(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_enum_variants, yy_action_67)
}

fn yy_state_581(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_582)
    _ => Error
  }
}

fn yy_state_582(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_enum_declaration, yy_action_66)
}

fn yy_state_583(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_584)
    _ => Error
  }
}

fn yy_state_584(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_585)
    _ => Error
  }
}

fn yy_state_585(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_586)
    T_IDENT | T_TYPE | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_586(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_587)
    T_TYPE => Shift(yy_state_590)
    NT_field_declaration => Shift(yy_state_594)
    NT_type_member_declaration => Shift(yy_state_595)
    NT_struct_member => Shift(yy_state_596)
    NT_non_empty_struct_members => Shift(yy_state_597)
    NT_struct_members => Shift(yy_state_600)
    T_RBRACE => Reduce(0, NT_struct_members, yy_action_65)
    _ => Error
  }
}

fn yy_state_587(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_588)
    _ => Error
  }
}

fn yy_state_588(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_589)
    _ => Error
  }
}

fn yy_state_589(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_field_declaration, yy_action_64)
}

fn yy_state_590(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_591)
    _ => Error
  }
}

fn yy_state_591(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_592)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_type_member_declaration, yy_action_63)
    _ => Error
  }
}

fn yy_state_592(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    NT_kind => Shift(yy_state_593)
    _ => Error
  }
}

fn yy_state_593(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_member_declaration, yy_action_62)
}

fn yy_state_594(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_61)
}

fn yy_state_595(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_60)
}

fn yy_state_596(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_members, yy_action_59)
}

fn yy_state_597(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_402)
    T_SEMICOLON => Shift(yy_state_403)
    NT_item_semicolon => Shift(yy_state_598)
    T_RBRACE => Reduce(1, NT_struct_members, yy_action_58)
    _ => Error
  }
}

fn yy_state_598(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_587)
    T_TYPE => Shift(yy_state_590)
    NT_field_declaration => Shift(yy_state_594)
    NT_type_member_declaration => Shift(yy_state_595)
    NT_struct_member => Shift(yy_state_599)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_struct_members, yy_action_57)
    _ => Error
  }
}

fn yy_state_599(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_members, yy_action_56)
}

fn yy_state_600(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_601)
    _ => Error
  }
}

fn yy_state_601(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_struct_declaration, yy_action_55)
}

fn yy_state_602(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_603)
    _ => Error
  }
}

fn yy_state_603(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_604)
    T_COLON | T_EQUAL => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_604(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_605)
    NT_type_alias_result_kind_opt => Shift(yy_state_607)
    T_EQUAL => Reduce(0, NT_type_alias_result_kind_opt, yy_action_54)
    _ => Error
  }
}

fn yy_state_605(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_52)
    T_LBRACKET => Shift(yy_state_55)
    T_KIND_EFFECT => Shift(yy_state_60)
    T_KIND_TYPE => Shift(yy_state_61)
    NT_kind => Shift(yy_state_606)
    _ => Error
  }
}

fn yy_state_606(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_alias_result_kind_opt, yy_action_53)
}

fn yy_state_607(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_608)
    _ => Error
  }
}

fn yy_state_608(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    T_LBRACE => Shift(yy_state_609)
    NT_type => Shift(yy_state_612)
    NT_type_alias_body => Shift(yy_state_613)
    _ => Error
  }
}

fn yy_state_609(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    NT_type => Shift(yy_state_16)
    NT_non_empty_type_list => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_610)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_366)
    _ => Error
  }
}

fn yy_state_610(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_611)
    _ => Error
  }
}

fn yy_state_611(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_body, yy_action_52)
}

fn yy_state_612(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_alias_body, yy_action_51)
}

fn yy_state_613(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type_alias_declaration, yy_action_50)
}

fn yy_state_614(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE => Shift(yy_state_615)
    _ => Error
  }
}

fn yy_state_615(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_616)
    _ => Error
  }
}

fn yy_state_616(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_617)
    T_COLON => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_617(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_618)
    _ => Error
  }
}

fn yy_state_618(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_EFFECT => Shift(yy_state_619)
    T_KIND_TYPE => Shift(yy_state_620)
    NT_external_type_result_kind => Shift(yy_state_621)
    _ => Error
  }
}

fn yy_state_619(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_external_type_result_kind, yy_action_49)
}

fn yy_state_620(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_external_type_result_kind, yy_action_48)
}

fn yy_state_621(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_external_type_declaration, yy_action_47)
}

fn yy_state_622(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_46)
}

fn yy_state_623(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_45)
}

fn yy_state_624(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_44)
}

fn yy_state_625(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_43)
}

fn yy_state_626(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_42)
}

fn yy_state_627(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_41)
}

fn yy_state_628(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_40)
}

fn yy_state_629(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_public_top_level_declaration, yy_action_39)
}

fn yy_state_630(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_38)
}

fn yy_state_631(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_632)
    _ => Error
  }
}

fn yy_state_632(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_633)
    T_DOTLBRACE => Shift(yy_state_635)
    T_DOTSTAR => Shift(yy_state_643)
    NT_module_alias => Shift(yy_state_644)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_NEWLINE => Reduce(2, NT_import_declaration, yy_action_37)
    _ => Error
  }
}

fn yy_state_633(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_634)
    _ => Error
  }
}

fn yy_state_634(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_alias, yy_action_36)
}

fn yy_state_635(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_636)
    NT_import_item => Shift(yy_state_637)
    NT_non_empty_import_item_list => Shift(yy_state_638)
    NT_import_item_list => Shift(yy_state_641)
    T_RBRACE => Reduce(0, NT_import_item_list, yy_action_35)
    _ => Error
  }
}

fn yy_state_636(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_item, yy_action_34)
}

fn yy_state_637(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_import_item_list, yy_action_33)
}

fn yy_state_638(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_81)
    T_COMMA => Shift(yy_state_82)
    NT_layout_list_separator => Shift(yy_state_639)
    T_RBRACE => Reduce(1, NT_import_item_list, yy_action_32)
    _ => Error
  }
}

fn yy_state_639(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_636)
    NT_import_item => Shift(yy_state_640)
    T_RBRACE | T_COMMA | T_LAYOUT_NEWLINE => Reduce(2, NT_non_empty_import_item_list, yy_action_31)
    _ => Error
  }
}

fn yy_state_640(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_import_item_list, yy_action_30)
}

fn yy_state_641(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_642)
    _ => Error
  }
}

fn yy_state_642(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_declaration, yy_action_29)
}

fn yy_state_643(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_declaration, yy_action_28)
}

fn yy_state_644(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_declaration, yy_action_27)
}

fn yy_state_645(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_646)
    T_OFFER => Shift(yy_state_652)
    T_FN => Shift(yy_state_667)
    T_EFFECT => Shift(yy_state_676)
    T_ENUM => Shift(yy_state_682)
    T_STRUCT => Shift(yy_state_688)
    T_TYPE => Shift(yy_state_694)
    T_EXTERN => Shift(yy_state_700)
    NT_public_offer_value_declaration => Shift(yy_state_706)
    NT_public_top_level_let_declaration => Shift(yy_state_707)
    NT_public_function_declaration => Shift(yy_state_708)
    NT_public_type_alias_declaration => Shift(yy_state_709)
    NT_public_external_type_declaration => Shift(yy_state_710)
    NT_public_effect_declaration => Shift(yy_state_711)
    NT_public_enum_declaration => Shift(yy_state_712)
    NT_public_struct_declaration => Shift(yy_state_713)
    NT_public_top_level_declaration => Shift(yy_state_714)
    T_IMPORT => Shift(yy_state_715)
    _ => Error
  }
}

fn yy_state_646(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_647)
    _ => Error
  }
}

fn yy_state_647(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_648)
    _ => Error
  }
}

fn yy_state_648(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_649)
    _ => Error
  }
}

fn yy_state_649(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_650)
    _ => Error
  }
}

fn yy_state_650(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_651)
    _ => Error
  }
}

fn yy_state_651(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_NEWLINE => Reduce(6, NT_public_top_level_let_declaration, yy_action_26)
    _ => Error
  }
}

fn yy_state_652(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_653)
    T_FN => Shift(yy_state_658)
    _ => Error
  }
}

fn yy_state_653(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_654)
    _ => Error
  }
}

fn yy_state_654(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_655)
    _ => Error
  }
}

fn yy_state_655(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_656)
    _ => Error
  }
}

fn yy_state_656(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_117)
    T_BUILTIN => Shift(yy_state_121)
    T_FN => Shift(yy_state_125)
    NT_function_literal_open => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_150)
    T_HANDLE => Shift(yy_state_153)
    T_MATCH => Shift(yy_state_154)
    T_IF => Shift(yy_state_155)
    T_DERIVE => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_169)
    NT_builtin_expression => Shift(yy_state_170)
    NT_derive_expression => Shift(yy_state_171)
    T_LBRACKET => Shift(yy_state_172)
    NT_function_literal => Shift(yy_state_175)
    NT_handler_expression => Shift(yy_state_176)
    NT_match_expression => Shift(yy_state_177)
    NT_if_expression => Shift(yy_state_178)
    NT_block_expression => Shift(yy_state_179)
    T_LPAREN => Shift(yy_state_180)
    T_FALSE => Shift(yy_state_182)
    T_TRUE => Shift(yy_state_183)
    T_CHAR => Shift(yy_state_184)
    T_STRING => Shift(yy_state_185)
    T_DOUBLE => Shift(yy_state_186)
    T_INT => Shift(yy_state_187)
    NT_owner_path_expression => Shift(yy_state_188)
    NT_identifier => Shift(yy_state_197)
    NT_non_owner_primary_expression => Shift(yy_state_211)
    NT_owner_expression => Shift(yy_state_212)
    NT_member_expression => Shift(yy_state_219)
    NT_value_postfix_expression => Shift(yy_state_220)
    NT_postfix_expression => Shift(yy_state_227)
    T_BANG => Shift(yy_state_228)
    T_MINUS => Shift(yy_state_230)
    T_IDENT => Shift(yy_state_232)
    NT_unary_expression => Shift(yy_state_233)
    T_VALUE_IDENTIFIER_SLOT => Shift(yy_state_263)
    NT_expression => Shift(yy_state_657)
    _ => Error
  }
}

fn yy_state_657(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_235)
    T_SLASH => Shift(yy_state_237)
    T_STAR => Shift(yy_state_239)
    T_MINUS => Shift(yy_state_241)
    T_PLUS => Shift(yy_state_243)
    T_GTEQ => Shift(yy_state_245)
    T_GT => Shift(yy_state_247)
    T_LTEQ => Shift(yy_state_249)
    T_LT => Shift(yy_state_251)
    T_BANGEQ => Shift(yy_state_253)
    T_EQEQ => Shift(yy_state_255)
    T_AMPAMP => Shift(yy_state_257)
    T_BARBAR => Shift(yy_state_259)
    T_PIPE => Shift(yy_state_261)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_NEWLINE => Reduce(6, NT_public_offer_value_declaration, yy_action_25)
    _ => Error
  }
}

fn yy_state_658(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_659)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_659(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_660)
    _ => Error
  }
}

fn yy_state_660(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_494)
    NT_parameters => Shift(yy_state_661)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_661(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_662)
    _ => Error
  }
}

fn yy_state_662(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_663)
    _ => Error
  }
}

fn yy_state_663(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_664)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_664(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_665)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_665(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_666)
    _ => Error
  }
}

fn yy_state_666(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_public_function_declaration, yy_action_23)
}

fn yy_state_667(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_668)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_668(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_669)
    _ => Error
  }
}

fn yy_state_669(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_494)
    NT_parameters => Shift(yy_state_670)
    T_LPAREN => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_670(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_671)
    _ => Error
  }
}

fn yy_state_671(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    NT_type => Shift(yy_state_672)
    _ => Error
  }
}

fn yy_state_672(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_24)
    NT_effect_annotation => Shift(yy_state_96)
    NT_effect_annotation_opt => Shift(yy_state_673)
    T_LBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_effect_annotation_opt, yy_action_361)
    _ => Error
  }
}

fn yy_state_673(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_114)
    NT_layout_continuation_opt => Shift(yy_state_674)
    T_LBRACE => Reduce(0, NT_layout_continuation_opt, yy_action_367)
    _ => Error
  }
}

fn yy_state_674(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_150)
    NT_block_expression => Shift(yy_state_675)
    _ => Error
  }
}

fn yy_state_675(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_public_function_declaration, yy_action_21)
}

fn yy_state_676(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_677)
    _ => Error
  }
}

fn yy_state_677(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_678)
    _ => Error
  }
}

fn yy_state_678(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_679)
    T_IDENT | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_679(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_543)
    NT_effect_operation => Shift(yy_state_557)
    NT_non_empty_effect_operations => Shift(yy_state_558)
    NT_effect_operations => Shift(yy_state_680)
    T_RBRACE => Reduce(0, NT_effect_operations, yy_action_81)
    _ => Error
  }
}

fn yy_state_680(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_681)
    _ => Error
  }
}

fn yy_state_681(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_effect_declaration, yy_action_20)
}

fn yy_state_682(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_683)
    _ => Error
  }
}

fn yy_state_683(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_684)
    _ => Error
  }
}

fn yy_state_684(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_685)
    T_IDENT | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_685(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_567)
    NT_enum_variant => Shift(yy_state_577)
    NT_non_empty_enum_variants => Shift(yy_state_578)
    NT_enum_variants => Shift(yy_state_686)
    T_RBRACE => Reduce(0, NT_enum_variants, yy_action_73)
    _ => Error
  }
}

fn yy_state_686(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_687)
    _ => Error
  }
}

fn yy_state_687(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_enum_declaration, yy_action_19)
}

fn yy_state_688(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_689)
    _ => Error
  }
}

fn yy_state_689(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    NT_type_parameter_bracket_list => Shift(yy_state_530)
    T_LAYOUT_NEWLINE => Shift(yy_state_534)
    T_LBRACE => Shift(yy_state_540)
    NT_nominal_body_open => Shift(yy_state_690)
    _ => Error
  }
}

fn yy_state_690(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_691)
    T_IDENT | T_TYPE | T_RBRACE | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_691(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_identifier => Shift(yy_state_587)
    T_TYPE => Shift(yy_state_590)
    NT_field_declaration => Shift(yy_state_594)
    NT_type_member_declaration => Shift(yy_state_595)
    NT_struct_member => Shift(yy_state_596)
    NT_non_empty_struct_members => Shift(yy_state_597)
    NT_struct_members => Shift(yy_state_692)
    T_RBRACE => Reduce(0, NT_struct_members, yy_action_65)
    _ => Error
  }
}

fn yy_state_692(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_693)
    _ => Error
  }
}

fn yy_state_693(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_struct_declaration, yy_action_18)
}

fn yy_state_694(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_695)
    _ => Error
  }
}

fn yy_state_695(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_696)
    T_COLON | T_EQUAL => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_696(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_605)
    NT_type_alias_result_kind_opt => Shift(yy_state_697)
    T_EQUAL => Reduce(0, NT_type_alias_result_kind_opt, yy_action_54)
    _ => Error
  }
}

fn yy_state_697(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_698)
    _ => Error
  }
}

fn yy_state_698(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_13)
    T_LPAREN => Shift(yy_state_20)
    T_IDENT => Shift(yy_state_28)
    NT_qualified_type_name => Shift(yy_state_31)
    NT_type_primary => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_35)
    NT_type_application => Shift(yy_state_39)
    NT_function_type => Shift(yy_state_45)
    NT_type_lambda => Shift(yy_state_46)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_47)
    T_LBRACKET => Shift(yy_state_48)
    T_LBRACE => Shift(yy_state_609)
    NT_type => Shift(yy_state_612)
    NT_type_alias_body => Shift(yy_state_699)
    _ => Error
  }
}

fn yy_state_699(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_type_alias_declaration, yy_action_17)
}

fn yy_state_700(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE => Shift(yy_state_701)
    _ => Error
  }
}

fn yy_state_701(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_72)
    NT_identifier => Shift(yy_state_702)
    _ => Error
  }
}

fn yy_state_702(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_48)
    T_LAYOUT_NEWLINE => Shift(yy_state_489)
    NT_type_parameter_bracket_list => Shift(yy_state_491)
    NT_type_parameters => Shift(yy_state_703)
    T_COLON => Reduce(0, NT_type_parameters, yy_action_103)
    _ => Error
  }
}

fn yy_state_703(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_704)
    _ => Error
  }
}

fn yy_state_704(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_EFFECT => Shift(yy_state_619)
    T_KIND_TYPE => Shift(yy_state_620)
    NT_external_type_result_kind => Shift(yy_state_705)
    _ => Error
  }
}

fn yy_state_705(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_external_type_declaration, yy_action_16)
}

fn yy_state_706(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_15)
}

fn yy_state_707(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_14)
}

fn yy_state_708(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_13)
}

fn yy_state_709(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_12)
}

fn yy_state_710(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_11)
}

fn yy_state_711(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_10)
}

fn yy_state_712(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_9)
}

fn yy_state_713(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_8)
}

fn yy_state_714(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declaration, yy_action_7)
}

fn yy_state_715(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_716)
    _ => Error
  }
}

fn yy_state_716(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOTLBRACE => Shift(yy_state_717)
    _ => Error
  }
}

fn yy_state_717(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_636)
    NT_import_item => Shift(yy_state_637)
    NT_non_empty_import_item_list => Shift(yy_state_638)
    NT_import_item_list => Shift(yy_state_718)
    T_RBRACE => Reduce(0, NT_import_item_list, yy_action_35)
    _ => Error
  }
}

fn yy_state_718(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_719)
    _ => Error
  }
}

fn yy_state_719(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_import_declaration, yy_action_6)
}

fn yy_state_720(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_721)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_721(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    NT_top_level_declarations => Shift(yy_state_722)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB => Reduce(0, NT_top_level_declarations, yy_action_5)
    _ => Error
  }
}

fn yy_state_722(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_10)
    T_OFFER => Shift(yy_state_482)
    T_FN => Shift(yy_state_527)
    T_EFFECT => Shift(yy_state_528)
    T_ENUM => Shift(yy_state_563)
    T_STRUCT => Shift(yy_state_583)
    T_TYPE => Shift(yy_state_602)
    T_EXTERN => Shift(yy_state_614)
    NT_offer_value_declaration => Shift(yy_state_622)
    NT_top_level_let_declaration => Shift(yy_state_623)
    NT_function_declaration => Shift(yy_state_624)
    NT_type_alias_declaration => Shift(yy_state_625)
    NT_external_type_declaration => Shift(yy_state_626)
    NT_effect_declaration => Shift(yy_state_627)
    NT_enum_declaration => Shift(yy_state_628)
    NT_struct_declaration => Shift(yy_state_629)
    NT_non_public_top_level_declaration => Shift(yy_state_630)
    T_PUB => Shift(yy_state_723)
    NT_top_level_declaration => Shift(yy_state_724)
    T_EOF => Reduce(3, NT_module_body, yy_action_4)
    _ => Error
  }
}

fn yy_state_723(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_646)
    T_OFFER => Shift(yy_state_652)
    T_FN => Shift(yy_state_667)
    T_EFFECT => Shift(yy_state_676)
    T_ENUM => Shift(yy_state_682)
    T_STRUCT => Shift(yy_state_688)
    T_TYPE => Shift(yy_state_694)
    T_EXTERN => Shift(yy_state_700)
    NT_public_offer_value_declaration => Shift(yy_state_706)
    NT_public_top_level_let_declaration => Shift(yy_state_707)
    NT_public_function_declaration => Shift(yy_state_708)
    NT_public_type_alias_declaration => Shift(yy_state_709)
    NT_public_external_type_declaration => Shift(yy_state_710)
    NT_public_effect_declaration => Shift(yy_state_711)
    NT_public_enum_declaration => Shift(yy_state_712)
    NT_public_struct_declaration => Shift(yy_state_713)
    NT_public_top_level_declaration => Shift(yy_state_714)
    _ => Error
  }
}

fn yy_state_724(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_725)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_725(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB => Reduce(3, NT_top_level_declarations, yy_action_3)
    _ => Error
  }
}

fn yy_state_726(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_727)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_727(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_10)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_OFFER => Shift(yy_state_482)
    T_FN => Shift(yy_state_527)
    T_EFFECT => Shift(yy_state_528)
    T_ENUM => Shift(yy_state_563)
    T_STRUCT => Shift(yy_state_583)
    T_TYPE => Shift(yy_state_602)
    T_EXTERN => Shift(yy_state_614)
    NT_offer_value_declaration => Shift(yy_state_622)
    NT_top_level_let_declaration => Shift(yy_state_623)
    NT_function_declaration => Shift(yy_state_624)
    NT_type_alias_declaration => Shift(yy_state_625)
    NT_external_type_declaration => Shift(yy_state_626)
    NT_effect_declaration => Shift(yy_state_627)
    NT_enum_declaration => Shift(yy_state_628)
    NT_struct_declaration => Shift(yy_state_629)
    NT_non_public_top_level_declaration => Shift(yy_state_630)
    T_IMPORT => Shift(yy_state_631)
    T_PUB => Shift(yy_state_645)
    NT_top_level_declaration => Shift(yy_state_720)
    NT_public_import_declaration => Shift(yy_state_726)
    NT_module_body => Shift(yy_state_728)
    NT_import_declaration => Shift(yy_state_729)
    T_EOF => Reduce(0, NT_module_body, yy_action_368)
    _ => Error
  }
}

fn yy_state_728(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_module_body, yy_action_2)
}

fn yy_state_729(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_730)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_NEWLINE => Reduce(0, NT_layout_semicolons, yy_action_369)
    _ => Error
  }
}

fn yy_state_730(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_10)
    T_LAYOUT_NEWLINE => Shift(yy_state_406)
    T_OFFER => Shift(yy_state_482)
    T_FN => Shift(yy_state_527)
    T_EFFECT => Shift(yy_state_528)
    T_ENUM => Shift(yy_state_563)
    T_STRUCT => Shift(yy_state_583)
    T_TYPE => Shift(yy_state_602)
    T_EXTERN => Shift(yy_state_614)
    NT_offer_value_declaration => Shift(yy_state_622)
    NT_top_level_let_declaration => Shift(yy_state_623)
    NT_function_declaration => Shift(yy_state_624)
    NT_type_alias_declaration => Shift(yy_state_625)
    NT_external_type_declaration => Shift(yy_state_626)
    NT_effect_declaration => Shift(yy_state_627)
    NT_enum_declaration => Shift(yy_state_628)
    NT_struct_declaration => Shift(yy_state_629)
    NT_non_public_top_level_declaration => Shift(yy_state_630)
    T_IMPORT => Shift(yy_state_631)
    T_PUB => Shift(yy_state_645)
    NT_top_level_declaration => Shift(yy_state_720)
    NT_public_import_declaration => Shift(yy_state_726)
    NT_import_declaration => Shift(yy_state_729)
    NT_module_body => Shift(yy_state_731)
    T_EOF => Reduce(0, NT_module_body, yy_action_368)
    _ => Error
  }
}

fn yy_state_731(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_module_body, yy_action_1)
}

fn yy_state_732(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_733)
    _ => Error
  }
}

fn yy_state_733(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_file, yy_action_0)
}

fn[T] yy_parse(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  start : YYState,
  return_ : (YYObj) -> T,
  initial_pos? : SourceSpan,
) -> T raise ParseError {
  let mut cursor = 0
  let mut state_stack : @list.List[YYState] = @list.cons(start, @list.empty())
  let data_stack : Array[(YYObj, SourceSpan, SourceSpan)] = []
  let mut last_pos = initial_pos.unwrap_or(tokens[0].1)
  let mut state = start
  let mut lookahead : Option[(YYSymbol, (YYObj, SourceSpan, SourceSpan), Token?)] = None
  let mut last_shifted_state_stack = state_stack
  while true {
    let decision = match state(EOI) {
      ReduceNoLookahead(_) | Accept as t => t
      _ => {
        match lookahead {
          Some(la) => state(la.0)
          None => {
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (symbol, data) = yy_input(token, start_pos, end_pos)
              lookahead = Some((symbol, (data, start_pos, end_pos), Some(token)))
              state(symbol)
            } else {
              lookahead = Some((EOI, (YYObj_Void, last_pos, last_pos), None))
              state(EOI)
            }
          }
        }
      }
    }
    match decision {
      Accept => return return_(data_stack.unsafe_pop().0)
      Shift(next_state) => {
        guard lookahead is Some(la)
        data_stack.push(la.1)
        state_stack = @list.cons(next_state, state_stack)
        last_shifted_state_stack = state_stack
        state = next_state
        last_pos = la.1.2
        lookahead = None
      }
      Reduce(count, symbol, action)
      | ReduceNoLookahead(count, symbol, action) => {
        for count = count, symbol = symbol, action = action {
          let args = data_stack[data_stack.length() - count:]
          let data = action(last_pos, args)
          let (start_pos, end_pos) = if args.length() == 0 {
            (last_pos, last_pos)
          } else {
            (args[0].1, args[args.length() - 1].2)
          }
          for _ in 0..<count {
            ignore(data_stack.unsafe_pop())
            state_stack = state_stack.unsafe_tail()
          }
          state = state_stack.unsafe_head()
          data_stack.push((data, start_pos, end_pos))
          match state(symbol) {
            Accept => return return_(data_stack.unsafe_pop().0)
            Shift(next_state) => {
              state_stack = @list.cons(next_state, state_stack)
              state = next_state
              break ()
            }
            Reduce(count, symbol, action)
            | ReduceNoLookahead(count, symbol, action) => continue count, symbol, action
            _ => panic()
          }
        }
      }
      Error => {
        let (_, (_, start_pos, end_pos), token) = lookahead.unwrap()
        error(last_shifted_state_stack, token, (start_pos, end_pos))
      }
    }
  }
  panic()
}

fn error(stack : @list.List[YYState], token : Token?, loc : (SourceSpan, SourceSpan)) -> Unit raise ParseError {
  let expected = []
  fn try_add(symbol : YYSymbol, kind : TokenKind) {
    fn go(stack : @list.List[YYState]) {
      match stack {
        Empty => ()
        More(state, ..) => {
          match state(symbol) {
            Accept | Shift(_) => expected.push(kind)
            Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
              fn inner_go(stack : @list.List[YYState], count, symbol) {
                let stack = stack.drop(count)
                guard stack is More(state, ..)
                match state(symbol) {
                  Shift(state) => go(@list.cons(state, stack))
                  Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => inner_go(stack, count, symbol)
                  _ => panic()
                }
              }
              inner_go(stack, count, symbol)
            }
            Error => ()
          }
        }
      }
    }
    go(stack)
  }
  for term in ([(T_INT, TK_INT), (T_DOUBLE, TK_DOUBLE), (T_STRING, TK_STRING), (T_CHAR, TK_CHAR), (T_IDENT, TK_IDENT), (T_RESERVED, TK_RESERVED), (T_EOF, TK_EOF), (T_FALSE, TK_FALSE), (T_TRUE, TK_TRUE), (T_STRUCT, TK_STRUCT), (T_ENUM, TK_ENUM), (T_EFFECT, TK_EFFECT), (T_FN, TK_FN), (T_LET, TK_LET), (T_TYPE, TK_TYPE), (T_KIND_TYPE, TK_KIND_TYPE), (T_KIND_EFFECT, TK_KIND_EFFECT), (T_OFFER, TK_OFFER), (T_AUTO, TK_AUTO), (T_IF, TK_IF), (T_ELSE, TK_ELSE), (T_MATCH, TK_MATCH), (T_HANDLE, TK_HANDLE), (T_WITH, TK_WITH), (T_FINAL, TK_FINAL), (T_DERIVE, TK_DERIVE), (T_BUILTIN, TK_BUILTIN), (T_EXTERN, TK_EXTERN), (T_MODULE, TK_MODULE), (T_IMPORT, TK_IMPORT), (T_AS, TK_AS), (T_PUB, TK_PUB), (T_PLUS, TK_PLUS), (T_MINUS, TK_MINUS), (T_STAR, TK_STAR), (T_SLASH, TK_SLASH), (T_PERCENT, TK_PERCENT), (T_EQEQ, TK_EQEQ), (T_BANGEQ, TK_BANGEQ), (T_LT, TK_LT), (T_LTEQ, TK_LTEQ), (T_GT, TK_GT), (T_GTEQ, TK_GTEQ), (T_AMPAMP, TK_AMPAMP), (T_BARBAR, TK_BARBAR), (T_BANG, TK_BANG), (T_PIPE, TK_PIPE), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_OWNER_LBRACKET, TK_OWNER_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR, TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR), (T_EMPTY_TYPE_PARAMETER_LIST_ERROR, TK_EMPTY_TYPE_PARAMETER_LIST_ERROR), (T_TYPE_IDENTIFIER_SLOT, TK_TYPE_IDENTIFIER_SLOT), (T_EFFECT_IDENTIFIER_SLOT, TK_EFFECT_IDENTIFIER_SLOT), (T_VALUE_IDENTIFIER_SLOT, TK_VALUE_IDENTIFIER_SLOT), (T_PATTERN_IDENTIFIER_SLOT, TK_PATTERN_IDENTIFIER_SLOT), (T_MISSING_TUPLE_TYPE_ITEM_ERROR, TK_MISSING_TUPLE_TYPE_ITEM_ERROR), (T_MISSING_TUPLE_EXPRESSION_ITEM_ERROR, TK_MISSING_TUPLE_EXPRESSION_ITEM_ERROR), (T_MISSING_TUPLE_PATTERN_ITEM_ERROR, TK_MISSING_TUPLE_PATTERN_ITEM_ERROR), (T_COMMA, TK_COMMA), (T_SEMICOLON, TK_SEMICOLON), (T_LAYOUT_NEWLINE, TK_LAYOUT_NEWLINE), (T_DOTSTAR, TK_DOTSTAR), (T_DOTLBRACE, TK_DOTLBRACE), (T_DOT, TK_DOT), (T_COLON, TK_COLON), (T_COLONCOLON, TK_COLONCOLON), (T_TIGHT_COLONCOLON, TK_TIGHT_COLONCOLON), (T_THIN_ARROW, TK_THIN_ARROW), (T_FAT_ARROW, TK_FAT_ARROW), (T_EQUAL, TK_EQUAL), (T_UNDERSCORE, TK_UNDERSCORE)] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

pub fn source_file(tokens : Array[(Token, SourceSpan, SourceSpan)], initial_pos? : SourceSpan) -> SourceFile raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    (it) => {
      guard it is YYObj_SourceFile(result)
      result
    },
    initial_pos?,
  )
}

fn _get_symbol_start_pos(args : ArrayView[(YYObj, SourceSpan, SourceSpan)], last_pos : SourceSpan) -> SourceSpan {
  if args.length() == 0 {
    last_pos
  } else {
    for i = 0; i < args.length(); i = i + 1 {
      let (_, start_pos, end_pos) = args[i]
      if start_pos == end_pos {
        continue
      }
      return start_pos
    }
    args[args.length() - 1].2
  }
}
