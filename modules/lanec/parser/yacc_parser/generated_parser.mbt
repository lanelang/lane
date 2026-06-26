///|
pub(all) enum Token {
  INT(String)
  STRING(String)
  IDENT(String)
  RESERVED(String)
  EOF
  FALSE
  TRUE
  STRUCT
  ENUM
  FN
  LET
  TYPE
  OFFER
  AUTO
  IF
  ELSE
  MATCH
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

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    INT(_) => TK_INT
    STRING(_) => TK_STRING
    IDENT(_) => TK_IDENT
    RESERVED(_) => TK_RESERVED
    EOF => TK_EOF
    FALSE => TK_FALSE
    TRUE => TK_TRUE
    STRUCT => TK_STRUCT
    ENUM => TK_ENUM
    FN => TK_FN
    LET => TK_LET
    TYPE => TK_TYPE
    OFFER => TK_OFFER
    AUTO => TK_AUTO
    IF => TK_IF
    ELSE => TK_ELSE
    MATCH => TK_MATCH
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

///|
pub(all) enum TokenKind {
  TK_INT
  TK_STRING
  TK_IDENT
  TK_RESERVED
  TK_EOF
  TK_FALSE
  TK_TRUE
  TK_STRUCT
  TK_ENUM
  TK_FN
  TK_LET
  TK_TYPE
  TK_OFFER
  TK_AUTO
  TK_IF
  TK_ELSE
  TK_MATCH
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

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_INT => "INT"
      TK_STRING => "STRING"
      TK_IDENT => "IDENT"
      TK_RESERVED => "RESERVED"
      TK_EOF => "EOF"
      TK_FALSE => "\"false\""
      TK_TRUE => "\"true\""
      TK_STRUCT => "\"struct\""
      TK_ENUM => "\"enum\""
      TK_FN => "\"fn\""
      TK_LET => "\"let\""
      TK_TYPE => "\"type\""
      TK_OFFER => "\"offer\""
      TK_AUTO => "\"auto\""
      TK_IF => "\"if\""
      TK_ELSE => "\"else\""
      TK_MATCH => "\"match\""
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
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_INT => to_repr("INT")
    TK_STRING => to_repr("STRING")
    TK_IDENT => to_repr("IDENT")
    TK_RESERVED => to_repr("RESERVED")
    TK_EOF => to_repr("EOF")
    TK_FALSE => to_repr("false")
    TK_TRUE => to_repr("true")
    TK_STRUCT => to_repr("struct")
    TK_ENUM => to_repr("enum")
    TK_FN => to_repr("fn")
    TK_LET => to_repr("let")
    TK_TYPE => to_repr("type")
    TK_OFFER => to_repr("offer")
    TK_AUTO => to_repr("auto")
    TK_IF => to_repr("if")
    TK_ELSE => to_repr("else")
    TK_MATCH => to_repr("match")
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

///|
pub suberror ParseError {
  UnexpectedToken(Token, (SourceSpan, SourceSpan), Array[TokenKind])
  UnexpectedEndOfInput(SourceSpan, Array[TokenKind])
} derive(Debug)

///|
type YYObj = Error

///|
priv suberror YYObj_Void

///|
priv suberror YYObj_Bool {
  YYObj_Bool(Bool)
}

///|
priv suberror YYObj_Expr {
  YYObj_Expr(Expr)
}

///|
priv suberror YYObj_Kind {
  YYObj_Kind(Kind)
}

///|
priv suberror YYObj_Type {
  YYObj_Type(Type)
}

///|
priv suberror YYObj_Array_Expr_ {
  YYObj_Array_Expr_(Array[Expr])
}

///|
priv suberror YYObj_Array_Kind_ {
  YYObj_Array_Kind_(Array[Kind])
}

///|
priv suberror YYObj_Array_Type_ {
  YYObj_Array_Type_(Array[Type])
}

///|
priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
}

///|
priv suberror YYObj_Array_Pattern_ {
  YYObj_Array_Pattern_(Array[Pattern])
}

///|
priv suberror YYObj_Array_MatchArm_ {
  YYObj_Array_MatchArm_(Array[MatchArm])
}

///|
priv suberror YYObj_Array_LocalItem_ {
  YYObj_Array_LocalItem_(Array[LocalItem])
}

///|
priv suberror YYObj_Array_Parameter_ {
  YYObj_Array_Parameter_(Array[Parameter])
}

///|
priv suberror YYObj_Array_ImportItem_ {
  YYObj_Array_ImportItem_(Array[ImportItem])
}

///|
priv suberror YYObj_Array_EnumVariant_ {
  YYObj_Array_EnumVariant_(Array[EnumVariant])
}

///|
priv suberror YYObj_Array_CallArgument_ {
  YYObj_Array_CallArgument_(Array[CallArgument])
}

///|
priv suberror YYObj_Array_StructMember_ {
  YYObj_Array_StructMember_(Array[StructMember])
}

///|
priv suberror YYObj_Array_TypeParameter_ {
  YYObj_Array_TypeParameter_(Array[TypeParameter])
}

///|
priv suberror YYObj_Array_ImportDeclaration_ {
  YYObj_Array_ImportDeclaration_(Array[ImportDeclaration])
}

///|
priv suberror YYObj_Array_StructLiteralField_ {
  YYObj_Array_StructLiteralField_(Array[StructLiteralField])
}

///|
priv suberror YYObj_Array_StructPatternField_ {
  YYObj_Array_StructPatternField_(Array[StructPatternField])
}

///|
priv suberror YYObj_Array_TopLevelDeclaration_ {
  YYObj_Array_TopLevelDeclaration_(Array[TopLevelDeclaration])
}

///|
priv suberror YYObj_Array_FunctionLiteralParameter_ {
  YYObj_Array_FunctionLiteralParameter_(Array[FunctionLiteralParameter])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_Pattern {
  YYObj_Pattern(Pattern)
}

///|
priv suberror YYObj_MatchArm {
  YYObj_MatchArm(MatchArm)
}

///|
priv suberror YYObj_LocalItem {
  YYObj_LocalItem(LocalItem)
}

///|
priv suberror YYObj_Parameter {
  YYObj_Parameter(Parameter)
}

///|
priv suberror YYObj_ImportItem {
  YYObj_ImportItem(ImportItem)
}

///|
priv suberror YYObj_ModulePath {
  YYObj_ModulePath(ModulePath)
}

///|
priv suberror YYObj_SourceFile {
  YYObj_SourceFile(SourceFile)
}

///|
priv suberror YYObj_EnumVariant {
  YYObj_EnumVariant(EnumVariant)
}

///|
priv suberror YYObj_CallArgument {
  YYObj_CallArgument(CallArgument)
}

///|
priv suberror YYObj_StructMember {
  YYObj_StructMember(StructMember)
}

///|
priv suberror YYObj_TypeParameter {
  YYObj_TypeParameter(TypeParameter)
}

///|
priv suberror YYObj_LetDeclaration {
  YYObj_LetDeclaration(LetDeclaration)
}

///|
priv suberror YYObj_EnumDeclaration {
  YYObj_EnumDeclaration(EnumDeclaration)
}

///|
priv suberror YYObj_FieldDeclaration {
  YYObj_FieldDeclaration(FieldDeclaration)
}

///|
priv suberror YYObj_OfferDeclaration {
  YYObj_OfferDeclaration(OfferDeclaration)
}

///|
priv suberror YYObj_ImportDeclaration {
  YYObj_ImportDeclaration(ImportDeclaration)
}

///|
priv suberror YYObj_StructDeclaration {
  YYObj_StructDeclaration(StructDeclaration)
}

///|
priv suberror YYObj_ParameterModifiers {
  YYObj_ParameterModifiers(ParameterModifiers)
}

///|
priv suberror YYObj_StructLiteralField {
  YYObj_StructLiteralField(StructLiteralField)
}

///|
priv suberror YYObj_StructPatternField {
  YYObj_StructPatternField(StructPatternField)
}

///|
priv suberror YYObj_FunctionDeclaration {
  YYObj_FunctionDeclaration(FunctionDeclaration)
}

///|
priv suberror YYObj_TopLevelDeclaration {
  YYObj_TopLevelDeclaration(TopLevelDeclaration)
}

///|
priv suberror YYObj_TypeAliasDeclaration {
  YYObj_TypeAliasDeclaration(TypeAliasDeclaration)
}

///|
priv suberror YYObj_PatternLetDeclaration {
  YYObj_PatternLetDeclaration(PatternLetDeclaration)
}

///|
priv suberror YYObj_TypeMemberDeclaration {
  YYObj_TypeMemberDeclaration(TypeMemberDeclaration)
}

///|
priv suberror YYObj_FunctionLiteralParameter {
  YYObj_FunctionLiteralParameter(FunctionLiteralParameter)
}

///|
priv suberror YYObj_Type_ {
  YYObj_Type_(Type?)
}

///|
type YYState = (YYSymbol) -> YYDecision

///|
type YYAction = (SourceSpan, ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj

///|
priv enum YYDecision {
  Accept
  Shift(YYState)
  Reduce(Int, YYSymbol, YYAction)
  ReduceNoLookahead(Int, YYSymbol, YYAction)
  Error
}

///|
priv enum YYSymbol {
  T_INT
  T_STRING
  T_IDENT
  T_RESERVED
  T_EOF
  T_FALSE
  T_TRUE
  T_STRUCT
  T_ENUM
  T_FN
  T_LET
  T_TYPE
  T_OFFER
  T_AUTO
  T_IF
  T_ELSE
  T_MATCH
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
  NT_top_level_declarations
  NT_top_level_declaration
  NT_public_top_level_declaration
  NT_type_alias_declaration
  NT_public_type_alias_declaration
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
  NT_function_declaration
  NT_public_function_declaration
  NT_parameters
  NT_non_empty_parameter_list
  NT_parameter
  NT_parameter_modifiers
  NT_top_level_let_declaration
  NT_public_top_level_let_declaration
  NT_local_let_declaration
  NT_local_pattern_let_declaration
  NT_local_type_annotation
  NT_offer_value_declaration
  NT_public_offer_value_declaration
  NT_type_parameters
  NT_non_empty_type_parameter_list
  NT_type_parameter
  NT_type
  NT_type_lambda
  NT_type_application
  NT_type_primary
  NT_qualified_type_name
  NT_function_type
  NT_type_list
  NT_non_empty_type_list
  NT_expression
  NT_primary_expression
  NT_nominal_type_name
  NT_variant_type_arguments
  NT_struct_literal_fields
  NT_non_empty_struct_literal_fields
  NT_struct_literal_field
  NT_variant_arguments
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
  NT_function_literal
  NT_function_literal_parameters
  NT_non_empty_function_literal_parameters
  NT_function_literal_parameter
  NT_function_literal_parameter_modifiers
  NT_return_type_annotation
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

///|
fn init {
  match (EOI : YYSymbol) {
    EOI => ()
    _ => ()
  }
}

// file:///./parser.mbty
// 77|    module_declaration import_declarations top_level_declarations EOF {
// 78|    { module_path: $1, imports: $2, declarations: $3, loc: span($sloc) }
// 79|  }

///|
fn yy_action_0(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ModulePath(_dollar1)
  guard _args[1].0 is YYObj_Array_ImportDeclaration_(_dollar2)
  guard _args[2].0 is YYObj_Array_TopLevelDeclaration_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_SourceFile(
    {
      ()
      {
        module_path: _dollar1,
        imports: _dollar2,
        declarations: _dollar3,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 129|    top_level_declarations top_level_declaration { comma_push($1, $2) }

///|
fn yy_action_1(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopLevelDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_Array_TopLevelDeclaration_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 133|    struct_declaration { Struct($1) }

///|
fn yy_action_2(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Struct(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 134|    enum_declaration { Enum($1) }

///|
fn yy_action_3(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Enum(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 135|    type_alias_declaration { TypeAlias($1) }

///|
fn yy_action_4(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      TypeAlias(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 136|    function_declaration { Function($1) }

///|
fn yy_action_5(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Function(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 137|    top_level_let_declaration { Let($1) }

///|
fn yy_action_6(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Let(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 138|    offer_value_declaration { Offer($1) }

///|
fn yy_action_7(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Offer(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 139|    "pub" public_top_level_declaration { $2 }

///|
fn yy_action_8(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_TopLevelDeclaration(_dollar2)
  YYObj_TopLevelDeclaration(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 143|    public_struct_declaration { Struct($1) }

///|
fn yy_action_9(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_StructDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Struct(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 144|    public_enum_declaration { Enum($1) }

///|
fn yy_action_10(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_EnumDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Enum(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 145|    public_type_alias_declaration { TypeAlias($1) }

///|
fn yy_action_11(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeAliasDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      TypeAlias(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 146|    public_function_declaration { Function($1) }

///|
fn yy_action_12(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Function(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 147|    public_top_level_let_declaration { Let($1) }

///|
fn yy_action_13(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Let(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 148|    public_offer_value_declaration { Offer($1) }

///|
fn yy_action_14(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_TopLevelDeclaration(
    {
      ()
      Offer(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 158|    "type" IDENT type_parameters "=" type {
// 159|    { is_public: true, name: $2, type_parameters: $3, body: $5, loc: span($sloc) }
// 160|  }

///|
fn yy_action_15(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_TypeAliasDeclaration(
    {
      ()
      {
        is_public: true,
        name: _dollar2,
        type_parameters: _dollar3,
        body: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 170|    "struct" IDENT type_parameters "{" struct_members "}" {
// 171|    { is_public: true, name: $2, type_parameters: $3, members: $5, loc: span($sloc) }
// 172|  }

///|
fn yy_action_16(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructDeclaration(
    {
      ()
      {
        is_public: true,
        name: _dollar2,
        type_parameters: _dollar3,
        members: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 230|    "enum" IDENT type_parameters "{" enum_variants "}" {
// 231|    { is_public: true, name: $2, type_parameters: $3, variants: $5, loc: span($sloc) }
// 232|  }

///|
fn yy_action_17(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumDeclaration(
    {
      ()
      {
        is_public: true,
        name: _dollar2,
        type_parameters: _dollar3,
        variants: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 270|    "fn" type_parameters IDENT parameters "->" type block_expression {
// 271|    {
// 272|      is_public: true,
// 273|      type_parameters: $2,
// 274|      name: $3,
// 275|      parameters: $4,
// 276|      return_type: $6,
// 277|      body: $7,
// 278|      loc: span($sloc),
// 279|    }
// 280|  }

///|
fn yy_action_18(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_FunctionDeclaration(
    {
      ()
      {
        is_public: true,
        type_parameters: _dollar2,
        name: _dollar3,
        parameters: _dollar4,
        return_type: _dollar6,
        body: _dollar7,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 314|    "let" IDENT ":" type "=" expression {
// 315|    { is_public: true, name: Some($2), type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 316|  }

///|
fn yy_action_19(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_LetDeclaration(
    {
      ()
      {
        is_public: true,
        name: Some(_dollar2),
        type_annotation: Some(_dollar4),
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 343|    "offer" IDENT ":" type "=" expression {
// 344|    { is_public: true, name: $2, type_annotation: $4, initializer: $6, loc: span($sloc) }
// 345|  }

///|
fn yy_action_20(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_OfferDeclaration(
    {
      ()
      {
        is_public: true,
        name: _dollar2,
        type_annotation: _dollar4,
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 152|    "type" IDENT type_parameters "=" type {
// 153|    { is_public: false, name: $2, type_parameters: $3, body: $5, loc: span($sloc) }
// 154|  }

///|
fn yy_action_21(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_TypeAliasDeclaration(
    {
      ()
      {
        is_public: false,
        name: _dollar2,
        type_parameters: _dollar3,
        body: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 164|    "struct" IDENT type_parameters "{" struct_members "}" {
// 165|    { is_public: false, name: $2, type_parameters: $3, members: $5, loc: span($sloc) }
// 166|  }

///|
fn yy_action_22(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_StructMember_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructDeclaration(
    {
      ()
      {
        is_public: false,
        name: _dollar2,
        type_parameters: _dollar3,
        members: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 177|    struct_members struct_member { comma_push($1, $2) }

///|
fn yy_action_23(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMember_(_dollar1)
  guard _args[1].0 is YYObj_StructMember(_dollar2)
  YYObj_Array_StructMember_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 181|    type_member_declaration { TypeMember($1) }

///|
fn yy_action_24(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeMemberDeclaration(_dollar1)
  YYObj_StructMember(
    {
      ()
      TypeMember(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 182|    field_declaration { Field($1) }

///|
fn yy_action_25(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_FieldDeclaration(_dollar1)
  YYObj_StructMember(
    {
      ()
      Field(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 186|    "type" IDENT ":" kind {
// 187|    { name: $2, kind: $4, loc: span($sloc) }
// 188|  }

///|
fn yy_action_26(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Kind(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_TypeMemberDeclaration(
    {
      ()
      {
        name: _dollar2,
        kind: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 213|    field_offer_modifier IDENT ":" type {
// 214|    { is_offered: $1, name: $2, type_: $4, loc: span($sloc) }
// 215|  }

///|
fn yy_action_27(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_FieldDeclaration(
    {
      ()
      {
        is_offered: _dollar1,
        name: _dollar2,
        type_: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 220|    "offer" { true }

///|
fn yy_action_28(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Bool(
    {
      ()
      true
    },
  )
}

// file:///./parser.mbty
// 219|    { false }

///|
fn yy_action_29(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Bool(
    {
      ()
      false
    },
  )
}

// file:///./parser.mbty
// 176|    { [] }

///|
fn yy_action_30(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_StructMember_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 224|    "enum" IDENT type_parameters "{" enum_variants "}" {
// 225|    { is_public: false, name: $2, type_parameters: $3, variants: $5, loc: span($sloc) }
// 226|  }

///|
fn yy_action_31(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[4].0 is YYObj_Array_EnumVariant_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumDeclaration(
    {
      ()
      {
        is_public: false,
        name: _dollar2,
        type_parameters: _dollar3,
        variants: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 237|    enum_variants enum_variant { comma_push($1, $2) }

///|
fn yy_action_32(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_EnumVariant_(_dollar1)
  guard _args[1].0 is YYObj_EnumVariant(_dollar2)
  YYObj_Array_EnumVariant_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 250|    IDENT type_parameters "(" non_empty_type_list ")" {
// 251|    { name: $1, type_parameters: $2, payload: $4, loc: span($sloc) }
// 252|  }

///|
fn yy_action_33(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumVariant(
    {
      ()
      {
        name: _dollar1,
        type_parameters: _dollar2,
        payload: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 244|    IDENT type_parameters {
// 245|    { name: $1, type_parameters: $2, payload: [], loc: span($sloc) }
// 246|  }

///|
fn yy_action_34(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumVariant(
    {
      ()
      {
        name: _dollar1,
        type_parameters: _dollar2,
        payload: [],
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 247|    IDENT "(" non_empty_type_list ")" {
// 248|    { name: $1, type_parameters: [], payload: $3, loc: span($sloc) }
// 249|  }

///|
fn yy_action_35(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumVariant(
    {
      ()
      {
        name: _dollar1,
        type_parameters: [],
        payload: _dollar3,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 241|    IDENT {
// 242|    { name: $1, type_parameters: [], payload: [], loc: span($sloc) }
// 243|  }

///|
fn yy_action_36(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_EnumVariant(
    {
      ()
      {
        name: _dollar1,
        type_parameters: [],
        payload: [],
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 236|    { [] }

///|
fn yy_action_37(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_EnumVariant_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 308|    "let" IDENT ":" type "=" expression {
// 309|    { is_public: false, name: Some($2), type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 310|  }

///|
fn yy_action_38(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_LetDeclaration(
    {
      ()
      {
        is_public: false,
        name: Some(_dollar2),
        type_annotation: Some(_dollar4),
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 337|    "offer" IDENT ":" type "=" expression {
// 338|    { is_public: false, name: $2, type_annotation: $4, initializer: $6, loc: span($sloc) }
// 339|  }

///|
fn yy_action_39(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_OfferDeclaration(
    {
      ()
      {
        is_public: false,
        name: _dollar2,
        type_annotation: _dollar4,
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 256|    "fn" type_parameters IDENT parameters "->" type block_expression {
// 257|    {
// 258|      is_public: false,
// 259|      type_parameters: $2,
// 260|      name: $3,
// 261|      parameters: $4,
// 262|      return_type: $6,
// 263|      body: $7,
// 264|      loc: span($sloc),
// 265|    }
// 266|  }

///|
fn yy_action_40(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_Parameter_(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_FunctionDeclaration(
    {
      ()
      {
        is_public: false,
        type_parameters: _dollar2,
        name: _dollar3,
        parameters: _dollar4,
        return_type: _dollar6,
        body: _dollar7,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 284|    "(" ")" { [] }

///|
fn yy_action_41(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Parameter_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 285|    "(" non_empty_parameter_list ")" { $2 }

///|
fn yy_action_42(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Parameter_(_dollar2)
  YYObj_Array_Parameter_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 290|    non_empty_parameter_list "," parameter { comma_push($1, $3) }

///|
fn yy_action_43(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Parameter_(_dollar1)
  guard _args[2].0 is YYObj_Parameter(_dollar3)
  YYObj_Array_Parameter_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 289|    parameter { [ $1 ] }

///|
fn yy_action_44(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Parameter(_dollar1)
  YYObj_Array_Parameter_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 294|    parameter_modifiers IDENT ":" type {
// 295|    { is_auto: $1.is_auto, is_offered: $1.is_offered, name: $2, type_: $4, loc: span($sloc) }
// 296|  }

///|
fn yy_action_45(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ParameterModifiers(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Parameter(
    {
      ()
      {
        is_auto: _dollar1.is_auto,
        is_offered: _dollar1.is_offered,
        name: _dollar2,
        type_: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 303|    "auto" "offer" { { is_auto: true, is_offered: true } }

///|
fn yy_action_46(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ParameterModifiers(
    {
      ()
      { is_auto: true, is_offered: true }
    },
  )
}

// file:///./parser.mbty
// 301|    "auto" { { is_auto: true, is_offered: false } }

///|
fn yy_action_47(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ParameterModifiers(
    {
      ()
      { is_auto: true, is_offered: false }
    },
  )
}

// file:///./parser.mbty
// 304|    "offer" "auto" { { is_auto: true, is_offered: true } }

///|
fn yy_action_48(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ParameterModifiers(
    {
      ()
      { is_auto: true, is_offered: true }
    },
  )
}

// file:///./parser.mbty
// 302|    "offer" { { is_auto: false, is_offered: true } }

///|
fn yy_action_49(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ParameterModifiers(
    {
      ()
      { is_auto: false, is_offered: true }
    },
  )
}

// file:///./parser.mbty
// 300|    { { is_auto: false, is_offered: false } }

///|
fn yy_action_50(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ParameterModifiers(
    {
      ()
      { is_auto: false, is_offered: false }
    },
  )
}

// file:///./parser.mbty
// 350|    "[" non_empty_type_parameter_list "]" { $2 }

///|
fn yy_action_51(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  YYObj_Array_TypeParameter_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 320|    "let" IDENT local_type_annotation "=" expression {
// 321|    { is_public: false, name: Some($2), type_annotation: $3, initializer: $5, loc: span($sloc) }
// 322|  }

///|
fn yy_action_52(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_LetDeclaration(
    {
      ()
      {
        is_public: false,
        name: Some(_dollar2),
        type_annotation: _dollar3,
        initializer: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 326|    "let" struct_pattern "=" expression {
// 327|    { pattern: $2, initializer: $4, loc: span($sloc) }
// 328|  }

///|
fn yy_action_53(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Pattern(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_PatternLetDeclaration(
    {
      ()
      {
        pattern: _dollar2,
        initializer: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 572|    "{" local_items expression "}" {
// 573|    Block(items=$2, result=$3, loc=span($sloc))
// 574|  }

///|
fn yy_action_54(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_LocalItem_(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Block(
        items=_dollar2,
        result=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 579|    local_items local_item { comma_push($1, $2) }

///|
fn yy_action_55(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_LocalItem_(_dollar1)
  guard _args[1].0 is YYObj_LocalItem(_dollar2)
  YYObj_Array_LocalItem_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 583|    local_let_declaration { Let($1) }

///|
fn yy_action_56(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_LetDeclaration(_dollar1)
  YYObj_LocalItem(
    {
      ()
      Let(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 584|    local_pattern_let_declaration { PatternLet($1) }

///|
fn yy_action_57(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_PatternLetDeclaration(_dollar1)
  YYObj_LocalItem(
    {
      ()
      PatternLet(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 585|    function_declaration { Function($1) }

///|
fn yy_action_58(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_FunctionDeclaration(_dollar1)
  YYObj_LocalItem(
    {
      ()
      Function(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 586|    offer_value_declaration { Offer($1) }

///|
fn yy_action_59(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_OfferDeclaration(_dollar1)
  YYObj_LocalItem(
    {
      ()
      Offer(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 601|    "match" expression "{" match_arms "}" {
// 602|    Match(scrutinee=$2, arms=$4, loc=span($sloc))
// 603|  }

///|
fn yy_action_60(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_Array_MatchArm_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Match(
        scrutinee=_dollar2,
        arms=_dollar4,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 608|    match_arms match_arm { comma_push($1, $2) }

///|
fn yy_action_61(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_MatchArm_(_dollar1)
  guard _args[1].0 is YYObj_MatchArm(_dollar2)
  YYObj_Array_MatchArm_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 612|    pattern "=>" expression {
// 613|    { pattern: $1, body: $3, loc: span($sloc) }
// 614|  }

///|
fn yy_action_62(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_MatchArm(
    {
      ()
      {
        pattern: _dollar1,
        body: _dollar3,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 672|    nominal_type_name "tight ::" IDENT variant_type_binders "(" pattern_list ")" {
// 673|    QualifiedVariant(type_name=$1, variant=$3, type_binders=$4, arguments=$6, loc=span($sloc))
// 674|  }

///|
fn yy_action_63(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_String_(_dollar4)
  guard _args[5].0 is YYObj_Array_Pattern_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      QualifiedVariant(
        type_name=_dollar1,
        variant=_dollar3,
        type_binders=_dollar4,
        arguments=_dollar6,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 669|    nominal_type_name "tight ::" IDENT variant_type_binders {
// 670|    QualifiedVariant(type_name=$1, variant=$3, type_binders=$4, arguments=[], loc=span($sloc))
// 671|  }

///|
fn yy_action_64(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_String_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      QualifiedVariant(
        type_name=_dollar1,
        variant=_dollar3,
        type_binders=_dollar4,
        arguments=[],
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 678|    nominal_type_name "tight ::" "{" struct_pattern_fields "}" {
// 679|    Struct(type_name=$1, fields=$4, loc=span($sloc))
// 680|  }

///|
fn yy_action_65(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[3].0 is YYObj_Array_StructPatternField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      Struct(
        type_name=_dollar1,
        fields=_dollar4,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 712|    non_empty_struct_pattern_fields "," struct_pattern_field { comma_push($1, $3) }

///|
fn yy_action_66(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  guard _args[2].0 is YYObj_StructPatternField(_dollar3)
  YYObj_Array_StructPatternField_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 713|    non_empty_struct_pattern_fields "," { $1 }

///|
fn yy_action_67(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 707|    non_empty_struct_pattern_fields { $1 }

///|
fn yy_action_68(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructPatternField_(_dollar1)
  YYObj_Array_StructPatternField_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 711|    struct_pattern_field { [ $1 ] }

///|
fn yy_action_69(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_StructPatternField(_dollar1)
  YYObj_Array_StructPatternField_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 666|    "::" IDENT variant_type_binders "(" pattern_list ")" {
// 667|    ShorthandVariant(variant=$2, type_binders=$3, arguments=$5, loc=span($sloc))
// 668|  }

///|
fn yy_action_70(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_String_(_dollar3)
  guard _args[4].0 is YYObj_Array_Pattern_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      ShorthandVariant(
        variant=_dollar2,
        type_binders=_dollar3,
        arguments=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 512|    IDENT { $1 }

///|
fn yy_action_71(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 661|    IDENT { Binding($1, loc=span($sloc)) }

///|
fn yy_action_72(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      Binding(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 513|    qualified_type_name { type_name_text($1) }

///|
fn yy_action_73(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_String(
    {
      ()
      type_name_text(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 656|    "_" { Wildcard(span($sloc)) }

///|
fn yy_action_74(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      Wildcard(span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 657|    INT { IntLiteral($1, loc=span($sloc)) }

///|
fn yy_action_75(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 658|    STRING { StringLiteral($1, loc=span($sloc)) }

///|
fn yy_action_76(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 659|    "true" { BoolLiteral(true, loc=span($sloc)) }

///|
fn yy_action_77(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 660|    "false" { BoolLiteral(false, loc=span($sloc)) }

///|
fn yy_action_78(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 662|    struct_pattern { $1 }

///|
fn yy_action_79(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Pattern(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 701|    non_empty_pattern_list "," pattern { comma_push($1, $3) }

///|
fn yy_action_80(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  YYObj_Array_Pattern_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 702|    non_empty_pattern_list "," { $1 }

///|
fn yy_action_81(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 696|    non_empty_pattern_list { $1 }

///|
fn yy_action_82(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Pattern_(_dollar1)
  YYObj_Array_Pattern_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 700|    pattern { [ $1 ] }

///|
fn yy_action_83(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Pattern(_dollar1)
  YYObj_Array_Pattern_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 695|    { [] }

///|
fn yy_action_84(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Pattern_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 663|    "::" IDENT variant_type_binders {
// 664|    ShorthandVariant(variant=$2, type_binders=$3, arguments=[], loc=span($sloc))
// 665|  }

///|
fn yy_action_85(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Array_String_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Pattern(
    {
      ()
      ShorthandVariant(
        variant=_dollar2,
        type_binders=_dollar3,
        arguments=[],
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 685|    "[" non_empty_ident_list "]" { $2 }

///|
fn yy_action_86(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_Array_String_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 690|    non_empty_ident_list "," IDENT { comma_push($1, $3) }

///|
fn yy_action_87(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 691|    non_empty_ident_list "," { $1 }

///|
fn yy_action_88(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  YYObj_Array_String_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 689|    IDENT { [ $1 ] }

///|
fn yy_action_89(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 684|    { [] }

///|
fn yy_action_90(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_String_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 723|    IDENT ":" pattern {
// 724|    Value(name=$1, pattern=Some($3), loc=span($sloc))
// 725|  }

///|
fn yy_action_91(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Pattern(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructPatternField(
    {
      ()
      Value(
        name=_dollar1,
        pattern=Some(_dollar3),
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 717|    IDENT {
// 718|    Value(name=$1, pattern=None, loc=span($sloc))
// 719|  }

///|
fn yy_action_92(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructPatternField(
    {
      ()
      Value(
        name=_dollar1,
        pattern=None,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 720|    "_" {
// 721|    TypeWildcard(loc=span($sloc))
// 722|  }

///|
fn yy_action_93(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructPatternField(
    {
      ()
      TypeWildcard(loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 706|    { [] }

///|
fn yy_action_94(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_StructPatternField_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 607|    { [] }

///|
fn yy_action_95(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_MatchArm_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 590|    "if" expression block_expression "else" else_branch_expression {
// 591|    If(condition=$2, then_branch=$3, else_branch=$5, loc=span($sloc))
// 592|  }

///|
fn yy_action_96(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      If(
        condition=_dollar2,
        then_branch=_dollar3,
        else_branch=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 596|    block_expression { $1 }

///|
fn yy_action_97(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 597|    if_expression { $1 }

///|
fn yy_action_98(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 503|    "(" expression ")" { $2 }

///|
fn yy_action_99(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  YYObj_Expr(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 472|    "!" expression %prec UNARY {
// 473|    Unary(operator=Not, operand=$2, loc=span($sloc))
// 474|  }

///|
fn yy_action_100(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Unary(
        operator=Not,
        operand=_dollar2,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 484|    expression "[" type_list "]" "tight ::" "{" struct_literal_fields "}" %prec "tight ::" {
// 485|    StructLiteral(type_name=expression_type_name_text($1), type_arguments=$3, fields=$7, loc=span($sloc))
// 486|  }

///|
fn yy_action_101(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[6].0 is YYObj_Array_StructLiteralField_(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      StructLiteral(
        type_name=expression_type_name_text(_dollar1),
        type_arguments=_dollar3,
        fields=_dollar7,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 490|    expression "[" type_list "]" "tight ::" IDENT variant_type_arguments variant_arguments %prec "tight ::" {
// 491|    QualifiedVariant(type_name=expression_type_name_text($1), type_arguments=$3, variant=$6, variant_type_arguments=$7, arguments=$8, loc=span($sloc))
// 492|  }

///|
fn yy_action_102(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[5].0 is YYObj_String(_dollar6)
  guard _args[6].0 is YYObj_Array_Type_(_dollar7)
  guard _args[7].0 is YYObj_Array_Expr_(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      QualifiedVariant(
        type_name=expression_type_name_text(_dollar1),
        type_arguments=_dollar3,
        variant=_dollar6,
        variant_type_arguments=_dollar7,
        arguments=_dollar8,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 566|    expression { [ $1 ] }

///|
fn yy_action_103(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 546|    "(" non_empty_positional_argument_list ")" { $2 }

///|
fn yy_action_104(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  YYObj_Array_Expr_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 481|    expression "tight ::" "{" struct_literal_fields "}" %prec "tight ::" {
// 482|    StructLiteral(type_name=expression_type_name_text($1), type_arguments=[], fields=$4, loc=span($sloc))
// 483|  }

///|
fn yy_action_105(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[3].0 is YYObj_Array_StructLiteralField_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      StructLiteral(
        type_name=expression_type_name_text(_dollar1),
        type_arguments=[],
        fields=_dollar4,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 528|    non_empty_struct_literal_fields "," struct_literal_field { comma_push($1, $3) }

///|
fn yy_action_106(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  guard _args[2].0 is YYObj_StructLiteralField(_dollar3)
  YYObj_Array_StructLiteralField_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 529|    non_empty_struct_literal_fields "," { $1 }

///|
fn yy_action_107(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 523|    non_empty_struct_literal_fields { $1 }

///|
fn yy_action_108(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructLiteralField_(_dollar1)
  YYObj_Array_StructLiteralField_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 527|    struct_literal_field { [ $1 ] }

///|
fn yy_action_109(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_StructLiteralField(_dollar1)
  YYObj_Array_StructLiteralField_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 475|    expression "(" argument_list ")" {
// 476|    Call(callee=$1, arguments=$3, loc=span($sloc))
// 477|  }

///|
fn yy_action_110(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_CallArgument_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Call(
        callee=_dollar1,
        arguments=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 561|    expression { Positional($1) }

///|
fn yy_action_111(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_CallArgument(
    {
      ()
      Positional(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 427|    expression "|>" expression {
// 428|    Pipeline(left=$1, right=$3, loc=span($sloc))
// 429|  }

///|
fn yy_action_112(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Pipeline(
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 430|    expression "||" expression {
// 431|    Binary(operator=Or, left=$1, right=$3, loc=span($sloc))
// 432|  }

///|
fn yy_action_113(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Or,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 433|    expression "&&" expression {
// 434|    Binary(operator=And, left=$1, right=$3, loc=span($sloc))
// 435|  }

///|
fn yy_action_114(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=And,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 436|    expression "==" expression {
// 437|    Binary(operator=Equal, left=$1, right=$3, loc=span($sloc))
// 438|  }

///|
fn yy_action_115(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Equal,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 439|    expression "!=" expression {
// 440|    Binary(operator=NotEqual, left=$1, right=$3, loc=span($sloc))
// 441|  }

///|
fn yy_action_116(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=NotEqual,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 442|    expression "<" expression {
// 443|    Binary(operator=Less, left=$1, right=$3, loc=span($sloc))
// 444|  }

///|
fn yy_action_117(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Less,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 445|    expression "<=" expression {
// 446|    Binary(operator=LessEqual, left=$1, right=$3, loc=span($sloc))
// 447|  }

///|
fn yy_action_118(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=LessEqual,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 448|    expression ">" expression {
// 449|    Binary(operator=Greater, left=$1, right=$3, loc=span($sloc))
// 450|  }

///|
fn yy_action_119(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Greater,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 451|    expression ">=" expression {
// 452|    Binary(operator=GreaterEqual, left=$1, right=$3, loc=span($sloc))
// 453|  }

///|
fn yy_action_120(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=GreaterEqual,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 454|    expression "+" expression {
// 455|    Binary(operator=Add, left=$1, right=$3, loc=span($sloc))
// 456|  }

///|
fn yy_action_121(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Add,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 457|    expression "-" expression {
// 458|    Binary(operator=Sub, left=$1, right=$3, loc=span($sloc))
// 459|  }

///|
fn yy_action_122(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Sub,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 460|    expression "*" expression {
// 461|    Binary(operator=Mul, left=$1, right=$3, loc=span($sloc))
// 462|  }

///|
fn yy_action_123(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Mul,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 463|    expression "/" expression {
// 464|    Binary(operator=Div, left=$1, right=$3, loc=span($sloc))
// 465|  }

///|
fn yy_action_124(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Div,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 466|    expression "%" expression {
// 467|    Binary(operator=Rem, left=$1, right=$3, loc=span($sloc))
// 468|  }

///|
fn yy_action_125(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Binary(
        operator=Rem,
        left=_dollar1,
        right=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 562|    IDENT "=" expression { Named(name=$1, value=$3, loc=span($sloc)) }

///|
fn yy_action_126(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_CallArgument(
    {
      ()
      Named(
        name=_dollar1,
        value=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 556|    non_empty_argument_list "," call_argument { comma_push($1, $3) }

///|
fn yy_action_127(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  guard _args[2].0 is YYObj_CallArgument(_dollar3)
  YYObj_Array_CallArgument_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 557|    non_empty_argument_list "," { $1 }

///|
fn yy_action_128(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 551|    non_empty_argument_list { $1 }

///|
fn yy_action_129(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_CallArgument_(_dollar1)
  YYObj_Array_CallArgument_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 555|    call_argument { [ $1 ] }

///|
fn yy_action_130(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_CallArgument(_dollar1)
  YYObj_Array_CallArgument_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 550|    { [] }

///|
fn yy_action_131(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_CallArgument_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 478|    expression "." IDENT {
// 479|    Field(base=$1, name=$3, loc=span($sloc))
// 480|  }

///|
fn yy_action_132(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Field(
        base=_dollar1,
        name=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 536|    IDENT ":" expression {
// 537|    Value(name=$1, value=Some($3), loc=span($sloc))
// 538|  }

///|
fn yy_action_133(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructLiteralField(
    {
      ()
      Value(
        name=_dollar1,
        value=Some(_dollar3),
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 539|    IDENT "=" type {
// 540|    TypeWitness(name=$1, witness=$3, loc=span($sloc))
// 541|  }

///|
fn yy_action_134(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructLiteralField(
    {
      ()
      TypeWitness(
        name=_dollar1,
        witness=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 533|    IDENT {
// 534|    Value(name=$1, value=None, loc=span($sloc))
// 535|  }

///|
fn yy_action_135(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_StructLiteralField(
    {
      ()
      Value(name=_dollar1, value=None, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 522|    { [] }

///|
fn yy_action_136(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_StructLiteralField_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 487|    expression "tight ::" IDENT variant_type_arguments variant_arguments %prec "tight ::" {
// 488|    QualifiedVariant(type_name=expression_type_name_text($1), type_arguments=[], variant=$3, variant_type_arguments=$4, arguments=$5, loc=span($sloc))
// 489|  }

///|
fn yy_action_137(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      QualifiedVariant(
        type_name=expression_type_name_text(_dollar1),
        type_arguments=[],
        variant=_dollar3,
        variant_type_arguments=_dollar4,
        arguments=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 567|    non_empty_positional_argument_list "," expression { comma_push($1, $3) }

///|
fn yy_action_138(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 568|    non_empty_positional_argument_list "," { $1 }

///|
fn yy_action_139(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 545|    { [] }

///|
fn yy_action_140(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Expr_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 518|    "[" type_list "]" { $2 }

///|
fn yy_action_141(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  YYObj_Array_Type_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 517|    { [] }

///|
fn yy_action_142(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Type_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 469|    "-" expression %prec UNARY {
// 470|    Unary(operator=Neg, operand=$2, loc=span($sloc))
// 471|  }

///|
fn yy_action_143(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Unary(
        operator=Neg,
        operand=_dollar2,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 493|    primary_expression { $1 }

///|
fn yy_action_144(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 497|    INT { IntLiteral($1, loc=span($sloc)) }

///|
fn yy_action_145(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      IntLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 498|    STRING { StringLiteral($1, loc=span($sloc)) }

///|
fn yy_action_146(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      StringLiteral(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 499|    "true" { BoolLiteral(true, loc=span($sloc)) }

///|
fn yy_action_147(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      BoolLiteral(true, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 500|    "false" { BoolLiteral(false, loc=span($sloc)) }

///|
fn yy_action_148(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      BoolLiteral(false, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 501|    IDENT { Var($1, loc=span($sloc)) }

///|
fn yy_action_149(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Var(_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 502|    "(" ")" { UnitLiteral(loc=span($sloc)) }

///|
fn yy_action_150(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      UnitLiteral(loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 504|    block_expression { $1 }

///|
fn yy_action_151(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 505|    if_expression { $1 }

///|
fn yy_action_152(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 506|    match_expression { $1 }

///|
fn yy_action_153(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 507|    function_literal { $1 }

///|
fn yy_action_154(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 508|    builtin_expression { $1 }

///|
fn yy_action_155(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 578|    { [] }

///|
fn yy_action_156(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_LocalItem_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 618|    "fn" type_parameters "(" function_literal_parameters ")" return_type_annotation block_expression {
// 619|    FunctionLiteral(type_parameters=$2, parameters=$4, return_type=$6, body=$7, loc=span($sloc))
// 620|  }

///|
fn yy_action_157(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[3].0 is YYObj_Array_FunctionLiteralParameter_(_dollar4)
  guard _args[5].0 is YYObj_Type_(_dollar6)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      FunctionLiteral(
        type_parameters=_dollar2,
        parameters=_dollar4,
        return_type=_dollar6,
        body=_dollar7,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 646|    "->" type { Some($2) }

///|
fn yy_action_158(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type_(
    {
      ()
      Some(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 645|    { None }

///|
fn yy_action_159(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Type_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 630|    non_empty_function_literal_parameters "," function_literal_parameter { comma_push($1, $3) }

///|
fn yy_action_160(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  guard _args[2].0 is YYObj_FunctionLiteralParameter(_dollar3)
  YYObj_Array_FunctionLiteralParameter_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 625|    non_empty_function_literal_parameters { $1 }

///|
fn yy_action_161(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionLiteralParameter_(_dollar1)
  YYObj_Array_FunctionLiteralParameter_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 629|    function_literal_parameter { [ $1 ] }

///|
fn yy_action_162(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_FunctionLiteralParameter(_dollar1)
  YYObj_Array_FunctionLiteralParameter_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 333|    ":" type { Some($2) }

///|
fn yy_action_163(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type_(
    {
      ()
      Some(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 634|    function_literal_parameter_modifiers IDENT local_type_annotation {
// 635|    { is_offered: $1, name: $2, type_annotation: $3, loc: span($sloc) }
// 636|  }

///|
fn yy_action_164(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_FunctionLiteralParameter(
    {
      ()
      {
        is_offered: _dollar1,
        name: _dollar2,
        type_annotation: _dollar3,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 332|    { None }

///|
fn yy_action_165(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Type_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 641|    "offer" { true }

///|
fn yy_action_166(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Bool(
    {
      ()
      true
    },
  )
}

// file:///./parser.mbty
// 624|    { [] }

///|
fn yy_action_167(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_FunctionLiteralParameter_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 640|    { false }

///|
fn yy_action_168(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Bool(
    {
      ()
      false
    },
  )
}

// file:///./parser.mbty
// 349|    { [] }

///|
fn yy_action_169(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_TypeParameter_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 650|    "builtin" "(" STRING ")" {
// 651|    Builtin($3, loc=span($sloc))
// 652|  }

///|
fn yy_action_170(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Expr(
    {
      ()
      Builtin(_dollar3, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 411|    "[" non_empty_type_parameter_list "]" "(" type_list ")" "->" type {
// 412|    Function(type_parameters=$2, parameters=$5, result=$8, loc=span($sloc))
// 413|  }

///|
fn yy_action_171(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameter_(_dollar2)
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  guard _args[7].0 is YYObj_Type(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      Function(
        type_parameters=_dollar2,
        parameters=_dollar5,
        result=_dollar8,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 395|    "(" type ")" { $2 }

///|
fn yy_action_172(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 354|    type_parameter { [ $1 ] }

///|
fn yy_action_173(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameter(_dollar1)
  YYObj_Array_TypeParameter_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 355|    non_empty_type_parameter_list "," type_parameter { comma_push($1, $3) }

///|
fn yy_action_174(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameter(_dollar3)
  YYObj_Array_TypeParameter_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 356|    non_empty_type_parameter_list "," { $1 }

///|
fn yy_action_175(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameter_(_dollar1)
  YYObj_Array_TypeParameter_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 370|    type_application "->" type {
// 371|    Function(type_parameters=[], parameters=[$1], result=$3, loc=span($sloc))
// 372|  }

///|
fn yy_action_176(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      Function(
        type_parameters=[],
        parameters=[_dollar1],
        result=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 369|    type_lambda { $1 }

///|
fn yy_action_177(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 385|    type_application "[" type_list "]" {
// 386|    Apply(callee=$1, arguments=$3, loc=span($sloc))
// 387|  }

///|
fn yy_action_178(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      Apply(
        callee=_dollar1,
        arguments=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 374|    type_application { $1 }

///|
fn yy_action_179(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 373|    function_type { $1 }

///|
fn yy_action_180(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 378|    "type" "[" non_empty_type_parameter_list "]" "=>" type {
// 379|    TypeLambda(parameters=$3, body=$6, loc=span($sloc))
// 380|  }

///|
fn yy_action_181(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameter_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      TypeLambda(
        parameters=_dollar3,
        body=_dollar6,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 384|    type_primary { $1 }

///|
fn yy_action_182(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 402|    qualified_type_name "." IDENT {
// 403|    extend_qualified_type_name($1, $3, span($sloc))
// 404|  }

///|
fn yy_action_183(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      extend_qualified_type_name(
        _dollar1,
        _dollar3,
        span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 391|    qualified_type_name { $1 }

///|
fn yy_action_184(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 399|    IDENT "." IDENT {
// 400|    QualifiedName(module_path={ components: [ $1 ], loc: span($sloc) }, name=$3, loc=span($sloc))
// 401|  }

///|
fn yy_action_185(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Type(
    {
      ()
      QualifiedName(
        module_path={
          components: [_dollar1],
          loc: span((_symbol_start_pos, _end_pos)),
        },
        name=_dollar3,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 392|    IDENT {
// 393|    Name(name=$1, loc=span($sloc))
// 394|  }

///|
fn yy_action_186(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      Name(name=_dollar1, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 408|    "(" type_list ")" "->" type {
// 409|    Function(type_parameters=[], parameters=$2, result=$5, loc=span($sloc))
// 410|  }

///|
fn yy_action_187(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  guard _args[4].0 is YYObj_Type(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Type(
    {
      ()
      Function(
        type_parameters=[],
        parameters=_dollar2,
        result=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 423|    non_empty_type_list "," type { comma_push($1, $3) }

///|
fn yy_action_188(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 418|    non_empty_type_list { $1 }

///|
fn yy_action_189(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 422|    type { [ $1 ] }

///|
fn yy_action_190(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 417|    { [] }

///|
fn yy_action_191(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Type_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 195|    "[" kind_list "]" "->" kind {
// 196|    Function(parameters=$2, result=$5, loc=span($sloc))
// 197|  }

///|
fn yy_action_192(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Kind(
    {
      ()
      Function(
        parameters=_dollar2,
        result=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 192|    IDENT {
// 193|    Type(loc=span($sloc))
// 194|  }

///|
fn yy_action_193(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_Kind(
    {
      ()
      Type(loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 208|    non_empty_kind_list "," kind { comma_push($1, $3) }

///|
fn yy_action_194(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 209|    non_empty_kind_list "," { $1 }

///|
fn yy_action_195(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 203|    non_empty_kind_list { $1 }

///|
fn yy_action_196(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 207|    kind { [ $1 ] }

///|
fn yy_action_197(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 202|    { [] }

///|
fn yy_action_198(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Kind_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 198|    "(" kind ")" { $2 }

///|
fn yy_action_199(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Kind(_dollar2)
  YYObj_Kind(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 363|    IDENT ":" kind {
// 364|    { name: $1, kind: Some($3), loc: span($sloc) }
// 365|  }

///|
fn yy_action_200(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_TypeParameter(
    {
      ()
      {
        name: _dollar1,
        kind: Some(_dollar3),
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 360|    IDENT {
// 361|    { name: $1, kind: None, loc: span($sloc) }
// 362|  }

///|
fn yy_action_201(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_TypeParameter(
    {
      ()
      { name: _dollar1, kind: None, loc: span((_symbol_start_pos, _end_pos)) }
    },
  )
}

// file:///./parser.mbty
// 97|    import_declarations import_declaration { comma_push($1, $2) }

///|
fn yy_action_202(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_ImportDeclaration(_dollar2)
  YYObj_Array_ImportDeclaration_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 104|    "import" module_path ".*" {
// 105|    Open(module_path=$2, loc=span($sloc))
// 106|  }

///|
fn yy_action_203(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_ImportDeclaration(
    {
      ()
      Open(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 107|    "import" module_path ".{" import_item_list "}" {
// 108|    Selective(module_path=$2, items=$4, loc=span($sloc))
// 109|  }

///|
fn yy_action_204(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  guard _args[3].0 is YYObj_Array_ImportItem_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_ImportDeclaration(
    {
      ()
      Selective(
        module_path=_dollar2,
        items=_dollar4,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 119|    non_empty_import_item_list "," import_item { comma_push($1, $3) }

///|
fn yy_action_205(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  guard _args[2].0 is YYObj_ImportItem(_dollar3)
  YYObj_Array_ImportItem_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 120|    non_empty_import_item_list "," { $1 }

///|
fn yy_action_206(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 114|    non_empty_import_item_list { $1 }

///|
fn yy_action_207(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportItem_(_dollar1)
  YYObj_Array_ImportItem_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 118|    import_item { [ $1 ] }

///|
fn yy_action_208(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ImportItem(_dollar1)
  YYObj_Array_ImportItem_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 124|    IDENT { { name: $1, loc: span($sloc) } }

///|
fn yy_action_209(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_ImportItem(
    {
      ()
      { name: _dollar1, loc: span((_symbol_start_pos, _end_pos)) }
    },
  )
}

// file:///./parser.mbty
// 113|    { [] }

///|
fn yy_action_210(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_ImportItem_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 101|    "import" module_path {
// 102|    Qualified(module_path=$2, loc=span($sloc))
// 103|  }

///|
fn yy_action_211(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_ImportDeclaration(
    {
      ()
      Qualified(module_path=_dollar2, loc=span((_symbol_start_pos, _end_pos)))
    },
  )
}

// file:///./parser.mbty
// 128|    { [] }

///|
fn yy_action_212(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_TopLevelDeclaration_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 96|    { [] }

///|
fn yy_action_213(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_ImportDeclaration_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 83|    "module" module_path { $2 }

///|
fn yy_action_214(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ModulePath(_dollar2)
  YYObj_ModulePath(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 92|    non_empty_module_path "." IDENT { comma_push($1, $3) }

///|
fn yy_action_215(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 87|    non_empty_module_path { { components: $1, loc: span($sloc) } }

///|
fn yy_action_216(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_ModulePath(
    {
      ()
      { components: _dollar1, loc: span((_symbol_start_pos, _end_pos)) }
    },
  )
}

// file:///./parser.mbty
// 91|    IDENT { [ $1 ] }

///|
fn yy_action_217(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_(
    {
      ()
      [_dollar1]
    },
  )
}

///|
fn yy_input(
  token : Token,
  _start_pos : SourceSpan,
  _end_pos : SourceSpan,
) -> (YYSymbol, YYObj) {
  match token {
    INT(data) => (T_INT, YYObj_String(data))
    STRING(data) => (T_STRING, YYObj_String(data))
    IDENT(data) => (T_IDENT, YYObj_String(data))
    RESERVED(data) => (T_RESERVED, YYObj_String(data))
    EOF => (T_EOF, YYObj_Void)
    FALSE => (T_FALSE, YYObj_Void)
    TRUE => (T_TRUE, YYObj_Void)
    STRUCT => (T_STRUCT, YYObj_Void)
    ENUM => (T_ENUM, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    OFFER => (T_OFFER, YYObj_Void)
    AUTO => (T_AUTO, YYObj_Void)
    IF => (T_IF, YYObj_Void)
    ELSE => (T_ELSE, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
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

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_file => Shift(yy_state_1)
    T_MODULE => Shift(yy_state_2)
    NT_module_declaration => Shift(yy_state_8)
    _ => Error
  }
}

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_7)
    _ => Error
  }
}

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_module_path, yy_action_217)
}

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_5)
    T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IMPORT
    | T_PUB
    | T_DOTSTAR
    | T_DOTLBRACE => Reduce(1, NT_module_path, yy_action_216)
    _ => Error
  }
}

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_6)
    _ => Error
  }
}

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_module_path, yy_action_215)
}

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_declaration, yy_action_214)
}

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_declarations => Shift(yy_state_9)
    T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IMPORT
    | T_PUB => Reduce(0, NT_import_declarations, yy_action_213)
    _ => Error
  }
}

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IMPORT => Shift(yy_state_10)
    NT_import_declaration => Shift(yy_state_21)
    NT_top_level_declarations => Shift(yy_state_22)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB =>
      Reduce(0, NT_top_level_declarations, yy_action_212)
    _ => Error
  }
}

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    NT_non_empty_module_path => Shift(yy_state_4)
    NT_module_path => Shift(yy_state_11)
    _ => Error
  }
}

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOTLBRACE => Shift(yy_state_12)
    T_DOTSTAR => Shift(yy_state_20)
    T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IMPORT
    | T_PUB => Reduce(2, NT_import_declaration, yy_action_211)
    _ => Error
  }
}

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_13)
    NT_import_item => Shift(yy_state_14)
    NT_non_empty_import_item_list => Shift(yy_state_15)
    NT_import_item_list => Shift(yy_state_18)
    T_RBRACE => Reduce(0, NT_import_item_list, yy_action_210)
    _ => Error
  }
}

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_item, yy_action_209)
}

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_import_item_list, yy_action_208)
}

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_16)
    T_RBRACE => Reduce(1, NT_import_item_list, yy_action_207)
    _ => Error
  }
}

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_13)
    NT_import_item => Shift(yy_state_17)
    T_RBRACE | T_COMMA =>
      Reduce(2, NT_non_empty_import_item_list, yy_action_206)
    _ => Error
  }
}

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_import_item_list, yy_action_205)
}

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_19)
    _ => Error
  }
}

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_declaration, yy_action_204)
}

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_declaration, yy_action_203)
}

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_import_declarations, yy_action_202)
}

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_23)
    T_LET => Shift(yy_state_308)
    T_FN => Shift(yy_state_314)
    T_ENUM => Shift(yy_state_316)
    T_STRUCT => Shift(yy_state_331)
    T_TYPE => Shift(yy_state_349)
    T_PUB => Shift(yy_state_354)
    NT_offer_value_declaration => Shift(yy_state_398)
    NT_top_level_let_declaration => Shift(yy_state_399)
    NT_function_declaration => Shift(yy_state_400)
    NT_type_alias_declaration => Shift(yy_state_401)
    NT_enum_declaration => Shift(yy_state_402)
    NT_struct_declaration => Shift(yy_state_403)
    NT_top_level_declaration => Shift(yy_state_404)
    T_EOF => Shift(yy_state_405)
    _ => Error
  }
}

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_24)
    _ => Error
  }
}

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_25)
    _ => Error
  }
}

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_85)
    _ => Error
  }
}

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_27)
    NT_non_empty_type_parameter_list => Shift(yy_state_43)
    NT_type_parameter => Shift(yy_state_78)
    _ => Error
  }
}

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_28)
    T_RBRACKET | T_COMMA => Reduce(1, NT_type_parameter, yy_action_201)
    _ => Error
  }
}

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_kind => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_30)
    T_LBRACKET => Shift(yy_state_33)
    T_IDENT => Shift(yy_state_38)
    _ => Error
  }
}

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter, yy_action_200)
}

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    NT_kind => Shift(yy_state_31)
    T_LBRACKET => Shift(yy_state_33)
    T_IDENT => Shift(yy_state_38)
    _ => Error
  }
}

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_32)
    _ => Error
  }
}

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind, yy_action_199)
}

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    T_LBRACKET => Shift(yy_state_33)
    NT_kind => Shift(yy_state_34)
    NT_non_empty_kind_list => Shift(yy_state_35)
    T_IDENT => Shift(yy_state_38)
    NT_kind_list => Shift(yy_state_39)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_198)
    _ => Error
  }
}

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_197)
}

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_36)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_196)
    _ => Error
  }
}

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    T_LBRACKET => Shift(yy_state_33)
    NT_kind => Shift(yy_state_37)
    T_IDENT => Shift(yy_state_38)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_kind_list, yy_action_195)
    _ => Error
  }
}

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_194)
}

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_193)
}

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_40)
    _ => Error
  }
}

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_41)
    _ => Error
  }
}

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    T_LBRACKET => Shift(yy_state_33)
    T_IDENT => Shift(yy_state_38)
    NT_kind => Shift(yy_state_42)
    _ => Error
  }
}

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_192)
}

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_44)
    T_COMMA => Shift(yy_state_76)
    _ => Error
  }
}

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_45)
    _ => Error
  }
}

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    NT_non_empty_type_list => Shift(yy_state_47)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type_list => Shift(yy_state_81)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_191)
    _ => Error
  }
}

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_190)
}

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_48)
    T_RPAREN | T_RBRACKET => Reduce(1, NT_type_list, yy_action_189)
    _ => Error
  }
}

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_49)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    _ => Error
  }
}

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_188)
}

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_non_empty_type_list => Shift(yy_state_47)
    T_LPAREN => Shift(yy_state_50)
    NT_type_list => Shift(yy_state_51)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_79)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_191)
    _ => Error
  }
}

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_52)
    _ => Error
  }
}

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_53)
    _ => Error
  }
}

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    NT_type => Shift(yy_state_54)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    _ => Error
  }
}

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_type, yy_action_187)
}

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_56)
    T_IDENT
    | T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_PUB
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_RBRACKET
    | T_COMMA
    | T_THIN_ARROW
    | T_EQUAL => Reduce(1, NT_type_primary, yy_action_186)
    _ => Error
  }
}

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_57)
    _ => Error
  }
}

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_185)
}

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_59)
    T_IDENT
    | T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_PUB
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_RBRACKET
    | T_COMMA
    | T_THIN_ARROW
    | T_EQUAL => Reduce(1, NT_type_primary, yy_action_184)
    _ => Error
  }
}

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_60)
    _ => Error
  }
}

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_qualified_type_name, yy_action_183)
}

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_application, yy_action_182)
}

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_63)
    _ => Error
  }
}

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_27)
    NT_non_empty_type_parameter_list => Shift(yy_state_64)
    NT_type_parameter => Shift(yy_state_78)
    _ => Error
  }
}

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_65)
    T_COMMA => Shift(yy_state_76)
    _ => Error
  }
}

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_66)
    _ => Error
  }
}

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_type => Shift(yy_state_67)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    _ => Error
  }
}

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type_lambda, yy_action_181)
}

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_180)
}

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_70)
    T_THIN_ARROW => Shift(yy_state_74)
    T_IDENT
    | T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_PUB
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_RBRACKET
    | T_COMMA
    | T_EQUAL => Reduce(1, NT_type, yy_action_179)
    _ => Error
  }
}

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    NT_non_empty_type_list => Shift(yy_state_47)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_list => Shift(yy_state_71)
    NT_type_lambda => Shift(yy_state_73)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_191)
    _ => Error
  }
}

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_72)
    _ => Error
  }
}

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_178)
}

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_177)
}

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_75)
    _ => Error
  }
}

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type, yy_action_176)
}

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_27)
    NT_type_parameter => Shift(yy_state_77)
    T_RBRACKET | T_COMMA =>
      Reduce(2, NT_non_empty_type_parameter_list, yy_action_175)
    _ => Error
  }
}

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_list, yy_action_174)
}

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_list, yy_action_173)
}

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_80)
    T_COMMA => Reduce(1, NT_non_empty_type_list, yy_action_190)
    _ => Error
  }
}

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_primary, yy_action_172)
}

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_82)
    _ => Error
  }
}

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_83)
    _ => Error
  }
}

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_84)
    _ => Error
  }
}

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_171)
}

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_86)
    _ => Error
  }
}

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_307)
    _ => Error
  }
}

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_88)
    _ => Error
  }
}

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_89)
    _ => Error
  }
}

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_90)
    _ => Error
  }
}

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_builtin_expression, yy_action_170)
}

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameters => Shift(yy_state_92)
    T_LBRACKET => Shift(yy_state_283)
    T_LPAREN => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_93)
    _ => Error
  }
}

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_94)
    NT_function_literal_parameter_modifiers => Shift(yy_state_95)
    NT_function_literal_parameter => Shift(yy_state_100)
    NT_non_empty_function_literal_parameters => Shift(yy_state_101)
    NT_function_literal_parameters => Shift(yy_state_104)
    T_RPAREN => Reduce(0, NT_function_literal_parameters, yy_action_167)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_168)
    _ => Error
  }
}

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_literal_parameter_modifiers, yy_action_166)
}

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_96)
    _ => Error
  }
}

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_type_annotation => Shift(yy_state_97)
    T_COLON => Shift(yy_state_98)
    T_RPAREN | T_COMMA => Reduce(0, NT_local_type_annotation, yy_action_165)
    _ => Error
  }
}

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_parameter, yy_action_164)
}

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_99)
    _ => Error
  }
}

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_type_annotation, yy_action_163)
}

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_function_literal_parameters, yy_action_162)
}

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_102)
    T_RPAREN => Reduce(1, NT_function_literal_parameters, yy_action_161)
    _ => Error
  }
}

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_94)
    NT_function_literal_parameter_modifiers => Shift(yy_state_95)
    NT_function_literal_parameter => Shift(yy_state_103)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_168)
    _ => Error
  }
}

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_function_literal_parameters, yy_action_160)
}

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_105)
    _ => Error
  }
}

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_106)
    NT_return_type_annotation => Shift(yy_state_108)
    T_LBRACE => Reduce(0, NT_return_type_annotation, yy_action_159)
    _ => Error
  }
}

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_107)
    _ => Error
  }
}

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_return_type_annotation, yy_action_158)
}

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block_expression => Shift(yy_state_109)
    T_LBRACE => Shift(yy_state_110)
    _ => Error
  }
}

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_literal, yy_action_157)
}

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_items => Shift(yy_state_111)
    T_INT
    | T_STRING
    | T_IDENT
    | T_FALSE
    | T_TRUE
    | T_FN
    | T_LET
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_MINUS
    | T_BANG
    | T_LPAREN
    | T_LBRACE => Reduce(0, NT_local_items, yy_action_156)
    _ => Error
  }
}

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_23)
    T_BUILTIN => Shift(yy_state_87)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_offer_value_declaration => Shift(yy_state_265)
    NT_function_declaration => Shift(yy_state_266)
    NT_local_pattern_let_declaration => Shift(yy_state_267)
    NT_local_let_declaration => Shift(yy_state_268)
    NT_local_item => Shift(yy_state_269)
    NT_expression => Shift(yy_state_270)
    T_LET => Shift(yy_state_272)
    T_FN => Shift(yy_state_282)
    _ => Error
  }
}

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_215)
    _ => Error
  }
}

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_209)
    _ => Error
  }
}

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_155)
}

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_154)
}

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_153)
}

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_152)
}

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_151)
}

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_RPAREN => Shift(yy_state_120)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_207)
    _ => Error
  }
}

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_primary_expression, yy_action_150)
}

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_149)
}

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_148)
}

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_147)
}

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_146)
}

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_145)
}

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_144)
}

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_206)
    _ => Error
  }
}

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_129)
    _ => Error
  }
}

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(2, NT_expression, yy_action_143)
    _ => Error
  }
}

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    NT_non_empty_type_list => Shift(yy_state_47)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type_list => Shift(yy_state_131)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_191)
    _ => Error
  }
}

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_132)
    _ => Error
  }
}

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_133)
    _ => Error
  }
}

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_LBRACE => Shift(yy_state_203)
    _ => Error
  }
}

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_135)
    NT_variant_type_arguments => Shift(yy_state_138)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_LPAREN
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_DOT
    | T_COLONCOLON
    | T_TIGHT_COLONCOLON
    | T_UNDERSCORE => Reduce(0, NT_variant_type_arguments, yy_action_142)
    _ => Error
  }
}

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    NT_non_empty_type_list => Shift(yy_state_47)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type_list => Shift(yy_state_136)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_191)
    _ => Error
  }
}

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_137)
    _ => Error
  }
}

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_arguments, yy_action_141)
}

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_139)
    NT_variant_arguments => Shift(yy_state_202)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_DOT
    | T_COLONCOLON
    | T_TIGHT_COLONCOLON
    | T_UNDERSCORE => Reduce(0, NT_variant_arguments, yy_action_140)
    _ => Error
  }
}

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_non_empty_positional_argument_list => Shift(yy_state_140)
    NT_expression => Shift(yy_state_201)
    _ => Error
  }
}

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_141)
    T_RPAREN => Shift(yy_state_200)
    _ => Error
  }
}

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_142)
    T_RPAREN | T_COMMA =>
      Reduce(2, NT_non_empty_positional_argument_list, yy_action_139)
    _ => Error
  }
}

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RPAREN | T_COMMA =>
      Reduce(3, NT_non_empty_positional_argument_list, yy_action_138)
    _ => Error
  }
}

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_144)
    T_LBRACE => Shift(yy_state_147)
    _ => Error
  }
}

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_135)
    NT_variant_type_arguments => Shift(yy_state_145)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_LPAREN
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_DOT
    | T_COLONCOLON
    | T_TIGHT_COLONCOLON
    | T_UNDERSCORE => Reduce(0, NT_variant_type_arguments, yy_action_142)
    _ => Error
  }
}

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_139)
    NT_variant_arguments => Shift(yy_state_146)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_DOT
    | T_COLONCOLON
    | T_TIGHT_COLONCOLON
    | T_UNDERSCORE => Reduce(0, NT_variant_arguments, yy_action_140)
    _ => Error
  }
}

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_expression, yy_action_137)
}

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_148)
    NT_struct_literal_field => Shift(yy_state_194)
    NT_non_empty_struct_literal_fields => Shift(yy_state_195)
    NT_struct_literal_fields => Shift(yy_state_198)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_136)
    _ => Error
  }
}

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_149)
    T_COLON => Shift(yy_state_151)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_literal_field, yy_action_135)
    _ => Error
  }
}

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_150)
    _ => Error
  }
}

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_literal_field, yy_action_134)
}

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_152)
    _ => Error
  }
}

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RBRACE | T_COMMA => Reduce(3, NT_struct_literal_field, yy_action_133)
    _ => Error
  }
}

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_154)
    _ => Error
  }
}

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_132)
}

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_call_argument => Shift(yy_state_156)
    NT_non_empty_argument_list => Shift(yy_state_157)
    T_IDENT => Shift(yy_state_160)
    NT_expression => Shift(yy_state_191)
    NT_argument_list => Shift(yy_state_192)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_131)
    _ => Error
  }
}

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_argument_list, yy_action_130)
}

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_158)
    T_RPAREN => Reduce(1, NT_argument_list, yy_action_129)
    _ => Error
  }
}

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_call_argument => Shift(yy_state_159)
    T_IDENT => Shift(yy_state_160)
    NT_expression => Shift(yy_state_191)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_argument_list, yy_action_128)
    _ => Error
  }
}

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_argument_list, yy_action_127)
}

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_161)
    T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_PIPE
    | T_LPAREN
    | T_RPAREN
    | T_LBRACKET
    | T_COMMA
    | T_DOT
    | T_TIGHT_COLONCOLON => Reduce(1, NT_primary_expression, yy_action_149)
    _ => Error
  }
}

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_162)
    _ => Error
  }
}

///|
fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RPAREN | T_COMMA => Reduce(3, NT_call_argument, yy_action_126)
    _ => Error
  }
}

///|
fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_164)
    _ => Error
  }
}

///|
fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_125)
    _ => Error
  }
}

///|
fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_166)
    _ => Error
  }
}

///|
fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_124)
    _ => Error
  }
}

///|
fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_168)
    _ => Error
  }
}

///|
fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_123)
    _ => Error
  }
}

///|
fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_170)
    _ => Error
  }
}

///|
fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_122)
    _ => Error
  }
}

///|
fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_172)
    _ => Error
  }
}

///|
fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_121)
    _ => Error
  }
}

///|
fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_174)
    _ => Error
  }
}

///|
fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_120)
    _ => Error
  }
}

///|
fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_176)
    _ => Error
  }
}

///|
fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_119)
    _ => Error
  }
}

///|
fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_178)
    _ => Error
  }
}

///|
fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_118)
    _ => Error
  }
}

///|
fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_180)
    _ => Error
  }
}

///|
fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_117)
    _ => Error
  }
}

///|
fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_182)
    _ => Error
  }
}

///|
fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_116)
    _ => Error
  }
}

///|
fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_184)
    _ => Error
  }
}

///|
fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_EQEQ
    | T_BANGEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_115)
    _ => Error
  }
}

///|
fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_186)
    _ => Error
  }
}

///|
fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_114)
    _ => Error
  }
}

///|
fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_188)
    _ => Error
  }
}

///|
fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_113)
    _ => Error
  }
}

///|
fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_190)
    _ => Error
  }
}

///|
fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_112)
    _ => Error
  }
}

