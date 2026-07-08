
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
  OFFER
  AUTO
  IF
  ELSE
  MATCH
  HANDLE
  WITH
  FINAL
  BUILTIN
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
  RBRACKET
  EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  EMPTY_TYPE_PARAMETER_LIST_ERROR
  COMMA
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
    OFFER => TK_OFFER
    AUTO => TK_AUTO
    IF => TK_IF
    ELSE => TK_ELSE
    MATCH => TK_MATCH
    HANDLE => TK_HANDLE
    WITH => TK_WITH
    FINAL => TK_FINAL
    BUILTIN => TK_BUILTIN
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
    RBRACKET => TK_RBRACKET
    EMPTY_GENERIC_ARGUMENT_LIST_ERROR => TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
    EMPTY_TYPE_PARAMETER_LIST_ERROR => TK_EMPTY_TYPE_PARAMETER_LIST_ERROR
    COMMA => TK_COMMA
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
  TK_OFFER
  TK_AUTO
  TK_IF
  TK_ELSE
  TK_MATCH
  TK_HANDLE
  TK_WITH
  TK_FINAL
  TK_BUILTIN
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
  TK_RBRACKET
  TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  TK_EMPTY_TYPE_PARAMETER_LIST_ERROR
  TK_COMMA
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

pub impl Show for TokenKind with output(self, logger) {
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
      TK_OFFER => "\"offer\""
      TK_AUTO => "\"auto\""
      TK_IF => "\"if\""
      TK_ELSE => "\"else\""
      TK_MATCH => "\"match\""
      TK_HANDLE => "\"handle\""
      TK_WITH => "\"with\""
      TK_FINAL => "\"final\""
      TK_BUILTIN => "\"builtin\""
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
      TK_RBRACKET => "\"]\""
      TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => "EMPTY_GENERIC_ARGUMENT_LIST_ERROR"
      TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => "EMPTY_TYPE_PARAMETER_LIST_ERROR"
      TK_COMMA => "\",\""
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

pub impl Debug for TokenKind with to_repr(self) {
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
      TK_OFFER => to_repr("offer")
      TK_AUTO => to_repr("auto")
      TK_IF => to_repr("if")
      TK_ELSE => to_repr("else")
      TK_MATCH => to_repr("match")
      TK_HANDLE => to_repr("handle")
      TK_WITH => to_repr("with")
      TK_FINAL => to_repr("final")
      TK_BUILTIN => to_repr("builtin")
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
      TK_RBRACKET => to_repr("]")
      TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => to_repr("EMPTY_GENERIC_ARGUMENT_LIST_ERROR")
      TK_EMPTY_TYPE_PARAMETER_LIST_ERROR => to_repr("EMPTY_TYPE_PARAMETER_LIST_ERROR")
      TK_COMMA => to_repr(",")
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

priv suberror YYObj_OwnerExpression {
  YYObj_OwnerExpression(OwnerExpression)
}

priv suberror YYObj_FieldDeclaration {
  YYObj_FieldDeclaration(FieldDeclaration)
}

priv suberror YYObj_HandlerWithBlock {
  YYObj_HandlerWithBlock(HandlerWithBlock)
}

priv suberror YYObj_OfferDeclaration {
  YYObj_OfferDeclaration(OfferDeclaration)
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

priv suberror YYObj_FunctionLiteralParameter {
  YYObj_FunctionLiteralParameter(FunctionLiteralParameter)
}

priv suberror YYObj_EffectOperationDeclaration {
  YYObj_EffectOperationDeclaration(EffectOperationDeclaration)
}

priv suberror YYObj_HandlerOperationArmParameters {
  YYObj_HandlerOperationArmParameters(HandlerOperationArmParameters)
}

priv suberror YYObj_HandlerOperationHeadAfterIdent {
  YYObj_HandlerOperationHeadAfterIdent(HandlerOperationHeadAfterIdent)
}

priv suberror YYObj_HandlerOperationAfterTypeArguments {
  YYObj_HandlerOperationAfterTypeArguments(HandlerOperationAfterTypeArguments)
}

priv suberror YYObj_Type_ {
  YYObj_Type_(Type?)
}

priv suberror YYObj_EffectTerm_ {
  YYObj_EffectTerm_(EffectTerm?)
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
  T_OFFER
  T_AUTO
  T_IF
  T_ELSE
  T_MATCH
  T_HANDLE
  T_WITH
  T_FINAL
  T_BUILTIN
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
  T_RBRACKET
  T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR
  T_EMPTY_TYPE_PARAMETER_LIST_ERROR
  T_COMMA
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
  NT_type_alias_declaration
  NT_public_type_alias_declaration
  NT_type_alias_body
  NT_struct_declaration
  NT_public_struct_declaration
  NT_struct_members
  NT_struct_member
  NT_type_member_declaration
  NT_kind
  NT_kind_list
  NT_non_empty_kind_list
  NT_field_declaration
  NT_field_offer_modifier
  NT_enum_declaration
  NT_public_enum_declaration
  NT_enum_variants
  NT_enum_variant
  NT_effect_declaration
  NT_public_effect_declaration
  NT_effect_operations
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
  NT_non_owner_primary_expression
  NT_list_literal_items
  NT_operation_type_witnesses
  NT_type_arguments
  NT_type_argument_bracket_list
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
  NT_else_branch_expression
  NT_match_expression
  NT_match_arms
  NT_match_arm
  NT_handler_expression
  NT_handler_with_blocks
  NT_handler_with_block
  NT_handler_operation_arms
  NT_handler_operation_arm
  NT_handler_operation_head
  NT_handler_operation_head_after_ident
  NT_handler_operation_after_type_arguments
  NT_handler_operation_type_binders
  NT_ident_bracket_list
  NT_handler_operation_owner_arguments
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
  NT_pattern
  NT_struct_pattern
  NT_variant_type_binders
  NT_non_empty_ident_list
  NT_pattern_list
  NT_non_empty_pattern_list
  NT_struct_pattern_fields
  NT_non_empty_struct_pattern_fields
  NT_struct_pattern_field
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
// 87|    module_declaration import_declarations top_level_declarations EOF {
// 88|    { module_path: $1, imports: $2, declarations: $3, loc: span($sloc) }
// 89|  }
fn yy_action_0(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePath(_dollar1)
  guard _args[1].0 is YYObj_Array_ImportDeclaration_(_dollar2)
  guard _args[2].0 is YYObj_Array_TopLevelDeclaration_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_SourceFile({(); 
    { module_path: _dollar1, imports: _dollar2, declarations: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 143|    top_level_declarations top_level_declaration { comma_push($1, $2) }
fn yy_action_1(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopLevelDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_Array_TopLevelDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 147|    struct_declaration { Struct($1) }
fn yy_action_2(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 148|    enum_declaration { Enum($1) }
fn yy_action_3(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 149|    effect_declaration { Effect($1) }
fn yy_action_4(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 150|    type_alias_declaration { TypeAlias($1) }
fn yy_action_5(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 151|    function_declaration { Function($1) }
fn yy_action_6(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 152|    top_level_let_declaration { Let($1) }
fn yy_action_7(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 153|    offer_value_declaration { Offer($1) }
fn yy_action_8(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Offer(_dollar1) })
}

// file:///./parser.mbty
// 154|    "pub" public_top_level_declaration { $2 }
fn yy_action_9(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_TopLevelDeclaration({();  _dollar2 })
}

// file:///./parser.mbty
// 158|    public_struct_declaration { Struct($1) }
fn yy_action_10(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 159|    public_enum_declaration { Enum($1) }
fn yy_action_11(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Enum(_dollar1) })
}

// file:///./parser.mbty
// 160|    public_effect_declaration { Effect($1) }
fn yy_action_12(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Effect(_dollar1) })
}

// file:///./parser.mbty
// 161|    public_type_alias_declaration { TypeAlias($1) }
fn yy_action_13(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  TypeAlias(_dollar1) })
}

// file:///./parser.mbty
// 162|    public_function_declaration { Function($1) }
fn yy_action_14(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 163|    public_top_level_let_declaration { Let($1) }
fn yy_action_15(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Let(_dollar1) })
}

// file:///./parser.mbty
// 164|    public_offer_value_declaration { Offer($1) }
fn yy_action_16(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_TopLevelDeclaration({();  Offer(_dollar1) })
}

// file:///./parser.mbty
// 174|    "type" IDENT type_parameters "=" type_alias_body {
// 175|    { is_public: true, name: $2, type_parameters: $3, body: $5, loc: span($sloc) }
// 176|  }
fn yy_action_17(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_TypeAliasBody(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasDeclaration({(); 
    { is_public: true, name: _dollar2, type_parameters: _dollar3, body: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 199|    "struct" IDENT type_parameters "{" struct_members "}" {
// 200|    { is_public: true, name: $2, type_parameters: $3, members: $5, loc: span($sloc) }
// 201|  }
fn yy_action_18(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: true, name: _dollar2, type_parameters: _dollar3, members: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 266|    "enum" IDENT type_parameters "{" enum_variants "}" {
// 267|    { is_public: true, name: $2, type_parameters: $3, variants: $5, loc: span($sloc) }
// 268|  }
fn yy_action_19(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: true, name: _dollar2, type_parameters: _dollar3, variants: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 292|    "effect" IDENT type_parameters "{" effect_operations "}" {
// 293|    { is_public: true, name: $2, type_parameters: $3, operations: $5, loc: span($sloc) }
// 294|  }
fn yy_action_20(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EffectOperationDeclaration_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: true, name: _dollar2, type_parameters: _dollar3, operations: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 328|    "fn" type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 329|    {
// 330|      is_public: true,
// 331|      type_parameters: $2,
// 332|      name: $3.name,
// 333|      name_loc: $3.loc,
// 334|      parameters: $4,
// 335|      return_type: $6,
// 336|      effect: effect_or_empty($7, $6),
// 337|      body: $8,
// 338|      loc: span($sloc),
// 339|    }
// 340|  }
fn yy_action_21(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 374|    "let" identifier ":" type "=" expression {
// 375|    { is_public: true, name: Some($2.name), name_loc: Some($2.loc), type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 376|  }
fn yy_action_22(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: true, name: Some(_dollar2.name), name_loc: Some(_dollar2.loc), type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 395|    "offer" identifier ":" type "=" expression {
// 396|    { is_public: true, name: $2.name, name_loc: $2.loc, type_annotation: $4, initializer: $6, loc: span($sloc) }
// 397|  }
fn yy_action_23(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OfferDeclaration({(); 
    { is_public: true, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: _dollar4, initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 168|    "type" IDENT type_parameters "=" type_alias_body {
// 169|    { is_public: false, name: $2, type_parameters: $3, body: $5, loc: span($sloc) }
// 170|  }
fn yy_action_24(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_TypeAliasBody(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasDeclaration({(); 
    { is_public: false, name: _dollar2, type_parameters: _dollar3, body: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 180|    type { TypeBody($1) }
fn yy_action_25(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_TypeAliasBody({();  TypeBody(_dollar1) })
}

// file:///./parser.mbty
// 181|    "{" type_list "}" {
// 182|    EffectBody(
// 183|      if $2.is_empty() {
// 184|        Empty(loc=span($sloc))
// 185|      } else {
// 186|        Union(items=$2, loc=span($sloc))
// 187|      }
// 188|    )
// 189|  }
fn yy_action_26(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeAliasBody({(); 
    EffectBody(
      if _dollar2.is_empty() {
        Empty(loc=span((_symbol_start_pos, _end_pos)))
      } else {
        Union(items=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
      }
    )
  })
}

// file:///./parser.mbty
// 193|    "struct" IDENT type_parameters "{" struct_members "}" {
// 194|    { is_public: false, name: $2, type_parameters: $3, members: $5, loc: span($sloc) }
// 195|  }
fn yy_action_27(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructDeclaration({(); 
    { is_public: false, name: _dollar2, type_parameters: _dollar3, members: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 206|    struct_members struct_member { comma_push($1, $2) }
fn yy_action_28(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  guard _args[1].0 is YYObj_StructMember(_dollar2)
  YYObj_Array_StructMember_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 210|    type_member_declaration { TypeMember($1) }
fn yy_action_29(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeMemberDeclaration(_dollar1)
  YYObj_StructMember({();  TypeMember(_dollar1) })
}

// file:///./parser.mbty
// 211|    field_declaration { Field($1) }
fn yy_action_30(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FieldDeclaration(_dollar1)
  YYObj_StructMember({();  Field(_dollar1) })
}

// file:///./parser.mbty
// 215|    "type" IDENT ":" kind {
// 216|    { name: $2, kind: $4, loc: span($sloc) }
// 217|  }
fn yy_action_31(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Kind(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeMemberDeclaration({(); 
    { name: _dollar2, kind: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 249|    field_offer_modifier IDENT ":" type {
// 250|    { is_offered: $1, name: $2, type_: $4, loc: span($sloc) }
// 251|  }
fn yy_action_32(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FieldDeclaration({(); 
    { is_offered: _dollar1, name: _dollar2, type_: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 256|    "offer" { true }
fn yy_action_33(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 255|    { false }
fn yy_action_34(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 205|    { [] }
fn yy_action_35(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructMember_({();  [] })
}

// file:///./parser.mbty
// 260|    "enum" IDENT type_parameters "{" enum_variants "}" {
// 261|    { is_public: false, name: $2, type_parameters: $3, variants: $5, loc: span($sloc) }
// 262|  }
fn yy_action_36(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumDeclaration({(); 
    { is_public: false, name: _dollar2, type_parameters: _dollar3, variants: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 273|    enum_variants enum_variant { comma_push($1, $2) }
fn yy_action_37(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  guard _args[1].0 is YYObj_EnumVariant(_dollar2)
  YYObj_Array_EnumVariant_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 277|    IDENT "(" type_list ")" {
// 278|    { name: $1, type_parameters: [], payload: $3, loc: span($sloc) }
// 279|  }
fn yy_action_38(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1, type_parameters: [], payload: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 280|    IDENT type_parameter_bracket_list "(" type_list ")" {
// 281|    { name: $1, type_parameters: $2, payload: $4, loc: span($sloc) }
// 282|  }
fn yy_action_39(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EnumVariant({(); 
    { name: _dollar1, type_parameters: _dollar2, payload: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 272|    { [] }
fn yy_action_40(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EnumVariant_({();  [] })
}

// file:///./parser.mbty
// 286|    "effect" IDENT type_parameters "{" effect_operations "}" {
// 287|    { is_public: false, name: $2, type_parameters: $3, operations: $5, loc: span($sloc) }
// 288|  }
fn yy_action_41(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EffectOperationDeclaration_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectDeclaration({(); 
    { is_public: false, name: _dollar2, type_parameters: _dollar3, operations: _dollar5, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 299|    effect_operations effect_operation { comma_push($1, $2) }
fn yy_action_42(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_EffectOperationDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_EffectOperationDeclaration(_dollar2)
  YYObj_Array_EffectOperationDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 303|    IDENT "(" type_list ")" "->" type {
// 304|    { name: $1, type_parameters: [], payload: $3, result: $6, loc: span($sloc) }
// 305|  }
fn yy_action_43(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1, type_parameters: [], payload: _dollar3, result: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 306|    IDENT type_parameter_bracket_list "(" type_list ")" "->" type {
// 307|    { name: $1, type_parameters: $2, payload: $4, result: $7, loc: span($sloc) }
// 308|  }
fn yy_action_44(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[6].0 is YYObj_Type(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectOperationDeclaration({(); 
    { name: _dollar1, type_parameters: _dollar2, payload: _dollar4, result: _dollar7, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 298|    { [] }
fn yy_action_45(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_EffectOperationDeclaration_({();  [] })
}

// file:///./parser.mbty
// 368|    "let" identifier ":" type "=" expression {
// 369|    { is_public: false, name: Some($2.name), name_loc: Some($2.loc), type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 370|  }
fn yy_action_46(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LetDeclaration({(); 
    { is_public: false, name: Some(_dollar2.name), name_loc: Some(_dollar2.loc), type_annotation: Some(_dollar4), initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 389|    "offer" identifier ":" type "=" expression {
// 390|    { is_public: false, name: $2.name, name_loc: $2.loc, type_annotation: $4, initializer: $6, loc: span($sloc) }
// 391|  }
fn yy_action_47(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OfferDeclaration({(); 
    { is_public: false, name: _dollar2.name, name_loc: _dollar2.loc, type_annotation: _dollar4, initializer: _dollar6, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 312|    "fn" type_parameters identifier parameters "->" type effect_annotation_opt block_expression {
// 313|    {
// 314|      is_public: false,
// 315|      type_parameters: $2,
// 316|      name: $3.name,
// 317|      name_loc: $3.loc,
// 318|      parameters: $4,
// 319|      return_type: $6,
// 320|      effect: effect_or_empty($7, $6),
// 321|      body: $8,
// 322|      loc: span($sloc),
// 323|    }
// 324|  }
fn yy_action_48(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 344|    "(" ")" { [] }
fn yy_action_49(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Parameter_({();  [] })
}

// file:///./parser.mbty
// 345|    "(" non_empty_parameter_list ")" { $2 }
fn yy_action_50(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Parameter_(_dollar2)
  YYObj_Array_Parameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 350|    non_empty_parameter_list "," parameter { comma_push($1, $3) }
fn yy_action_51(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Parameter_(_dollar1)
  guard _args[2].0 is YYObj_Parameter(_dollar3)
  YYObj_Array_Parameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 349|    parameter { [ $1 ] }
fn yy_action_52(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Parameter(_dollar1)
  YYObj_Array_Parameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 354|    parameter_modifiers IDENT ":" type {
// 355|    { is_auto: $1.is_auto, is_offered: $1.is_offered, name: $2, type_: $4, loc: span($sloc) }
// 356|  }
fn yy_action_53(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParameterModifiers(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Parameter({(); 
    { is_auto: _dollar1.is_auto, is_offered: _dollar1.is_offered, name: _dollar2, type_: _dollar4, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 363|    "auto" "offer" { { is_auto: true, is_offered: true } }
fn yy_action_54(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 361|    "auto" { { is_auto: true, is_offered: false } }
fn yy_action_55(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: false } })
}

// file:///./parser.mbty
// 364|    "offer" "auto" { { is_auto: true, is_offered: true } }
fn yy_action_56(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: true, is_offered: true } })
}

// file:///./parser.mbty
// 362|    "offer" { { is_auto: false, is_offered: true } }
fn yy_action_57(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: true } })
}

// file:///./parser.mbty
// 360|    { { is_auto: false, is_offered: false } }
fn yy_action_58(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ParameterModifiers({();  { is_auto: false, is_offered: false } })
}

// file:///./parser.mbty
// 402|    type_parameter_bracket_list { $1 }
fn yy_action_59(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 380|    "let" pattern local_type_annotation "=" expression { local_let_item($2, $3, $5, span($sloc)) }
fn yy_action_60(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Pattern(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_LocalItem({();  local_let_item(_dollar2, _dollar3, _dollar5, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 717|    "{" local_items expression "}" {
// 718|    Block(items=$2, result=$3, loc=span($sloc))
// 719|  }
fn yy_action_61(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_LocalItem_(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Block(items=_dollar2, result=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 724|    local_items local_item { comma_push($1, $2) }
fn yy_action_62(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_LocalItem_(_dollar1)
  guard _args[1].0 is YYObj_LocalItem(_dollar2)
  YYObj_Array_LocalItem_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 728|    local_let_item { $1 }
fn yy_action_63(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_LocalItem(_dollar1)
  YYObj_LocalItem({();  _dollar1 })
}

// file:///./parser.mbty
// 729|    function_declaration { Function($1) }
fn yy_action_64(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_LocalItem({();  Function(_dollar1) })
}

// file:///./parser.mbty
// 730|    offer_value_declaration { Offer($1) }
fn yy_action_65(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_LocalItem({();  Offer(_dollar1) })
}

// file:///./parser.mbty
// 762|    "handle" expression handler_with_blocks handler_final_branch {
// 763|    Handler(body=$2, handlers=$3, final_branch=$4, loc=span($sloc))
// 764|  }
fn yy_action_66(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 769|    handler_with_blocks handler_with_block { comma_push($1, $2) }
fn yy_action_67(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerWithBlock_(_dollar1)
  guard _args[1].0 is YYObj_HandlerWithBlock(_dollar2)
  YYObj_Array_HandlerWithBlock_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 839|    "final" identifier block_expression { { binder: $2.name, binder_loc: $2.loc, body: $3, loc: span($sloc) } }
fn yy_action_68(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Identifier(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerFinalBranch({();  { binder: _dollar2.name, binder_loc: _dollar2.loc, body: _dollar3, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 768|    handler_with_block { [ $1 ] }
fn yy_action_69(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerWithBlock(_dollar1)
  YYObj_Array_HandlerWithBlock_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 798|    IDENT handler_operation_head_after_ident { handler_operation_head_from_ident($1, $2, span($sloc)) }
fn yy_action_70(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_HandlerOperationHeadAfterIdent(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerOperationHead({();  handler_operation_head_from_ident(_dollar1, _dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 804|    "[" non_empty_type_list "]" handler_operation_after_type_arguments { handler_operation_head_after_type_arguments($2, $4) }
fn yy_action_71(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  guard _args[3].0 is YYObj_HandlerOperationAfterTypeArguments(_dollar4)
  YYObj_HandlerOperationHeadAfterIdent({();  handler_operation_head_after_type_arguments(_dollar2, _dollar4) })
}

// file:///./parser.mbty
// 810|    "tight ::" IDENT handler_operation_type_binders { OwnerArguments(operation=$2, type_binders=$3) }
fn yy_action_72(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_String_(_dollar3)
  YYObj_HandlerOperationAfterTypeArguments({();  OwnerArguments(operation=_dollar2, type_binders=_dollar3) })
}

// file:///./parser.mbty
// 809|    { OperationBinders }
fn yy_action_73(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_HandlerOperationAfterTypeArguments({();  OperationBinders })
}

// file:///./parser.mbty
// 805|    "tight ::" IDENT handler_operation_type_binders { Qualified(owner_arguments=[], operation=$2, type_binders=$3) }
fn yy_action_74(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_String_(_dollar3)
  YYObj_HandlerOperationHeadAfterIdent({();  Qualified(owner_arguments=[], operation=_dollar2, type_binders=_dollar3) })
}

// file:///./parser.mbty
// 803|    { Unqualified([]) }
fn yy_action_75(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_HandlerOperationHeadAfterIdent({();  Unqualified([]) })
}

// file:///./parser.mbty
// 799|    qualified_type_name handler_operation_owner_arguments "tight ::" IDENT handler_operation_type_binders { handler_operation_head_from_qualified($1, $2, $4, $5, span($sloc)) }
fn yy_action_76(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  guard _args[3].0 is YYObj_String(_dollar4)
  guard _args[4].0 is YYObj_Array_String_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerOperationHead({();  handler_operation_head_from_qualified(_dollar1, _dollar2, _dollar4, _dollar5, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 815|    ident_bracket_list { $1 }
fn yy_action_77(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  YYObj_Array_String_({();  _dollar1 })
}

// file:///./parser.mbty
// 819|    "[" non_empty_ident_list "]" { $2 }
fn yy_action_78(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_Array_String_({();  _dollar2 })
}

// file:///./parser.mbty
// 820|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_79(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_String_({();  [] })
}

// file:///./parser.mbty
// 814|    { [] }
fn yy_action_80(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_String_({();  [] })
}

// file:///./parser.mbty
// 825|    type_arguments { $1 }
fn yy_action_81(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 824|    { [] }
fn yy_action_82(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 773|    "with" "{" handler_operation_arms "}" {
// 774|    { arms: $3, loc: span($sloc) }
// 775|  }
fn yy_action_83(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_HandlerOperationArm_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_HandlerWithBlock({(); 
    { arms: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 780|    handler_operation_arms handler_operation_arm { comma_push($1, $2) }
fn yy_action_84(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerOperationArm_(_dollar1)
  guard _args[1].0 is YYObj_HandlerOperationArm(_dollar2)
  YYObj_Array_HandlerOperationArm_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 779|    handler_operation_arm { [ $1 ] }
fn yy_action_85(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_HandlerOperationArm(_dollar1)
  YYObj_Array_HandlerOperationArm_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 784|    handler_operation_head "(" handler_operation_arm_parameters ")" "=>" expression {
// 785|    {
// 786|      name: $1.name,
// 787|      type_binders: $1.type_binders,
// 788|      payload_patterns: $3.payload_patterns,
// 789|      resume_binder: $3.resume_binder,
// 790|      resume_loc: $3.resume_loc,
// 791|      body: $6,
// 792|      loc: span($sloc)
// 793|    }
// 794|  }
fn yy_action_86(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 829|    identifier { { payload_patterns: [], resume_binder: $1.name, resume_loc: $1.loc } }
fn yy_action_87(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Identifier(_dollar1)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: [], resume_binder: _dollar1.name, resume_loc: _dollar1.loc } })
}

// file:///./parser.mbty
// 138|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_88(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Identifier({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 830|    handler_payload_patterns "," identifier { { payload_patterns: $1, resume_binder: $3.name, resume_loc: $3.loc } }
fn yy_action_89(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Identifier(_dollar3)
  YYObj_HandlerOperationArmParameters({();  { payload_patterns: _dollar1, resume_binder: _dollar3.name, resume_loc: _dollar3.loc } })
}

// file:///./parser.mbty
// 835|    handler_payload_patterns "," pattern { comma_push($1, $3) }
fn yy_action_90(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 834|    pattern { [ $1 ] }
fn yy_action_91(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 745|    "match" expression "{" match_arms "}" {
// 746|    Match(scrutinee=$2, arms=$4, loc=span($sloc))
// 747|  }
fn yy_action_92(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_Array_MatchArm_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Match(scrutinee=_dollar2, arms=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 752|    match_arms match_arm { comma_push($1, $2) }
fn yy_action_93(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  guard _args[1].0 is YYObj_MatchArm(_dollar2)
  YYObj_Array_MatchArm_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 756|    pattern "=>" expression {
// 757|    { pattern: $1, body: $3, loc: span($sloc) }
// 758|  }
fn yy_action_94(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_MatchArm({(); 
    { pattern: _dollar1, body: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 892|    nominal_type_name "tight ::" IDENT variant_type_binders "(" pattern_list ")" { QualifiedVariant(type_name=$1, variant=$3, type_binders=$4, arguments=$6, loc=span(($startpos, $endpos))) }
fn yy_action_95(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_String_(_dollar4)
  guard _args[5].0 is YYObj_Array_Pattern_(_dollar6)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  QualifiedVariant(type_name=_dollar1, variant=_dollar3, type_binders=_dollar4, arguments=_dollar6, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 896|    nominal_type_name "tight ::" "{" struct_pattern_fields "}" {
// 897|    Struct(type_name=$1, fields=$4, loc=span($sloc))
// 898|  }
fn yy_action_96(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[3].0 is YYObj_Array_StructPatternField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({(); 
    Struct(type_name=_dollar1, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 930|    non_empty_struct_pattern_fields "," struct_pattern_field { comma_push($1, $3) }
fn yy_action_97(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  guard _args[2].0 is YYObj_StructPatternField(_dollar3)
  YYObj_Array_StructPatternField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 931|    non_empty_struct_pattern_fields "," { $1 }
fn yy_action_98(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 925|    non_empty_struct_pattern_fields { $1 }
fn yy_action_99(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_({();  _dollar1 })
}

// file:///./parser.mbty
// 929|    struct_pattern_field { [ $1 ] }
fn yy_action_100(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructPatternField(_dollar1)
  YYObj_Array_StructPatternField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 890|    IDENT variant_type_binders "(" pattern_list ")" { UnqualifiedVariant(variant=$1, type_binders=$2, arguments=$4, loc=span(($startpos, $endpos))) }
fn yy_action_101(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  guard _args[3].0 is YYObj_Array_Pattern_(_dollar4)
  let _start_pos = if _args.length() == 0 { _last_pos } else { _args[0].1 }
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  UnqualifiedVariant(variant=_dollar1, type_binders=_dollar2, arguments=_dollar4, loc=span((_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 919|    non_empty_pattern_list "," pattern { comma_push($1, $3) }
fn yy_action_102(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 920|    non_empty_pattern_list "," { $1 }
fn yy_action_103(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 914|    non_empty_pattern_list { $1 }
fn yy_action_104(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_({();  _dollar1 })
}

// file:///./parser.mbty
// 918|    pattern { [ $1 ] }
fn yy_action_105(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 913|    { [] }
fn yy_action_106(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Pattern_({();  [] })
}

// file:///./parser.mbty
// 903|    "[" non_empty_ident_list "]" { $2 }
fn yy_action_107(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_Array_String_({();  _dollar2 })
}

// file:///./parser.mbty
// 908|    non_empty_ident_list "," IDENT { comma_push($1, $3) }
fn yy_action_108(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 909|    non_empty_ident_list "," { $1 }
fn yy_action_109(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  YYObj_Array_String_({();  _dollar1 })
}

// file:///./parser.mbty
// 907|    IDENT { [ $1 ] }
fn yy_action_110(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 659|    IDENT { $1 }
fn yy_action_111(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 889|    IDENT { Binding($1, loc=span($sloc)) }
fn yy_action_112(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Binding(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 902|    { [] }
fn yy_action_113(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_String_({();  [] })
}

// file:///./parser.mbty
// 660|    qualified_type_name { type_name_text($1) }
fn yy_action_114(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_String({();  type_name_text(_dollar1) })
}

// file:///./parser.mbty
// 883|    "_" { Wildcard(span($sloc)) }
fn yy_action_115(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  Wildcard(span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 884|    INT { IntLiteral($1, loc=span($sloc)) }
fn yy_action_116(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 885|    DOUBLE { DoubleLiteral($1, loc=span($sloc)) }
fn yy_action_117(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  DoubleLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 886|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_118(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 887|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_119(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 888|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_120(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Pattern({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 891|    struct_pattern { $1 }
fn yy_action_121(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Pattern({();  _dollar1 })
}

// file:///./parser.mbty
// 941|    IDENT ":" pattern {
// 942|    Value(name=$1, pattern=Some($3), loc=span($sloc))
// 943|  }
fn yy_action_122(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 935|    IDENT {
// 936|    Value(name=$1, pattern=None, loc=span($sloc))
// 937|  }
fn yy_action_123(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    Value(name=_dollar1, pattern=None, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 938|    "_" {
// 939|    TypeWildcard(loc=span($sloc))
// 940|  }
fn yy_action_124(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructPatternField({(); 
    TypeWildcard(loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 924|    { [] }
fn yy_action_125(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructPatternField_({();  [] })
}

// file:///./parser.mbty
// 751|    { [] }
fn yy_action_126(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_MatchArm_({();  [] })
}

// file:///./parser.mbty
// 734|    "if" expression block_expression "else" else_branch_expression {
// 735|    If(condition=$2, then_branch=$3, else_branch=$5, loc=span($sloc))
// 736|  }
fn yy_action_127(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    If(condition=_dollar2, then_branch=_dollar3, else_branch=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 740|    block_expression { $1 }
fn yy_action_128(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 741|    if_expression { $1 }
fn yy_action_129(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 636|    "[" list_literal_items "]" { ListLiteral(items=$2, loc=span($sloc)) }
fn yy_action_130(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  ListLiteral(items=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 712|    non_empty_positional_argument_list "," expression { comma_push($1, $3) }
fn yy_action_131(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 630|    "(" expression ")" { $2 }
fn yy_action_132(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  YYObj_Expr({();  _dollar2 })
}

// file:///./parser.mbty
// 576|    IDENT "!" "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1, loc=span($sloc)), type_witnesses=[], arguments=$4, loc=span($sloc)) }
fn yy_action_133(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[3].0 is YYObj_Array_Expr_(_dollar4)
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1, loc=span((_symbol_start_pos, _end_pos))), type_witnesses=[], arguments=_dollar4, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 581|    owner_expression "tight ::" IDENT "!" "(" positional_argument_list ")" %prec "tight ::" {
// 582|    EffectOperationCall(
// 583|      name=Qualified(
// 584|        owner=$1.owner,
// 585|        operation=$3,
// 586|        loc=span($sloc)
// 587|      ),
// 588|      type_witnesses=[],
// 589|      arguments=$6,
// 590|      loc=span($sloc)
// 591|    )
// 592|  }
fn yy_action_134(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[5].0 is YYObj_Array_Expr_(_dollar6)
  YYObj_Expr({(); 
    EffectOperationCall(
      name=Qualified(
        owner=_dollar1.owner,
        operation=_dollar3,
        loc=span((_symbol_start_pos, _end_pos))
      ),
      type_witnesses=[],
      arguments=_dollar6,
      loc=span((_symbol_start_pos, _end_pos))
    )
  })
}

// file:///./parser.mbty
// 593|    owner_expression "tight ::" IDENT "!" operation_type_witnesses "(" positional_argument_list ")" %prec "tight ::" {
// 594|    EffectOperationCall(
// 595|      name=Qualified(
// 596|        owner=$1.owner,
// 597|        operation=$3,
// 598|        loc=span($sloc)
// 599|      ),
// 600|      type_witnesses=$5,
// 601|      arguments=$7,
// 602|      loc=span($sloc)
// 603|    )
// 604|  }
fn yy_action_135(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  guard _args[6].0 is YYObj_Array_Expr_(_dollar7)
  YYObj_Expr({(); 
    EffectOperationCall(
      name=Qualified(
        owner=_dollar1.owner,
        operation=_dollar3,
        loc=span((_symbol_start_pos, _end_pos))
      ),
      type_witnesses=_dollar5,
      arguments=_dollar7,
      loc=span((_symbol_start_pos, _end_pos))
    )
  })
}

// file:///./parser.mbty
// 608|    owner_expression "tight ::" IDENT variant_type_arguments variant_arguments %prec VARIANT_EXPR {
// 609|    QualifiedVariant(owner=$1.owner, variant=$3, variant_type_arguments=$4, arguments=$5, loc=span($sloc))
// 610|  }
fn yy_action_136(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    QualifiedVariant(owner=_dollar1.owner, variant=_dollar3, variant_type_arguments=_dollar4, arguments=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 711|    expression { [ $1 ] }
fn yy_action_137(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 686|    "(" positional_argument_list ")" { $2 }
fn yy_action_138(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  YYObj_Array_Expr_({();  _dollar2 })
}

// file:///./parser.mbty
// 665|    type_arguments { $1 }
fn yy_action_139(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 664|    %prec VARIANT_EXPR { [] }
fn yy_action_140(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 605|    owner_expression "tight ::" "{" struct_literal_fields "}" %prec "tight ::" {
// 606|    StructLiteral(owner=$1.owner, fields=$4, loc=span($sloc))
// 607|  }
fn yy_action_141(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[3].0 is YYObj_Array_StructLiteralField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    StructLiteral(owner=_dollar1.owner, fields=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 675|    non_empty_struct_literal_fields "," struct_literal_field { comma_push($1, $3) }
fn yy_action_142(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  guard _args[2].0 is YYObj_StructLiteralField(_dollar3)
  YYObj_Array_StructLiteralField_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 676|    non_empty_struct_literal_fields "," { $1 }
fn yy_action_143(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 670|    non_empty_struct_literal_fields { $1 }
fn yy_action_144(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_({();  _dollar1 })
}

// file:///./parser.mbty
// 674|    struct_literal_field { [ $1 ] }
fn yy_action_145(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_StructLiteralField(_dollar1)
  YYObj_Array_StructLiteralField_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 681|    IDENT ":" expression { Value(name=$1, value=Some($3), loc=span($sloc)) }
fn yy_action_146(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=Some(_dollar3), loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 573|    value_postfix_expression "(" argument_list ")" { Call(callee=$1, arguments=$3, loc=span($sloc)) }
fn yy_action_147(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_CallArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Call(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 706|    expression { Positional(value=$1, loc=span($sloc)) }
fn yy_action_148(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Positional(value=_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 510|    expression "|>" expression {
// 511|    Pipeline(left=$1, right=$3, loc=span($sloc))
// 512|  }
fn yy_action_149(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Pipeline(left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 513|    expression "||" expression {
// 514|    Binary(operator=Or, left=$1, right=$3, loc=span($sloc))
// 515|  }
fn yy_action_150(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Or, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 516|    expression "&&" expression {
// 517|    Binary(operator=And, left=$1, right=$3, loc=span($sloc))
// 518|  }
fn yy_action_151(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=And, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 519|    expression "==" expression {
// 520|    Binary(operator=Equal, left=$1, right=$3, loc=span($sloc))
// 521|  }
fn yy_action_152(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Equal, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 522|    expression "!=" expression {
// 523|    Binary(operator=NotEqual, left=$1, right=$3, loc=span($sloc))
// 524|  }
fn yy_action_153(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=NotEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 525|    expression "<" expression {
// 526|    Binary(operator=Less, left=$1, right=$3, loc=span($sloc))
// 527|  }
fn yy_action_154(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Less, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 528|    expression "<=" expression {
// 529|    Binary(operator=LessEqual, left=$1, right=$3, loc=span($sloc))
// 530|  }
fn yy_action_155(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=LessEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 531|    expression ">" expression {
// 532|    Binary(operator=Greater, left=$1, right=$3, loc=span($sloc))
// 533|  }
fn yy_action_156(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Greater, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 534|    expression ">=" expression {
// 535|    Binary(operator=GreaterEqual, left=$1, right=$3, loc=span($sloc))
// 536|  }
fn yy_action_157(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=GreaterEqual, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 537|    expression "+" expression {
// 538|    Binary(operator=Add, left=$1, right=$3, loc=span($sloc))
// 539|  }
fn yy_action_158(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Add, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 540|    expression "-" expression {
// 541|    Binary(operator=Sub, left=$1, right=$3, loc=span($sloc))
// 542|  }
fn yy_action_159(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Sub, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 543|    expression "*" expression {
// 544|    Binary(operator=Mul, left=$1, right=$3, loc=span($sloc))
// 545|  }
fn yy_action_160(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Mul, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 546|    expression "/" expression {
// 547|    Binary(operator=Div, left=$1, right=$3, loc=span($sloc))
// 548|  }
fn yy_action_161(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Div, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 549|    expression "%" expression {
// 550|    Binary(operator=Rem, left=$1, right=$3, loc=span($sloc))
// 551|  }
fn yy_action_162(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Binary(operator=Rem, left=_dollar1, right=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 707|    IDENT "=" expression { Named(name=$1, value=$3, loc=span($sloc)) }
fn yy_action_163(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_CallArgument({();  Named(name=_dollar1, value=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 552|    unary_expression { $1 }
fn yy_action_164(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 556|    "-" unary_expression %prec UNARY {
// 557|    Unary(operator=Neg, operand=$2, loc=span($sloc))
// 558|  }
fn yy_action_165(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Unary(operator=Neg, operand=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 559|    "!" unary_expression %prec UNARY {
// 560|    Unary(operator=Not, operand=$2, loc=span($sloc))
// 561|  }
fn yy_action_166(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Unary(operator=Not, operand=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 562|    postfix_expression { $1 }
fn yy_action_167(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 701|    non_empty_argument_list "," call_argument { comma_push($1, $3) }
fn yy_action_168(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  guard _args[2].0 is YYObj_CallArgument(_dollar3)
  YYObj_Array_CallArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 702|    non_empty_argument_list "," { $1 }
fn yy_action_169(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 696|    non_empty_argument_list { $1 }
fn yy_action_170(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 700|    call_argument { [ $1 ] }
fn yy_action_171(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_CallArgument(_dollar1)
  YYObj_Array_CallArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 695|    { [] }
fn yy_action_172(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_CallArgument_({();  [] })
}

// file:///./parser.mbty
// 574|    value_postfix_expression type_arguments %prec "[" { TypeApplication(callee=$1, arguments=$2, loc=span($sloc)) }
fn yy_action_173(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  TypeApplication(callee=_dollar1, arguments=_dollar2, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 575|    value_postfix_expression "." IDENT { Field(base=$1, name=$3, loc=span($sloc)) }
fn yy_action_174(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  Field(base=_dollar1, name=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 566|    value_postfix_expression { $1 }
fn yy_action_175(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 570|    member_expression { $1 }
fn yy_action_176(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 682|    IDENT "=" type { TypeWitness(name=$1, witness=$3, loc=span($sloc)) }
fn yy_action_177(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  TypeWitness(name=_dollar1, witness=_dollar3, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 680|    IDENT { Value(name=$1, value=None, loc=span($sloc)) }
fn yy_action_178(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_StructLiteralField({();  Value(name=_dollar1, value=None, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 669|    { [] }
fn yy_action_179(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_StructLiteralField_({();  [] })
}

// file:///./parser.mbty
// 571|    owner_expression { $1.expr }
fn yy_action_180(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  YYObj_Expr({();  _dollar1.expr })
}

// file:///./parser.mbty
// 572|    non_owner_primary_expression { $1 }
fn yy_action_181(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 577|    IDENT "!" operation_type_witnesses "(" positional_argument_list ")" { EffectOperationCall(name=Unqualified(operation=$1, loc=span($sloc)), type_witnesses=$3, arguments=$5, loc=span($sloc)) }
fn yy_action_182(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  YYObj_Expr({();  EffectOperationCall(name=Unqualified(operation=_dollar1, loc=span((_symbol_start_pos, _end_pos))), type_witnesses=_dollar3, arguments=_dollar5, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 691|    non_empty_positional_argument_list { $1 }
fn yy_action_183(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 690|    { [] }
fn yy_action_184(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 646|    type_arguments { $1 }
fn yy_action_185(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 614|    IDENT { { expr: Var($1, loc=span($sloc)), owner: Name(name=$1, loc=span($sloc)) } }
fn yy_action_186(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  { expr: Var(_dollar1, loc=span((_symbol_start_pos, _end_pos))), owner: Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos))) } })
}

// file:///./parser.mbty
// 615|    owner_path_expression "." IDENT { owner_expression_field($1, $3, span($sloc)) }
fn yy_action_187(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  owner_expression_field(_dollar1, _dollar3, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 620|    owner_path_expression type_arguments %prec "[" { owner_expression_with_arguments($1, $2, span($sloc)) }
fn yy_action_188(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_OwnerExpression({();  owner_expression_with_arguments(_dollar1, _dollar2, span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 650|    type_argument_bracket_list { $1 }
fn yy_action_189(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 654|    "[" non_empty_type_list "]" { $2 }
fn yy_action_190(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  YYObj_Array_Type_({();  _dollar2 })
}

// file:///./parser.mbty
// 655|    "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" { [] }
fn yy_action_191(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 619|    owner_path_expression { $1 }
fn yy_action_192(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OwnerExpression(_dollar1)
  YYObj_OwnerExpression({();  _dollar1 })
}

// file:///./parser.mbty
// 624|    INT { IntLiteral($1, loc=span($sloc)) }
fn yy_action_193(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 625|    DOUBLE { DoubleLiteral($1, loc=span($sloc)) }
fn yy_action_194(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  DoubleLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 626|    STRING { StringLiteral($1, loc=span($sloc)) }
fn yy_action_195(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 627|    "true" { BoolLiteral(true, loc=span($sloc)) }
fn yy_action_196(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 628|    "false" { BoolLiteral(false, loc=span($sloc)) }
fn yy_action_197(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 629|    "(" ")" { UnitLiteral(loc=span($sloc)) }
fn yy_action_198(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({();  UnitLiteral(loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 631|    block_expression { $1 }
fn yy_action_199(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 632|    if_expression { $1 }
fn yy_action_200(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 633|    match_expression { $1 }
fn yy_action_201(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 634|    handler_expression { $1 }
fn yy_action_202(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 635|    function_literal { $1 }
fn yy_action_203(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 713|    non_empty_positional_argument_list "," { $1 }
fn yy_action_204(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 642|    non_empty_positional_argument_list { $1 }
fn yy_action_205(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 641|    { [] }
fn yy_action_206(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 637|    builtin_expression { $1 }
fn yy_action_207(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 723|    { [] }
fn yy_action_208(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_LocalItem_({();  [] })
}

// file:///./parser.mbty
// 843|    "fn" type_parameters "(" function_literal_parameters ")" return_annotation block_expression {
// 844|    FunctionLiteral(type_parameters=$2, parameters=$4, return_type=$6.return_type, effect=$6.effect, body=$7, loc=span($sloc))
// 845|  }
fn yy_action_209(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 871|    "->" type effect_annotation_opt {
// 872|    { return_type: Some($2), effect: $3 }
// 873|  }
fn yy_action_210(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[2].0 is YYObj_EffectTerm_(_dollar3)
  YYObj_ReturnAnnotation({(); 
    { return_type: Some(_dollar2), effect: _dollar3 }
  })
}

// file:///./parser.mbty
// 870|    { { return_type: None, effect: None } }
fn yy_action_211(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ReturnAnnotation({();  { return_type: None, effect: None } })
}

// file:///./parser.mbty
// 855|    non_empty_function_literal_parameters "," function_literal_parameter { comma_push($1, $3) }
fn yy_action_212(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  guard _args[2].0 is YYObj_FunctionLiteralParameter(_dollar3)
  YYObj_Array_FunctionLiteralParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 850|    non_empty_function_literal_parameters { $1 }
fn yy_action_213(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 854|    function_literal_parameter { [ $1 ] }
fn yy_action_214(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_FunctionLiteralParameter(_dollar1)
  YYObj_Array_FunctionLiteralParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 385|    ":" type { Some($2) }
fn yy_action_215(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type_({();  Some(_dollar2) })
}

// file:///./parser.mbty
// 859|    function_literal_parameter_modifiers IDENT local_type_annotation {
// 860|    { is_offered: $1, name: $2, type_annotation: $3, loc: span($sloc) }
// 861|  }
fn yy_action_216(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_FunctionLiteralParameter({(); 
    { is_offered: _dollar1, name: _dollar2, type_annotation: _dollar3, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 384|    { None }
fn yy_action_217(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Type_({();  None })
}

// file:///./parser.mbty
// 866|    "offer" { true }
fn yy_action_218(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 849|    { [] }
fn yy_action_219(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_FunctionLiteralParameter_({();  [] })
}

// file:///./parser.mbty
// 865|    { false }
fn yy_action_220(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 401|    { [] }
fn yy_action_221(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 877|    "builtin" "(" STRING ")" {
// 878|    Builtin($3, loc=span($sloc))
// 879|  }
fn yy_action_222(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Expr({(); 
    Builtin(_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 474|    type_parameter_bracket_list "(" type_list ")" "->" type effect_annotation_opt {
// 475|    Function(type_parameters=$1, parameters=$3, result=$6, effect=effect_or_empty($7, $6), loc=span($sloc))
// 476|  }
fn yy_action_223(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 471|    "(" type "," type_list ")" "->" type effect_annotation_opt {
// 472|    Function(type_parameters=[], parameters=[$2] + $4, result=$7, effect=effect_or_empty($8, $7), loc=span($sloc))
// 473|  }
fn yy_action_224(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 468|    "(" ")" "->" type effect_annotation_opt {
// 469|    Function(type_parameters=[], parameters=[], result=$4, effect=effect_or_empty($5, $4), loc=span($sloc))
// 470|  }
fn yy_action_225(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[4].0 is YYObj_EffectTerm_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Function(type_parameters=[], parameters=[], result=_dollar4, effect=effect_or_empty(_dollar5, _dollar4), loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 489|    type_application { Term(type_=$1, loc=span($sloc)) }
fn yy_action_226(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectTerm({();  Term(type_=_dollar1, loc=span((_symbol_start_pos, _end_pos))) })
}

// file:///./parser.mbty
// 455|    "(" type ")" %prec PAREN_TYPE { $2 }
fn yy_action_227(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type({();  _dollar2 })
}

// file:///./parser.mbty
// 485|    "!" effect_set { $2 }
fn yy_action_228(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_EffectTerm(_dollar2)
  YYObj_EffectTerm({();  _dollar2 })
}

// file:///./parser.mbty
// 427|    type_application "->" type effect_annotation_opt {
// 428|    Function(type_parameters=[], parameters=[$1], result=$3, effect=effect_or_empty($4, $3), loc=span($sloc))
// 429|  }
fn yy_action_229(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
// 481|    effect_annotation { Some($1) }
fn yy_action_230(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectTerm(_dollar1)
  YYObj_EffectTerm_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 406|    "[" non_empty_type_parameter_list "]" { $2 }
fn yy_action_231(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_({();  _dollar2 })
}

// file:///./parser.mbty
// 412|    non_empty_type_parameter_list "," type_parameter { comma_push($1, $3) }
fn yy_action_232(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameter(_dollar3)
  YYObj_Array_TypeParameter_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 413|    non_empty_type_parameter_list "," { $1 }
fn yy_action_233(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_({();  _dollar1 })
}

// file:///./parser.mbty
// 407|    "[" EMPTY_TYPE_PARAMETER_LIST_ERROR "]" { [] }
fn yy_action_234(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameter_({();  [] })
}

// file:///./parser.mbty
// 411|    type_parameter { [ $1 ] }
fn yy_action_235(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameter(_dollar1)
  YYObj_Array_TypeParameter_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 231|    "[" kind_list "]" "->" kind {
// 232|    Function(parameters=$2, result=$5, loc=span($sloc))
// 233|  }
fn yy_action_236(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({(); 
    Function(parameters=_dollar2, result=_dollar5, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 221|    IDENT {
// 222|    if $1 == "Effect" {
// 223|      Effect(loc=span($sloc))
// 224|    } else {
// 225|      Type(loc=span($sloc))
// 226|    }
// 227|  }
fn yy_action_237(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({(); 
    if _dollar1 == "Effect" {
      Effect(loc=span((_symbol_start_pos, _end_pos)))
    } else {
      Type(loc=span((_symbol_start_pos, _end_pos)))
    }
  })
}

// file:///./parser.mbty
// 228|    "effect" {
// 229|    Effect(loc=span($sloc))
// 230|  }
fn yy_action_238(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Kind({(); 
    Effect(loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 244|    non_empty_kind_list "," kind { comma_push($1, $3) }
fn yy_action_239(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 245|    non_empty_kind_list "," { $1 }
fn yy_action_240(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 239|    non_empty_kind_list { $1 }
fn yy_action_241(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 243|    kind { [ $1 ] }
fn yy_action_242(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 238|    { [] }
fn yy_action_243(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Kind_({();  [] })
}

// file:///./parser.mbty
// 234|    "(" kind ")" { $2 }
fn yy_action_244(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  YYObj_Kind({();  _dollar2 })
}

// file:///./parser.mbty
// 420|    IDENT ":" kind {
// 421|    { name: $1, kind: Some($3), loc: span($sloc) }
// 422|  }
fn yy_action_245(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1, kind: Some(_dollar3), loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 417|    IDENT {
// 418|    { name: $1, kind: None, loc: span($sloc) }
// 419|  }
fn yy_action_246(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_TypeParameter({(); 
    { name: _dollar1, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
  })
}

// file:///./parser.mbty
// 426|    type_lambda { $1 }
fn yy_action_247(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 442|    type_application "[" non_empty_type_list "]" {
// 443|    Apply(callee=$1, arguments=$3, loc=span($sloc))
// 444|  }
fn yy_action_248(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 445|    type_application "[" EMPTY_GENERIC_ARGUMENT_LIST_ERROR "]" {
// 446|    Apply(callee=$1, arguments=[], loc=span($sloc))
// 447|  }
fn yy_action_249(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Apply(callee=_dollar1, arguments=[], loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 431|    type_application %prec PAREN_TYPE { $1 }
fn yy_action_250(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 430|    function_type { $1 }
fn yy_action_251(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 435|    "type" type_parameter_bracket_list "=>" type {
// 436|    TypeLambda(parameters=$2, body=$4, loc=span($sloc))
// 437|  }
fn yy_action_252(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    TypeLambda(parameters=_dollar2, body=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 441|    type_primary { $1 }
fn yy_action_253(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 462|    qualified_type_name "." IDENT {
// 463|    extend_qualified_type_name($1, $3, span($sloc))
// 464|  }
fn yy_action_254(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    extend_qualified_type_name(_dollar1, _dollar3, span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 451|    qualified_type_name { $1 }
fn yy_action_255(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 459|    IDENT "." IDENT {
// 460|    QualifiedName(module_path={ components: [ $1 ], loc: span($sloc) }, name=$3, loc=span($sloc))
// 461|  }
fn yy_action_256(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Type({(); 
    QualifiedName(module_path={ components: [ _dollar1 ], loc: span((_symbol_start_pos, _end_pos)) }, name=_dollar3, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 452|    IDENT {
// 453|    Name(name=$1, loc=span($sloc))
// 454|  }
fn yy_action_257(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Type({(); 
    Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 490|    "{" type_list "}" {
// 491|    if $2.is_empty() {
// 492|      Empty(loc=span($sloc))
// 493|    } else {
// 494|      Union(items=$2, loc=span($sloc))
// 495|    }
// 496|  }
fn yy_action_258(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_EffectTerm({(); 
    if _dollar2.is_empty() {
      Empty(loc=span((_symbol_start_pos, _end_pos)))
    } else {
      Union(items=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
    }
  })
}

// file:///./parser.mbty
// 480|    { None }
fn yy_action_259(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_EffectTerm_({();  None })
}

// file:///./parser.mbty
// 506|    non_empty_type_list "," type { comma_push($1, $3) }
fn yy_action_260(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 501|    non_empty_type_list { $1 }
fn yy_action_261(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 505|    type { [ $1 ] }
fn yy_action_262(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 500|    { [] }
fn yy_action_263(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 107|    import_declarations import_declaration { comma_push($1, $2) }
fn yy_action_264(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_ImportDeclaration(_dollar2)
  YYObj_Array_ImportDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 114|    "import" module_path ".*" {
// 115|    Open(module_path=$2, loc=span($sloc))
// 116|  }
fn yy_action_265(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Open(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 117|    "import" module_path ".{" import_item_list "}" {
// 118|    Selective(module_path=$2, items=$4, loc=span($sloc))
// 119|  }
fn yy_action_266(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  guard _args[3].0 is YYObj_Array_ImportItem_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Selective(module_path=_dollar2, items=_dollar4, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 129|    non_empty_import_item_list "," import_item { comma_push($1, $3) }
fn yy_action_267(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  guard _args[2].0 is YYObj_ImportItem(_dollar3)
  YYObj_Array_ImportItem_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 130|    non_empty_import_item_list "," { $1 }
fn yy_action_268(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 124|    non_empty_import_item_list { $1 }
fn yy_action_269(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 128|    import_item { [ $1 ] }
fn yy_action_270(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportItem(_dollar1)
  YYObj_Array_ImportItem_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 134|    IDENT { { name: $1, loc: span($sloc) } }
fn yy_action_271(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportItem({();  { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 123|    { [] }
fn yy_action_272(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ImportItem_({();  [] })
}

// file:///./parser.mbty
// 111|    "import" module_path {
// 112|    Qualified(module_path=$2, loc=span($sloc))
// 113|  }
fn yy_action_273(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ImportDeclaration({(); 
    Qualified(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
  })
}

// file:///./parser.mbty
// 142|    { [] }
fn yy_action_274(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TopLevelDeclaration_({();  [] })
}

// file:///./parser.mbty
// 106|    { [] }
fn yy_action_275(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ImportDeclaration_({();  [] })
}

// file:///./parser.mbty
// 93|    "module" module_path { $2 }
fn yy_action_276(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  YYObj_ModulePath({();  _dollar2 })
}

// file:///./parser.mbty
// 102|    non_empty_module_path "." IDENT { comma_push($1, $3) }
fn yy_action_277(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 97|    non_empty_module_path { { components: $1, loc: span($sloc) } }
fn yy_action_278(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_ModulePath({();  { components: _dollar1, loc: span((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 101|    IDENT { [ $1 ] }
fn yy_action_279(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
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
    OFFER => (T_OFFER, YYObj_Void)
    AUTO => (T_AUTO, YYObj_Void)
    IF => (T_IF, YYObj_Void)
    ELSE => (T_ELSE, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
    HANDLE => (T_HANDLE, YYObj_Void)
    WITH => (T_WITH, YYObj_Void)
    FINAL => (T_FINAL, YYObj_Void)
    BUILTIN => (T_BUILTIN, YYObj_Void)
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
    RBRACKET => (T_RBRACKET, YYObj_Void)
    EMPTY_GENERIC_ARGUMENT_LIST_ERROR => (T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR, YYObj_Void)
    EMPTY_TYPE_PARAMETER_LIST_ERROR => (T_EMPTY_TYPE_PARAMETER_LIST_ERROR, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
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
  ReduceNoLookahead(1, NT_non_empty_module_path, yy_action_279)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_5)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IMPORT | T_PUB | T_DOTSTAR | T_DOTLBRACE => Reduce(1, NT_module_path, yy_action_278)
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
  ReduceNoLookahead(3, NT_non_empty_module_path, yy_action_277)
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_declaration, yy_action_276)
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_declarations => Shift(yy_state_9)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IMPORT | T_PUB => Reduce(0, NT_import_declarations, yy_action_275)
    _ => Error
  }
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IMPORT => Shift(yy_state_10)
    NT_import_declaration => Shift(yy_state_21)
    NT_top_level_declarations => Shift(yy_state_22)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB => Reduce(0, NT_top_level_declarations, yy_action_274)
    _ => Error
  }
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_11)
    _ => Error
  }
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOTLBRACE => Shift(yy_state_12)
    T_DOTSTAR => Shift(yy_state_20)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IMPORT | T_PUB => Reduce(2, NT_import_declaration, yy_action_273)
    _ => Error
  }
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_13)
    NT_import_item => Shift(yy_state_14)
    NT_non_empty_import_item_list => Shift(yy_state_15)
    NT_import_item_list => Shift(yy_state_18)
    T_RBRACE => Reduce(0, NT_import_item_list, yy_action_272)
    _ => Error
  }
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_item, yy_action_271)
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_import_item_list, yy_action_270)
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_16)
    T_RBRACE => Reduce(1, NT_import_item_list, yy_action_269)
    _ => Error
  }
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_13)
    NT_import_item => Shift(yy_state_17)
    T_RBRACE | T_COMMA => Reduce(2, NT_non_empty_import_item_list, yy_action_268)
    _ => Error
  }
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_import_item_list, yy_action_267)
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_19)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_declaration, yy_action_266)
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_declaration, yy_action_265)
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_import_declarations, yy_action_264)
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_23)
    T_LET => Shift(yy_state_403)
    T_FN => Shift(yy_state_409)
    T_EFFECT => Shift(yy_state_411)
    T_ENUM => Shift(yy_state_430)
    T_STRUCT => Shift(yy_state_445)
    T_TYPE => Shift(yy_state_463)
    T_PUB => Shift(yy_state_472)
    NT_offer_value_declaration => Shift(yy_state_524)
    NT_top_level_let_declaration => Shift(yy_state_525)
    NT_function_declaration => Shift(yy_state_526)
    NT_type_alias_declaration => Shift(yy_state_527)
    NT_effect_declaration => Shift(yy_state_528)
    NT_enum_declaration => Shift(yy_state_529)
    NT_struct_declaration => Shift(yy_state_530)
    NT_top_level_declaration => Shift(yy_state_531)
    T_EOF => Shift(yy_state_532)
    _ => Error
  }
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_24)
    T_IDENT => Shift(yy_state_364)
    _ => Error
  }
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_25)
    _ => Error
  }
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_106)
    _ => Error
  }
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_27)
    _ => Error
  }
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_101)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_262)
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_30)
    T_RPAREN | T_RBRACE => Reduce(1, NT_type_list, yy_action_261)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_31)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_260)
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_RPAREN => Shift(yy_state_33)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_94)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_34)
    _ => Error
  }
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    NT_type => Shift(yy_state_35)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_93)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    NT_effect_set => Shift(yy_state_88)
    T_LPAREN => Shift(yy_state_89)
    NT_type_application => Shift(yy_state_92)
    _ => Error
  }
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    NT_type_list => Shift(yy_state_38)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_39)
    _ => Error
  }
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_effect_set, yy_action_258)
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_41)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_THIN_ARROW | T_EQUAL => Reduce(1, NT_type_primary, yy_action_257)
    _ => Error
  }
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_42)
    _ => Error
  }
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_256)
}

fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_44)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_THIN_ARROW | T_EQUAL => Reduce(1, NT_type_primary, yy_action_255)
    _ => Error
  }
}

fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_45)
    _ => Error
  }
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_254)
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_application, yy_action_253)
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_48)
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_49)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_type => Shift(yy_state_50)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_lambda, yy_action_252)
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_251)
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_53)
    T_THIN_ARROW => Shift(yy_state_84)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(1, NT_type, yy_action_250)
    _ => Error
  }
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_54)
    NT_non_empty_type_list => Shift(yy_state_56)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_55)
    _ => Error
  }
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_249)
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_30)
    T_RBRACKET => Shift(yy_state_57)
    _ => Error
  }
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_248)
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_247)
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_60)
    NT_type_parameter => Shift(yy_state_77)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_78)
    NT_non_empty_type_parameter_list => Shift(yy_state_80)
    _ => Error
  }
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_61)
    T_RBRACKET | T_COMMA => Reduce(1, NT_type_parameter, yy_action_246)
    _ => Error
  }
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_kind => Shift(yy_state_62)
    T_LPAREN => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_66)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    _ => Error
  }
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter, yy_action_245)
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    NT_kind => Shift(yy_state_64)
    T_LBRACKET => Shift(yy_state_66)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    _ => Error
  }
}

fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind, yy_action_244)
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_66)
    NT_kind => Shift(yy_state_67)
    NT_non_empty_kind_list => Shift(yy_state_68)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    NT_kind_list => Shift(yy_state_73)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_243)
    _ => Error
  }
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_242)
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_69)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_241)
    _ => Error
  }
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_66)
    NT_kind => Shift(yy_state_70)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_kind_list, yy_action_240)
    _ => Error
  }
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_239)
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_238)
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_237)
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_74)
    _ => Error
  }
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_75)
    _ => Error
  }
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_66)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    NT_kind => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_236)
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_list, yy_action_235)
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_79)
    _ => Error
  }
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_234)
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_81)
    T_RBRACKET => Shift(yy_state_83)
    _ => Error
  }
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_60)
    NT_type_parameter => Shift(yy_state_82)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_type_parameter_list, yy_action_233)
    _ => Error
  }
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_list, yy_action_232)
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_bracket_list, yy_action_231)
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_85)
    _ => Error
  }
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_87)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_annotation_opt, yy_action_230)
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type, yy_action_229)
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect_annotation, yy_action_228)
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_90)
    _ => Error
  }
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_91)
    _ => Error
  }
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_primary, yy_action_227)
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_53)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_BANG | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(1, NT_effect_set, yy_action_226)
    _ => Error
  }
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_type, yy_action_225)
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_91)
    T_COMMA => Shift(yy_state_95)
    _ => Error
  }
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_96)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_97)
    _ => Error
  }
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_98)
    _ => Error
  }
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_99)
    _ => Error
  }
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_100)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_224)
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_102)
    _ => Error
  }
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_103)
    _ => Error
  }
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_104)
    _ => Error
  }
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_105)
    T_IDENT | T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_EQUAL => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_type, yy_action_223)
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_107)
    _ => Error
  }
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_402)
    _ => Error
  }
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_109)
    _ => Error
  }
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_110)
    _ => Error
  }
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_111)
    _ => Error
  }
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_builtin_expression, yy_action_222)
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameters => Shift(yy_state_113)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    T_LPAREN => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_114)
    _ => Error
  }
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_115)
    NT_function_literal_parameter_modifiers => Shift(yy_state_116)
    NT_function_literal_parameter => Shift(yy_state_121)
    NT_non_empty_function_literal_parameters => Shift(yy_state_122)
    NT_function_literal_parameters => Shift(yy_state_125)
    T_RPAREN => Reduce(0, NT_function_literal_parameters, yy_action_219)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_220)
    _ => Error
  }
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_literal_parameter_modifiers, yy_action_218)
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_117)
    _ => Error
  }
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_type_annotation => Shift(yy_state_118)
    T_COLON => Shift(yy_state_119)
    T_RPAREN | T_COMMA => Reduce(0, NT_local_type_annotation, yy_action_217)
    _ => Error
  }
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_parameter, yy_action_216)
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_120)
    _ => Error
  }
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_type_annotation, yy_action_215)
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_function_literal_parameters, yy_action_214)
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_123)
    T_RPAREN => Reduce(1, NT_function_literal_parameters, yy_action_213)
    _ => Error
  }
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_115)
    NT_function_literal_parameter_modifiers => Shift(yy_state_116)
    NT_function_literal_parameter => Shift(yy_state_124)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_220)
    _ => Error
  }
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_function_literal_parameters, yy_action_212)
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_126)
    _ => Error
  }
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_127)
    NT_return_annotation => Shift(yy_state_130)
    T_LBRACE => Reduce(0, NT_return_annotation, yy_action_211)
    _ => Error
  }
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_128)
    _ => Error
  }
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_129)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_return_annotation, yy_action_210)
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block_expression => Shift(yy_state_131)
    T_LBRACE => Shift(yy_state_132)
    _ => Error
  }
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_literal, yy_action_209)
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_items => Shift(yy_state_133)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_BUILTIN | T_MINUS | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET => Reduce(0, NT_local_items, yy_action_208)
    _ => Error
  }
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_23)
    T_BUILTIN => Shift(yy_state_108)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_offer_value_declaration => Shift(yy_state_367)
    NT_function_declaration => Shift(yy_state_368)
    NT_local_let_item => Shift(yy_state_369)
    NT_local_item => Shift(yy_state_370)
    NT_expression => Shift(yy_state_371)
    T_LET => Shift(yy_state_373)
    T_FN => Shift(yy_state_378)
    _ => Error
  }
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_315)
    _ => Error
  }
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_266)
    _ => Error
  }
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_260)
    _ => Error
  }
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_207)
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_non_empty_positional_argument_list => Shift(yy_state_139)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_242)
    NT_list_literal_items => Shift(yy_state_258)
    T_RBRACKET => Reduce(0, NT_list_literal_items, yy_action_206)
    _ => Error
  }
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_140)
    T_RBRACKET => Reduce(1, NT_list_literal_items, yy_action_205)
    _ => Error
  }
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_257)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_positional_argument_list, yy_action_204)
    _ => Error
  }
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_203)
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_202)
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_201)
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_200)
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_199)
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_RPAREN => Shift(yy_state_147)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_255)
    _ => Error
  }
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_non_owner_primary_expression, yy_action_198)
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_197)
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_196)
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_195)
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_194)
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_owner_primary_expression, yy_action_193)
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    NT_type_arguments => Shift(yy_state_160)
    T_DOT => Shift(yy_state_161)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_TIGHT_COLONCOLON | T_UNDERSCORE => Reduce(1, NT_owner_expression, yy_action_192)
    _ => Error
  }
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR => Shift(yy_state_155)
    NT_non_empty_type_list => Shift(yy_state_157)
    _ => Error
  }
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_156)
    _ => Error
  }
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_191)
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_30)
    T_RBRACKET => Shift(yy_state_158)
    _ => Error
  }
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_argument_bracket_list, yy_action_190)
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_arguments, yy_action_189)
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_owner_expression, yy_action_188)
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_162)
    _ => Error
  }
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_owner_path_expression, yy_action_187)
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_164)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_DOT | T_TIGHT_COLONCOLON | T_UNDERSCORE => Reduce(1, NT_owner_path_expression, yy_action_186)
    _ => Error
  }
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    NT_type_arguments => Shift(yy_state_165)
    NT_operation_type_witnesses => Shift(yy_state_166)
    T_LPAREN => Shift(yy_state_252)
    _ => Error
  }
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_operation_type_witnesses, yy_action_185)
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_167)
    _ => Error
  }
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_empty_positional_argument_list => Shift(yy_state_168)
    NT_positional_argument_list => Shift(yy_state_169)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_242)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_184)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_140)
    T_RPAREN => Reduce(1, NT_positional_argument_list, yy_action_183)
    _ => Error
  }
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_170)
    _ => Error
  }
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_value_postfix_expression, yy_action_182)
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_181)
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_173)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_DOT | T_UNDERSCORE => Reduce(1, NT_value_postfix_expression, yy_action_180)
    _ => Error
  }
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_174)
    T_IDENT => Shift(yy_state_236)
    _ => Error
  }
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_175)
    NT_struct_literal_field => Shift(yy_state_230)
    NT_non_empty_struct_literal_fields => Shift(yy_state_231)
    NT_struct_literal_fields => Shift(yy_state_234)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_179)
    _ => Error
  }
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_176)
    T_COLON => Shift(yy_state_178)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_literal_field, yy_action_178)
    _ => Error
  }
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_177)
    _ => Error
  }
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_literal_field, yy_action_177)
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_229)
    _ => Error
  }
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_postfix_expression, yy_action_176)
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    T_DOT => Shift(yy_state_181)
    NT_type_arguments => Shift(yy_state_183)
    T_LPAREN => Shift(yy_state_184)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(1, NT_postfix_expression, yy_action_175)
    _ => Error
  }
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_182)
    _ => Error
  }
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_value_postfix_expression, yy_action_174)
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value_postfix_expression, yy_action_173)
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_call_argument => Shift(yy_state_185)
    NT_non_empty_argument_list => Shift(yy_state_186)
    T_IDENT => Shift(yy_state_189)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_226)
    NT_argument_list => Shift(yy_state_227)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_172)
    _ => Error
  }
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_argument_list, yy_action_171)
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_187)
    T_RPAREN => Reduce(1, NT_argument_list, yy_action_170)
    _ => Error
  }
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_call_argument => Shift(yy_state_188)
    T_IDENT => Shift(yy_state_189)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_226)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_argument_list, yy_action_169)
    _ => Error
  }
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_argument_list, yy_action_168)
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_164)
    T_EQUAL => Shift(yy_state_190)
    T_PLUS | T_MINUS | T_STAR | T_SLASH | T_PERCENT | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACKET | T_COMMA | T_DOT | T_TIGHT_COLONCOLON => Reduce(1, NT_owner_path_expression, yy_action_186)
    _ => Error
  }
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_197)
    _ => Error
  }
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_unary_expression, yy_action_167)
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    NT_unary_expression => Shift(yy_state_193)
    T_MINUS => Shift(yy_state_194)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_166)
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_195)
    _ => Error
  }
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary_expression, yy_action_165)
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_164)
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RPAREN | T_COMMA => Reduce(3, NT_call_argument, yy_action_163)
    _ => Error
  }
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_199)
    _ => Error
  }
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_162)
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_201)
    _ => Error
  }
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_161)
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_203)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_160)
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_205)
    _ => Error
  }
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_159)
    _ => Error
  }
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_207)
    _ => Error
  }
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_PLUS | T_MINUS | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_158)
    _ => Error
  }
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_209)
    _ => Error
  }
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_157)
    _ => Error
  }
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_211)
    _ => Error
  }
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_156)
    _ => Error
  }
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_213)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_155)
    _ => Error
  }
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_215)
    _ => Error
  }
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_LT | T_LTEQ | T_GT | T_GTEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_154)
    _ => Error
  }
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_217)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_153)
    _ => Error
  }
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_219)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_EQEQ | T_BANGEQ | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_152)
    _ => Error
  }
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_221)
    _ => Error
  }
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_AMPAMP | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_151)
    _ => Error
  }
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_223)
    _ => Error
  }
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_BARBAR | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_150)
    _ => Error
  }
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_225)
    _ => Error
  }
}

fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_WITH | T_BUILTIN | T_PUB | T_BANG | T_PIPE | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_149)
    _ => Error
  }
}

fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RPAREN | T_COMMA => Reduce(1, NT_call_argument, yy_action_148)
    _ => Error
  }
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_228)
    _ => Error
  }
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_value_postfix_expression, yy_action_147)
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RBRACE | T_COMMA => Reduce(3, NT_struct_literal_field, yy_action_146)
    _ => Error
  }
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_literal_fields, yy_action_145)
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_232)
    T_RBRACE => Reduce(1, NT_struct_literal_fields, yy_action_144)
    _ => Error
  }
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_175)
    NT_struct_literal_field => Shift(yy_state_233)
    T_RBRACE | T_COMMA => Reduce(2, NT_non_empty_struct_literal_fields, yy_action_143)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_literal_fields, yy_action_142)
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_235)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_141)
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    NT_type_arguments => Shift(yy_state_237)
    NT_variant_type_arguments => Shift(yy_state_238)
    T_BANG => Shift(yy_state_244)
    T_LPAREN => Reduce(0, NT_variant_type_arguments, yy_action_140)
    _ => Error
  }
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_variant_type_arguments, yy_action_139)
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_239)
    NT_variant_arguments => Shift(yy_state_243)
    _ => Error
  }
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_empty_positional_argument_list => Shift(yy_state_168)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_positional_argument_list => Shift(yy_state_240)
    NT_expression => Shift(yy_state_242)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_184)
    _ => Error
  }
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_241)
    _ => Error
  }
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_arguments, yy_action_138)
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(1, NT_non_empty_positional_argument_list, yy_action_137)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_member_expression, yy_action_136)
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    NT_type_arguments => Shift(yy_state_165)
    NT_operation_type_witnesses => Shift(yy_state_245)
    T_LPAREN => Shift(yy_state_249)
    _ => Error
  }
}

fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_246)
    _ => Error
  }
}

fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_empty_positional_argument_list => Shift(yy_state_168)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_242)
    NT_positional_argument_list => Shift(yy_state_247)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_184)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_248)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_member_expression, yy_action_135)
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_empty_positional_argument_list => Shift(yy_state_168)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_242)
    NT_positional_argument_list => Shift(yy_state_250)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_184)
    _ => Error
  }
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_251)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_member_expression, yy_action_134)
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_empty_positional_argument_list => Shift(yy_state_168)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_242)
    NT_positional_argument_list => Shift(yy_state_253)
    T_RPAREN => Reduce(0, NT_positional_argument_list, yy_action_184)
    _ => Error
  }
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_254)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_value_postfix_expression, yy_action_133)
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RPAREN => Shift(yy_state_256)
    _ => Error
  }
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_132)
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RPAREN | T_RBRACKET | T_COMMA => Reduce(3, NT_non_empty_positional_argument_list, yy_action_131)
    _ => Error
  }
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_259)
    _ => Error
  }
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_owner_primary_expression, yy_action_130)
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_132)
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    NT_block_expression => Shift(yy_state_261)
    _ => Error
  }
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_262)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_132)
    T_IF => Shift(yy_state_136)
    NT_if_expression => Shift(yy_state_263)
    NT_block_expression => Shift(yy_state_264)
    NT_else_branch_expression => Shift(yy_state_265)
    _ => Error
  }
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_129)
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_128)
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_if_expression, yy_action_127)
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_LBRACE => Shift(yy_state_267)
    _ => Error
  }
}

fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_match_arms => Shift(yy_state_268)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_RBRACE | T_UNDERSCORE => Reduce(0, NT_match_arms, yy_action_126)
    _ => Error
  }
}

fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    NT_pattern => Shift(yy_state_310)
    NT_match_arm => Shift(yy_state_313)
    T_RBRACE => Shift(yy_state_314)
    _ => Error
  }
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_270)
    _ => Error
  }
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_271)
    T_IDENT => Shift(yy_state_305)
    _ => Error
  }
}

fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_272)
    T_IDENT => Shift(yy_state_273)
    NT_struct_pattern_field => Shift(yy_state_299)
    NT_non_empty_struct_pattern_fields => Shift(yy_state_300)
    NT_struct_pattern_fields => Shift(yy_state_303)
    T_RBRACE => Reduce(0, NT_struct_pattern_fields, yy_action_125)
    _ => Error
  }
}

fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_pattern_field, yy_action_124)
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_274)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_pattern_field, yy_action_123)
    _ => Error
  }
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_pattern => Shift(yy_state_275)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_pattern_field, yy_action_122)
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_121)
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_120)
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_119)
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_118)
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_117)
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_116)
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_115)
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_44)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_114)
    _ => Error
  }
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_41)
    T_LBRACKET => Shift(yy_state_285)
    NT_variant_type_binders => Shift(yy_state_291)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_113)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_111)
    T_RPAREN | T_RBRACE | T_COMMA | T_COLON | T_FAT_ARROW | T_EQUAL => Reduce(1, NT_pattern, yy_action_112)
    _ => Error
  }
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_286)
    NT_non_empty_ident_list => Shift(yy_state_287)
    _ => Error
  }
}

fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_ident_list, yy_action_110)
}

fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_288)
    T_RBRACKET => Shift(yy_state_290)
    _ => Error
  }
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_289)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_ident_list, yy_action_109)
    _ => Error
  }
}

fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_ident_list, yy_action_108)
}

fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_binders, yy_action_107)
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_292)
    _ => Error
  }
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    NT_pattern => Shift(yy_state_293)
    NT_non_empty_pattern_list => Shift(yy_state_294)
    NT_pattern_list => Shift(yy_state_297)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_106)
    _ => Error
  }
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_pattern_list, yy_action_105)
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_295)
    T_RPAREN => Reduce(1, NT_pattern_list, yy_action_104)
    _ => Error
  }
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    NT_pattern => Shift(yy_state_296)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_pattern_list, yy_action_103)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_pattern_list, yy_action_102)
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_298)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_pattern, yy_action_101)
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_pattern_fields, yy_action_100)
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_301)
    T_RBRACE => Reduce(1, NT_struct_pattern_fields, yy_action_99)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_272)
    T_IDENT => Shift(yy_state_273)
    NT_struct_pattern_field => Shift(yy_state_302)
    T_RBRACE | T_COMMA => Reduce(2, NT_non_empty_struct_pattern_fields, yy_action_98)
    _ => Error
  }
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_pattern_fields, yy_action_97)
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_304)
    _ => Error
  }
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_pattern, yy_action_96)
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_285)
    NT_variant_type_binders => Shift(yy_state_306)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_113)
    _ => Error
  }
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_307)
    _ => Error
  }
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    NT_pattern => Shift(yy_state_293)
    NT_non_empty_pattern_list => Shift(yy_state_294)
    NT_pattern_list => Shift(yy_state_308)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_106)
    _ => Error
  }
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_309)
    _ => Error
  }
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_pattern, yy_action_95)
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_311)
    _ => Error
  }
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_312)
    _ => Error
  }
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_RBRACE | T_UNDERSCORE => Reduce(3, NT_match_arm, yy_action_94)
    _ => Error
  }
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_match_arms, yy_action_93)
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_match_expression, yy_action_92)
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_WITH => Shift(yy_state_316)
    NT_handler_with_block => Shift(yy_state_359)
    NT_handler_with_blocks => Shift(yy_state_360)
    _ => Error
  }
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_317)
    _ => Error
  }
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_handler_operation_head => Shift(yy_state_318)
    NT_handler_operation_arm => Shift(yy_state_331)
    NT_handler_operation_arms => Shift(yy_state_332)
    NT_qualified_type_name => Shift(yy_state_335)
    T_IDENT => Shift(yy_state_347)
    _ => Error
  }
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_319)
    _ => Error
  }
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    NT_pattern => Shift(yy_state_320)
    NT_handler_payload_patterns => Shift(yy_state_321)
    T_IDENT => Shift(yy_state_325)
    NT_identifier => Shift(yy_state_326)
    NT_handler_operation_arm_parameters => Shift(yy_state_327)
    _ => Error
  }
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_payload_patterns, yy_action_91)
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_322)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    NT_pattern => Shift(yy_state_323)
    NT_identifier => Shift(yy_state_324)
    T_IDENT => Shift(yy_state_325)
    _ => Error
  }
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_payload_patterns, yy_action_90)
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_arm_parameters, yy_action_89)
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_41)
    T_LBRACKET => Shift(yy_state_285)
    NT_variant_type_binders => Shift(yy_state_291)
    T_LPAREN => Reduce(0, NT_variant_type_binders, yy_action_113)
    T_RPAREN => Reduce(1, NT_identifier, yy_action_88)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_111)
    T_COMMA => Reduce(1, NT_pattern, yy_action_112)
    _ => Error
  }
}

fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_arm_parameters, yy_action_87)
}

fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_328)
    _ => Error
  }
}

fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_329)
    _ => Error
  }
}

fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_330)
    _ => Error
  }
}

fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_IDENT | T_RBRACE => Reduce(6, NT_handler_operation_arm, yy_action_86)
    _ => Error
  }
}

fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_arms, yy_action_85)
}

fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_handler_operation_head => Shift(yy_state_318)
    NT_handler_operation_arm => Shift(yy_state_333)
    T_RBRACE => Shift(yy_state_334)
    NT_qualified_type_name => Shift(yy_state_335)
    T_IDENT => Shift(yy_state_347)
    _ => Error
  }
}

fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_operation_arms, yy_action_84)
}

fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_with_block, yy_action_83)
}

fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_44)
    T_LBRACKET => Shift(yy_state_154)
    NT_type_argument_bracket_list => Shift(yy_state_159)
    NT_type_arguments => Shift(yy_state_336)
    NT_handler_operation_owner_arguments => Shift(yy_state_337)
    T_TIGHT_COLONCOLON => Reduce(0, NT_handler_operation_owner_arguments, yy_action_82)
    _ => Error
  }
}

fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_owner_arguments, yy_action_81)
}

fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_338)
    _ => Error
  }
}

fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_339)
    _ => Error
  }
}

fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_340)
    NT_ident_bracket_list => Shift(yy_state_345)
    NT_handler_operation_type_binders => Shift(yy_state_346)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_80)
    _ => Error
  }
}

fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_286)
    T_EMPTY_TYPE_PARAMETER_LIST_ERROR => Shift(yy_state_341)
    NT_non_empty_ident_list => Shift(yy_state_343)
    _ => Error
  }
}

fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_342)
    _ => Error
  }
}

fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_79)
}

fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_288)
    T_RBRACKET => Shift(yy_state_344)
    _ => Error
  }
}

fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_ident_bracket_list, yy_action_78)
}

fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_operation_type_binders, yy_action_77)
}

fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_handler_operation_head, yy_action_76)
}

fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_41)
    T_TIGHT_COLONCOLON => Shift(yy_state_348)
    T_LBRACKET => Shift(yy_state_351)
    NT_handler_operation_head_after_ident => Shift(yy_state_358)
    T_LPAREN => Reduce(0, NT_handler_operation_head_after_ident, yy_action_75)
    _ => Error
  }
}

fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_340)
    NT_ident_bracket_list => Shift(yy_state_345)
    NT_handler_operation_type_binders => Shift(yy_state_350)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_80)
    _ => Error
  }
}

fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_head_after_ident, yy_action_74)
}

fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_non_empty_type_list => Shift(yy_state_352)
    _ => Error
  }
}

fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_30)
    T_RBRACKET => Shift(yy_state_353)
    _ => Error
  }
}

fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_354)
    NT_handler_operation_after_type_arguments => Shift(yy_state_357)
    T_LPAREN => Reduce(0, NT_handler_operation_after_type_arguments, yy_action_73)
    _ => Error
  }
}

fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_355)
    _ => Error
  }
}

fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_340)
    NT_ident_bracket_list => Shift(yy_state_345)
    NT_handler_operation_type_binders => Shift(yy_state_356)
    T_LPAREN => Reduce(0, NT_handler_operation_type_binders, yy_action_80)
    _ => Error
  }
}

fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_operation_after_type_arguments, yy_action_72)
}

fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_operation_head_after_ident, yy_action_71)
}

fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_operation_head, yy_action_70)
}

fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_handler_with_blocks, yy_action_69)
}

fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_WITH => Shift(yy_state_316)
    T_FINAL => Shift(yy_state_361)
    NT_handler_with_block => Shift(yy_state_365)
    NT_handler_final_branch => Shift(yy_state_366)
    _ => Error
  }
}

fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_identifier => Shift(yy_state_362)
    T_IDENT => Shift(yy_state_364)
    _ => Error
  }
}

fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_132)
    NT_block_expression => Shift(yy_state_363)
    _ => Error
  }
}

fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_handler_final_branch, yy_action_68)
}

fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_identifier, yy_action_88)
}

fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_with_blocks, yy_action_67)
}

fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_expression, yy_action_66)
}

fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_65)
}

fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_64)
}

fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_63)
}

fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_items, yy_action_62)
}

fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_RBRACE => Shift(yy_state_372)
    _ => Error
  }
}

fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block_expression, yy_action_61)
}

fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_269)
    NT_struct_pattern => Shift(yy_state_276)
    T_FALSE => Shift(yy_state_277)
    T_TRUE => Shift(yy_state_278)
    T_STRING => Shift(yy_state_279)
    T_DOUBLE => Shift(yy_state_280)
    T_INT => Shift(yy_state_281)
    T_UNDERSCORE => Shift(yy_state_282)
    NT_qualified_type_name => Shift(yy_state_283)
    T_IDENT => Shift(yy_state_284)
    NT_pattern => Shift(yy_state_374)
    _ => Error
  }
}

fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_119)
    NT_local_type_annotation => Shift(yy_state_375)
    T_EQUAL => Reduce(0, NT_local_type_annotation, yy_action_217)
    _ => Error
  }
}

fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_376)
    _ => Error
  }
}

fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_377)
    _ => Error
  }
}

fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_FN | T_LET | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_BUILTIN | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET => Reduce(5, NT_local_let_item, yy_action_60)
    _ => Error
  }
}

fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_380)
    T_IDENT | T_LPAREN => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameters, yy_action_59)
}

fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_114)
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_381)
    _ => Error
  }
}

fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_382)
    NT_parameters => Shift(yy_state_397)
    _ => Error
  }
}

fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_383)
    T_AUTO => Shift(yy_state_385)
    NT_parameter_modifiers => Shift(yy_state_387)
    NT_parameter => Shift(yy_state_391)
    NT_non_empty_parameter_list => Shift(yy_state_392)
    T_RPAREN => Shift(yy_state_396)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_58)
    _ => Error
  }
}

fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AUTO => Shift(yy_state_384)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_57)
    _ => Error
  }
}

fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_56)
}

fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_386)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_55)
    _ => Error
  }
}

fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_54)
}

fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_388)
    _ => Error
  }
}

fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_389)
    _ => Error
  }
}

fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_390)
    _ => Error
  }
}

fn yy_state_390(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameter, yy_action_53)
}

fn yy_state_391(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_parameter_list, yy_action_52)
}

fn yy_state_392(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_393)
    T_RPAREN => Shift(yy_state_395)
    _ => Error
  }
}

fn yy_state_393(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_383)
    T_AUTO => Shift(yy_state_385)
    NT_parameter_modifiers => Shift(yy_state_387)
    NT_parameter => Shift(yy_state_394)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_58)
    _ => Error
  }
}

fn yy_state_394(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_parameter_list, yy_action_51)
}

fn yy_state_395(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parameters, yy_action_50)
}

fn yy_state_396(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameters, yy_action_49)
}

fn yy_state_397(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_398)
    _ => Error
  }
}

fn yy_state_398(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_399)
    _ => Error
  }
}

fn yy_state_399(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_400)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_400(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_132)
    NT_block_expression => Shift(yy_state_401)
    _ => Error
  }
}

fn yy_state_401(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_declaration, yy_action_48)
}

fn yy_state_402(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_INT | T_DOUBLE | T_STRING | T_IDENT | T_EOF | T_FALSE | T_TRUE | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_IF | T_MATCH | T_HANDLE | T_BUILTIN | T_PUB | T_BANG | T_LPAREN | T_LBRACE | T_LBRACKET => Reduce(6, NT_offer_value_declaration, yy_action_47)
    _ => Error
  }
}

fn yy_state_403(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_404)
    _ => Error
  }
}

fn yy_state_404(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_405)
    _ => Error
  }
}

fn yy_state_405(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_406)
    _ => Error
  }
}

fn yy_state_406(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_407)
    _ => Error
  }
}

fn yy_state_407(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_408)
    _ => Error
  }
}

fn yy_state_408(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB => Reduce(6, NT_top_level_let_declaration, yy_action_46)
    _ => Error
  }
}

fn yy_state_409(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_410)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_410(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_381)
    _ => Error
  }
}

fn yy_state_411(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_412)
    _ => Error
  }
}

fn yy_state_412(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_413)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_413(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_414)
    _ => Error
  }
}

fn yy_state_414(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_effect_operations => Shift(yy_state_415)
    T_IDENT | T_RBRACE => Reduce(0, NT_effect_operations, yy_action_45)
    _ => Error
  }
}

fn yy_state_415(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_416)
    NT_effect_operation => Shift(yy_state_428)
    T_RBRACE => Shift(yy_state_429)
    _ => Error
  }
}

fn yy_state_416(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_417)
    T_LPAREN => Shift(yy_state_423)
    _ => Error
  }
}

fn yy_state_417(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_418)
    _ => Error
  }
}

fn yy_state_418(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_419)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_419(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_420)
    _ => Error
  }
}

fn yy_state_420(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_421)
    _ => Error
  }
}

fn yy_state_421(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_422)
    _ => Error
  }
}

fn yy_state_422(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_effect_operation, yy_action_44)
}

fn yy_state_423(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_424)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_424(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_425)
    _ => Error
  }
}

fn yy_state_425(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_426)
    _ => Error
  }
}

fn yy_state_426(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_427)
    _ => Error
  }
}

fn yy_state_427(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_effect_operation, yy_action_43)
}

fn yy_state_428(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect_operations, yy_action_42)
}

fn yy_state_429(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_effect_declaration, yy_action_41)
}

fn yy_state_430(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_431)
    _ => Error
  }
}

fn yy_state_431(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_432)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_432(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_433)
    _ => Error
  }
}

fn yy_state_433(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_enum_variants => Shift(yy_state_434)
    T_IDENT | T_RBRACE => Reduce(0, NT_enum_variants, yy_action_40)
    _ => Error
  }
}

fn yy_state_434(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_435)
    NT_enum_variant => Shift(yy_state_443)
    T_RBRACE => Shift(yy_state_444)
    _ => Error
  }
}

fn yy_state_435(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_436)
    T_LPAREN => Shift(yy_state_440)
    _ => Error
  }
}

fn yy_state_436(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_437)
    _ => Error
  }
}

fn yy_state_437(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_438)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_438(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_439)
    _ => Error
  }
}

fn yy_state_439(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_enum_variant, yy_action_39)
}

fn yy_state_440(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_441)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_441(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_442)
    _ => Error
  }
}

fn yy_state_442(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_enum_variant, yy_action_38)
}

fn yy_state_443(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_enum_variants, yy_action_37)
}

fn yy_state_444(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_enum_declaration, yy_action_36)
}

fn yy_state_445(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_446)
    _ => Error
  }
}

fn yy_state_446(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_447)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_447(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_448)
    _ => Error
  }
}

fn yy_state_448(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_449)
    T_IDENT | T_TYPE | T_OFFER | T_RBRACE => Reduce(0, NT_struct_members, yy_action_35)
    _ => Error
  }
}

fn yy_state_449(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_450)
    NT_field_offer_modifier => Shift(yy_state_451)
    T_TYPE => Shift(yy_state_455)
    NT_field_declaration => Shift(yy_state_459)
    NT_type_member_declaration => Shift(yy_state_460)
    NT_struct_member => Shift(yy_state_461)
    T_RBRACE => Shift(yy_state_462)
    T_IDENT => Reduce(0, NT_field_offer_modifier, yy_action_34)
    _ => Error
  }
}

