
pub(all) enum Token {
  INT(String)
  DOUBLE(String)
  STRING(String)
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
  BUILTIN
  EXTERN
  MODULE
  IMPORT
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
  COMMA
  SEMICOLON
  LAYOUT_SEMICOLON
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
    BUILTIN => TK_BUILTIN
    EXTERN => TK_EXTERN
    MODULE => TK_MODULE
    IMPORT => TK_IMPORT
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
    COMMA => TK_COMMA
    SEMICOLON => TK_SEMICOLON
    LAYOUT_SEMICOLON => TK_LAYOUT_SEMICOLON
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
  TK_BUILTIN
  TK_EXTERN
  TK_MODULE
  TK_IMPORT
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
  TK_COMMA
  TK_SEMICOLON
  TK_LAYOUT_SEMICOLON
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
      TK_BUILTIN => "\"builtin\""
      TK_EXTERN => "\"extern\""
      TK_MODULE => "\"module\""
      TK_IMPORT => "\"import\""
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
      TK_COMMA => "\",\""
      TK_SEMICOLON => "\";\""
      TK_LAYOUT_SEMICOLON => "LAYOUT_SEMICOLON"
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
      TK_INT => to_repr("INT")
      TK_DOUBLE => to_repr("DOUBLE")
      TK_STRING => to_repr("STRING")
      TK_IDENT => to_repr("IDENT")
      TK_RESERVED => to_repr("RESERVED")
      TK_EOF => to_repr("EOF")
      TK_FALSE => to_repr("false")
      TK_TRUE => to_repr("true")
      TK_STRUCT => to_repr("struct")
      TK_ENUM => to_repr("enum")
      TK_EFFECT => to_repr("effect")
      TK_FN => to_repr("fn")
      TK_LET => to_repr("let")
      TK_TYPE => to_repr("type")
      TK_KIND_TYPE => to_repr("Type")
      TK_KIND_EFFECT => to_repr("Effect")
      TK_OFFER => to_repr("offer")
      TK_AUTO => to_repr("auto")
      TK_IF => to_repr("if")
      TK_ELSE => to_repr("else")
      TK_MATCH => to_repr("match")
      TK_HANDLE => to_repr("handle")
      TK_WITH => to_repr("with")
      TK_FINAL => to_repr("final")
      TK_BUILTIN => to_repr("builtin")
      TK_EXTERN => to_repr("extern")
      TK_MODULE => to_repr("module")
      TK_IMPORT => to_repr("import")
      TK_PUB => to_repr("pub")
      TK_PLUS => to_repr("+")
      TK_MINUS => to_repr("-")
      TK_STAR => to_repr("*")
      TK_SLASH => to_repr("/")
      TK_PERCENT => to_repr("%")
      TK_EQEQ => to_repr("==")
      TK_BANGEQ => to_repr("!=")
      TK_LT => to_repr("<")
      TK_LTEQ => to_repr("<=")
      TK_GT => to_repr(">")
      TK_GTEQ => to_repr(">=")
      TK_AMPAMP => to_repr("&&")
      TK_BARBAR => to_repr("||")
      TK_BANG => to_repr("!")
      TK_PIPE => to_repr("|>")
      TK_LPAREN => to_repr("(")
      TK_RPAREN => to_repr(")")
      TK_LBRACE => to_repr("{")
      TK_RBRACE => to_repr("}")
      TK_LBRACKET => to_repr("[")
      TK_OWNER_LBRACKET => to_repr("owner [")
      TK_RBRACKET => to_repr("]")
      TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => to_repr("EMPTY_GENERIC_ARGUMENT_LIST_ERROR")
      TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => to_repr("EMPTY_TYPE_PARAMETER_LIST_ERROR")
      TK_TYPE_IDENTIFIER_SLOT => to_repr("TYPE_IDENTIFIER_SLOT")
      TK_EFFECT_IDENTIFIER_SLOT => to_repr("EFFECT_IDENTIFIER_SLOT")
      TK_COMMA => to_repr(",")
      TK_SEMICOLON => to_repr(";")
      TK_LAYOUT_SEMICOLON => to_repr("LAYOUT_SEMICOLON")
      TK_DOTSTAR => to_repr(".*")
      TK_DOTLBRACE => to_repr(".{")
      TK_DOT => to_repr(".")
      TK_COLON => to_repr(":")
      TK_COLONCOLON => to_repr("::")
      TK_TIGHT_COLONCOLON => to_repr("tight ::")
      TK_THIN_ARROW => to_repr("->")
      TK_FAT_ARROW => to_repr("=>")
      TK_EQUAL => to_repr("=")
      TK_UNDERSCORE => to_repr("_")
    }
}

pub suberror ParseError {
  UnexpectedToken(Token, (SourceSpan, SourceSpan), Array[TokenKind])
  UnexpectedEndOfInput(SourceSpan, Array[TokenKind])
} derive(Debug)

type YYObj = Error

priv suberror YYObj_Void

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