///|
fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RPAREN | T_COMMA => Reduce(1, NT_call_argument, yy_action_111)
    _ => Error
  }
}

///|
fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_193)
    _ => Error
  }
}

///|
fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_expression, yy_action_110)
}

///|
fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_literal_fields, yy_action_109)
}

///|
fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_196)
    T_RBRACE => Reduce(1, NT_struct_literal_fields, yy_action_108)
    _ => Error
  }
}

///|
fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_148)
    NT_struct_literal_field => Shift(yy_state_197)
    T_RBRACE | T_COMMA =>
      Reduce(2, NT_non_empty_struct_literal_fields, yy_action_107)
    _ => Error
  }
}

///|
fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_literal_fields, yy_action_106)
}

///|
fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_199)
    _ => Error
  }
}

///|
fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_expression, yy_action_105)
}

///|
fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_arguments, yy_action_104)
}

///|
fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RPAREN | T_COMMA =>
      Reduce(1, NT_non_empty_positional_argument_list, yy_action_103)
    _ => Error
  }
}

///|
fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expression, yy_action_102)
}

///|
fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_148)
    NT_struct_literal_field => Shift(yy_state_194)
    NT_non_empty_struct_literal_fields => Shift(yy_state_195)
    NT_struct_literal_fields => Shift(yy_state_204)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_136)
    _ => Error
  }
}