fn yy_state_450(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_field_offer_modifier, yy_action_33)
}

fn yy_state_451(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_452)
    _ => Error
  }
}

fn yy_state_452(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_453)
    _ => Error
  }
}

fn yy_state_453(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_454)
    _ => Error
  }
}

fn yy_state_454(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_field_declaration, yy_action_32)
}

fn yy_state_455(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_456)
    _ => Error
  }
}

fn yy_state_456(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_457)
    _ => Error
  }
}

fn yy_state_457(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_66)
    T_EFFECT => Shift(yy_state_71)
    T_IDENT => Shift(yy_state_72)
    NT_kind => Shift(yy_state_458)
    _ => Error
  }
}

fn yy_state_458(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_member_declaration, yy_action_31)
}

fn yy_state_459(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_30)
}

fn yy_state_460(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_29)
}

fn yy_state_461(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_struct_members, yy_action_28)
}

fn yy_state_462(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_struct_declaration, yy_action_27)
}

fn yy_state_463(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_464)
    _ => Error
  }
}

fn yy_state_464(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_465)
    T_EQUAL => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_465(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_466)
    _ => Error
  }
}

fn yy_state_466(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_467)
    NT_type => Shift(yy_state_470)
    NT_type_alias_body => Shift(yy_state_471)
    _ => Error
  }
}

fn yy_state_467(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    NT_type => Shift(yy_state_28)
    NT_non_empty_type_list => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type_list => Shift(yy_state_468)
    T_RBRACE => Reduce(0, NT_type_list, yy_action_263)
    _ => Error
  }
}

fn yy_state_468(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_469)
    _ => Error
  }
}

fn yy_state_469(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_body, yy_action_26)
}

fn yy_state_470(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_alias_body, yy_action_25)
}

fn yy_state_471(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_type_alias_declaration, yy_action_24)
}

fn yy_state_472(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_473)
    T_LET => Shift(yy_state_479)
    T_FN => Shift(yy_state_485)
    T_EFFECT => Shift(yy_state_493)
    T_ENUM => Shift(yy_state_499)
    T_STRUCT => Shift(yy_state_505)
    T_TYPE => Shift(yy_state_511)
    NT_public_offer_value_declaration => Shift(yy_state_516)
    NT_public_top_level_let_declaration => Shift(yy_state_517)
    NT_public_function_declaration => Shift(yy_state_518)
    NT_public_type_alias_declaration => Shift(yy_state_519)
    NT_public_effect_declaration => Shift(yy_state_520)
    NT_public_enum_declaration => Shift(yy_state_521)
    NT_public_struct_declaration => Shift(yy_state_522)
    NT_public_top_level_declaration => Shift(yy_state_523)
    _ => Error
  }
}

fn yy_state_473(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_474)
    _ => Error
  }
}

fn yy_state_474(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_475)
    _ => Error
  }
}

fn yy_state_475(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_476)
    _ => Error
  }
}

fn yy_state_476(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_477)
    _ => Error
  }
}

fn yy_state_477(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_478)
    _ => Error
  }
}

fn yy_state_478(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB => Reduce(6, NT_public_offer_value_declaration, yy_action_23)
    _ => Error
  }
}

fn yy_state_479(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_480)
    _ => Error
  }
}

fn yy_state_480(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_481)
    _ => Error
  }
}

fn yy_state_481(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_482)
    _ => Error
  }
}

fn yy_state_482(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_483)
    _ => Error
  }
}

fn yy_state_483(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_108)
    T_FN => Shift(yy_state_112)
    T_LBRACE => Shift(yy_state_132)
    T_HANDLE => Shift(yy_state_134)
    T_MATCH => Shift(yy_state_135)
    T_IF => Shift(yy_state_136)
    NT_builtin_expression => Shift(yy_state_137)
    T_LBRACKET => Shift(yy_state_138)
    NT_function_literal => Shift(yy_state_141)
    NT_handler_expression => Shift(yy_state_142)
    NT_match_expression => Shift(yy_state_143)
    NT_if_expression => Shift(yy_state_144)
    NT_block_expression => Shift(yy_state_145)
    T_LPAREN => Shift(yy_state_146)
    T_FALSE => Shift(yy_state_148)
    T_TRUE => Shift(yy_state_149)
    T_STRING => Shift(yy_state_150)
    T_DOUBLE => Shift(yy_state_151)
    T_INT => Shift(yy_state_152)
    NT_owner_path_expression => Shift(yy_state_153)
    T_IDENT => Shift(yy_state_163)
    NT_non_owner_primary_expression => Shift(yy_state_171)
    NT_owner_expression => Shift(yy_state_172)
    NT_member_expression => Shift(yy_state_179)
    NT_value_postfix_expression => Shift(yy_state_180)
    NT_postfix_expression => Shift(yy_state_191)
    T_BANG => Shift(yy_state_192)
    T_MINUS => Shift(yy_state_194)
    NT_unary_expression => Shift(yy_state_196)
    NT_expression => Shift(yy_state_484)
    _ => Error
  }
}

fn yy_state_484(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_198)
    T_SLASH => Shift(yy_state_200)
    T_STAR => Shift(yy_state_202)
    T_MINUS => Shift(yy_state_204)
    T_PLUS => Shift(yy_state_206)
    T_GTEQ => Shift(yy_state_208)
    T_GT => Shift(yy_state_210)
    T_LTEQ => Shift(yy_state_212)
    T_LT => Shift(yy_state_214)
    T_BANGEQ => Shift(yy_state_216)
    T_EQEQ => Shift(yy_state_218)
    T_AMPAMP => Shift(yy_state_220)
    T_BARBAR => Shift(yy_state_222)
    T_PIPE => Shift(yy_state_224)
    T_EOF | T_STRUCT | T_ENUM | T_EFFECT | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB => Reduce(6, NT_public_top_level_let_declaration, yy_action_22)
    _ => Error
  }
}

fn yy_state_485(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_486)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_486(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_364)
    NT_identifier => Shift(yy_state_487)
    _ => Error
  }
}

fn yy_state_487(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_382)
    NT_parameters => Shift(yy_state_488)
    _ => Error
  }
}

fn yy_state_488(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_489)
    _ => Error
  }
}

fn yy_state_489(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    NT_type => Shift(yy_state_490)
    _ => Error
  }
}

fn yy_state_490(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_36)
    NT_effect_annotation => Shift(yy_state_86)
    NT_effect_annotation_opt => Shift(yy_state_491)
    T_LBRACE => Reduce(0, NT_effect_annotation_opt, yy_action_259)
    _ => Error
  }
}

fn yy_state_491(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_132)
    NT_block_expression => Shift(yy_state_492)
    _ => Error
  }
}

fn yy_state_492(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_public_function_declaration, yy_action_21)
}

fn yy_state_493(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_494)
    _ => Error
  }
}

fn yy_state_494(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_495)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_495(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_496)
    _ => Error
  }
}

fn yy_state_496(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_effect_operations => Shift(yy_state_497)
    T_IDENT | T_RBRACE => Reduce(0, NT_effect_operations, yy_action_45)
    _ => Error
  }
}

fn yy_state_497(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_416)
    NT_effect_operation => Shift(yy_state_428)
    T_RBRACE => Shift(yy_state_498)
    _ => Error
  }
}

fn yy_state_498(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_effect_declaration, yy_action_20)
}

fn yy_state_499(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_500)
    _ => Error
  }
}

fn yy_state_500(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_501)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_501(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_502)
    _ => Error
  }
}

fn yy_state_502(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_enum_variants => Shift(yy_state_503)
    T_IDENT | T_RBRACE => Reduce(0, NT_enum_variants, yy_action_40)
    _ => Error
  }
}

fn yy_state_503(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_435)
    NT_enum_variant => Shift(yy_state_443)
    T_RBRACE => Shift(yy_state_504)
    _ => Error
  }
}

fn yy_state_504(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_enum_declaration, yy_action_19)
}

fn yy_state_505(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_506)
    _ => Error
  }
}

fn yy_state_506(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_507)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_507(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_508)
    _ => Error
  }
}

fn yy_state_508(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_509)
    T_IDENT | T_TYPE | T_OFFER | T_RBRACE => Reduce(0, NT_struct_members, yy_action_35)
    _ => Error
  }
}

fn yy_state_509(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_450)
    NT_field_offer_modifier => Shift(yy_state_451)
    T_TYPE => Shift(yy_state_455)
    NT_field_declaration => Shift(yy_state_459)
    NT_type_member_declaration => Shift(yy_state_460)
    NT_struct_member => Shift(yy_state_461)
    T_RBRACE => Shift(yy_state_510)
    T_IDENT => Reduce(0, NT_field_offer_modifier, yy_action_34)
    _ => Error
  }
}

fn yy_state_510(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_struct_declaration, yy_action_18)
}

fn yy_state_511(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_512)
    _ => Error
  }
}

fn yy_state_512(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    NT_type_parameter_bracket_list => Shift(yy_state_379)
    NT_type_parameters => Shift(yy_state_513)
    T_EQUAL => Reduce(0, NT_type_parameters, yy_action_221)
    _ => Error
  }
}

fn yy_state_513(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_514)
    _ => Error
  }
}

fn yy_state_514(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameter_bracket_list => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_40)
    NT_qualified_type_name => Shift(yy_state_43)
    NT_type_primary => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_47)
    NT_function_type => Shift(yy_state_51)
    NT_type_application => Shift(yy_state_52)
    NT_type_lambda => Shift(yy_state_58)
    T_LBRACKET => Shift(yy_state_59)
    T_LBRACE => Shift(yy_state_467)
    NT_type => Shift(yy_state_470)
    NT_type_alias_body => Shift(yy_state_515)
    _ => Error
  }
}

fn yy_state_515(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_public_type_alias_declaration, yy_action_17)
}

fn yy_state_516(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_16)
}

fn yy_state_517(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_15)
}

fn yy_state_518(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_14)
}

fn yy_state_519(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_13)
}

fn yy_state_520(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_12)
}

fn yy_state_521(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_11)
}

fn yy_state_522(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_10)
}

fn yy_state_523(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declaration, yy_action_9)
}

fn yy_state_524(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_8)
}

fn yy_state_525(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_7)
}

fn yy_state_526(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_6)
}

fn yy_state_527(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_5)
}

fn yy_state_528(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_4)
}

fn yy_state_529(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_3)
}

fn yy_state_530(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_2)
}

fn yy_state_531(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declarations, yy_action_1)
}

fn yy_state_532(_lookahead : YYSymbol) -> YYDecision {
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
  for term in ([(T_INT, TK_INT), (T_DOUBLE, TK_DOUBLE), (T_STRING, TK_STRING), (T_IDENT, TK_IDENT), (T_RESERVED, TK_RESERVED), (T_EOF, TK_EOF), (T_FALSE, TK_FALSE), (T_TRUE, TK_TRUE), (T_STRUCT, TK_STRUCT), (T_ENUM, TK_ENUM), (T_EFFECT, TK_EFFECT), (T_FN, TK_FN), (T_LET, TK_LET), (T_TYPE, TK_TYPE), (T_OFFER, TK_OFFER), (T_AUTO, TK_AUTO), (T_IF, TK_IF), (T_ELSE, TK_ELSE), (T_MATCH, TK_MATCH), (T_HANDLE, TK_HANDLE), (T_WITH, TK_WITH), (T_FINAL, TK_FINAL), (T_BUILTIN, TK_BUILTIN), (T_MODULE, TK_MODULE), (T_IMPORT, TK_IMPORT), (T_PUB, TK_PUB), (T_PLUS, TK_PLUS), (T_MINUS, TK_MINUS), (T_STAR, TK_STAR), (T_SLASH, TK_SLASH), (T_PERCENT, TK_PERCENT), (T_EQEQ, TK_EQEQ), (T_BANGEQ, TK_BANGEQ), (T_LT, TK_LT), (T_LTEQ, TK_LTEQ), (T_GT, TK_GT), (T_GTEQ, TK_GTEQ), (T_AMPAMP, TK_AMPAMP), (T_BARBAR, TK_BARBAR), (T_BANG, TK_BANG), (T_PIPE, TK_PIPE), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_EMPTY_GENERIC_ARGUMENT_LIST_ERROR, TK_EMPTY_GENERIC_ARGUMENT_LIST_ERROR), (T_EMPTY_TYPE_PARAMETER_LIST_ERROR, TK_EMPTY_TYPE_PARAMETER_LIST_ERROR), (T_COMMA, TK_COMMA), (T_DOTSTAR, TK_DOTSTAR), (T_DOTLBRACE, TK_DOTLBRACE), (T_DOT, TK_DOT), (T_COLON, TK_COLON), (T_COLONCOLON, TK_COLONCOLON), (T_TIGHT_COLONCOLON, TK_TIGHT_COLONCOLON), (T_THIN_ARROW, TK_THIN_ARROW), (T_FAT_ARROW, TK_FAT_ARROW), (T_EQUAL, TK_EQUAL), (T_UNDERSCORE, TK_UNDERSCORE)] : Array[(YYSymbol, TokenKind)]) {
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