priv suberror YYObj_Array_ImportDeclaration_ {
  YYObj_Array_ImportDeclaration_(Array[ImportDeclaration])
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

priv suberror YYObj_ModulePath {
  YYObj_ModulePath(ModulePath)
}

priv suberror YYObj_SourceFile {
  YYObj_SourceFile(SourceFile)
}

priv suberror YYObj_EnumVariant {
  YYObj_EnumVariant(EnumVariant)
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

priv suberror YYObj_ParameterModifiers {
  YYObj_ParameterModifiers(ParameterModifiers)
}

priv suberror YYObj_StructLiteralField {
  YYObj_StructLiteralField(StructLiteralField)
}

priv suberror YYObj_StructPatternField {
  YYObj_StructPatternField(StructPatternField)
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
  T_BUILTIN
  T_EXTERN
  T_MODULE
  T_IMPORT
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
  T_COMMA
  T_SEMICOLON
  T_LAYOUT_SEMICOLON
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
  NT_module_declaration
  NT_module_path
  NT_non_empty_module_path
  NT_import_declarations
  NT_import_declaration
  NT_import_item_list
  NT_non_empty_import_item_list
  NT_import_item
  NT_identifier
  NT_top_level_declarations
  NT_top_level_declaration
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
  NT_type_parameter_bracket_list
  NT_non_empty_type_parameter_list
  NT_type_parameter
  NT_type
  NT_type_lambda
  NT_type_application
  NT_type_primary
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
  NT_handler_operation_head
  NT_handler_operation_type_binders
  NT_ident_bracket_list
  NT_handler_operation_owner_arguments
  NT_handler_operation_generic_arguments
  NT_handler_operation_arm_parameters
  NT_handler_payload_patterns
  NT_handler_final_branch
  NT_function_literal
  NT_function_literal_parameters
  NT_non_empty_function_literal_parameters
  NT_function_literal_parameter
  NT_function_literal_parameter_modifiers
  NT_return_annotation
  NT_builtin_expression
  NT_extern_expression
  NT_pattern
  NT_struct_pattern
  NT_variant_type_binders
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
// 95|    module_declaration layout_semicolons import_declarations top_level_declarations EOF {
// 96|    { module_path: $1, imports: $3, declarations: $4, loc: span($sloc) }
// 97|  }
fn yy_action_0(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePath(_dollar1)
  guard _args[2].0 is YYObj_Array_ImportDeclaration_(_dollar3)
  guard _args[3].0 is YYObj_Array_TopLevelDeclaration_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_SourceFile({(); 
    { module_path: _dollar1, imports: _dollar3, declarations: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 166|    top_level_declarations top_level_declaration layout_semicolons { comma_push($1, $2) }
fn yy_action_1(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopLevelDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_Array_TopLevelDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 170|    struct_declaration { Struct($1) }
fn yy_action_2(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 171|    enum_declaration { Enum($1) }
fn yy_action_3(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 172|    effect_declaration { Effect($1) }
fn yy_action_4(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 173|    external_type_declaration { ExternalType($1) }
fn yy_action_5(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ExternalTypeDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  ExternalType(_dollar1) })
}

// file:///./parser.mbty
// 174|    type_alias_declaration { TypeAlias($1) }
fn yy_action_6(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 175|    function_declaration { Function($1) }
fn yy_action_7(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 176|    top_level_let_declaration { Let($1) }
fn yy_action_8(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 177|    offer_value_declaration { Let($1) }
fn yy_action_9(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 178|    "pub" public_top_level_declaration { with_public_loc($2, span($sloc)) }
fn yy_action_10(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TopLevelDeclaration({();  with_public_loc(_dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 182|    public_struct_declaration { Struct($1) }
fn yy_action_11(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 183|    public_enum_declaration { Enum($1) }
fn yy_action_12(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 184|    public_effect_declaration { Effect($1) }
fn yy_action_13(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 185|    public_external_type_declaration { ExternalType($1) }
fn yy_action_14(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ExternalTypeDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  ExternalType(_dollar1) })
}

// file:///./parser.mbty
// 186|    public_type_alias_declaration { TypeAlias($1) }
fn yy_action_15(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 187|    public_function_declaration { Function($1) }
fn yy_action_16(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 188|    public_top_level_let_declaration { Let($1) }
fn yy_action_17(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 189|    public_offer_value_declaration { Let($1) }
fn yy_action_18(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 197|    "extern" "type" identifier type_parameters ":" external_type_result_kind { make_external_type(true, $3, $4, $6, span($sloc)) }
fn yy_action_19(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeParameter_(_dollar4)
  guard _args[5].0 is YYObj_ExternalTypeKind(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeDeclaration({();  make_external_type(true, _dollar3, _dollar4, _dollar6, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 212|    "type" identifier type_parameters type_alias_result_kind_opt "=" type_alias_body {
// 213|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, result_kind: $4, body: $6, loc: span($sloc) }
// 214|  }
fn yy_action_20(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 231|    "struct" identifier type_parameters "{" layout_semicolons struct_members "}" {
// 232|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, members: $6, loc: span($sloc) }
// 233|  }
fn yy_action_21(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_StructMember_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, members: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 294|    "enum" identifier type_parameters "{" layout_semicolons enum_variants "}" {
// 295|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, variants: $6, loc: span($sloc) }
// 296|  }
fn yy_action_22(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_EnumVariant_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, variants: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 326|    "effect" identifier type_parameters "{" layout_semicolons effect_operations "}" {
// 327|    { is_public: true, name: $2.name, name_loc: $2.loc, type_parameters: $3, operations: $6, loc: span($sloc) }
// 328|  }
fn yy_action_23(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_EffectOperationDeclaration_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, operations: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 369|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 370|    {
// 371|      is_public: true,
// 372|      is_offered: $1,
// 373|      type_parameters: $2,
// 374|      name: $3.name,
// 375|      name_loc: $3.loc,
// 376|      parameters: $4,
// 377|      return_type: $6,
// 378|      effect: effect_or_empty($7, $6),
// 379|      body: $8,
// 380|      loc: span($sloc),
// 381|    }
// 382|  }
fn yy_action_24(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_25(_last_pos, _args[0:1])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[7].0 is YYObj_Expr(_dollar8)
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
      body: _dollar8,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 369|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 370|    {
// 371|      is_public: true,
// 372|      is_offered: $1,
// 373|      type_parameters: $2,
// 374|      name: $3.name,
// 375|      name_loc: $3.loc,
// 376|      parameters: $4,
// 377|      return_type: $6,
// 378|      effect: effect_or_empty($7, $6),
// 379|      body: $8,
// 380|      loc: span($sloc),
// 381|    }
// 382|  }
fn yy_action_26(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_27(_last_pos, _args[0:2])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar3)
  guard _args[4].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar8)
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
      body: _dollar8,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 442|    "offer" identifier ":" type "=" expression {
// 443|    { is_public: true, is_offered: true, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 444|  }
fn yy_action_28(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 421|    "let" identifier ":" type "=" expression {
// 422|    { is_public: true, is_offered: false, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 423|  }
fn yy_action_29(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 193|    "extern" "type" identifier type_parameters ":" external_type_result_kind { make_external_type(false, $3, $4, $6, span($sloc)) }
fn yy_action_30(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeParameter_(_dollar4)
  guard _args[5].0 is YYObj_ExternalTypeKind(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeDeclaration({();  make_external_type(false, _dollar3, _dollar4, _dollar6, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 201|    "Type" { Type(loc=span($sloc)) }
fn yy_action_31(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeKind({();  Type(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 202|    "Effect" { Effect(loc=span($sloc)) }
fn yy_action_32(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ExternalTypeKind({();  Effect(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 206|    "type" identifier type_parameters type_alias_result_kind_opt "=" type_alias_body {
// 207|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, result_kind: $4, body: $6, loc: span($sloc) }
// 208|  }
fn yy_action_33(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 218|    type { TypeBody($1) }
fn yy_action_34(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_TypeAliasBody({();  TypeBody(_dollar1) })
}

// file:///./parser.mbty
// 219|    "{" type_list "}" {
// 220|    EffectBody(effect_set($2, span($sloc)))
// 221|  }
fn yy_action_35(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasBody({(); 
    EffectBody(effect_set(_dollar2, span((_symbol_start_pos, _end_pos))))
  })
}

// file:///./parser.mbty
// 1025|    ":" kind { Some($2) }
fn yy_action_36(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  YYObj_Kind_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 1024|    { None }
fn yy_action_37(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind_({();  None })
}

// file:///./parser.mbty
// 225|    "struct" identifier type_parameters "{" layout_semicolons struct_members "}" {
// 226|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, members: $6, loc: span($sloc) }
// 227|  }
fn yy_action_38(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_StructMember_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, members: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 243|    non_empty_struct_members item_semicolon struct_member { comma_push($1, $3) }
fn yy_action_39(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  guard _args[2].0 is YYObj_StructMember(_dollar3)
  YYObj_Array_StructMember_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 244|    non_empty_struct_members item_semicolon { $1 }
fn yy_action_40(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  YYObj_Array_StructMember_({();  _dollar1 })
}

// file:///./parser.mbty
// 238|    non_empty_struct_members { $1 }
fn yy_action_41(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  YYObj_Array_StructMember_({();  _dollar1 })
}

// file:///./parser.mbty
// 242|    struct_member { [ $1 ] }
fn yy_action_42(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructMember(_dollar1)
  YYObj_Array_StructMember_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 248|    type_member_declaration { TypeMember($1) }
fn yy_action_43(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeMemberDeclaration(_dollar1)
  YYObj_StructMember({();  TypeMember(_dollar1) })
}

// file:///./parser.mbty
// 249|    field_declaration { Field($1) }
fn yy_action_44(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FieldDeclaration(_dollar1)
  YYObj_StructMember({();  Field(_dollar1) })
}

// file:///./parser.mbty
// 256|    "type" identifier ":" kind {
// 257|    { name: $2.name, name_loc: $2.loc, kind: Some($4), loc: span($sloc) }
// 258|  }
fn yy_action_45(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Kind(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeMemberDeclaration({(); 
    { name: _dollar2.name, name_loc: _dollar2.loc, kind: Some(_dollar4), loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 253|    "type" identifier {
// 254|    { name: $2.name, name_loc: $2.loc, kind: None, loc: span($sloc) }
// 255|  }
fn yy_action_46(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeMemberDeclaration({(); 
    { name: _dollar2.name, name_loc: _dollar2.loc, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 282|    identifier ":" type {
// 283|    { name: $1.name, name_loc: $1.loc, type_: $3, loc: span($sloc) }
// 284|  }
fn yy_action_47(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FieldDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 237|    { [] }
fn yy_action_48(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructMember_({();  [] })
}

// file:///./parser.mbty
// 288|    "enum" identifier type_parameters "{" layout_semicolons enum_variants "}" {
// 289|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, variants: $6, loc: span($sloc) }
// 290|  }
fn yy_action_49(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_EnumVariant_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, variants: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 306|    non_empty_enum_variants item_semicolon enum_variant { comma_push($1, $3) }
fn yy_action_50(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  guard _args[2].0 is YYObj_EnumVariant(_dollar3)
  YYObj_Array_EnumVariant_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 307|    non_empty_enum_variants item_semicolon { $1 }
fn yy_action_51(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  YYObj_Array_EnumVariant_({();  _dollar1 })
}

// file:///./parser.mbty
// 301|    non_empty_enum_variants { $1 }
fn yy_action_52(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  YYObj_Array_EnumVariant_({();  _dollar1 })
}

// file:///./parser.mbty
// 305|    enum_variant { [ $1 ] }
fn yy_action_53(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumVariant(_dollar1)
  YYObj_Array_EnumVariant_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 311|    identifier "(" type_list ")" {
// 312|    { name: $1.name, name_loc: $1.loc, type_parameters: [], payload: $3, loc: span($sloc) }
// 313|  }
fn yy_action_54(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: [], payload: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 314|    identifier type_parameter_bracket_list "(" type_list ")" {
// 315|    { name: $1.name, name_loc: $1.loc, type_parameters: $2, payload: $4, loc: span($sloc) }
// 316|  }
fn yy_action_55(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: _dollar2, payload: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 300|    { [] }
fn yy_action_56(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EnumVariant_({();  [] })
}

// file:///./parser.mbty
// 320|    "effect" identifier type_parameters "{" layout_semicolons effect_operations "}" {
// 321|    { is_public: false, name: $2.name, name_loc: $2.loc, type_parameters: $3, operations: $6, loc: span($sloc) }
// 322|  }
fn yy_action_57(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Array_EffectOperationDeclaration_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_parameters: _dollar3, operations: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 338|    non_empty_effect_operations item_semicolon effect_operation { comma_push($1, $3) }
fn yy_action_58(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  guard _args[2].0 is YYObj_EffectOperationDeclaration(_dollar3)
  YYObj_Array_EffectOperationDeclaration_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 339|    non_empty_effect_operations item_semicolon { $1 }
fn yy_action_59(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  _dollar1 })
}

// file:///./parser.mbty
// 333|    non_empty_effect_operations { $1 }
fn yy_action_60(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  _dollar1 })
}

// file:///./parser.mbty
// 337|    effect_operation { [ $1 ] }
fn yy_action_61(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectOperationDeclaration(_dollar1)
  YYObj_Array_EffectOperationDeclaration_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 343|    identifier "(" type_list ")" "->" type {
// 344|    { name: $1.name, name_loc: $1.loc, type_parameters: [], payload: $3, result: $6, loc: span($sloc) }
// 345|  }
fn yy_action_62(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: [], payload: _dollar3, result: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 346|    identifier type_parameter_bracket_list "(" type_list ")" "->" type {
// 347|    { name: $1.name, name_loc: $1.loc, type_parameters: $2, payload: $4, result: $7, loc: span($sloc) }
// 348|  }
fn yy_action_63(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, type_parameters: _dollar2, payload: _dollar4, result: _dollar7, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 332|    { [] }
fn yy_action_64(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EffectOperationDeclaration_({();  [] })
}

// file:///./parser.mbty
// 415|    "let" identifier ":" type "=" expression {
// 416|    { is_public: false, is_offered: false, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 417|  }
fn yy_action_65(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 352|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 353|    {
// 354|      is_public: false,
// 355|      is_offered: $1,
// 356|      type_parameters: $2,
// 357|      name: $3.name,
// 358|      name_loc: $3.loc,
// 359|      parameters: $4,
// 360|      return_type: $6,
// 361|      effect: effect_or_empty($7, $6),
// 362|      body: $8,
// 363|      loc: span($sloc),
// 364|    }
// 365|  }
fn yy_action_66(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_25(_last_pos, _args[0:1])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[7].0 is YYObj_Expr(_dollar8)
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
      body: _dollar8,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 386|    "fn" { false }
fn yy_action_25(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 352|    function_prefix type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 353|    {
// 354|      is_public: false,
// 355|      is_offered: $1,
// 356|      type_parameters: $2,
// 357|      name: $3.name,
// 358|      name_loc: $3.loc,
// 359|      parameters: $4,
// 360|      return_type: $6,
// 361|      effect: effect_or_empty($7, $6),
// 362|      body: $8,
// 363|      loc: span($sloc),
// 364|    }
// 365|  }
fn yy_action_67(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _sub_action_0_result = yy_action_27(_last_pos, _args[0:2])
  guard _sub_action_0_result is YYObj_Bool(_dollar1)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar3)
  guard _args[4].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_EffectTerm_(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar8)
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
      body: _dollar8,
      loc: span((_symbol_start_pos, _end_pos)),
    }
  })
}

// file:///./parser.mbty
// 387|    "offer" "fn" { true }
fn yy_action_27(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 391|    "(" ")" { [] }
fn yy_action_68(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Parameter_({();  [] })
}

// file:///./parser.mbty
// 392|    "(" non_empty_parameter_list ")" { $2 }
fn yy_action_69(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Parameter_(_dollar2)
  YYObj_Array_Parameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 397|    non_empty_parameter_list "," parameter { comma_push($1, $3) }
fn yy_action_70(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Parameter_(_dollar1)
  guard _args[2].0 is YYObj_Parameter(_dollar3)
  YYObj_Array_Parameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 396|    parameter { [ $1 ] }
fn yy_action_71(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Parameter(_dollar1)
  YYObj_Array_Parameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 401|    parameter_modifiers identifier ":" type {
// 402|    { is_auto: $1.is_auto, is_offered: $1.is_offered, name: $2.name, name_loc: $2.loc, type_: $4, loc: span($sloc) }
// 403|  }
fn yy_action_72(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 410|    "auto" "offer" { { is_auto: true, is_offered: true } }
fn yy_action_73(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 408|    "auto" { { is_auto: true, is_offered: false } }
fn yy_action_74(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: false } })
}

// file:///./parser.mbty
// 411|    "offer" "auto" { { is_auto: true, is_offered: true } }
fn yy_action_75(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 409|    "offer" { { is_auto: false, is_offered: true } }
fn yy_action_76(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: true } })
}

// file:///./parser.mbty
// 407|    { { is_auto: false, is_offered: false } }
fn yy_action_77(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: false } })
}

// file:///./parser.mbty
// 449|    type_parameter_bracket_list { $1 }
fn yy_action_78(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 436|    "offer" identifier ":" type "=" expression {
// 437|    { is_public: false, is_offered: true, name: $2.name, name_loc: $2.loc, type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 438|  }
fn yy_action_79(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 427|    "let" pattern local_type_annotation "=" expression { local_let_item($2, $3, $5, span($sloc)) }
fn yy_action_80(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Pattern(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LocalItem({();  local_let_item(_dollar2, _dollar3, _dollar5, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 778|    "{" layout_semicolons local_items expression "}" {
// 779|    Block(items=$3, result=$4, loc=span($sloc))
// 780|  }
fn yy_action_81(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_LocalItem_(_dollar3)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Block(items=_dollar3, result=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 792|    expression { Expression(expression=$1) }
fn yy_action_82(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_LocalItem({();  Expression(expression=_dollar1) })
}

// file:///./parser.mbty
// 785|    local_items local_item item_semicolon { comma_push($1, $2) }
fn yy_action_83(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_LocalItem_(_dollar1)
  guard _args[1].0 is YYObj_LocalItem(_dollar2)
  YYObj_Array_LocalItem_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 789|    local_let_item { $1 }
fn yy_action_84(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LocalItem(_dollar1)
  YYObj_LocalItem({();  _dollar1 })
}

// file:///./parser.mbty
// 790|    function_declaration { Function($1) }
fn yy_action_85(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_LocalItem({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 791|    offer_value_declaration { Let($1) }
fn yy_action_86(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_LocalItem({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 835|    "handle" expression handler_with_blocks handler_final_branch {
// 836|    Handler(body=$2, handlers=$3, final_branch=$4, loc=span($sloc))
// 837|  }
fn yy_action_87(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 842|    handler_with_blocks handler_with_block { comma_push($1, $2) }
fn yy_action_88(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerWithBlock_(_dollar1)
  guard _args[1].0 is YYObj_HandlerWithBlock(_dollar2)
  YYObj_Array_HandlerWithBlock_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 912|    "final" identifier block_expression { { binder: $2.name, binder_loc: $2.loc, body: $3, loc: span($sloc) } }
fn yy_action_89(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerFinalBranch({();  { binder: _dollar2.name, binder_loc: _dollar2.loc, body: _dollar3, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 841|    handler_with_block { [ $1 ] }
fn yy_action_90(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerWithBlock(_dollar1)
  YYObj_Array_HandlerWithBlock_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 846|    "with" "{" layout_semicolons handler_operation_arms "}" {
// 847|    { arms: $4, loc: span($sloc) }
// 848|  }
fn yy_action_91(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Array_HandlerOperationArm_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerWithBlock({(); 
    { arms: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 879|    qualified_type_name handler_operation_owner_arguments "tight ::" identifier handler_operation_type_binders { handler_operation_head_from_qualified($1, $2, $4, $5) }
fn yy_action_92(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[1].0 is YYObj_GenericArgumentList_(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar4)
  guard _args[4].0 is YYObj_Array_TypeBinder_(_dollar5)
  YYObj_HandlerOperationHead({();  handler_operation_head_from_qualified(_dollar1, _dollar2, _dollar4, _dollar5) })
}

// file:///./parser.mbty
// 894|    handler_operation_generic_arguments { Some($1) }
fn yy_action_93(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgumentList(_dollar1)
  YYObj_GenericArgumentList_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 893|    { None }
fn yy_action_94(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_GenericArgumentList_({();  None })
}

// file:///./parser.mbty
// 857|    non_empty_handler_operation_arms item_semicolon handler_operation_arm { comma_push($1, $3) }
fn yy_action_95(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  guard _args[2].0 is YYObj_HandlerOperationArm(_dollar3)
  YYObj_Array_HandlerOperationArm_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 858|    non_empty_handler_operation_arms item_semicolon { $1 }
fn yy_action_96(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 852|    non_empty_handler_operation_arms { $1 }
fn yy_action_97(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 856|    handler_operation_arm { [ $1 ] }
fn yy_action_98(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerOperationArm(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 862|    handler_operation_head "(" handler_operation_arm_parameters ")" "=>" expression {
// 863|    {
// 864|      name: $1.name,
// 865|      type_binders: $1.type_binders,
// 866|      payload_patterns: $3.payload_patterns,
// 867|      resume_binder: $3.resume_binder,
// 868|      resume_loc: $3.resume_loc,
// 869|      body: $6,
// 870|      loc: span($sloc)
// 871|    }
// 872|  }
fn yy_action_99(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerOperationHead(_dollar1)
  guard _args[2].0 is YYObj_HandlerOperationArmParameters(_dollar3)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerOperationArm({(); 
    {
      name: _dollar1.name,
      type_binders: _dollar1.type_binders,
      payload_patterns: _dollar3.payload_patterns,
      resume_binder: _dollar3.resume_binder,
      resume_loc: _dollar3.resume_loc,
      body: _dollar6,
      loc: span((_symbol_start_pos, _end_pos))
    }
  })
}

// file:///./parser.mbty
// 902|    identifier { { payload_patterns: [], resume_binder: $1.name, resume_loc: $1.loc } }
fn yy_action_100(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: [], resume_binder: _dollar1.name, resume_loc: _dollar1.loc } })
}

// file:///./parser.mbty
// 903|    handler_payload_patterns "," identifier { { payload_patterns: $1, resume_binder: $3.name, resume_loc: $3.loc } }
fn yy_action_101(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: _dollar1, resume_binder: _dollar3.name, resume_loc: _dollar3.loc } })
}

// file:///./parser.mbty
// 908|    handler_payload_patterns "," pattern { comma_push($1, $3) }
fn yy_action_102(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 907|    pattern { [ $1 ] }
fn yy_action_103(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 876|    identifier handler_operation_type_binders { unqualified_handler_operation_head($1, $2) }
fn yy_action_104(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_HandlerOperationHead({();  unqualified_handler_operation_head(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 877|    identifier "tight ::" identifier handler_operation_type_binders { handler_operation_head_from_qualified(Name(name=$1.name, loc=$1.loc), None, $3, $4) }
fn yy_action_105(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeBinder_(_dollar4)
  YYObj_HandlerOperationHead({();  handler_operation_head_from_qualified(Name(name=_dollar1.name, loc=_dollar1.loc), None, _dollar3, _dollar4) })
}

// file:///./parser.mbty
// 878|    identifier handler_operation_generic_arguments "tight ::" identifier handler_operation_type_binders { handler_operation_head_from_qualified(Name(name=$1.name, loc=$1.loc), Some($2), $4, $5) }
fn yy_action_106(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[1].0 is YYObj_GenericArgumentList(_dollar2)
  guard _args[3].0 is YYObj_Identifier(_dollar4)
  guard _args[4].0 is YYObj_Array_TypeBinder_(_dollar5)
  YYObj_HandlerOperationHead({();  handler_operation_head_from_qualified(Name(name=_dollar1.name, loc=_dollar1.loc), Some(_dollar2), _dollar4, _dollar5) })
}

// file:///./parser.mbty
// 884|    ident_bracket_list { $1 }
fn yy_action_107(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  YYObj_Array_TypeBinder_({();  _dollar1 })
}

// file:///./parser.mbty
// 888|    "[" non_empty_ident_list "]" { $2 }
fn yy_action_108(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_Array_TypeBinder_({();  _dollar2 })
}

// file:///./parser.mbty
// 889|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_109(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeBinder_({();  [] })
}

// file:///./parser.mbty
// 898|    "owner [" non_empty_generic_argument_list "]" { { arguments: $2, loc: span($sloc) } }
fn yy_action_110(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_GenericArgumentList({();  { arguments: _dollar2, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 883|    { [] }
fn yy_action_111(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeBinder_({();  [] })
}

// file:///./parser.mbty
// 812|    "match" expression "{" layout_semicolons match_arms "}" {
// 813|    Match(scrutinee=$2, arms=$5, loc=span($sloc))
// 814|  }
fn yy_action_112(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[4].0 is YYObj_Array_MatchArm_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Match(scrutinee=_dollar2, arms=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 106|    ";" { () }
fn yy_action_113(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 107|    LAYOUT_SEMICOLON { () }
fn yy_action_114(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 824|    non_empty_match_arms item_semicolon match_arm { comma_push($1, $3) }
fn yy_action_115(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  guard _args[2].0 is YYObj_MatchArm(_dollar3)
  YYObj_Array_MatchArm_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 825|    non_empty_match_arms item_semicolon { $1 }
fn yy_action_116(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  YYObj_Array_MatchArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 819|    non_empty_match_arms { $1 }
fn yy_action_117(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  YYObj_Array_MatchArm_({();  _dollar1 })
}

// file:///./parser.mbty
// 823|    match_arm { [ $1 ] }
fn yy_action_118(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_MatchArm(_dollar1)
  YYObj_Array_MatchArm_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 829|    pattern "=>" expression {
// 830|    { pattern: $1, body: $3, loc: span($sloc) }
// 831|  }
fn yy_action_119(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_MatchArm({(); 
    { pattern: _dollar1, body: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 969|    nominal_type_name "tight ::" IDENT variant_type_binders "(" pattern_list ")" { QualifiedVariant(type_name=$1.name, type_name_loc=$1.loc, variant=$3, variant_loc=$1.loc.ascii_after(2, $3.length()), type_binders=$4, arguments=$6, loc=span(($startpos, $endpos))) }
fn yy_action_120(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_TypeBinder_(_dollar4)
  guard _args[5].0 is YYObj_Array_Pattern_(_dollar6)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  QualifiedVariant(type_name=_dollar1.name, type_name_loc=_dollar1.loc, variant=_dollar3, variant_loc=_dollar1.loc.ascii_after(2, _dollar3.length()), type_binders=_dollar4, arguments=_dollar6, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 973|    nominal_type_name "tight ::" "{" struct_pattern_fields "}" {
// 974|    Struct(type_name=$1.name, type_name_loc=$1.loc, fields=$4, loc=span($sloc))
// 975|  }
fn yy_action_121(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_NominalTypeName(_dollar1)
  guard _args[3].0 is YYObj_Array_StructPatternField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({(); 
    Struct(type_name=_dollar1.name, type_name_loc=_dollar1.loc, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1007|    non_empty_struct_pattern_fields layout_list_separator struct_pattern_field { comma_push($1, $3) }
fn yy_action_122(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  guard _args[2].0 is YYObj_StructPatternField(_dollar3)
  YYObj_Array_StructPatternField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1008|    non_empty_struct_pattern_fields layout_list_separator { $1 }
fn yy_action_123(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 1002|    non_empty_struct_pattern_fields { $1 }
fn yy_action_124(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 1006|    struct_pattern_field { [ $1 ] }
fn yy_action_125(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructPatternField(_dollar1)
  YYObj_Array_StructPatternField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 967|    IDENT variant_type_binders "(" pattern_list ")" { UnqualifiedVariant(variant=$1, variant_loc=span(($startpos, $endpos)).ascii_prefix($1.length()), type_binders=$2, arguments=$4, loc=span(($startpos, $endpos))) }
fn yy_action_126(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  guard _args[3].0 is YYObj_Array_Pattern_(_dollar4)
  YYObj_Pattern({();  UnqualifiedVariant(variant=_dollar1, variant_loc=span((_start_pos, _end_pos)).ascii_prefix(_dollar1.length()), type_binders=_dollar2, arguments=_dollar4, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 996|    non_empty_pattern_list "," pattern { comma_push($1, $3) }
fn yy_action_127(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 997|    non_empty_pattern_list "," { $1 }
fn yy_action_128(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 991|    non_empty_pattern_list { $1 }
fn yy_action_129(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 995|    pattern { [ $1 ] }
fn yy_action_130(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 990|    { [] }
fn yy_action_131(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Pattern_({();  [] })
}

// file:///./parser.mbty
// 980|    "[" non_empty_ident_list "]" { $2 }
fn yy_action_132(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeBinder_(_dollar2)
  YYObj_Array_TypeBinder_({();  _dollar2 })
}

// file:///./parser.mbty
// 985|    non_empty_ident_list "," identifier { comma_push($1, { name: $3.name, loc: $3.loc }) }
fn yy_action_133(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_Array_TypeBinder_({();  comma_push(_dollar1, { name: _dollar3.name, loc: _dollar3.loc }) })
}

// file:///./parser.mbty
// 986|    non_empty_ident_list "," { $1 }
fn yy_action_134(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeBinder_(_dollar1)
  YYObj_Array_TypeBinder_({();  _dollar1 })
}

// file:///./parser.mbty
// 984|    identifier { [ { name: $1.name, loc: $1.loc } ] }
fn yy_action_135(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_Array_TypeBinder_({();  [ { name: _dollar1.name, loc: _dollar1.loc } ] })
}

// file:///./parser.mbty
// 720|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_136(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_NominalTypeName({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 966|    IDENT { Binding($1, loc=span($sloc)) }
fn yy_action_137(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Binding(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 979|    { [] }
fn yy_action_138(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeBinder_({();  [] })
}

// file:///./parser.mbty
// 721|    qualified_type_name { { name: type_name_text($1), loc: $1.loc() } }
fn yy_action_139(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_NominalTypeName({();  { name: type_name_text(_dollar1), loc: _dollar1.loc() } })
}

// file:///./parser.mbty
// 960|    "_" { Wildcard(span($sloc)) }
fn yy_action_140(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Wildcard(span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 961|    INT { IntLiteral($1, loc=span($sloc)) }
fn yy_action_141(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 962|    DOUBLE { DoubleLiteral($1, loc=span($sloc)) }
fn yy_action_142(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  DoubleLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 963|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_143(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 964|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_144(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 965|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_145(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 968|    struct_pattern { $1 }
fn yy_action_146(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Pattern({();  _dollar1 })
}

// file:///./parser.mbty
// 1018|    IDENT ":" pattern {
// 1019|    Value(name=$1, pattern=Some($3), loc=span($sloc))
// 1020|  }
fn yy_action_147(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1012|    IDENT {
// 1013|    Value(name=$1, pattern=None, loc=span($sloc))
// 1014|  }
fn yy_action_148(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=None, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1015|    "_" {
// 1016|    TypeWildcard(loc=span($sloc))
// 1017|  }
fn yy_action_149(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    TypeWildcard(loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 1001|    { [] }
fn yy_action_150(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructPatternField_({();  [] })
}

// file:///./parser.mbty
// 818|    { [] }
fn yy_action_151(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_MatchArm_({();  [] })
}

// file:///./parser.mbty
// 796|    "if" expression block_expression optional_else_branch {
// 797|    If(condition=$2, then_branch=$3, else_branch=$4, loc=span($sloc))
// 798|  }
fn yy_action_152(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[3].0 is YYObj_Expr_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    If(condition=_dollar2, then_branch=_dollar3, else_branch=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 803|    "else" else_branch_expression { Some($2) }
fn yy_action_153(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  YYObj_Expr_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 807|    block_expression { $1 }
fn yy_action_154(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 808|    if_expression { $1 }
fn yy_action_155(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 802|    { None }
fn yy_action_156(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Expr_({();  None })
}

// file:///./parser.mbty
// 685|    "[" list_literal_items "]" { ListLiteral(items=$2, loc=span($sloc)) }
fn yy_action_157(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  ListLiteral(items=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 773|    non_empty_positional_argument_list "," expression { comma_push($1, $3) }
fn yy_action_158(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 679|    "(" expression ")" { Grouped(expression=$2, loc=span($sloc)) }
fn yy_action_159(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Grouped(expression=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 620|    identifier "!" "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1.name, operation_loc=$1.loc), type_witnesses=[], arguments=$4, loc=span($sloc)) }
fn yy_action_160(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[3].0 is YYObj_Array_Expr_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1.name, operation_loc=_dollar1.loc), type_witnesses=[], arguments=_dollar4, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 652|    owner_expression "tight ::" IDENT variant_type_arguments variant_arguments %prec VARIANT_EXPR {
// 653|    QualifiedVariant(owner=$1.owner, variant=$3, variant_loc=$1.owner.loc().ascii_after(2, $3.length()), variant_type_arguments=$4, arguments=$5, loc=span($sloc))
// 654|  }
fn yy_action_161(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 747|    "(" positional_argument_list ")" { $2 }
fn yy_action_162(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  YYObj_Array_Expr_({();  _dollar2 })
}

// file:///./parser.mbty
// 726|    type_arguments { $1 }
fn yy_action_163(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 725|    %prec VARIANT_EXPR { [] }
fn yy_action_164(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 625|    owner_expression "tight ::" identifier "!" "(" positional_argument_list ")" %prec "tight ::" {
// 626|    EffectOperationCall(
// 627|      name=Qualified(
// 628|        owner=$1.owner,
// 629|        operation=$3.name,
// 630|        operation_loc=$3.loc
// 631|      ),
// 632|      type_witnesses=[],
// 633|      arguments=$6,
// 634|      loc=span($sloc)
// 635|    )
// 636|  }
fn yy_action_165(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 772|    expression { [ $1 ] }
fn yy_action_166(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 637|    owner_expression "tight ::" identifier "!" operation_type_witnesses "(" positional_argument_list ")" %prec "tight ::" {
// 638|    EffectOperationCall(
// 639|      name=Qualified(
// 640|        owner=$1.owner,
// 641|        operation=$3.name,
// 642|        operation_loc=$3.loc
// 643|      ),
// 644|      type_witnesses=$5,
// 645|      arguments=$7,
// 646|      loc=span($sloc)
// 647|    )
// 648|  }
fn yy_action_167(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 649|    owner_expression "tight ::" "{" struct_literal_fields "}" %prec "tight ::" {
// 650|    StructLiteral(owner=$1.owner, fields=$4, loc=span($sloc))
// 651|  }
fn yy_action_168(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[3].0 is YYObj_Array_StructLiteralField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    StructLiteral(owner=_dollar1.owner, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 736|    non_empty_struct_literal_fields layout_list_separator struct_literal_field { comma_push($1, $3) }
fn yy_action_169(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  guard _args[2].0 is YYObj_StructLiteralField(_dollar3)
  YYObj_Array_StructLiteralField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 737|    non_empty_struct_literal_fields layout_list_separator { $1 }
fn yy_action_170(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 731|    non_empty_struct_literal_fields { $1 }
fn yy_action_171(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 735|    struct_literal_field { [ $1 ] }
fn yy_action_172(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructLiteralField(_dollar1)
  YYObj_Array_StructLiteralField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 742|    IDENT ":" expression { Value(name=$1, value=Some($3), loc=span($sloc)) }
fn yy_action_173(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 617|    value_postfix_expression "(" argument_list ")" { Call(callee=$1, arguments=$3, loc=span($sloc)) }
fn yy_action_174(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_CallArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Call(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 768|    IDENT "=" expression { Named(name=$1, value=$3, loc=span($sloc)) }
fn yy_action_175(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Named(name=_dollar1, value=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 554|    expression "|>" expression {
// 555|    Pipeline(left=$1, right=$3, loc=span($sloc))
// 556|  }
fn yy_action_176(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Pipeline(left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 557|    expression "||" expression {
// 558|    Binary(operator=Or, left=$1, right=$3, loc=span($sloc))
// 559|  }
fn yy_action_177(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Or, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 560|    expression "&&" expression {
// 561|    Binary(operator=And, left=$1, right=$3, loc=span($sloc))
// 562|  }
fn yy_action_178(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=And, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 563|    expression "==" expression {
// 564|    Binary(operator=Equal, left=$1, right=$3, loc=span($sloc))
// 565|  }
fn yy_action_179(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Equal, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 566|    expression "!=" expression {
// 567|    Binary(operator=NotEqual, left=$1, right=$3, loc=span($sloc))
// 568|  }
fn yy_action_180(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=NotEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 569|    expression "<" expression {
// 570|    Binary(operator=Less, left=$1, right=$3, loc=span($sloc))
// 571|  }
fn yy_action_181(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Less, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 572|    expression "<=" expression {
// 573|    Binary(operator=LessEqual, left=$1, right=$3, loc=span($sloc))
// 574|  }
fn yy_action_182(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=LessEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 575|    expression ">" expression {
// 576|    Binary(operator=Greater, left=$1, right=$3, loc=span($sloc))
// 577|  }
fn yy_action_183(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Greater, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 578|    expression ">=" expression {
// 579|    Binary(operator=GreaterEqual, left=$1, right=$3, loc=span($sloc))
// 580|  }
fn yy_action_184(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=GreaterEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 581|    expression "+" expression {
// 582|    Binary(operator=Add, left=$1, right=$3, loc=span($sloc))
// 583|  }
fn yy_action_185(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Add, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 584|    expression "-" expression {
// 585|    Binary(operator=Sub, left=$1, right=$3, loc=span($sloc))
// 586|  }
fn yy_action_186(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Sub, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 587|    expression "*" expression {
// 588|    Binary(operator=Mul, left=$1, right=$3, loc=span($sloc))
// 589|  }
fn yy_action_187(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Mul, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 590|    expression "/" expression {
// 591|    Binary(operator=Div, left=$1, right=$3, loc=span($sloc))
// 592|  }
fn yy_action_188(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Div, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 593|    expression "%" expression {
// 594|    Binary(operator=Rem, left=$1, right=$3, loc=span($sloc))
// 595|  }
fn yy_action_189(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Rem, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 767|    expression { Positional(value=$1, loc=span($sloc)) }
fn yy_action_190(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Positional(value=_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 596|    unary_expression { $1 }
fn yy_action_191(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 658|    IDENT { { expr: Var($1, loc=span($sloc)), owner: Name(name=$1, loc=span($sloc)) } }
fn yy_action_192(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  { expr: Var(_dollar1, loc=span((_symbol_start_pos, _end_pos))), owner: Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos))) } })
}

// file:///./parser.mbty
// 600|    "-" unary_expression %prec UNARY {
// 601|    Unary(operator=Neg, operand=$2, loc=span($sloc))
// 602|  }
fn yy_action_193(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Unary(operator=Neg, operand=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 603|    "!" unary_expression %prec UNARY {
// 604|    Unary(operator=Not, operand=$2, loc=span($sloc))
// 605|  }
fn yy_action_194(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Unary(operator=Not, operand=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 606|    postfix_expression { $1 }
fn yy_action_195(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 762|    non_empty_argument_list "," call_argument { comma_push($1, $3) }
fn yy_action_196(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  guard _args[2].0 is YYObj_CallArgument(_dollar3)
  YYObj_Array_CallArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 763|    non_empty_argument_list "," { $1 }
fn yy_action_197(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 757|    non_empty_argument_list { $1 }
fn yy_action_198(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 761|    call_argument { [ $1 ] }
fn yy_action_199(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_CallArgument(_dollar1)
  YYObj_Array_CallArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 756|    { [] }
fn yy_action_200(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_CallArgument_({();  [] })
}

// file:///./parser.mbty
// 618|    value_postfix_expression type_arguments %prec "[" { TypeApplication(callee=$1, arguments=$2, loc=span($sloc)) }
fn yy_action_201(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  TypeApplication(callee=_dollar1, arguments=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 619|    value_postfix_expression "." IDENT { Field(base=$1, name=$3, name_loc=span($sloc).ascii_suffix($3.length()), loc=span($sloc)) }
fn yy_action_202(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Field(base=_dollar1, name=_dollar3, name_loc=span((_symbol_start_pos, _end_pos)).ascii_suffix(_dollar3.length()), loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 610|    value_postfix_expression { $1 }
fn yy_action_203(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 614|    member_expression { $1 }
fn yy_action_204(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 743|    IDENT "=" type { TypeWitness(name=$1, witness=$3, loc=span($sloc)) }
fn yy_action_205(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  TypeWitness(name=_dollar1, witness=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 741|    IDENT { Value(name=$1, value=None, loc=span($sloc)) }
fn yy_action_206(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=None, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 730|    { [] }
fn yy_action_207(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructLiteralField_({();  [] })
}

// file:///./parser.mbty
// 615|    owner_expression { $1.expr }
fn yy_action_208(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  YYObj_Expr({();  _dollar1.expr })
}

// file:///./parser.mbty
// 616|    non_owner_primary_expression { $1 }
fn yy_action_209(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 621|    identifier "!" operation_type_witnesses "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1.name, operation_loc=$1.loc), type_witnesses=$3, arguments=$5, loc=span($sloc)) }
fn yy_action_210(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1.name, operation_loc=_dollar1.loc), type_witnesses=_dollar3, arguments=_dollar5, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 752|    non_empty_positional_argument_list { $1 }
fn yy_action_211(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 751|    { [] }
fn yy_action_212(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 696|    type_arguments { $1 }
fn yy_action_213(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 700|    type_argument_bracket_list { $1 }
fn yy_action_214(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 704|    "[" non_empty_generic_argument_list "]" { $2 }
fn yy_action_215(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj_Array_GenericArgument_({();  _dollar2 })
}

// file:///./parser.mbty
// 705|    "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" { [] }
fn yy_action_216(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 659|    owner_path_expression "." IDENT { owner_expression_field($1, $3, span($sloc).ascii_suffix($3.length()), span($sloc)) }
fn yy_action_217(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  owner_expression_field(_dollar1, _dollar3, span((_symbol_start_pos, _end_pos)).ascii_suffix(_dollar3.length()), span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 664|    owner_path_expression owner_type_arguments %prec "owner [" { owner_expression_with_arguments($1, $2, span($sloc)) }
fn yy_action_218(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  owner_expression_with_arguments(_dollar1, _dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 668|    "owner [" non_empty_generic_argument_list "]" { $2 }
fn yy_action_219(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj_Array_GenericArgument_({();  _dollar2 })
}

// file:///./parser.mbty
// 669|    "owner [" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" { [] }
fn yy_action_220(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 663|    owner_path_expression { $1 }
fn yy_action_221(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  YYObj_OwnerExpression({();  _dollar1 })
}

// file:///./parser.mbty
// 673|    INT { IntLiteral($1, loc=span($sloc)) }
fn yy_action_222(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 674|    DOUBLE { DoubleLiteral($1, loc=span($sloc)) }
fn yy_action_223(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  DoubleLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 675|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_224(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 676|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_225(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 677|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_226(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 678|    "(" ")" { UnitLiteral(loc=span($sloc)) }
fn yy_action_227(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  UnitLiteral(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 680|    block_expression { $1 }
fn yy_action_228(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 681|    if_expression { $1 }
fn yy_action_229(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 682|    match_expression { $1 }
fn yy_action_230(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 683|    handler_expression { $1 }
fn yy_action_231(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 684|    function_literal { $1 }
fn yy_action_232(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 774|    non_empty_positional_argument_list "," { $1 }
fn yy_action_233(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 692|    non_empty_positional_argument_list { $1 }
fn yy_action_234(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 691|    { [] }
fn yy_action_235(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 686|    builtin_expression { $1 }
fn yy_action_236(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 687|    extern_expression { $1 }
fn yy_action_237(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 784|    { [] }
fn yy_action_238(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_LocalItem_({();  [] })
}

// file:///./parser.mbty
// 916|    "fn" type_parameters "(" function_literal_parameters ")" return_annotation block_expression {
// 917|    FunctionLiteral(type_parameters=$2, parameters=$4, return_type=$6.return_type, effect=$6.effect, body=$7, loc=span($sloc))
// 918|  }
fn yy_action_239(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_FunctionLiteralParameter_(_dollar4)
  guard _args[5].0 is YYObj_ReturnAnnotation(_dollar6)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    FunctionLiteral(type_parameters=_dollar2, parameters=_dollar4, return_type=_dollar6.return_type, effect=_dollar6.effect, body=_dollar7, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 944|    "->" type effect_annotation_opt {
// 945|    { return_type: Some($2), effect: $3 }
// 946|  }
fn yy_action_240(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[2].0 is YYObj_EffectTerm_(_dollar3)
  YYObj_ReturnAnnotation({(); 
    { return_type: Some(_dollar2), effect: _dollar3 }
  })
}

// file:///./parser.mbty
// 943|    { { return_type: None, effect: None } }
fn yy_action_241(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ReturnAnnotation({();  { return_type: None, effect: None } })
}

// file:///./parser.mbty
// 928|    non_empty_function_literal_parameters "," function_literal_parameter { comma_push($1, $3) }
fn yy_action_242(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  guard _args[2].0 is YYObj_FunctionLiteralParameter(_dollar3)
  YYObj_Array_FunctionLiteralParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 923|    non_empty_function_literal_parameters { $1 }
fn yy_action_243(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 927|    function_literal_parameter { [ $1 ] }
fn yy_action_244(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionLiteralParameter(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 432|    ":" type { Some($2) }
fn yy_action_245(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 932|    function_literal_parameter_modifiers identifier local_type_annotation {
// 933|    { is_offered: $1, name: $2.name, name_loc: $2.loc, type_annotation: $3, loc: span($sloc) }
// 934|  }
fn yy_action_246(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 431|    { None }
fn yy_action_247(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Type_({();  None })
}

// file:///./parser.mbty
// 939|    "offer" { true }
fn yy_action_248(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 922|    { [] }
fn yy_action_249(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_FunctionLiteralParameter_({();  [] })
}

// file:///./parser.mbty
// 938|    { false }
fn yy_action_250(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 448|    { [] }
fn yy_action_251(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 950|    "builtin" "(" STRING ")" {
// 951|    Builtin($3, loc=span($sloc))
// 952|  }
fn yy_action_252(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Builtin(_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 956|    "extern" "(" STRING ")" { Extern($3, loc=span($sloc)) }
fn yy_action_253(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Extern(_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 522|    type_parameter_bracket_list "(" type_list ")" "->" type effect_annotation_opt {
// 523|    Function(type_parameters=$1, parameters=$3, result=$6, effect=effect_or_empty($7, $6), loc=span($sloc))
// 524|  }
fn yy_action_254(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_EffectTerm_(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=_dollar1, parameters=_dollar3, result=_dollar6, effect=effect_or_empty(_dollar7, _dollar6), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 519|    "(" type "," type_list ")" "->" type effect_annotation_opt {
// 520|    Function(type_parameters=[], parameters=[$2] + $4, result=$7, effect=effect_or_empty($8, $7), loc=span($sloc))
// 521|  }
fn yy_action_255(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 516|    "(" ")" "->" type effect_annotation_opt {
// 517|    Function(type_parameters=[], parameters=[], result=$4, effect=effect_or_empty($5, $4), loc=span($sloc))
// 518|  }
fn yy_action_256(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[4].0 is YYObj_EffectTerm_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[], result=_dollar4, effect=effect_or_empty(_dollar5, _dollar4), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 538|    type_application { Term(type_=$1, loc=$1.loc()) }
fn yy_action_257(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_EffectTerm({();  Term(type_=_dollar1, loc=_dollar1.loc()) })
}

// file:///./parser.mbty
// 503|    "(" type ")" %prec PAREN_TYPE { Grouped(type_=$2, loc=span($sloc)) }
fn yy_action_258(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({();  Grouped(type_=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 533|    "!" effect_set { $2 }
fn yy_action_259(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_EffectTerm(_dollar2)
  YYObj_EffectTerm({();  _dollar2 })
}

// file:///./parser.mbty
// 537|    EFFECT_IDENTIFIER_SLOT { abort("effect completion slot token must not be shifted") }
fn yy_action_260(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_EffectTerm({();  abort("effect completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 475|    type_application "->" type effect_annotation_opt {
// 476|    Function(type_parameters=[], parameters=[$1], result=$3, effect=effect_or_empty($4, $3), loc=span($sloc))
// 477|  }
fn yy_action_261(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  guard _args[3].0 is YYObj_EffectTerm_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[_dollar1], result=_dollar3, effect=effect_or_empty(_dollar4, _dollar3), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 529|    effect_annotation { Some($1) }
fn yy_action_262(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectTerm(_dollar1)
  YYObj_EffectTerm_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 490|    type_application "[" non_empty_generic_argument_list "]" {
// 491|    Apply(callee=$1, arguments=$3, loc=span($sloc))
// 492|  }
fn yy_action_263(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 715|    non_empty_generic_argument_list layout_list_separator generic_argument { comma_push($1, $3) }
fn yy_action_264(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  guard _args[2].0 is YYObj_GenericArgument(_dollar3)
  YYObj_Array_GenericArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 716|    non_empty_generic_argument_list layout_list_separator { $1 }
fn yy_action_265(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 493|    type_application "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" {
// 494|    Apply(callee=$1, arguments=[], loc=span($sloc))
// 495|  }
fn yy_action_266(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=[], loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 709|    type { TypeTerm($1) }
fn yy_action_267(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_GenericArgument({();  TypeTerm(_dollar1) })
}

// file:///./parser.mbty
// 453|    "[" non_empty_type_parameter_list "]" { $2 }
fn yy_action_268(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 161|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_269(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Identifier({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 459|    non_empty_type_parameter_list "," type_parameter { comma_push($1, $3) }
fn yy_action_270(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameter(_dollar3)
  YYObj_Array_TypeParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 460|    non_empty_type_parameter_list "," { $1 }
fn yy_action_271(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 454|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_272(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 458|    type_parameter { [ $1 ] }
fn yy_action_273(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameter(_dollar1)
  YYObj_Array_TypeParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 264|    "[" kind_list "]" "->" kind {
// 265|    Function(parameters=$2, result=$5, loc=span($sloc))
// 266|  }
fn yy_action_274(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({(); 
    Function(parameters=_dollar2, result=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 262|    "Type" { Type(loc=span($sloc)) }
fn yy_action_275(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Type(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 263|    "Effect" { Effect(loc=span($sloc)) }
fn yy_action_276(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Effect(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 277|    non_empty_kind_list "," kind { comma_push($1, $3) }
fn yy_action_277(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 278|    non_empty_kind_list "," { $1 }
fn yy_action_278(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 272|    non_empty_kind_list { $1 }
fn yy_action_279(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 276|    kind { [ $1 ] }
fn yy_action_280(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 271|    { [] }
fn yy_action_281(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Kind_({();  [] })
}

// file:///./parser.mbty
// 267|    "(" kind ")" { Grouped(kind=$2, loc=span($sloc)) }
fn yy_action_282(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({();  Grouped(kind=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 467|    identifier ":" kind {
// 468|    { name: $1.name, name_loc: $1.loc, kind: Some($3), loc: span($sloc) }
// 469|  }
fn yy_action_283(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, kind: Some(_dollar3), loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 464|    identifier {
// 465|    { name: $1.name, name_loc: $1.loc, kind: None, loc: span($sloc) }
// 466|  }
fn yy_action_284(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1.name, name_loc: _dollar1.loc, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 473|    TYPE_IDENTIFIER_SLOT { abort("type completion slot token must not be shifted") }
fn yy_action_285(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Type({();  abort("type completion slot token must not be shifted") })
}

// file:///./parser.mbty
// 474|    type_lambda { $1 }
fn yy_action_286(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 710|    "{" type_list "}" { EffectTerm(effect_set($2, span($sloc))) }
fn yy_action_287(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_GenericArgument({();  EffectTerm(effect_set(_dollar2, span((_symbol_start_pos, _end_pos)))) })
}

// file:///./parser.mbty
// 714|    generic_argument { [ $1 ] }
fn yy_action_288(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgument(_dollar1)
  YYObj_Array_GenericArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 479|    type_application %prec PAREN_TYPE { $1 }
fn yy_action_289(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 478|    function_type { $1 }
fn yy_action_290(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 483|    "type" type_parameter_bracket_list "=>" type {
// 484|    TypeLambda(parameters=$2, body=$4, loc=span($sloc))
// 485|  }
fn yy_action_291(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    TypeLambda(parameters=_dollar2, body=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 489|    type_primary { $1 }
fn yy_action_292(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 510|    qualified_type_name "." IDENT {
// 511|    extend_qualified_type_name($1, $3, span($sloc))
// 512|  }
fn yy_action_293(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    extend_qualified_type_name(_dollar1, _dollar3, span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 499|    qualified_type_name { $1 }
fn yy_action_294(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 507|    IDENT "." IDENT {
// 508|    QualifiedName(module_path={ components: [ $1 ], loc: span($sloc) }, name=$3, loc=span($sloc))
// 509|  }
fn yy_action_295(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Type({(); 
    QualifiedName(module_path={ components: [ _dollar1 ], loc: span((_symbol_start_pos, _end_pos)) }, name=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 500|    IDENT {
// 501|    Name(name=$1, loc=span($sloc))
// 502|  }
fn yy_action_296(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 539|    "{" type_list "}" { effect_set($2, span($sloc)) }
fn yy_action_297(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectTerm({();  effect_set(_dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 528|    { None }
fn yy_action_298(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_EffectTerm_({();  None })
}

// file:///./parser.mbty
// 549|    non_empty_type_list layout_list_separator type { comma_push($1, $3) }
fn yy_action_299(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 550|    non_empty_type_list layout_list_separator { $1 }
fn yy_action_300(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 544|    non_empty_type_list { $1 }
fn yy_action_301(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 548|    type { [ $1 ] }
fn yy_action_302(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 543|    { [] }
fn yy_action_303(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 130|    import_declarations import_declaration layout_semicolons { comma_push($1, $2) }
fn yy_action_304(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_ImportDeclaration(_dollar2)
  YYObj_Array_ImportDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 137|    "import" module_path ".*" {
// 138|    Open(module_path=$2, loc=span($sloc))
// 139|  }
fn yy_action_305(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Open(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 140|    "import" module_path ".{" import_item_list "}" {
// 141|    Selective(module_path=$2, items=$4, loc=span($sloc))
// 142|  }
fn yy_action_306(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  guard _args[3].0 is YYObj_Array_ImportItem_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Selective(module_path=_dollar2, items=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 111|    "," { () }
fn yy_action_307(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 112|    LAYOUT_SEMICOLON { () }
fn yy_action_308(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 152|    non_empty_import_item_list layout_list_separator import_item { comma_push($1, $3) }
fn yy_action_309(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  guard _args[2].0 is YYObj_ImportItem(_dollar3)
  YYObj_Array_ImportItem_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 153|    non_empty_import_item_list layout_list_separator { $1 }
fn yy_action_310(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 147|    non_empty_import_item_list { $1 }
fn yy_action_311(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 151|    import_item { [ $1 ] }
fn yy_action_312(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportItem(_dollar1)
  YYObj_Array_ImportItem_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 157|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_313(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportItem({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 146|    { [] }
fn yy_action_314(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ImportItem_({();  [] })
}

// file:///./parser.mbty
// 134|    "import" module_path {
// 135|    Qualified(module_path=$2, loc=span($sloc))
// 136|  }
fn yy_action_315(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Qualified(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 165|    { [] }
fn yy_action_316(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TopLevelDeclaration_({();  [] })
}

// file:///./parser.mbty
// 102|    layout_semicolons LAYOUT_SEMICOLON { () }
fn yy_action_317(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 129|    { [] }
fn yy_action_318(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ImportDeclaration_({();  [] })
}

// file:///./parser.mbty
// 101|    { () }
fn yy_action_319(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Unit({();  () })
}

// file:///./parser.mbty
// 116|    "module" module_path { $2 }
fn yy_action_320(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  YYObj_ModulePath({();  _dollar2 })
}

// file:///./parser.mbty
// 125|    non_empty_module_path "." IDENT { comma_push($1, $3) }
fn yy_action_321(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 120|    non_empty_module_path { { components: $1, loc: span($sloc) } }
fn yy_action_322(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ModulePath({();  { components: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 124|    IDENT { [ $1 ] }
fn yy_action_323(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_({();  [ _dollar1 ] })
}

fn yy_input(token : Token, _start_pos : SourceSpan, _end_pos : SourceSpan) -> (YYSymbol, YYObj) {
  match token {
    INT(data) => (T_INT, YYObj_String(data))
    DOUBLE(data) => (T_DOUBLE, YYObj_String(data))
    STRING(data) => (T_STRING, YYObj_String(data))
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
    BUILTIN => (T_BUILTIN, YYObj_Void)
    EXTERN => (T_EXTERN, YYObj_Void)
    MODULE => (T_MODULE, YYObj_Void)
    IMPORT => (T_IMPORT, YYObj_Void)
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
    COMMA => (T_COMMA, YYObj_Void)
    SEMICOLON => (T_SEMICOLON, YYObj_Void)
    LAYOUT_SEMICOLON => (T_LAYOUT_SEMICOLON, YYObj_Void)
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
  ReduceNoLookahead(1, NT_non_empty_module_path, yy_action_323)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_5)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_SEMICOLON | T_DOTSTAR | T_DOTLBRACE => Reduce(1, NT_module_path, yy_action_322)
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
  ReduceNoLookahead(3, NT_non_empty_module_path, yy_action_321)
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_declaration, yy_action_320)
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_9)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    NT_import_declarations => Shift(yy_state_11)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB => Reduce(0, NT_import_declarations, yy_action_318)
    _ => Error
  }
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_layout_semicolons, yy_action_317)
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IMPORT => Shift(yy_state_12)
    NT_import_declaration => Shift(yy_state_25)
    NT_top_level_declarations => Shift(yy_state_27)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB => Reduce(0, NT_top_level_declarations, yy_action_316)
    _ => Error
  }
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_13)
    _ => Error
  }
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOTLBRACE => Shift(yy_state_14)
    T_DOTSTAR => Shift(yy_state_24)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_SEMICOLON => Reduce(2, NT_import_declaration, yy_action_315)
    _ => Error
  }
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_15)
    NT_import_item => Shift(yy_state_16)
    NT_non_empty_import_item_list => Shift(yy_state_17)
    NT_import_item_list => Shift(yy_state_22)
    T_RBRACE => Reduce(0, NT_import_item_list, yy_action_314)
    _ => Error
  }
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_item, yy_action_313)
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_import_item_list, yy_action_312)
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_list_separator => Shift(yy_state_18)
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    T_RBRACE => Reduce(1, NT_import_item_list, yy_action_311)
    _ => Error
  }
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_15)
    NT_import_item => Shift(yy_state_19)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_import_item_list, yy_action_310)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_import_item_list, yy_action_309)
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_layout_list_separator, yy_action_308)
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_layout_list_separator, yy_action_307)
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_23)
    _ => Error
  }
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_declaration, yy_action_306)
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_declaration, yy_action_305)
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_26)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_IMPORT | T_PUB => Reduce(3, NT_import_declarations, yy_action_304)
    _ => Error
  }
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_28)
    T_OFFER => Shift(yy_state_417)
    T_FN => Shift(yy_state_456)
    T_EFFECT => Shift(yy_state_458)
    T_ENUM => Shift(yy_state_481)
    T_STRUCT => Shift(yy_state_500)
    T_TYPE => Shift(yy_state_520)
    T_EXTERN => Shift(yy_state_532)
    T_PUB => Shift(yy_state_540)
    NT_offer_value_declaration => Shift(yy_state_611)
    NT_top_level_let_declaration => Shift(yy_state_612)
    NT_function_declaration => Shift(yy_state_613)
    NT_type_alias_declaration => Shift(yy_state_614)
    NT_external_type_declaration => Shift(yy_state_615)
    NT_effect_declaration => Shift(yy_state_616)
    NT_enum_declaration => Shift(yy_state_617)
    NT_struct_declaration => Shift(yy_state_618)
    NT_top_level_declaration => Shift(yy_state_619)
    T_EOF => Shift(yy_state_621)
    _ => Error
  }
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_29)
    T_IDENT => Shift(yy_state_89)
    _ => Error
  }
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_30)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_121)
    _ => Error
  }
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_32)
    _ => Error
  }
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_116)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_302)
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_35)
    T_RPAREN | T_RBRACE => Reduce(1, NT_type_list, yy_action_301)
    _ => Error
  }
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_36)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    T_RPAREN | T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_type_list, yy_action_300)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_299)
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_RPAREN => Shift(yy_state_38)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_109)
    _ => Error
  }
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_39)
    _ => Error
  }
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    NT_type => Shift(yy_state_40)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_108)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_42)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_EFFECT_IDENTIFIER_SLOT => Shift(yy_state_102)
    NT_effect_set => Shift(yy_state_103)
    T_LPAREN => Shift(yy_state_104)
    NT_type_application => Shift(yy_state_107)
    _ => Error
  }
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    NT_type_list => Shift(yy_state_43)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_303)
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
  ReduceNoLookahead(3, NT_effect_set, yy_action_297)
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_46)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_THIN_ARROW | T_EQUAL => Reduce(1, NT_type_primary, yy_action_296)
    _ => Error
  }
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_47)
    _ => Error
  }
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_295)
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_49)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_THIN_ARROW | T_EQUAL => Reduce(1, NT_type_primary, yy_action_294)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_50)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_293)
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_application, yy_action_292)
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_53)
    T_LBRACKET => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_54)
    _ => Error
  }
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_type => Shift(yy_state_55)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_lambda, yy_action_291)
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_290)
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_58)
    T_THIN_ARROW => Shift(yy_state_98)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(1, NT_type, yy_action_289)
    _ => Error
  }
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_generic_argument => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_60)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_91)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_92)
    NT_non_empty_generic_argument_list => Shift(yy_state_94)
    _ => Error
  }
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_generic_argument_list, yy_action_288)
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_list => Shift(yy_state_61)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_62)
    _ => Error
  }
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_generic_argument, yy_action_287)
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_286)
}

fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_285)
}

fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_66)
    NT_type_parameter => Shift(yy_state_83)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_84)
    NT_non_empty_type_parameter_list => Shift(yy_state_86)
    T_IDENT => Shift(yy_state_89)
    _ => Error
  }
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_67)
    T_RBRACKET | T_COMMA => Reduce(1, NT_type_parameter, yy_action_284)
    _ => Error
  }
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_kind => Shift(yy_state_68)
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    _ => Error
  }
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter, yy_action_283)
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    NT_kind => Shift(yy_state_70)
    T_LBRACKET => Shift(yy_state_72)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    _ => Error
  }
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_71)
    _ => Error
  }
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind, yy_action_282)
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    NT_kind => Shift(yy_state_73)
    NT_non_empty_kind_list => Shift(yy_state_74)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    NT_kind_list => Shift(yy_state_79)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_281)
    _ => Error
  }
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_280)
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_75)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_279)
    _ => Error
  }
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    NT_kind => Shift(yy_state_76)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_kind_list, yy_action_278)
    _ => Error
  }
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_277)
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_276)
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_275)
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_80)
    _ => Error
  }
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_81)
    _ => Error
  }
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    NT_kind => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_274)
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_list, yy_action_273)
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_85)
    _ => Error
  }
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_272)
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_87)
    T_RBRACKET => Shift(yy_state_90)
    _ => Error
  }
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_66)
    NT_type_parameter => Shift(yy_state_88)
    T_IDENT => Shift(yy_state_89)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_type_parameter_list, yy_action_271)
    _ => Error
  }
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_list, yy_action_270)
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_identifier, yy_action_269)
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_268)
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_generic_argument, yy_action_267)
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_93)
    _ => Error
  }
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_266)
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_95)
    T_RBRACKET => Shift(yy_state_97)
    _ => Error
  }
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    T_LBRACE => Shift(yy_state_60)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_91)
    NT_generic_argument => Shift(yy_state_96)
    T_RBRACKET | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_generic_argument_list, yy_action_265)
    _ => Error
  }
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_generic_argument_list, yy_action_264)
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_263)
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_99)
    _ => Error
  }
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_101)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_annotation_opt, yy_action_262)
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type, yy_action_261)
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_set, yy_action_260)
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect_annotation, yy_action_259)
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_105)
    _ => Error
  }
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_106)
    _ => Error
  }
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_primary, yy_action_258)
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_58)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(1, NT_effect_set, yy_action_257)
    _ => Error
  }
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_type, yy_action_256)
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_106)
    T_COMMA => Shift(yy_state_110)
    _ => Error
  }
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_111)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_112)
    _ => Error
  }
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_113)
    _ => Error
  }
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_114)
    _ => Error
  }
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_115)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_255)
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_117)
    _ => Error
  }
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_118)
    _ => Error
  }
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_119)
    _ => Error
  }
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_120)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_type, yy_action_254)
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_122)
    _ => Error
  }
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_455)
    _ => Error
  }
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_124)
    _ => Error
  }
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_125)
    _ => Error
  }
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_126)
    _ => Error
  }
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_extern_expression, yy_action_253)
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_128)
    _ => Error
  }
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_129)
    _ => Error
  }
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_130)
    _ => Error
  }
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_builtin_expression, yy_action_252)
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameters => Shift(yy_state_132)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    T_LPAREN => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_133)
    _ => Error
  }
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_134)
    NT_function_literal_parameter_modifiers => Shift(yy_state_135)
    NT_function_literal_parameter => Shift(yy_state_140)
    NT_non_empty_function_literal_parameters => Shift(yy_state_141)
    NT_function_literal_parameters => Shift(yy_state_144)
    T_RPAREN => Reduce(0, NT_function_literal_parameters, yy_action_249)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_250)
    _ => Error
  }
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_literal_parameter_modifiers, yy_action_248)
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_136)
    _ => Error
  }
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_type_annotation => Shift(yy_state_137)
    T_COLON => Shift(yy_state_138)
    T_RPAREN | T_COMMA => Reduce(0, NT_local_type_annotation, yy_action_247)
    _ => Error
  }
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_parameter, yy_action_246)
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_139)
    _ => Error
  }
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_type_annotation, yy_action_245)
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_function_literal_parameters, yy_action_244)
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_142)
    T_RPAREN => Reduce(1, NT_function_literal_parameters, yy_action_243)
    _ => Error
  }
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_134)
    NT_function_literal_parameter_modifiers => Shift(yy_state_135)
    NT_function_literal_parameter => Shift(yy_state_143)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_250)
    _ => Error
  }
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_function_literal_parameters, yy_action_242)
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_145)
    _ => Error
  }
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_146)
    NT_return_annotation => Shift(yy_state_149)
    T_LBRACE => Reduce(0, NT_return_annotation, yy_action_241)
    _ => Error
  }
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_147)
    _ => Error
  }
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_148)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_return_annotation, yy_action_240)
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block_expression => Shift(yy_state_150)
    T_LBRACE => Shift(yy_state_151)
    _ => Error
  }
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_literal, yy_action_239)
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_152)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_BUILTIN | T_EXTERN | T_MINUS | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    NT_local_items => Shift(yy_state_153)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_BUILTIN | T_EXTERN | T_MINUS | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET => Reduce(0, NT_local_items, yy_action_238)
    _ => Error
  }
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_offer_value_declaration => Shift(yy_state_405)
    NT_function_declaration => Shift(yy_state_406)
    NT_local_let_item => Shift(yy_state_407)
    NT_local_item => Shift(yy_state_408)
    NT_expression => Shift(yy_state_410)
    T_LET => Shift(yy_state_412)
    T_OFFER => Shift(yy_state_417)
    T_FN => Shift(yy_state_447)
    _ => Error
  }
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_350)
    _ => Error
  }
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_295)
    _ => Error
  }
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_288)
    _ => Error
  }
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_237)
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_236)
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_non_empty_positional_argument_list => Shift(yy_state_160)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_269)
    NT_list_literal_items => Shift(yy_state_286)
    T_RBRACKET => Reduce(0, NT_list_literal_items, yy_action_235)
    _ => Error
  }
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_161)
    T_RBRACKET => Reduce(1, NT_list_literal_items, yy_action_234)
    _ => Error
  }
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_285)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_positional_argument_list, yy_action_233)
    _ => Error
  }
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_232)
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_231)
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_230)
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_229)
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_228)
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_RPAREN => Shift(yy_state_168)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_283)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_non_owner_primary_expression, yy_action_227)
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_226)
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_225)
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_224)
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_223)
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_222)
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER_LBRACKET => Shift(yy_state_175)
    NT_owner_type_arguments => Shift(yy_state_180)
    T_DOT => Shift(yy_state_181)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_expression, yy_action_221)
    _ => Error
  }
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_generic_argument => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_60)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_91)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_176)
    NT_non_empty_generic_argument_list => Shift(yy_state_178)
    _ => Error
  }
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_177)
    _ => Error
  }
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_type_arguments, yy_action_220)
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_95)
    T_RBRACKET => Shift(yy_state_179)
    _ => Error
  }
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_type_arguments, yy_action_219)
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_owner_expression, yy_action_218)
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_182)
    _ => Error
  }
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_path_expression, yy_action_217)
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_184)
    _ => Error
  }
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_185)
    NT_type_argument_bracket_list => Shift(yy_state_190)
    NT_type_arguments => Shift(yy_state_191)
    NT_operation_type_witnesses => Shift(yy_state_192)
    T_LPAREN => Shift(yy_state_280)
    _ => Error
  }
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_generic_argument => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_60)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_91)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_186)
    NT_non_empty_generic_argument_list => Shift(yy_state_188)
    _ => Error
  }
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_187)
    _ => Error
  }
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_216)
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_95)
    T_RBRACKET => Shift(yy_state_189)
    _ => Error
  }
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_215)
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_arguments, yy_action_214)
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_operation_type_witnesses, yy_action_213)
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_193)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_empty_positional_argument_list => Shift(yy_state_194)
    NT_positional_argument_list => Shift(yy_state_195)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_269)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_212)
    _ => Error
  }
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_161)
    T_RPAREN => Reduce(1, NT_positional_argument_list, yy_action_211)
    _ => Error
  }
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_196)
    _ => Error
  }
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_value_postfix_expression, yy_action_210)
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_209)
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_199)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_DOT => Reduce(1, NT_value_postfix_expression, yy_action_208)
    _ => Error
  }
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_200)
    NT_identifier => Shift(yy_state_263)
    T_IDENT => Shift(yy_state_273)
    _ => Error
  }
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_201)
    NT_struct_literal_field => Shift(yy_state_257)
    NT_non_empty_struct_literal_fields => Shift(yy_state_258)
    NT_struct_literal_fields => Shift(yy_state_261)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_207)
    _ => Error
  }
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_202)
    T_COLON => Shift(yy_state_204)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(1, NT_struct_literal_field, yy_action_206)
    _ => Error
  }
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_203)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_literal_field, yy_action_205)
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_256)
    _ => Error
  }
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_204)
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_185)
    NT_type_argument_bracket_list => Shift(yy_state_190)
    T_DOT => Shift(yy_state_207)
    NT_type_arguments => Shift(yy_state_209)
    T_LPAREN => Shift(yy_state_210)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(1, NT_postfix_expression, yy_action_203)
    _ => Error
  }
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_208)
    _ => Error
  }
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_value_postfix_expression, yy_action_202)
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value_postfix_expression, yy_action_201)
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_call_argument => Shift(yy_state_211)
    NT_non_empty_argument_list => Shift(yy_state_212)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_222)
    T_IDENT => Shift(yy_state_251)
    NT_argument_list => Shift(yy_state_254)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_200)
    _ => Error
  }
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_argument_list, yy_action_199)
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_213)
    T_RPAREN => Reduce(1, NT_argument_list, yy_action_198)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_call_argument => Shift(yy_state_214)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_222)
    T_IDENT => Shift(yy_state_251)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_argument_list, yy_action_197)
    _ => Error
  }
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_argument_list, yy_action_196)
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_unary_expression, yy_action_195)
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    NT_unary_expression => Shift(yy_state_217)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_194)
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    NT_unary_expression => Shift(yy_state_219)
    T_IDENT => Shift(yy_state_220)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_193)
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Reduce(1, NT_identifier, yy_action_269)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_OWNER_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_DOT | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_path_expression, yy_action_192)
    _ => Error
  }
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_191)
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RPAREN | T_COMMA => Reduce(1, NT_call_argument, yy_action_190)
    _ => Error
  }
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_224)
    _ => Error
  }
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_189)
}

fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_226)
    _ => Error
  }
}

fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_188)
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_228)
    _ => Error
  }
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_187)
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_230)
    _ => Error
  }
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_186)
    _ => Error
  }
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_232)
    _ => Error
  }
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_185)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_234)
    _ => Error
  }
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_184)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_236)
    _ => Error
  }
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_183)
    _ => Error
  }
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_238)
    _ => Error
  }
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_182)
    _ => Error
  }
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_240)
    _ => Error
  }
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_181)
    _ => Error
  }
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_242)
    _ => Error
  }
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_180)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_244)
    _ => Error
  }
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_179)
    _ => Error
  }
}

fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_246)
    _ => Error
  }
}

fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_AMPAMP | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_178)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_248)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_BARBAR | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_177)
    _ => Error
  }
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_250)
    _ => Error
  }
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_expression, yy_action_176)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_252)
    T_BANG => Reduce(1, NT_identifier, yy_action_269)
    T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACKET | T_OWNER_LBRACKET | T_COMMA | T_DOT | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_path_expression, yy_action_192)
    _ => Error
  }
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_253)
    _ => Error
  }
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RPAREN | T_COMMA => Reduce(3, NT_call_argument, yy_action_175)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_255)
    _ => Error
  }
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_value_postfix_expression, yy_action_174)
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(3, NT_struct_literal_field, yy_action_173)
    _ => Error
  }
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_literal_fields, yy_action_172)
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_259)
    T_RBRACE => Reduce(1, NT_struct_literal_fields, yy_action_171)
    _ => Error
  }
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_201)
    NT_struct_literal_field => Shift(yy_state_260)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_struct_literal_fields, yy_action_170)
    _ => Error
  }
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_literal_fields, yy_action_169)
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_262)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_168)
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_264)
    _ => Error
  }
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_185)
    NT_type_argument_bracket_list => Shift(yy_state_190)
    NT_type_arguments => Shift(yy_state_191)
    NT_operation_type_witnesses => Shift(yy_state_265)
    T_LPAREN => Shift(yy_state_270)
    _ => Error
  }
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_266)
    _ => Error
  }
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_empty_positional_argument_list => Shift(yy_state_194)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_positional_argument_list => Shift(yy_state_267)
    NT_expression => Shift(yy_state_269)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_212)
    _ => Error
  }
}

fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_268)
    _ => Error
  }
}

fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_member_expression, yy_action_167)
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(1, NT_non_empty_positional_argument_list, yy_action_166)
    _ => Error
  }
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_empty_positional_argument_list => Shift(yy_state_194)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_269)
    NT_positional_argument_list => Shift(yy_state_271)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_212)
    _ => Error
  }
}

fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_272)
    _ => Error
  }
}

fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_member_expression, yy_action_165)
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_185)
    NT_type_argument_bracket_list => Shift(yy_state_190)
    NT_type_arguments => Shift(yy_state_274)
    NT_variant_type_arguments => Shift(yy_state_275)
    T_LPAREN => Reduce(0, NT_variant_type_arguments, yy_action_164)
    T_BANG => Reduce(1, NT_identifier, yy_action_269)
    _ => Error
  }
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_variant_type_arguments, yy_action_163)
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_276)
    NT_variant_arguments => Shift(yy_state_279)
    _ => Error
  }
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_empty_positional_argument_list => Shift(yy_state_194)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_269)
    NT_positional_argument_list => Shift(yy_state_277)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_212)
    _ => Error
  }
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_278)
    _ => Error
  }
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_arguments, yy_action_162)
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_161)
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_empty_positional_argument_list => Shift(yy_state_194)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_269)
    NT_positional_argument_list => Shift(yy_state_281)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_212)
    _ => Error
  }
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_282)
    _ => Error
  }
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_value_postfix_expression, yy_action_160)
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RPAREN => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_159)
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(3, NT_non_empty_positional_argument_list, yy_action_158)
    _ => Error
  }
}

fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_287)
    _ => Error
  }
}

fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_157)
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    NT_block_expression => Shift(yy_state_289)
    _ => Error
  }
}

fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_290)
    NT_optional_else_branch => Shift(yy_state_294)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_WITH | T_EXTERN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_SEMICOLON | T_LAYOUT_SEMICOLON | T_DOT => Reduce(0, NT_optional_else_branch, yy_action_156)
    _ => Error
  }
}

fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    T_IF => Shift(yy_state_156)
    NT_if_expression => Shift(yy_state_291)
    NT_block_expression => Shift(yy_state_292)
    NT_else_branch_expression => Shift(yy_state_293)
    _ => Error
  }
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_155)
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_154)
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_optional_else_branch, yy_action_153)
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_if_expression, yy_action_152)
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_LBRACE => Shift(yy_state_296)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_297)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_RBRACE | T_LAYOUT_SEMICOLON | T_UNDERSCORE => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_339)
    NT_match_arm => Shift(yy_state_342)
    NT_non_empty_match_arms => Shift(yy_state_343)
    NT_match_arms => Shift(yy_state_348)
    T_RBRACE => Reduce(0, NT_match_arms, yy_action_151)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_299)
    _ => Error
  }
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_300)
    T_IDENT => Shift(yy_state_334)
    _ => Error
  }
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_301)
    T_IDENT => Shift(yy_state_302)
    NT_struct_pattern_field => Shift(yy_state_328)
    NT_non_empty_struct_pattern_fields => Shift(yy_state_329)
    NT_struct_pattern_fields => Shift(yy_state_332)
    T_RBRACE => Reduce(0, NT_struct_pattern_fields, yy_action_150)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_pattern_field, yy_action_149)
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_303)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(1, NT_struct_pattern_field, yy_action_148)
    _ => Error
  }
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_pattern => Shift(yy_state_304)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    _ => Error
  }
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_pattern_field, yy_action_147)
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_146)
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_145)
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_144)
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_143)
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_142)
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_141)
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_140)
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_49)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_139)
    _ => Error
  }
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_46)
    T_LBRACKET => Shift(yy_state_314)
    NT_variant_type_binders => Shift(yy_state_320)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_138)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_136)
    T_RPAREN | T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON | T_COLON | T_FAT_ARROW | T_EQUAL => Reduce(1, NT_pattern, yy_action_137)
    _ => Error
  }
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_315)
    NT_non_empty_ident_list => Shift(yy_state_316)
    _ => Error
  }
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_ident_list, yy_action_135)
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_317)
    T_RBRACKET => Shift(yy_state_319)
    _ => Error
  }
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_318)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_ident_list, yy_action_134)
    _ => Error
  }
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_ident_list, yy_action_133)
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_binders, yy_action_132)
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_321)
    _ => Error
  }
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_322)
    NT_non_empty_pattern_list => Shift(yy_state_323)
    NT_pattern_list => Shift(yy_state_326)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_131)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_pattern_list, yy_action_130)
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_324)
    T_RPAREN => Reduce(1, NT_pattern_list, yy_action_129)
    _ => Error
  }
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_325)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_pattern_list, yy_action_128)
    _ => Error
  }
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_pattern_list, yy_action_127)
}

fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_327)
    _ => Error
  }
}

fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_pattern, yy_action_126)
}

fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_pattern_fields, yy_action_125)
}

fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_330)
    T_RBRACE => Reduce(1, NT_struct_pattern_fields, yy_action_124)
    _ => Error
  }
}

fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_301)
    T_IDENT => Shift(yy_state_302)
    NT_struct_pattern_field => Shift(yy_state_331)
    T_RBRACE | T_COMMA | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_struct_pattern_fields, yy_action_123)
    _ => Error
  }
}

fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_pattern_fields, yy_action_122)
}

fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_333)
    _ => Error
  }
}

fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_pattern, yy_action_121)
}

fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_314)
    NT_variant_type_binders => Shift(yy_state_335)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_138)
    _ => Error
  }
}

fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_336)
    _ => Error
  }
}

fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_322)
    NT_non_empty_pattern_list => Shift(yy_state_323)
    NT_pattern_list => Shift(yy_state_337)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_131)
    _ => Error
  }
}

fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_338)
    _ => Error
  }
}

fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_pattern, yy_action_120)
}

fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_340)
    _ => Error
  }
}

fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_341)
    _ => Error
  }
}

fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(3, NT_match_arm, yy_action_119)
    _ => Error
  }
}

fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_match_arms, yy_action_118)
}

fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_item_semicolon => Shift(yy_state_344)
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    T_RBRACE => Reduce(1, NT_match_arms, yy_action_117)
    _ => Error
  }
}

fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_339)
    NT_match_arm => Shift(yy_state_345)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_match_arms, yy_action_116)
    _ => Error
  }
}

fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_match_arms, yy_action_115)
}

fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_item_semicolon, yy_action_114)
}

fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_item_semicolon, yy_action_113)
}

fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_match_expression, yy_action_112)
}

fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_WITH => Shift(yy_state_351)
    NT_handler_with_block => Shift(yy_state_398)
    NT_handler_with_blocks => Shift(yy_state_399)
    _ => Error
  }
}

fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_352)
    _ => Error
  }
}

fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_353)
    T_IDENT | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    NT_identifier => Shift(yy_state_354)
    NT_handler_operation_head => Shift(yy_state_372)
    NT_handler_operation_arm => Shift(yy_state_385)
    NT_non_empty_handler_operation_arms => Shift(yy_state_386)
    NT_qualified_type_name => Shift(yy_state_389)
    T_IDENT => Shift(yy_state_395)
    NT_handler_operation_arms => Shift(yy_state_396)
    _ => Error
  }
}

fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER_LBRACKET => Shift(yy_state_355)
    T_LBRACKET => Shift(yy_state_358)
    NT_ident_bracket_list => Shift(yy_state_363)
    NT_handler_operation_generic_arguments => Shift(yy_state_364)
    T_TIGHT_COLONCOLON => Shift(yy_state_368)
    NT_handler_operation_type_binders => Shift(yy_state_371)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_111)
    _ => Error
  }
}

fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_generic_argument => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_60)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_91)
    NT_non_empty_generic_argument_list => Shift(yy_state_356)
    _ => Error
  }
}

fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_20)
    T_COMMA => Shift(yy_state_21)
    NT_layout_list_separator => Shift(yy_state_95)
    T_RBRACKET => Shift(yy_state_357)
    _ => Error
  }
}

fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_generic_arguments, yy_action_110)
}

fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_315)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_359)
    NT_non_empty_ident_list => Shift(yy_state_361)
    _ => Error
  }
}

fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_360)
    _ => Error
  }
}

fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_109)
}

fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_317)
    T_RBRACKET => Shift(yy_state_362)
    _ => Error
  }
}

fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_108)
}

fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_type_binders, yy_action_107)
}

fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_365)
    _ => Error
  }
}

fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_366)
    _ => Error
  }
}

fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_358)
    NT_ident_bracket_list => Shift(yy_state_363)
    NT_handler_operation_type_binders => Shift(yy_state_367)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_111)
    _ => Error
  }
}

fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_handler_operation_head, yy_action_106)
}

fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_369)
    _ => Error
  }
}

fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_358)
    NT_ident_bracket_list => Shift(yy_state_363)
    NT_handler_operation_type_binders => Shift(yy_state_370)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_111)
    _ => Error
  }
}

fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_operation_head, yy_action_105)
}

fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_operation_head, yy_action_104)
}

fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_373)
    _ => Error
  }
}

fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    NT_pattern => Shift(yy_state_374)
    NT_handler_payload_patterns => Shift(yy_state_375)
    T_IDENT => Shift(yy_state_379)
    NT_identifier => Shift(yy_state_380)
    NT_handler_operation_arm_parameters => Shift(yy_state_381)
    _ => Error
  }
}

fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_payload_patterns, yy_action_103)
}

fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_376)
    _ => Error
  }
}

fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    NT_pattern => Shift(yy_state_377)
    NT_identifier => Shift(yy_state_378)
    T_IDENT => Shift(yy_state_379)
    _ => Error
  }
}

fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_payload_patterns, yy_action_102)
}

fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_arm_parameters, yy_action_101)
}

fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_46)
    T_LBRACKET => Shift(yy_state_314)
    NT_variant_type_binders => Shift(yy_state_320)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_138)
    T_RPAREN => Reduce(1, NT_identifier, yy_action_269)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_136)
    T_COMMA => Reduce(1, NT_pattern, yy_action_137)
    _ => Error
  }
}

fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_arm_parameters, yy_action_100)
}

fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_382)
    _ => Error
  }
}

fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_383)
    _ => Error
  }
}

fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_384)
    _ => Error
  }
}

fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(6, NT_handler_operation_arm, yy_action_99)
    _ => Error
  }
}

fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_handler_operation_arms, yy_action_98)
}

fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    NT_item_semicolon => Shift(yy_state_387)
    T_RBRACE => Reduce(1, NT_handler_operation_arms, yy_action_97)
    _ => Error
  }
}

fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_354)
    NT_handler_operation_head => Shift(yy_state_372)
    NT_handler_operation_arm => Shift(yy_state_388)
    NT_qualified_type_name => Shift(yy_state_389)
    T_IDENT => Shift(yy_state_395)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_handler_operation_arms, yy_action_96)
    _ => Error
  }
}

fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_handler_operation_arms, yy_action_95)
}

fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_49)
    T_OWNER_LBRACKET => Shift(yy_state_355)
    NT_handler_operation_generic_arguments => Shift(yy_state_390)
    NT_handler_operation_owner_arguments => Shift(yy_state_391)
    T_TIGHT_COLONCOLON => Reduce(0, NT_handler_operation_owner_arguments, yy_action_94)
    _ => Error
  }
}

fn yy_state_390(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_owner_arguments, yy_action_93)
}

fn yy_state_391(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_392)
    _ => Error
  }
}

fn yy_state_392(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_393)
    _ => Error
  }
}

fn yy_state_393(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_358)
    NT_ident_bracket_list => Shift(yy_state_363)
    NT_handler_operation_type_binders => Shift(yy_state_394)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_111)
    _ => Error
  }
}

fn yy_state_394(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_handler_operation_head, yy_action_92)
}

fn yy_state_395(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_46)
    T_LPAREN | T_LBRACKET | T_OWNER_LBRACKET | T_TIGHT_COLONCOLON => Reduce(1, NT_identifier, yy_action_269)
    _ => Error
  }
}

fn yy_state_396(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_397)
    _ => Error
  }
}

fn yy_state_397(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_handler_with_block, yy_action_91)
}

fn yy_state_398(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_with_blocks, yy_action_90)
}

fn yy_state_399(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_WITH => Shift(yy_state_351)
    T_FINAL => Shift(yy_state_400)
    NT_handler_with_block => Shift(yy_state_403)
    NT_handler_final_branch => Shift(yy_state_404)
    _ => Error
  }
}

fn yy_state_400(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_401)
    _ => Error
  }
}

fn yy_state_401(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    NT_block_expression => Shift(yy_state_402)
    _ => Error
  }
}

fn yy_state_402(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_final_branch, yy_action_89)
}

fn yy_state_403(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_with_blocks, yy_action_88)
}

fn yy_state_404(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_expression, yy_action_87)
}

fn yy_state_405(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_86)
}

fn yy_state_406(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_85)
}

fn yy_state_407(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_84)
}

fn yy_state_408(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    NT_item_semicolon => Shift(yy_state_409)
    _ => Error
  }
}

fn yy_state_409(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_local_items, yy_action_83)
}

fn yy_state_410(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_RBRACE => Shift(yy_state_411)
    T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(1, NT_local_item, yy_action_82)
    _ => Error
  }
}

fn yy_state_411(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_block_expression, yy_action_81)
}

fn yy_state_412(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_298)
    NT_struct_pattern => Shift(yy_state_305)
    T_FALSE => Shift(yy_state_306)
    T_TRUE => Shift(yy_state_307)
    T_STRING => Shift(yy_state_308)
    T_DOUBLE => Shift(yy_state_309)
    T_INT => Shift(yy_state_310)
    T_UNDERSCORE => Shift(yy_state_311)
    NT_qualified_type_name => Shift(yy_state_312)
    T_IDENT => Shift(yy_state_313)
    NT_pattern => Shift(yy_state_413)
    _ => Error
  }
}

fn yy_state_413(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_138)
    NT_local_type_annotation => Shift(yy_state_414)
    T_EQUAL => Reduce(0, NT_local_type_annotation, yy_action_247)
    _ => Error
  }
}

fn yy_state_414(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_415)
    _ => Error
  }
}

fn yy_state_415(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_416)
    _ => Error
  }
}

fn yy_state_416(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(5, NT_local_let_item, yy_action_80)
    _ => Error
  }
}

fn yy_state_417(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_418)
    T_FN => Shift(yy_state_423)
    _ => Error
  }
}

fn yy_state_418(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_419)
    _ => Error
  }
}

fn yy_state_419(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_420)
    _ => Error
  }
}

fn yy_state_420(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_421)
    _ => Error
  }
}

fn yy_state_421(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_422)
    _ => Error
  }
}

fn yy_state_422(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(6, NT_offer_value_declaration, yy_action_79)
    _ => Error
  }
}

fn yy_state_423(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_425)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_424(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameters, yy_action_78)
}

fn yy_state_425(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_426)
    _ => Error
  }
}

fn yy_state_426(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_427)
    NT_parameters => Shift(yy_state_442)
    _ => Error
  }
}

fn yy_state_427(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_428)
    T_AUTO => Shift(yy_state_430)
    NT_parameter_modifiers => Shift(yy_state_432)
    NT_parameter => Shift(yy_state_436)
    NT_non_empty_parameter_list => Shift(yy_state_437)
    T_RPAREN => Shift(yy_state_441)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_77)
    _ => Error
  }
}

fn yy_state_428(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AUTO => Shift(yy_state_429)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_76)
    _ => Error
  }
}

fn yy_state_429(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_75)
}

fn yy_state_430(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_431)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_74)
    _ => Error
  }
}

fn yy_state_431(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_73)
}

fn yy_state_432(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_433)
    _ => Error
  }
}

fn yy_state_433(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_434)
    _ => Error
  }
}

fn yy_state_434(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_435)
    _ => Error
  }
}

fn yy_state_435(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameter, yy_action_72)
}

fn yy_state_436(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_parameter_list, yy_action_71)
}

fn yy_state_437(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_438)
    T_RPAREN => Shift(yy_state_440)
    _ => Error
  }
}

fn yy_state_438(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_428)
    T_AUTO => Shift(yy_state_430)
    NT_parameter_modifiers => Shift(yy_state_432)
    NT_parameter => Shift(yy_state_439)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_77)
    _ => Error
  }
}

fn yy_state_439(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_parameter_list, yy_action_70)
}

fn yy_state_440(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parameters, yy_action_69)
}

fn yy_state_441(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameters, yy_action_68)
}

fn yy_state_442(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_443)
    _ => Error
  }
}

fn yy_state_443(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_444)
    _ => Error
  }
}

fn yy_state_444(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_445)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_445(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    NT_block_expression => Shift(yy_state_446)
    _ => Error
  }
}

fn yy_state_446(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_function_declaration, yy_action_67)
}

fn yy_state_447(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_448)
    T_IDENT | T_LPAREN => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_448(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    T_LPAREN => Shift(yy_state_133)
    NT_identifier => Shift(yy_state_449)
    _ => Error
  }
}

fn yy_state_449(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_427)
    NT_parameters => Shift(yy_state_450)
    _ => Error
  }
}

fn yy_state_450(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_451)
    _ => Error
  }
}

fn yy_state_451(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_452)
    _ => Error
  }
}

fn yy_state_452(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_453)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_453(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    NT_block_expression => Shift(yy_state_454)
    _ => Error
  }
}

fn yy_state_454(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_declaration, yy_action_66)
}

fn yy_state_455(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_SEMICOLON => Reduce(6, NT_top_level_let_declaration, yy_action_65)
    _ => Error
  }
}

fn yy_state_456(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_457)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_457(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_449)
    _ => Error
  }
}

fn yy_state_458(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_459)
    _ => Error
  }
}

fn yy_state_459(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_460)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_460(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_461)
    _ => Error
  }
}

fn yy_state_461(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_462)
    T_IDENT | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_462(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_463)
    NT_effect_operation => Shift(yy_state_475)
    NT_non_empty_effect_operations => Shift(yy_state_476)
    NT_effect_operations => Shift(yy_state_479)
    T_RBRACE => Reduce(0, NT_effect_operations, yy_action_64)
    _ => Error
  }
}

fn yy_state_463(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_464)
    T_LPAREN => Shift(yy_state_470)
    _ => Error
  }
}

fn yy_state_464(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_465)
    _ => Error
  }
}

fn yy_state_465(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_466)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_466(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_467)
    _ => Error
  }
}

fn yy_state_467(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_468)
    _ => Error
  }
}

fn yy_state_468(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_469)
    _ => Error
  }
}

fn yy_state_469(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_effect_operation, yy_action_63)
}

fn yy_state_470(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_471)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_471(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_472)
    _ => Error
  }
}

fn yy_state_472(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_473)
    _ => Error
  }
}

fn yy_state_473(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_474)
    _ => Error
  }
}

fn yy_state_474(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_effect_operation, yy_action_62)
}

fn yy_state_475(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_effect_operations, yy_action_61)
}

fn yy_state_476(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    NT_item_semicolon => Shift(yy_state_477)
    T_RBRACE => Reduce(1, NT_effect_operations, yy_action_60)
    _ => Error
  }
}

fn yy_state_477(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_463)
    NT_effect_operation => Shift(yy_state_478)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_effect_operations, yy_action_59)
    _ => Error
  }
}

fn yy_state_478(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_effect_operations, yy_action_58)
}

fn yy_state_479(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_480)
    _ => Error
  }
}

fn yy_state_480(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_effect_declaration, yy_action_57)
}

fn yy_state_481(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_482)
    _ => Error
  }
}

fn yy_state_482(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_483)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_483(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_484)
    _ => Error
  }
}

fn yy_state_484(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_485)
    T_IDENT | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_485(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_486)
    NT_enum_variant => Shift(yy_state_494)
    NT_non_empty_enum_variants => Shift(yy_state_495)
    NT_enum_variants => Shift(yy_state_498)
    T_RBRACE => Reduce(0, NT_enum_variants, yy_action_56)
    _ => Error
  }
}

fn yy_state_486(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_487)
    T_LPAREN => Shift(yy_state_491)
    _ => Error
  }
}

fn yy_state_487(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_488)
    _ => Error
  }
}

fn yy_state_488(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_489)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_489(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_490)
    _ => Error
  }
}

fn yy_state_490(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_enum_variant, yy_action_55)
}

fn yy_state_491(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_492)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_492(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_493)
    _ => Error
  }
}

fn yy_state_493(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_enum_variant, yy_action_54)
}

fn yy_state_494(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_enum_variants, yy_action_53)
}

fn yy_state_495(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    NT_item_semicolon => Shift(yy_state_496)
    T_RBRACE => Reduce(1, NT_enum_variants, yy_action_52)
    _ => Error
  }
}

fn yy_state_496(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_486)
    NT_enum_variant => Shift(yy_state_497)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_enum_variants, yy_action_51)
    _ => Error
  }
}

fn yy_state_497(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_enum_variants, yy_action_50)
}

fn yy_state_498(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_499)
    _ => Error
  }
}

fn yy_state_499(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_enum_declaration, yy_action_49)
}

fn yy_state_500(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_501)
    _ => Error
  }
}

fn yy_state_501(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_502)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_502(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_503)
    _ => Error
  }
}

fn yy_state_503(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_504)
    T_IDENT | T_TYPE | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_504(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_505)
    T_TYPE => Shift(yy_state_508)
    NT_field_declaration => Shift(yy_state_512)
    NT_type_member_declaration => Shift(yy_state_513)
    NT_struct_member => Shift(yy_state_514)
    NT_non_empty_struct_members => Shift(yy_state_515)
    NT_struct_members => Shift(yy_state_518)
    T_RBRACE => Reduce(0, NT_struct_members, yy_action_48)
    _ => Error
  }
}

fn yy_state_505(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_506)
    _ => Error
  }
}

fn yy_state_506(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_507)
    _ => Error
  }
}

fn yy_state_507(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_field_declaration, yy_action_47)
}

fn yy_state_508(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_509)
    _ => Error
  }
}

fn yy_state_509(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_510)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_type_member_declaration, yy_action_46)
    _ => Error
  }
}

fn yy_state_510(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    NT_kind => Shift(yy_state_511)
    _ => Error
  }
}

fn yy_state_511(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_member_declaration, yy_action_45)
}

fn yy_state_512(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_44)
}

fn yy_state_513(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_43)
}

fn yy_state_514(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_members, yy_action_42)
}

fn yy_state_515(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_346)
    T_SEMICOLON => Shift(yy_state_347)
    NT_item_semicolon => Shift(yy_state_516)
    T_RBRACE => Reduce(1, NT_struct_members, yy_action_41)
    _ => Error
  }
}

fn yy_state_516(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_505)
    T_TYPE => Shift(yy_state_508)
    NT_field_declaration => Shift(yy_state_512)
    NT_type_member_declaration => Shift(yy_state_513)
    NT_struct_member => Shift(yy_state_517)
    T_RBRACE | T_SEMICOLON | T_LAYOUT_SEMICOLON => Reduce(2, NT_non_empty_struct_members, yy_action_40)
    _ => Error
  }
}

fn yy_state_517(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_members, yy_action_39)
}

fn yy_state_518(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_519)
    _ => Error
  }
}

fn yy_state_519(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_struct_declaration, yy_action_38)
}

fn yy_state_520(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_521)
    _ => Error
  }
}

fn yy_state_521(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_522)
    T_COLON | T_EQUAL => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_522(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_523)
    NT_type_alias_result_kind_opt => Shift(yy_state_525)
    T_EQUAL => Reduce(0, NT_type_alias_result_kind_opt, yy_action_37)
    _ => Error
  }
}

fn yy_state_523(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_69)
    T_LBRACKET => Shift(yy_state_72)
    T_KIND_EFFECT => Shift(yy_state_77)
    T_KIND_TYPE => Shift(yy_state_78)
    NT_kind => Shift(yy_state_524)
    _ => Error
  }
}

fn yy_state_524(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_alias_result_kind_opt, yy_action_36)
}

fn yy_state_525(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_526)
    _ => Error
  }
}