///|
fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_205)
    _ => Error
  }
}

///|
fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expression, yy_action_101)
}

///|
fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_PLUS
    | T_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_EQEQ
    | T_BANGEQ
    | T_LT
    | T_LTEQ
    | T_GT
    | T_GTEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_LBRACKET
    | T_COMMA
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(2, NT_expression, yy_action_100)
    _ => Error
  }
}

///|
fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RPAREN => Shift(yy_state_208)
    _ => Error
  }
}

///|
fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_primary_expression, yy_action_99)
}

///|
fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_110)
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    NT_block_expression => Shift(yy_state_210)
    _ => Error
  }
}

///|
fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_211)
    _ => Error
  }
}

///|
fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_110)
    T_IF => Shift(yy_state_113)
    NT_if_expression => Shift(yy_state_212)
    NT_block_expression => Shift(yy_state_213)
    NT_else_branch_expression => Shift(yy_state_214)
    _ => Error
  }
}

///|
fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_98)
}

///|
fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_else_branch_expression, yy_action_97)
}

///|
fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_if_expression, yy_action_96)
}

///|
fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_LBRACE => Shift(yy_state_216)
    _ => Error
  }
}

///|
fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_match_arms => Shift(yy_state_217)
    T_INT
    | T_STRING
    | T_IDENT
    | T_FALSE
    | T_TRUE
    | T_RBRACE
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(0, NT_match_arms, yy_action_95)
    _ => Error
  }
}

///|
fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_218)
    T_COLONCOLON => Shift(yy_state_225)
    NT_struct_pattern => Shift(yy_state_239)
    T_FALSE => Shift(yy_state_240)
    T_TRUE => Shift(yy_state_241)
    T_STRING => Shift(yy_state_242)
    T_INT => Shift(yy_state_243)
    T_UNDERSCORE => Shift(yy_state_244)
    NT_qualified_type_name => Shift(yy_state_245)
    T_IDENT => Shift(yy_state_246)
    NT_pattern => Shift(yy_state_260)
    NT_match_arm => Shift(yy_state_263)
    T_RBRACE => Shift(yy_state_264)
    _ => Error
  }
}

///|
fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_219)
    _ => Error
  }
}

///|
fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_220)
    T_IDENT => Shift(yy_state_255)
    _ => Error
  }
}

///|
fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_221)
    T_IDENT => Shift(yy_state_222)
    NT_struct_pattern_field => Shift(yy_state_249)
    NT_non_empty_struct_pattern_fields => Shift(yy_state_250)
    NT_struct_pattern_fields => Shift(yy_state_253)
    T_RBRACE => Reduce(0, NT_struct_pattern_fields, yy_action_94)
    _ => Error
  }
}

///|
fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_pattern_field, yy_action_93)
}