fn yy_state_526(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    T_LBRACE => Shift(yy_state_527)
    NT_type => Shift(yy_state_530)
    NT_type_alias_body => Shift(yy_state_531)
    _ => Error
  }
}

fn yy_state_527(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    NT_type => Shift(yy_state_33)
    NT_non_empty_type_list => Shift(yy_state_34)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type_list => Shift(yy_state_528)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_303)
    _ => Error
  }
}

fn yy_state_528(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_529)
    _ => Error
  }
}

fn yy_state_529(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_body, yy_action_35)
}

fn yy_state_530(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_alias_body, yy_action_34)
}

fn yy_state_531(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type_alias_declaration, yy_action_33)
}

fn yy_state_532(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE => Shift(yy_state_533)
    _ => Error
  }
}

fn yy_state_533(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_534)
    _ => Error
  }
}

fn yy_state_534(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_535)
    T_COLON => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_535(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_536)
    _ => Error
  }
}

fn yy_state_536(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_EFFECT => Shift(yy_state_537)
    T_KIND_TYPE => Shift(yy_state_538)
    NT_external_type_result_kind => Shift(yy_state_539)
    _ => Error
  }
}

fn yy_state_537(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_external_type_result_kind, yy_action_32)
}

fn yy_state_538(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_external_type_result_kind, yy_action_31)
}

fn yy_state_539(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_external_type_declaration, yy_action_30)
}

fn yy_state_540(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LET => Shift(yy_state_541)
    T_OFFER => Shift(yy_state_547)
    T_FN => Shift(yy_state_561)
    T_EFFECT => Shift(yy_state_569)
    T_ENUM => Shift(yy_state_576)
    T_STRUCT => Shift(yy_state_583)
    T_TYPE => Shift(yy_state_590)
    T_EXTERN => Shift(yy_state_596)
    NT_public_offer_value_declaration => Shift(yy_state_602)
    NT_public_top_level_let_declaration => Shift(yy_state_603)
    NT_public_function_declaration => Shift(yy_state_604)
    NT_public_type_alias_declaration => Shift(yy_state_605)
    NT_public_external_type_declaration => Shift(yy_state_606)
    NT_public_effect_declaration => Shift(yy_state_607)
    NT_public_enum_declaration => Shift(yy_state_608)
    NT_public_struct_declaration => Shift(yy_state_609)
    NT_public_top_level_declaration => Shift(yy_state_610)
    _ => Error
  }
}

fn yy_state_541(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_542)
    _ => Error
  }
}

fn yy_state_542(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_543)
    _ => Error
  }
}

fn yy_state_543(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_544)
    _ => Error
  }
}

fn yy_state_544(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_545)
    _ => Error
  }
}

fn yy_state_545(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_546)
    _ => Error
  }
}

fn yy_state_546(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_SEMICOLON => Reduce(6, NT_public_top_level_let_declaration, yy_action_29)
    _ => Error
  }
}

fn yy_state_547(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_548)
    T_FN => Shift(yy_state_553)
    _ => Error
  }
}

fn yy_state_548(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_549)
    _ => Error
  }
}

fn yy_state_549(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_550)
    _ => Error
  }
}

fn yy_state_550(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_551)
    _ => Error
  }
}

fn yy_state_551(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERN => Shift(yy_state_123)
    T_BUILTIN => Shift(yy_state_127)
    T_FN => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_151)
    T_HANDLE => Shift(yy_state_154)
    T_MATCH => Shift(yy_state_155)
    T_IF => Shift(yy_state_156)
    NT_extern_expression => Shift(yy_state_157)
    NT_builtin_expression => Shift(yy_state_158)
    T_LBRACKET => Shift(yy_state_159)
    NT_function_literal => Shift(yy_state_162)
    NT_handler_expression => Shift(yy_state_163)
    NT_match_expression => Shift(yy_state_164)
    NT_if_expression => Shift(yy_state_165)
    NT_block_expression => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_167)
    T_FALSE => Shift(yy_state_169)
    T_TRUE => Shift(yy_state_170)
    T_STRING => Shift(yy_state_171)
    T_DOUBLE => Shift(yy_state_172)
    T_INT => Shift(yy_state_173)
    NT_owner_path_expression => Shift(yy_state_174)
    NT_identifier => Shift(yy_state_183)
    NT_non_owner_primary_expression => Shift(yy_state_197)
    NT_owner_expression => Shift(yy_state_198)
    NT_member_expression => Shift(yy_state_205)
    NT_value_postfix_expression => Shift(yy_state_206)
    NT_postfix_expression => Shift(yy_state_215)
    T_BANG => Shift(yy_state_216)
    T_MINUS => Shift(yy_state_218)
    T_IDENT => Shift(yy_state_220)
    NT_unary_expression => Shift(yy_state_221)
    NT_expression => Shift(yy_state_552)
    _ => Error
  }
}

fn yy_state_552(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_223)
    T_SLASH => Shift(yy_state_225)
    T_STAR => Shift(yy_state_227)
    T_MINUS => Shift(yy_state_229)
    T_PLUS => Shift(yy_state_231)
    T_GTEQ => Shift(yy_state_233)
    T_GT => Shift(yy_state_235)
    T_LTEQ => Shift(yy_state_237)
    T_LT => Shift(yy_state_239)
    T_BANGEQ => Shift(yy_state_241)
    T_EQEQ => Shift(yy_state_243)
    T_AMPAMP => Shift(yy_state_245)
    T_BARBAR => Shift(yy_state_247)
    T_PIPE => Shift(yy_state_249)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_SEMICOLON => Reduce(6, NT_public_offer_value_declaration, yy_action_28)
    _ => Error
  }
}

fn yy_state_553(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_554)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_554(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_555)
    _ => Error
  }
}

fn yy_state_555(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_427)
    NT_parameters => Shift(yy_state_556)
    _ => Error
  }
}

fn yy_state_556(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_557)
    _ => Error
  }
}

fn yy_state_557(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_558)
    _ => Error
  }
}

fn yy_state_558(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_559)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_559(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    NT_block_expression => Shift(yy_state_560)
    _ => Error
  }
}

fn yy_state_560(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_public_function_declaration, yy_action_26)
}

fn yy_state_561(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_562)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_562(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_563)
    _ => Error
  }
}

fn yy_state_563(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_427)
    NT_parameters => Shift(yy_state_564)
    _ => Error
  }
}

fn yy_state_564(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_565)
    _ => Error
  }
}

fn yy_state_565(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    NT_type => Shift(yy_state_566)
    _ => Error
  }
}

fn yy_state_566(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_41)
    NT_effect_annotation => Shift(yy_state_100)
    NT_effect_annotation_opt => Shift(yy_state_567)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_298)
    _ => Error
  }
}

fn yy_state_567(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_151)
    NT_block_expression => Shift(yy_state_568)
    _ => Error
  }
}

fn yy_state_568(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_public_function_declaration, yy_action_24)
}

fn yy_state_569(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_570)
    _ => Error
  }
}

fn yy_state_570(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_571)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_571(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_572)
    _ => Error
  }
}

fn yy_state_572(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_573)
    T_IDENT | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_573(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_463)
    NT_effect_operation => Shift(yy_state_475)
    NT_non_empty_effect_operations => Shift(yy_state_476)
    NT_effect_operations => Shift(yy_state_574)
    T_RBRACE => Reduce(0, NT_effect_operations, yy_action_64)
    _ => Error
  }
}

fn yy_state_574(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_575)
    _ => Error
  }
}

fn yy_state_575(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_public_effect_declaration, yy_action_23)
}

fn yy_state_576(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_577)
    _ => Error
  }
}

fn yy_state_577(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_578)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_578(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_579)
    _ => Error
  }
}

fn yy_state_579(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_580)
    T_IDENT | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_580(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_486)
    NT_enum_variant => Shift(yy_state_494)
    NT_non_empty_enum_variants => Shift(yy_state_495)
    NT_enum_variants => Shift(yy_state_581)
    T_RBRACE => Reduce(0, NT_enum_variants, yy_action_56)
    _ => Error
  }
}

fn yy_state_581(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_582)
    _ => Error
  }
}

fn yy_state_582(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_public_enum_declaration, yy_action_22)
}

fn yy_state_583(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_584)
    _ => Error
  }
}

fn yy_state_584(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_585)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_585(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_586)
    _ => Error
  }
}

fn yy_state_586(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_587)
    T_IDENT | T_TYPE | T_RBRACE | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_587(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_505)
    T_TYPE => Shift(yy_state_508)
    NT_field_declaration => Shift(yy_state_512)
    NT_type_member_declaration => Shift(yy_state_513)
    NT_struct_member => Shift(yy_state_514)
    NT_non_empty_struct_members => Shift(yy_state_515)
    NT_struct_members => Shift(yy_state_588)
    T_RBRACE => Reduce(0, NT_struct_members, yy_action_48)
    _ => Error
  }
}

fn yy_state_588(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_589)
    _ => Error
  }
}

fn yy_state_589(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_public_struct_declaration, yy_action_21)
}

fn yy_state_590(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_591)
    _ => Error
  }
}

fn yy_state_591(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_592)
    T_COLON | T_EQUAL => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_592(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_523)
    NT_type_alias_result_kind_opt => Shift(yy_state_593)
    T_EQUAL => Reduce(0, NT_type_alias_result_kind_opt, yy_action_37)
    _ => Error
  }
}

fn yy_state_593(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_594)
    _ => Error
  }
}

fn yy_state_594(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_45)
    NT_qualified_type_name => Shift(yy_state_48)
    NT_type_primary => Shift(yy_state_51)
    T_TYPE => Shift(yy_state_52)
    NT_function_type => Shift(yy_state_56)
    NT_type_application => Shift(yy_state_57)
    NT_type_lambda => Shift(yy_state_63)
    T_TYPE_IDENTIFIER_SLOT => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_65)
    T_LBRACE => Shift(yy_state_527)
    NT_type => Shift(yy_state_530)
    NT_type_alias_body => Shift(yy_state_595)
    _ => Error
  }
}

fn yy_state_595(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_type_alias_declaration, yy_action_20)
}

fn yy_state_596(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE => Shift(yy_state_597)
    _ => Error
  }
}

fn yy_state_597(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_89)
    NT_identifier => Shift(yy_state_598)
    _ => Error
  }
}

fn yy_state_598(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_65)
    NT_type_parameter_bracket_list => Shift(yy_state_424)
    NT_type_parameters => Shift(yy_state_599)
    T_COLON => Reduce(0, NT_type_parameters, yy_action_251)
    _ => Error
  }
}

fn yy_state_599(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_600)
    _ => Error
  }
}

fn yy_state_600(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_EFFECT => Shift(yy_state_537)
    T_KIND_TYPE => Shift(yy_state_538)
    NT_external_type_result_kind => Shift(yy_state_601)
    _ => Error
  }
}

fn yy_state_601(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_external_type_declaration, yy_action_19)
}

fn yy_state_602(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_18)
}

fn yy_state_603(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_17)
}

fn yy_state_604(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_16)
}

fn yy_state_605(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_15)
}

fn yy_state_606(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_14)
}

fn yy_state_607(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_13)
}

fn yy_state_608(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_12)
}

fn yy_state_609(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_11)
}

fn yy_state_610(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declaration, yy_action_10)
}

fn yy_state_611(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_9)
}

fn yy_state_612(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_8)
}

fn yy_state_613(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_7)
}

fn yy_state_614(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_6)
}

fn yy_state_615(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_5)
}

fn yy_state_616(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_4)
}

fn yy_state_617(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_3)
}

fn yy_state_618(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_2)
}

fn yy_state_619(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_layout_semicolons => Shift(yy_state_620)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB | T_LAYOUT_SEMICOLON => Reduce(0, NT_layout_semicolons, yy_action_319)
    _ => Error
  }
}

fn yy_state_620(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LAYOUT_SEMICOLON => Shift(yy_state_10)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_EXTERN | T_PUB => Reduce(3, NT_top_level_declarations, yy_action_1)
    _ => Error
  }
}

fn yy_state_621(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_source_file, yy_action_0)
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
  for term in ([(T_INT, TK_INT), (T_DOUBLE, TK_DOUBLE), (T_STRING, TK_STRING), (T_IDENT, TK_IDENT), (T_RESERVED, TK_RESERVED), (T_EOF, TK_EOF), (T_FALSE, TK_FALSE), (T_TRUE, TK_TRUE), (T_STRUCT, TK_STRUCT), (T_ENUM, TK_ENUM), (T_EFFECT, TK_EFFECT), (T_FN, TK_FN), (T_LET, TK_LET), (T_TYPE, TK_TYPE), (T_KIND_TYPE, TK_KIND_TYPE), (T_KIND_EFFECT, TK_KIND_EFFECT), (T_OFFER, TK_OFFER), (T_AUTO, TK_AUTO), (T_IF, TK_IF), (T_ELSE, TK_ELSE), (T_MATCH, TK_MATCH), (T_HANDLE, TK_HANDLE), (T_WITH, TK_WITH), (T_FINAL, TK_FINAL), (T_BUILTIN, TK_BUILTIN), (T_EXTERN, TK_EXTERN), (T_MODULE, TK_MODULE), (T_IMPORT, TK_IMPORT), (T_PUB, TK_PUB), (T_PLUS, TK_PLUS), (T_MINUS, TK_MINUS), (T_STAR, TK_STAR), (T_SLASH, TK_SLASH), (T_PERCENT, TK_PERCENT), (T_EQEQ, TK_EQEQ), (T_BANGEQ, TK_BANGEQ), (T_LT, TK_LT), (T_LTEQ, TK_LTEQ), (T_GT, TK_GT), (T_GTEQ, TK_GTEQ), (T_AMPAMP, TK_AMPAMP), (T_BARBAR, TK_BARBAR), (T_BANG, TK_BANG), (T_PIPE, TK_PIPE), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_OWNER_LBRACKET, TK_OWNER_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR, TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR), (T_EMPTY_TYPE_PARAMETER_LIST_ERROR, TK_EMPTY_TYPE_PARAMETER_LIST_ERROR), (T_TYPE_IDENTIFIER_SLOT, TK_TYPE_IDENTIFIER_SLOT), (T_EFFECT_IDENTIFIER_SLOT, TK_EFFECT_IDENTIFIER_SLOT), (T_COMMA, TK_COMMA), (T_SEMICOLON, TK_SEMICOLON), (T_LAYOUT_SEMICOLON, TK_LAYOUT_SEMICOLON), (T_DOTSTAR, TK_DOTSTAR), (T_DOTLBRACE, TK_DOTLBRACE), (T_DOT, TK_DOT), (T_COLON, TK_COLON), (T_COLONCOLON, TK_COLONCOLON), (T_TIGHT_COLONCOLON, TK_TIGHT_COLONCOLON), (T_THIN_ARROW, TK_THIN_ARROW), (T_FAT_ARROW, TK_FAT_ARROW), (T_EQUAL, TK_EQUAL), (T_UNDERSCORE, TK_UNDERSCORE)] : Array[(YYSymbol, TokenKind)]) {
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