///|
fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_223)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_pattern_field, yy_action_92)
    _ => Error
  }
}

///|
fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_218)
    NT_pattern => Shift(yy_state_224)
    T_COLONCOLON => Shift(yy_state_225)
    NT_struct_pattern => Shift(yy_state_239)
    T_FALSE => Shift(yy_state_240)
    T_TRUE => Shift(yy_state_241)
    T_STRING => Shift(yy_state_242)
    T_INT => Shift(yy_state_243)
    T_UNDERSCORE => Shift(yy_state_244)
    NT_qualified_type_name => Shift(yy_state_245)
    T_IDENT => Shift(yy_state_246)
    _ => Error
  }
}

///|
fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_pattern_field, yy_action_91)
}

///|
fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_226)
    _ => Error
  }
}

///|
fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_227)
    NT_variant_type_binders => Shift(yy_state_233)
    T_LPAREN | T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(0, NT_variant_type_binders, yy_action_90)
    _ => Error
  }
}

///|
fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_228)
    NT_non_empty_ident_list => Shift(yy_state_229)
    _ => Error
  }
}

///|
fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_ident_list, yy_action_89)
}

///|
fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_230)
    T_RBRACKET => Shift(yy_state_232)
    _ => Error
  }
}

///|
fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_231)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_ident_list, yy_action_88)
    _ => Error
  }
}

///|
fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_ident_list, yy_action_87)
}

///|
fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_binders, yy_action_86)
}

///|
fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_234)
    T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(3, NT_pattern, yy_action_85)
    _ => Error
  }
}

///|
fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_218)
    T_COLONCOLON => Shift(yy_state_225)
    NT_pattern => Shift(yy_state_235)
    NT_non_empty_pattern_list => Shift(yy_state_236)
    NT_struct_pattern => Shift(yy_state_239)
    T_FALSE => Shift(yy_state_240)
    T_TRUE => Shift(yy_state_241)
    T_STRING => Shift(yy_state_242)
    T_INT => Shift(yy_state_243)
    T_UNDERSCORE => Shift(yy_state_244)
    NT_qualified_type_name => Shift(yy_state_245)
    T_IDENT => Shift(yy_state_246)
    NT_pattern_list => Shift(yy_state_247)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_84)
    _ => Error
  }
}

///|
fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_pattern_list, yy_action_83)
}

///|
fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_237)
    T_RPAREN => Reduce(1, NT_pattern_list, yy_action_82)
    _ => Error
  }
}

///|
fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_218)
    T_COLONCOLON => Shift(yy_state_225)
    NT_pattern => Shift(yy_state_238)
    NT_struct_pattern => Shift(yy_state_239)
    T_FALSE => Shift(yy_state_240)
    T_TRUE => Shift(yy_state_241)
    T_STRING => Shift(yy_state_242)
    T_INT => Shift(yy_state_243)
    T_UNDERSCORE => Shift(yy_state_244)
    NT_qualified_type_name => Shift(yy_state_245)
    T_IDENT => Shift(yy_state_246)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_pattern_list, yy_action_81)
    _ => Error
  }
}

///|
fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_pattern_list, yy_action_80)
}

///|
fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_79)
}

///|
fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_78)
}

///|
fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_77)
}

///|
fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_76)
}

///|
fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_75)
}

///|
fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_74)
}

///|
fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_59)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_73)
    _ => Error
  }
}

///|
fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_56)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_71)
    T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(1, NT_pattern, yy_action_72)
    _ => Error
  }
}

///|
fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_248)
    _ => Error
  }
}

///|
fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_pattern, yy_action_70)
}

///|
fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_pattern_fields, yy_action_69)
}

///|
fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_251)
    T_RBRACE => Reduce(1, NT_struct_pattern_fields, yy_action_68)
    _ => Error
  }
}

///|
fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_221)
    T_IDENT => Shift(yy_state_222)
    NT_struct_pattern_field => Shift(yy_state_252)
    T_RBRACE | T_COMMA =>
      Reduce(2, NT_non_empty_struct_pattern_fields, yy_action_67)
    _ => Error
  }
}

///|
fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_pattern_fields, yy_action_66)
}

///|
fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_254)
    _ => Error
  }
}

///|
fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_pattern, yy_action_65)
}

///|
fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_227)
    NT_variant_type_binders => Shift(yy_state_256)
    T_LPAREN | T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(0, NT_variant_type_binders, yy_action_90)
    _ => Error
  }
}

///|
fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_257)
    T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(4, NT_pattern, yy_action_64)
    _ => Error
  }
}

///|
fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_nominal_type_name => Shift(yy_state_218)
    T_COLONCOLON => Shift(yy_state_225)
    NT_pattern => Shift(yy_state_235)
    NT_non_empty_pattern_list => Shift(yy_state_236)
    NT_struct_pattern => Shift(yy_state_239)
    T_FALSE => Shift(yy_state_240)
    T_TRUE => Shift(yy_state_241)
    T_STRING => Shift(yy_state_242)
    T_INT => Shift(yy_state_243)
    T_UNDERSCORE => Shift(yy_state_244)
    NT_qualified_type_name => Shift(yy_state_245)
    T_IDENT => Shift(yy_state_246)
    NT_pattern_list => Shift(yy_state_258)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_84)
    _ => Error
  }
}

///|
fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_259)
    _ => Error
  }
}

///|
fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_pattern, yy_action_63)
}

///|
fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_261)
    _ => Error
  }
}

///|
fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_262)
    _ => Error
  }
}

///|
fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_INT
    | T_STRING
    | T_IDENT
    | T_FALSE
    | T_TRUE
    | T_RBRACE
    | T_COLONCOLON
    | T_UNDERSCORE => Reduce(3, NT_match_arm, yy_action_62)
    _ => Error
  }
}

///|
fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_match_arms, yy_action_61)
}

///|
fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_match_expression, yy_action_60)
}

///|
fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_59)
}

///|
fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_58)
}

///|
fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_57)
}

///|
fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_56)
}

///|
fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_items, yy_action_55)
}

///|
fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_RBRACE => Shift(yy_state_271)
    _ => Error
  }
}

///|
fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block_expression, yy_action_54)
}

///|
fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_qualified_type_name => Shift(yy_state_245)
    NT_nominal_type_name => Shift(yy_state_273)
    NT_struct_pattern => Shift(yy_state_275)
    T_IDENT => Shift(yy_state_278)
    _ => Error
  }
}

///|
fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TIGHT_COLONCOLON => Shift(yy_state_274)
    _ => Error
  }
}

///|
fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_220)
    _ => Error
  }
}

///|
fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_276)
    _ => Error
  }
}

///|
fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_277)
    _ => Error
  }
}

///|
fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_INT
    | T_STRING
    | T_IDENT
    | T_FALSE
    | T_TRUE
    | T_FN
    | T_LET
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_BANG
    | T_LBRACE => Reduce(4, NT_local_pattern_let_declaration, yy_action_53)
    _ => Error
  }
}

///|
fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_56)
    T_COLON => Shift(yy_state_98)
    NT_local_type_annotation => Shift(yy_state_279)
    T_EQUAL => Reduce(0, NT_local_type_annotation, yy_action_165)
    T_TIGHT_COLONCOLON => Reduce(1, NT_nominal_type_name, yy_action_71)
    _ => Error
  }
}

///|
fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_280)
    _ => Error
  }
}

///|
fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_281)
    _ => Error
  }
}

///|
fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_INT
    | T_STRING
    | T_IDENT
    | T_FALSE
    | T_TRUE
    | T_FN
    | T_LET
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_BANG
    | T_LBRACE => Reduce(5, NT_local_let_declaration, yy_action_52)
    _ => Error
  }
}

///|
fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_286)
    T_IDENT | T_LPAREN => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_27)
    NT_type_parameter => Shift(yy_state_78)
    NT_non_empty_type_parameter_list => Shift(yy_state_284)
    _ => Error
  }
}

///|
fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_76)
    T_RBRACKET => Shift(yy_state_285)
    _ => Error
  }
}

///|
fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameters, yy_action_51)
}

///|
fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_93)
    T_IDENT => Shift(yy_state_287)
    _ => Error
  }
}

///|
fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_288)
    NT_parameters => Shift(yy_state_303)
    _ => Error
  }
}

///|
fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_289)
    T_AUTO => Shift(yy_state_291)
    NT_parameter_modifiers => Shift(yy_state_293)
    NT_parameter => Shift(yy_state_297)
    NT_non_empty_parameter_list => Shift(yy_state_298)
    T_RPAREN => Shift(yy_state_302)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_50)
    _ => Error
  }
}

///|
fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AUTO => Shift(yy_state_290)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_49)
    _ => Error
  }
}

///|
fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_48)
}

///|
fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_292)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_47)
    _ => Error
  }
}

///|
fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_46)
}

///|
fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_294)
    _ => Error
  }
}

///|
fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_295)
    _ => Error
  }
}

///|
fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_296)
    _ => Error
  }
}

///|
fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameter, yy_action_45)
}

///|
fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_parameter_list, yy_action_44)
}

///|
fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_299)
    T_RPAREN => Shift(yy_state_301)
    _ => Error
  }
}

///|
fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_289)
    T_AUTO => Shift(yy_state_291)
    NT_parameter_modifiers => Shift(yy_state_293)
    NT_parameter => Shift(yy_state_300)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_50)
    _ => Error
  }
}

///|
fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_parameter_list, yy_action_43)
}

///|
fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parameters, yy_action_42)
}

///|
fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameters, yy_action_41)
}

///|
fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_304)
    _ => Error
  }
}

///|
fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_305)
    _ => Error
  }
}

///|
fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_110)
    NT_block_expression => Shift(yy_state_306)
    _ => Error
  }
}

///|
fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_declaration, yy_action_40)
}

///|
fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_INT
    | T_STRING
    | T_IDENT
    | T_EOF
    | T_FALSE
    | T_TRUE
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_IF
    | T_MATCH
    | T_BUILTIN
    | T_PUB
    | T_BANG
    | T_LBRACE => Reduce(6, NT_offer_value_declaration, yy_action_39)
    _ => Error
  }
}

///|
fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_309)
    _ => Error
  }
}

///|
fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_310)
    _ => Error
  }
}

///|
fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_311)
    _ => Error
  }
}

///|
fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_312)
    _ => Error
  }
}

///|
fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_313)
    _ => Error
  }
}

///|
fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB =>
      Reduce(6, NT_top_level_let_declaration, yy_action_38)
    _ => Error
  }
}

///|
fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_315)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_287)
    _ => Error
  }
}

///|
fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_317)
    _ => Error
  }
}

///|
fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_318)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_319)
    _ => Error
  }
}

///|
fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_enum_variants => Shift(yy_state_320)
    T_IDENT | T_RBRACE => Reduce(0, NT_enum_variants, yy_action_37)
    _ => Error
  }
}

///|
fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_321)
    NT_enum_variant => Shift(yy_state_329)
    T_RBRACE => Shift(yy_state_330)
    _ => Error
  }
}

///|
fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    T_LPAREN => Shift(yy_state_322)
    NT_type_parameters => Shift(yy_state_325)
    T_IDENT | T_RBRACE => Reduce(1, NT_enum_variant, yy_action_36)
    _ => Error
  }
}

///|
fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_non_empty_type_list => Shift(yy_state_323)
    _ => Error
  }
}

///|
fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_48)
    T_RPAREN => Shift(yy_state_324)
    _ => Error
  }
}

///|
fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_enum_variant, yy_action_35)
}

///|
fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_326)
    T_IDENT | T_RBRACE => Reduce(2, NT_enum_variant, yy_action_34)
    _ => Error
  }
}

///|
fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    NT_type => Shift(yy_state_46)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_non_empty_type_list => Shift(yy_state_327)
    _ => Error
  }
}

///|
fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_48)
    T_RPAREN => Shift(yy_state_328)
    _ => Error
  }
}

///|
fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_enum_variant, yy_action_33)
}

///|
fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_enum_variants, yy_action_32)
}

///|
fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_enum_declaration, yy_action_31)
}

///|
fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_332)
    _ => Error
  }
}

///|
fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_333)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_334)
    _ => Error
  }
}

///|
fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_335)
    T_IDENT | T_TYPE | T_OFFER | T_RBRACE =>
      Reduce(0, NT_struct_members, yy_action_30)
    _ => Error
  }
}

///|
fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_336)
    NT_field_offer_modifier => Shift(yy_state_337)
    T_TYPE => Shift(yy_state_341)
    NT_field_declaration => Shift(yy_state_345)
    NT_type_member_declaration => Shift(yy_state_346)
    NT_struct_member => Shift(yy_state_347)
    T_RBRACE => Shift(yy_state_348)
    T_IDENT => Reduce(0, NT_field_offer_modifier, yy_action_29)
    _ => Error
  }
}

///|
fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_field_offer_modifier, yy_action_28)
}

///|
fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_338)
    _ => Error
  }
}

///|
fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_339)
    _ => Error
  }
}

///|
fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_340)
    _ => Error
  }
}

///|
fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_field_declaration, yy_action_27)
}

///|
fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_342)
    _ => Error
  }
}

///|
fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_343)
    _ => Error
  }
}

///|
fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    T_LBRACKET => Shift(yy_state_33)
    T_IDENT => Shift(yy_state_38)
    NT_kind => Shift(yy_state_344)
    _ => Error
  }
}

///|
fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_member_declaration, yy_action_26)
}

///|
fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_25)
}

///|
fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_24)
}

///|
fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_struct_members, yy_action_23)
}

///|
fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_struct_declaration, yy_action_22)
}

///|
fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_350)
    _ => Error
  }
}

///|
fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_351)
    T_EQUAL => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_352)
    _ => Error
  }
}

///|
fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_353)
    _ => Error
  }
}

///|
fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_type_alias_declaration, yy_action_21)
}

///|
fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_355)
    T_LET => Shift(yy_state_361)
    T_FN => Shift(yy_state_367)
    T_ENUM => Shift(yy_state_374)
    T_STRUCT => Shift(yy_state_380)
    T_TYPE => Shift(yy_state_386)
    NT_public_offer_value_declaration => Shift(yy_state_391)
    NT_public_top_level_let_declaration => Shift(yy_state_392)
    NT_public_function_declaration => Shift(yy_state_393)
    NT_public_type_alias_declaration => Shift(yy_state_394)
    NT_public_enum_declaration => Shift(yy_state_395)
    NT_public_struct_declaration => Shift(yy_state_396)
    NT_public_top_level_declaration => Shift(yy_state_397)
    _ => Error
  }
}

///|
fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_356)
    _ => Error
  }
}

///|
fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_357)
    _ => Error
  }
}

///|
fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_358)
    _ => Error
  }
}

///|
fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_359)
    _ => Error
  }
}

///|
fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_360)
    _ => Error
  }
}

///|
fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB =>
      Reduce(6, NT_public_offer_value_declaration, yy_action_20)
    _ => Error
  }
}

///|
fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_362)
    _ => Error
  }
}

///|
fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_363)
    _ => Error
  }
}

///|
fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_364)
    _ => Error
  }
}

///|
fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_365)
    _ => Error
  }
}

///|
fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_87)
    T_FN => Shift(yy_state_91)
    T_LBRACE => Shift(yy_state_110)
    T_MATCH => Shift(yy_state_112)
    T_IF => Shift(yy_state_113)
    NT_builtin_expression => Shift(yy_state_114)
    NT_function_literal => Shift(yy_state_115)
    NT_match_expression => Shift(yy_state_116)
    NT_if_expression => Shift(yy_state_117)
    NT_block_expression => Shift(yy_state_118)
    T_LPAREN => Shift(yy_state_119)
    T_IDENT => Shift(yy_state_121)
    T_FALSE => Shift(yy_state_122)
    T_TRUE => Shift(yy_state_123)
    T_STRING => Shift(yy_state_124)
    T_INT => Shift(yy_state_125)
    NT_primary_expression => Shift(yy_state_126)
    T_BANG => Shift(yy_state_127)
    T_MINUS => Shift(yy_state_128)
    NT_expression => Shift(yy_state_366)
    _ => Error
  }
}

///|
fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_130)
    T_TIGHT_COLONCOLON => Shift(yy_state_143)
    T_DOT => Shift(yy_state_153)
    T_LPAREN => Shift(yy_state_155)
    T_PERCENT => Shift(yy_state_163)
    T_SLASH => Shift(yy_state_165)
    T_STAR => Shift(yy_state_167)
    T_MINUS => Shift(yy_state_169)
    T_PLUS => Shift(yy_state_171)
    T_GTEQ => Shift(yy_state_173)
    T_GT => Shift(yy_state_175)
    T_LTEQ => Shift(yy_state_177)
    T_LT => Shift(yy_state_179)
    T_BANGEQ => Shift(yy_state_181)
    T_EQEQ => Shift(yy_state_183)
    T_AMPAMP => Shift(yy_state_185)
    T_BARBAR => Shift(yy_state_187)
    T_PIPE => Shift(yy_state_189)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER | T_PUB =>
      Reduce(6, NT_public_top_level_let_declaration, yy_action_19)
    _ => Error
  }
}

///|
fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_368)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_369)
    _ => Error
  }
}

///|
fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_288)
    NT_parameters => Shift(yy_state_370)
    _ => Error
  }
}

///|
fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_371)
    _ => Error
  }
}

///|
fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_372)
    _ => Error
  }
}

///|
fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_110)
    NT_block_expression => Shift(yy_state_373)
    _ => Error
  }
}

///|
fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_public_function_declaration, yy_action_18)
}

///|
fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_375)
    _ => Error
  }
}

///|
fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_376)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_377)
    _ => Error
  }
}

///|
fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_enum_variants => Shift(yy_state_378)
    T_IDENT | T_RBRACE => Reduce(0, NT_enum_variants, yy_action_37)
    _ => Error
  }
}

///|
fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_321)
    NT_enum_variant => Shift(yy_state_329)
    T_RBRACE => Shift(yy_state_379)
    _ => Error
  }
}

///|
fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_enum_declaration, yy_action_17)
}

///|
fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_381)
    _ => Error
  }
}

///|
fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_382)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_383)
    _ => Error
  }
}

///|
fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_384)
    T_IDENT | T_TYPE | T_OFFER | T_RBRACE =>
      Reduce(0, NT_struct_members, yy_action_30)
    _ => Error
  }
}

///|
fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_336)
    NT_field_offer_modifier => Shift(yy_state_337)
    T_TYPE => Shift(yy_state_341)
    NT_field_declaration => Shift(yy_state_345)
    NT_type_member_declaration => Shift(yy_state_346)
    NT_struct_member => Shift(yy_state_347)
    T_RBRACE => Shift(yy_state_385)
    T_IDENT => Reduce(0, NT_field_offer_modifier, yy_action_29)
    _ => Error
  }
}

///|
fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_public_struct_declaration, yy_action_16)
}

///|
fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_387)
    _ => Error
  }
}

///|
fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_283)
    NT_type_parameters => Shift(yy_state_388)
    T_EQUAL => Reduce(0, NT_type_parameters, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_389)
    _ => Error
  }
}

///|
fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_50)
    T_IDENT => Shift(yy_state_55)
    NT_qualified_type_name => Shift(yy_state_58)
    NT_type_primary => Shift(yy_state_61)
    T_TYPE => Shift(yy_state_62)
    NT_function_type => Shift(yy_state_68)
    NT_type_application => Shift(yy_state_69)
    NT_type_lambda => Shift(yy_state_73)
    NT_type => Shift(yy_state_390)
    _ => Error
  }
}

///|
fn yy_state_390(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_public_type_alias_declaration, yy_action_15)
}

///|
fn yy_state_391(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_14)
}

///|
fn yy_state_392(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_13)
}

///|
fn yy_state_393(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_12)
}

///|
fn yy_state_394(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_11)
}

///|
fn yy_state_395(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_10)
}

///|
fn yy_state_396(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_public_top_level_declaration, yy_action_9)
}

///|
fn yy_state_397(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declaration, yy_action_8)
}

///|
fn yy_state_398(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_7)
}

///|
fn yy_state_399(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_6)
}

///|
fn yy_state_400(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_5)
}

///|
fn yy_state_401(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_4)
}

///|
fn yy_state_402(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_3)
}

///|
fn yy_state_403(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_2)
}

///|
fn yy_state_404(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declarations, yy_action_1)
}

///|
fn yy_state_405(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_file, yy_action_0)
}

///|
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
  let mut lookahead : (YYSymbol, (YYObj, SourceSpan, SourceSpan), Token?)? = None
  let mut last_shifted_state_stack = state_stack
  while true {
    let decision = match state(EOI) {
      ReduceNoLookahead(_) | Accept as t => t
      _ =>
        match lookahead {
          Some(la) => state(la.0)
          None =>
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (symbol, data) = yy_input(token, start_pos, end_pos)
              lookahead = Some(
                (symbol, (data, start_pos, end_pos), Some(token)),
              )
              state(symbol)
            } else {
              lookahead = Some((EOI, (YYObj_Void, last_pos, last_pos), None))
              state(EOI)
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
      | ReduceNoLookahead(count, symbol, action) =>
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
            | ReduceNoLookahead(count, symbol, action) =>
              continue count, symbol, action
            _ => panic()
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

///|
fn error(
  stack : @list.List[YYState],
  token : Token?,
  loc : (SourceSpan, SourceSpan),
) -> Unit raise ParseError {
  let expected = []
  fn try_add(symbol : YYSymbol, kind : TokenKind) {
    fn go(stack : @list.List[YYState]) {
      match stack {
        Empty => ()
        More(state, ..) =>
          match state(symbol) {
            Accept | Shift(_) => expected.push(kind)
            Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
              fn inner_go(stack : @list.List[YYState], count, symbol) {
                let stack = stack.drop(count)
                guard stack is More(state, ..)
                match state(symbol) {
                  Shift(state) => go(@list.cons(state, stack))
                  Reduce(count, symbol, _)
                  | ReduceNoLookahead(count, symbol, _) =>
                    inner_go(stack, count, symbol)
                  _ => panic()
                }
              }
              inner_go(stack, count, symbol)
            }
            Error => ()
          }
      }
    }
    go(stack)
  }
  for
    term in (
      [
        (T_INT, TK_INT),
        (T_STRING, TK_STRING),
        (T_IDENT, TK_IDENT),
        (T_RESERVED, TK_RESERVED),
        (T_EOF, TK_EOF),
        (T_FALSE, TK_FALSE),
        (T_TRUE, TK_TRUE),
        (T_STRUCT, TK_STRUCT),
        (T_ENUM, TK_ENUM),
        (T_FN, TK_FN),
        (T_LET, TK_LET),
        (T_TYPE, TK_TYPE),
        (T_OFFER, TK_OFFER),
        (T_AUTO, TK_AUTO),
        (T_IF, TK_IF),
        (T_ELSE, TK_ELSE),
        (T_MATCH, TK_MATCH),
        (T_BUILTIN, TK_BUILTIN),
        (T_MODULE, TK_MODULE),
        (T_IMPORT, TK_IMPORT),
        (T_PUB, TK_PUB),
        (T_PLUS, TK_PLUS),
        (T_MINUS, TK_MINUS),
        (T_STAR, TK_STAR),
        (T_SLASH, TK_SLASH),
        (T_PERCENT, TK_PERCENT),
        (T_EQEQ, TK_EQEQ),
        (T_BANGEQ, TK_BANGEQ),
        (T_LT, TK_LT),
        (T_LTEQ, TK_LTEQ),
        (T_GT, TK_GT),
        (T_GTEQ, TK_GTEQ),
        (T_AMPAMP, TK_AMPAMP),
        (T_BARBAR, TK_BARBAR),
        (T_BANG, TK_BANG),
        (T_PIPE, TK_PIPE),
        (T_LPAREN, TK_LPAREN),
        (T_RPAREN, TK_RPAREN),
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_LBRACKET, TK_LBRACKET),
        (T_RBRACKET, TK_RBRACKET),
        (T_COMMA, TK_COMMA),
        (T_DOTSTAR, TK_DOTSTAR),
        (T_DOTLBRACE, TK_DOTLBRACE),
        (T_DOT, TK_DOT),
        (T_COLON, TK_COLON),
        (T_COLONCOLON, TK_COLONCOLON),
        (T_TIGHT_COLONCOLON, TK_TIGHT_COLONCOLON),
        (T_THIN_ARROW, TK_THIN_ARROW),
        (T_FAT_ARROW, TK_FAT_ARROW),
        (T_EQUAL, TK_EQUAL),
        (T_UNDERSCORE, TK_UNDERSCORE),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn source_file(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  initial_pos? : SourceSpan,
) -> SourceFile raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_SourceFile(result)
      result
    },
    initial_pos?,
  )
}

///|
fn _get_symbol_start_pos(
  args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
  last_pos : SourceSpan,
) -> SourceSpan {
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
