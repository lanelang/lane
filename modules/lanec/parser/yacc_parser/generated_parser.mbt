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
  DOT
  COLON
  COLONCOLON
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
    DOT => TK_DOT
    COLON => TK_COLON
    COLONCOLON => TK_COLONCOLON
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
  TK_DOT
  TK_COLON
  TK_COLONCOLON
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
      TK_DOT => "\".\""
      TK_COLON => "\":\""
      TK_COLONCOLON => "\"::\""
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
    TK_DOT => to_repr(".")
    TK_COLON => to_repr(":")
    TK_COLONCOLON => to_repr("::")
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
  T_DOT
  T_COLON
  T_COLONCOLON
  T_THIN_ARROW
  T_FAT_ARROW
  T_EQUAL
  T_UNDERSCORE
  NT_source_file
  NT_top_level_declarations
  NT_top_level_declaration
  NT_type_alias_declaration
  NT_struct_declaration
  NT_struct_members
  NT_struct_member
  NT_type_member_declaration
  NT_kind
  NT_kind_list
  NT_non_empty_kind_list
  NT_field_declaration
  NT_field_offer_modifier
  NT_enum_declaration
  NT_enum_variants
  NT_enum_variant
  NT_function_declaration
  NT_parameters
  NT_non_empty_parameter_list
  NT_parameter
  NT_parameter_modifiers
  NT_top_level_let_declaration
  NT_local_let_declaration
  NT_local_pattern_let_declaration
  NT_local_type_annotation
  NT_offer_value_declaration
  NT_type_parameters
  NT_non_empty_type_parameter_list
  NT_type_parameter
  NT_type
  NT_type_lambda
  NT_type_application
  NT_type_primary
  NT_function_type
  NT_type_list
  NT_non_empty_type_list
  NT_expression
  NT_primary_expression
  NT_qualified_expression
  NT_type_arguments
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
  NT_pattern_arguments
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
// 71|    top_level_declarations EOF {
// 72|    { declarations: $1, loc: span($sloc) }
// 73|  }

///|
fn yy_action_0(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopLevelDeclaration_(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 {
    _last_pos
  } else {
    _args[_args.length() - 1].2
  }
  YYObj_SourceFile(
    {
      ()
      { declarations: _dollar1, loc: span((_symbol_start_pos, _end_pos)) }
    },
  )
}

// file:///./parser.mbty
// 78|    top_level_declarations top_level_declaration { comma_push($1, $2) }

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
// 82|    struct_declaration { Struct($1) }

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
// 83|    enum_declaration { Enum($1) }

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
// 84|    type_alias_declaration { TypeAlias($1) }

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
// 85|    function_declaration { Function($1) }

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
// 86|    top_level_let_declaration { Let($1) }

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
// 87|    offer_value_declaration { Offer($1) }

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
// 91|    "type" IDENT "=" type {
// 92|    { name: $2, body: $4, loc: span($sloc) }
// 93|  }

///|
fn yy_action_8(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Type(_dollar4)
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
        name: _dollar2,
        body: _dollar4,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 97|    "struct" IDENT type_parameters "{" struct_members "}" {
// 98|    { name: $2, type_parameters: $3, members: $5, loc: span($sloc) }
// 99|  }

///|
fn yy_action_9(
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
        name: _dollar2,
        type_parameters: _dollar3,
        members: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 104|    struct_members struct_member { comma_push($1, $2) }

///|
fn yy_action_10(
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
// 108|    type_member_declaration { TypeMember($1) }

///|
fn yy_action_11(
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
// 109|    field_declaration { Field($1) }

///|
fn yy_action_12(
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
// 113|    "type" IDENT ":" kind {
// 114|    { name: $2, kind: $4, loc: span($sloc) }
// 115|  }

///|
fn yy_action_13(
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
// 140|    field_offer_modifier IDENT ":" type {
// 141|    { is_offered: $1, name: $2, type_: $4, loc: span($sloc) }
// 142|  }

///|
fn yy_action_14(
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
// 147|    "offer" { true }

///|
fn yy_action_15(
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
// 146|    { false }

///|
fn yy_action_16(
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
// 103|    { [] }

///|
fn yy_action_17(
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
// 151|    "enum" IDENT type_parameters "{" enum_variants "}" {
// 152|    { name: $2, type_parameters: $3, variants: $5, loc: span($sloc) }
// 153|  }

///|
fn yy_action_18(
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
        name: _dollar2,
        type_parameters: _dollar3,
        variants: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 158|    enum_variants enum_variant { comma_push($1, $2) }

///|
fn yy_action_19(
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
// 171|    IDENT type_parameters "(" non_empty_type_list ")" {
// 172|    { name: $1, type_parameters: $2, payload: $4, loc: span($sloc) }
// 173|  }

///|
fn yy_action_20(
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
// 165|    IDENT type_parameters {
// 166|    { name: $1, type_parameters: $2, payload: [], loc: span($sloc) }
// 167|  }

///|
fn yy_action_21(
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
// 168|    IDENT "(" non_empty_type_list ")" {
// 169|    { name: $1, type_parameters: [], payload: $3, loc: span($sloc) }
// 170|  }

///|
fn yy_action_22(
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
// 162|    IDENT {
// 163|    { name: $1, type_parameters: [], payload: [], loc: span($sloc) }
// 164|  }

///|
fn yy_action_23(
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
// 157|    { [] }

///|
fn yy_action_24(
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
// 214|    "let" IDENT ":" type "=" expression {
// 215|    { name: Some($2), type_annotation: Some($4), initializer: $6, loc: span($sloc) }
// 216|  }

///|
fn yy_action_25(
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
        name: Some(_dollar2),
        type_annotation: Some(_dollar4),
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 237|    "offer" IDENT ":" type "=" expression {
// 238|    { name: $2, type_annotation: $4, initializer: $6, loc: span($sloc) }
// 239|  }

///|
fn yy_action_26(
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
        name: _dollar2,
        type_annotation: _dollar4,
        initializer: _dollar6,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 177|    "fn" type_parameters IDENT parameters "->" type block_expression {
// 178|    {
// 179|      type_parameters: $2,
// 180|      name: $3,
// 181|      parameters: $4,
// 182|      return_type: $6,
// 183|      body: $7,
// 184|      loc: span($sloc),
// 185|    }
// 186|  }

///|
fn yy_action_27(
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
// 190|    "(" ")" { [] }

///|
fn yy_action_28(
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
// 191|    "(" non_empty_parameter_list ")" { $2 }

///|
fn yy_action_29(
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
// 196|    non_empty_parameter_list "," parameter { comma_push($1, $3) }

///|
fn yy_action_30(
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
// 195|    parameter { [ $1 ] }

///|
fn yy_action_31(
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
// 200|    parameter_modifiers IDENT ":" type {
// 201|    { is_auto: $1.is_auto, is_offered: $1.is_offered, name: $2, type_: $4, loc: span($sloc) }
// 202|  }

///|
fn yy_action_32(
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
// 209|    "auto" "offer" { { is_auto: true, is_offered: true } }

///|
fn yy_action_33(
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
// 207|    "auto" { { is_auto: true, is_offered: false } }

///|
fn yy_action_34(
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
// 210|    "offer" "auto" { { is_auto: true, is_offered: true } }

///|
fn yy_action_35(
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
// 208|    "offer" { { is_auto: false, is_offered: true } }

///|
fn yy_action_36(
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
// 206|    { { is_auto: false, is_offered: false } }

///|
fn yy_action_37(
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
// 244|    "[" non_empty_type_parameter_list "]" { $2 }

///|
fn yy_action_38(
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
// 220|    "let" IDENT local_type_annotation "=" expression {
// 221|    { name: Some($2), type_annotation: $3, initializer: $5, loc: span($sloc) }
// 222|  }

///|
fn yy_action_39(
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
        name: Some(_dollar2),
        type_annotation: _dollar3,
        initializer: _dollar5,
        loc: span((_symbol_start_pos, _end_pos)),
      }
    },
  )
}

// file:///./parser.mbty
// 226|    "let" struct_pattern "=" expression {
// 227|    { pattern: $2, initializer: $4, loc: span($sloc) }
// 228|  }

///|
fn yy_action_40(
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
// 454|    "{" local_items expression "}" {
// 455|    Block(items=$2, result=$3, loc=span($sloc))
// 456|  }

///|
fn yy_action_41(
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
// 461|    local_items local_item { comma_push($1, $2) }

///|
fn yy_action_42(
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
// 465|    local_let_declaration { Let($1) }

///|
fn yy_action_43(
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
// 466|    local_pattern_let_declaration { PatternLet($1) }

///|
fn yy_action_44(
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
// 467|    function_declaration { Function($1) }

///|
fn yy_action_45(
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
// 468|    offer_value_declaration { Offer($1) }

///|
fn yy_action_46(
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
// 478|    "match" expression "{" match_arms "}" {
// 479|    Match(scrutinee=$2, arms=$4, loc=span($sloc))
// 480|  }

///|
fn yy_action_47(
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
// 485|    match_arms match_arm { comma_push($1, $2) }

///|
fn yy_action_48(
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
// 489|    pattern "=>" expression {
// 490|    { pattern: $1, body: $3, loc: span($sloc) }
// 491|  }

///|
fn yy_action_49(
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
// 540|    IDENT "::" IDENT variant_type_binders pattern_arguments {
// 541|    QualifiedVariant(type_name=$1, variant=$3, type_binders=$4, arguments=$5, loc=span($sloc))
// 542|  }

///|
fn yy_action_50(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Array_String_(_dollar4)
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
      QualifiedVariant(
        type_name=_dollar1,
        variant=_dollar3,
        type_binders=_dollar4,
        arguments=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 564|    "(" pattern_list ")" { $2 }

///|
fn yy_action_51(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Pattern_(_dollar2)
  YYObj_Array_Pattern_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 574|    non_empty_pattern_list "," pattern { comma_push($1, $3) }

///|
fn yy_action_52(
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
// 575|    non_empty_pattern_list "," { $1 }

///|
fn yy_action_53(
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
// 569|    non_empty_pattern_list { $1 }

///|
fn yy_action_54(
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
// 573|    pattern { [ $1 ] }

///|
fn yy_action_55(
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
// 568|    { [] }

///|
fn yy_action_56(
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
// 563|    { [] }

///|
fn yy_action_57(
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
// 553|    "[" non_empty_ident_list "]" { $2 }

///|
fn yy_action_58(
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
// 558|    non_empty_ident_list "," IDENT { comma_push($1, $3) }

///|
fn yy_action_59(
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
// 559|    non_empty_ident_list "," { $1 }

///|
fn yy_action_60(
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
// 557|    IDENT { [ $1 ] }

///|
fn yy_action_61(
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
// 552|    { [] }

///|
fn yy_action_62(
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
// 546|    IDENT "::" "{" struct_pattern_fields "}" {
// 547|    Struct(type_name=$1, fields=$4, loc=span($sloc))
// 548|  }

///|
fn yy_action_63(
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
// 585|    non_empty_struct_pattern_fields "," struct_pattern_field { comma_push($1, $3) }

///|
fn yy_action_64(
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
// 586|    non_empty_struct_pattern_fields "," { $1 }

///|
fn yy_action_65(
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
// 580|    non_empty_struct_pattern_fields { $1 }

///|
fn yy_action_66(
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
// 584|    struct_pattern_field { [ $1 ] }

///|
fn yy_action_67(
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
// 533|    "_" { Wildcard(span($sloc)) }

///|
fn yy_action_68(
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
// 534|    INT { IntLiteral($1, loc=span($sloc)) }

///|
fn yy_action_69(
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
// 535|    STRING { StringLiteral($1, loc=span($sloc)) }

///|
fn yy_action_70(
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
// 536|    "true" { BoolLiteral(true, loc=span($sloc)) }

///|
fn yy_action_71(
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
// 537|    "false" { BoolLiteral(false, loc=span($sloc)) }

///|
fn yy_action_72(
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
// 596|    IDENT ":" pattern {
// 597|    Value(name=$1, pattern=Some($3), loc=span($sloc))
// 598|  }

///|
fn yy_action_73(
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
// 590|    IDENT {
// 591|    Value(name=$1, pattern=None, loc=span($sloc))
// 592|  }

///|
fn yy_action_74(
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
// 593|    "_" {
// 594|    TypeWildcard(loc=span($sloc))
// 595|  }

///|
fn yy_action_75(
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
// 579|    { [] }

///|
fn yy_action_76(
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
// 538|    IDENT { Binding($1, loc=span($sloc)) }

///|
fn yy_action_77(
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
// 539|    struct_pattern { $1 }

///|
fn yy_action_78(
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
// 484|    { [] }

///|
fn yy_action_79(
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
// 472|    "if" expression block_expression "else" block_expression {
// 473|    If(condition=$2, then_branch=$3, else_branch=$5, loc=span($sloc))
// 474|  }

///|
fn yy_action_80(
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
// 376|    "(" expression ")" { $2 }

///|
fn yy_action_81(
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
// 385|    IDENT type_arguments "::" "{" struct_literal_fields "}" {
// 386|    StructLiteral(type_name=$1, type_arguments=$2, fields=$5, loc=span($sloc))
// 387|  }

///|
fn yy_action_82(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  guard _args[4].0 is YYObj_Array_StructLiteralField_(_dollar5)
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
        type_name=_dollar1,
        type_arguments=_dollar2,
        fields=_dollar5,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 410|    non_empty_struct_literal_fields "," struct_literal_field { comma_push($1, $3) }

///|
fn yy_action_83(
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
// 411|    non_empty_struct_literal_fields "," { $1 }

///|
fn yy_action_84(
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
// 405|    non_empty_struct_literal_fields { $1 }

///|
fn yy_action_85(
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
// 409|    struct_literal_field { [ $1 ] }

///|
fn yy_action_86(
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
// 418|    IDENT ":" expression {
// 419|    Value(name=$1, value=Some($3), loc=span($sloc))
// 420|  }

///|
fn yy_action_87(
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
// 421|    IDENT "=" type {
// 422|    TypeWitness(name=$1, witness=$3, loc=span($sloc))
// 423|  }

///|
fn yy_action_88(
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
// 415|    IDENT {
// 416|    Value(name=$1, value=None, loc=span($sloc))
// 417|  }

///|
fn yy_action_89(
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
// 404|    { [] }

///|
fn yy_action_90(
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
// 388|    IDENT type_arguments "::" IDENT variant_type_arguments variant_arguments {
// 389|    QualifiedVariant(type_name=$1, type_arguments=$2, variant=$4, variant_type_arguments=$5, arguments=$6, loc=span($sloc))
// 390|  }

///|
fn yy_action_91(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  guard _args[3].0 is YYObj_String(_dollar4)
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  guard _args[5].0 is YYObj_Array_Expr_(_dollar6)
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
        type_name=_dollar1,
        type_arguments=_dollar2,
        variant=_dollar4,
        variant_type_arguments=_dollar5,
        arguments=_dollar6,
        loc=span((_symbol_start_pos, _end_pos)),
      )
    },
  )
}

// file:///./parser.mbty
// 448|    expression { [ $1 ] }

///|
fn yy_action_92(
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
// 428|    "(" non_empty_positional_argument_list ")" { $2 }

///|
fn yy_action_93(
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
// 449|    non_empty_positional_argument_list "," expression { comma_push($1, $3) }

///|
fn yy_action_94(
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
// 356|    "!" expression %prec UNARY {
// 357|    Unary(operator=Not, operand=$2, loc=span($sloc))
// 358|  }

///|
fn yy_action_95(
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
// 359|    expression "(" argument_list ")" {
// 360|    Call(callee=$1, arguments=$3, loc=span($sloc))
// 361|  }

///|
fn yy_action_96(
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
// 443|    expression { Positional($1) }

///|
fn yy_action_97(
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
// 311|    expression "|>" expression {
// 312|    Pipeline(left=$1, right=$3, loc=span($sloc))
// 313|  }

///|
fn yy_action_98(
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
// 314|    expression "||" expression {
// 315|    Binary(operator=Or, left=$1, right=$3, loc=span($sloc))
// 316|  }

///|
fn yy_action_99(
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
// 317|    expression "&&" expression {
// 318|    Binary(operator=And, left=$1, right=$3, loc=span($sloc))
// 319|  }

///|
fn yy_action_100(
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
// 320|    expression "==" expression {
// 321|    Binary(operator=Equal, left=$1, right=$3, loc=span($sloc))
// 322|  }

///|
fn yy_action_101(
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
// 323|    expression "!=" expression {
// 324|    Binary(operator=NotEqual, left=$1, right=$3, loc=span($sloc))
// 325|  }

///|
fn yy_action_102(
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
// 326|    expression "<" expression {
// 327|    Binary(operator=Less, left=$1, right=$3, loc=span($sloc))
// 328|  }

///|
fn yy_action_103(
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
// 329|    expression "<=" expression {
// 330|    Binary(operator=LessEqual, left=$1, right=$3, loc=span($sloc))
// 331|  }

///|
fn yy_action_104(
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
// 332|    expression ">" expression {
// 333|    Binary(operator=Greater, left=$1, right=$3, loc=span($sloc))
// 334|  }

///|
fn yy_action_105(
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
// 335|    expression ">=" expression {
// 336|    Binary(operator=GreaterEqual, left=$1, right=$3, loc=span($sloc))
// 337|  }

///|
fn yy_action_106(
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
// 338|    expression "+" expression {
// 339|    Binary(operator=Add, left=$1, right=$3, loc=span($sloc))
// 340|  }

///|
fn yy_action_107(
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
// 341|    expression "-" expression {
// 342|    Binary(operator=Sub, left=$1, right=$3, loc=span($sloc))
// 343|  }

///|
fn yy_action_108(
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
// 344|    expression "*" expression {
// 345|    Binary(operator=Mul, left=$1, right=$3, loc=span($sloc))
// 346|  }

///|
fn yy_action_109(
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
// 347|    expression "/" expression {
// 348|    Binary(operator=Div, left=$1, right=$3, loc=span($sloc))
// 349|  }

///|
fn yy_action_110(
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
// 350|    expression "%" expression {
// 351|    Binary(operator=Rem, left=$1, right=$3, loc=span($sloc))
// 352|  }

///|
fn yy_action_111(
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
// 444|    IDENT "=" expression { Named(name=$1, value=$3, loc=span($sloc)) }

///|
fn yy_action_112(
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
// 438|    non_empty_argument_list "," call_argument { comma_push($1, $3) }

///|
fn yy_action_113(
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
// 439|    non_empty_argument_list "," { $1 }

///|
fn yy_action_114(
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
// 433|    non_empty_argument_list { $1 }

///|
fn yy_action_115(
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
// 437|    call_argument { [ $1 ] }

///|
fn yy_action_116(
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
// 432|    { [] }

///|
fn yy_action_117(
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
// 362|    expression "." IDENT {
// 363|    Field(base=$1, name=$3, loc=span($sloc))
// 364|  }

///|
fn yy_action_118(
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
// 353|    "-" expression %prec UNARY {
// 354|    Unary(operator=Neg, operand=$2, loc=span($sloc))
// 355|  }

///|
fn yy_action_119(
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
// 365|    primary_expression { $1 }

///|
fn yy_action_120(
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
// 369|    INT { IntLiteral($1, loc=span($sloc)) }

///|
fn yy_action_121(
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
// 370|    STRING { StringLiteral($1, loc=span($sloc)) }

///|
fn yy_action_122(
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
// 371|    "true" { BoolLiteral(true, loc=span($sloc)) }

///|
fn yy_action_123(
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
// 372|    "false" { BoolLiteral(false, loc=span($sloc)) }

///|
fn yy_action_124(
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
// 450|    non_empty_positional_argument_list "," { $1 }

///|
fn yy_action_125(
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
// 427|    { [] }

///|
fn yy_action_126(
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
// 400|    "[" type_list "]" { $2 }

///|
fn yy_action_127(
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
// 399|    { [] }

///|
fn yy_action_128(
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
// 395|    "[" type_list "]" { $2 }

///|
fn yy_action_129(
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
// 394|    { [] }

///|
fn yy_action_130(
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
// 373|    IDENT { Var($1, loc=span($sloc)) }

///|
fn yy_action_131(
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
// 374|    qualified_expression { $1 }

///|
fn yy_action_132(
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
// 375|    "(" ")" { UnitLiteral(loc=span($sloc)) }

///|
fn yy_action_133(
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
// 377|    block_expression { $1 }

///|
fn yy_action_134(
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
// 378|    if_expression { $1 }

///|
fn yy_action_135(
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
// 379|    match_expression { $1 }

///|
fn yy_action_136(
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
// 380|    function_literal { $1 }

///|
fn yy_action_137(
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
// 381|    builtin_expression { $1 }

///|
fn yy_action_138(
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
// 460|    { [] }

///|
fn yy_action_139(
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
// 495|    "fn" type_parameters "(" function_literal_parameters ")" return_type_annotation block_expression {
// 496|    FunctionLiteral(type_parameters=$2, parameters=$4, return_type=$6, body=$7, loc=span($sloc))
// 497|  }

///|
fn yy_action_140(
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
// 523|    "->" type { Some($2) }

///|
fn yy_action_141(
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
// 522|    { None }

///|
fn yy_action_142(
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
// 507|    non_empty_function_literal_parameters "," function_literal_parameter { comma_push($1, $3) }

///|
fn yy_action_143(
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
// 502|    non_empty_function_literal_parameters { $1 }

///|
fn yy_action_144(
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
// 506|    function_literal_parameter { [ $1 ] }

///|
fn yy_action_145(
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
// 233|    ":" type { Some($2) }

///|
fn yy_action_146(
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
// 511|    function_literal_parameter_modifiers IDENT local_type_annotation {
// 512|    { is_offered: $1, name: $2, type_annotation: $3, loc: span($sloc) }
// 513|  }

///|
fn yy_action_147(
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
// 232|    { None }

///|
fn yy_action_148(
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
// 518|    "offer" { true }

///|
fn yy_action_149(
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
// 501|    { [] }

///|
fn yy_action_150(
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
// 517|    { false }

///|
fn yy_action_151(
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
// 243|    { [] }

///|
fn yy_action_152(
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
// 527|    "builtin" "(" STRING ")" {
// 528|    Builtin($3, loc=span($sloc))
// 529|  }

///|
fn yy_action_153(
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
// 295|    "[" non_empty_type_parameter_list "]" "(" type_list ")" "->" type {
// 296|    Function(type_parameters=$2, parameters=$5, result=$8, loc=span($sloc))
// 297|  }

///|
fn yy_action_154(
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
// 288|    "(" type ")" { $2 }

///|
fn yy_action_155(
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
// 248|    type_parameter { [ $1 ] }

///|
fn yy_action_156(
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
// 249|    non_empty_type_parameter_list "," type_parameter { comma_push($1, $3) }

///|
fn yy_action_157(
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
// 250|    non_empty_type_parameter_list "," { $1 }

///|
fn yy_action_158(
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
// 264|    type_application "->" type {
// 265|    Function(type_parameters=[], parameters=[$1], result=$3, loc=span($sloc))
// 266|  }

///|
fn yy_action_159(
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
// 263|    type_lambda { $1 }

///|
fn yy_action_160(
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
// 279|    type_application "[" type_list "]" {
// 280|    Apply(callee=$1, arguments=$3, loc=span($sloc))
// 281|  }

///|
fn yy_action_161(
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
// 268|    type_application { $1 }

///|
fn yy_action_162(
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
// 267|    function_type { $1 }

///|
fn yy_action_163(
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
// 272|    "type" "[" non_empty_type_parameter_list "]" "=>" type {
// 273|    TypeLambda(parameters=$3, body=$6, loc=span($sloc))
// 274|  }

///|
fn yy_action_164(
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
// 278|    type_primary { $1 }

///|
fn yy_action_165(
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
// 285|    IDENT {
// 286|    Name(name=$1, loc=span($sloc))
// 287|  }

///|
fn yy_action_166(
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
// 292|    "(" type_list ")" "->" type {
// 293|    Function(type_parameters=[], parameters=$2, result=$5, loc=span($sloc))
// 294|  }

///|
fn yy_action_167(
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
// 307|    non_empty_type_list "," type { comma_push($1, $3) }

///|
fn yy_action_168(
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
// 302|    non_empty_type_list { $1 }

///|
fn yy_action_169(
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
// 306|    type { [ $1 ] }

///|
fn yy_action_170(
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
// 301|    { [] }

///|
fn yy_action_171(
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
// 122|    "[" kind_list "]" "->" kind {
// 123|    Function(parameters=$2, result=$5, loc=span($sloc))
// 124|  }

///|
fn yy_action_172(
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
// 119|    IDENT {
// 120|    Type(loc=span($sloc))
// 121|  }

///|
fn yy_action_173(
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
// 135|    non_empty_kind_list "," kind { comma_push($1, $3) }

///|
fn yy_action_174(
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
// 136|    non_empty_kind_list "," { $1 }

///|
fn yy_action_175(
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
// 130|    non_empty_kind_list { $1 }

///|
fn yy_action_176(
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
// 134|    kind { [ $1 ] }

///|
fn yy_action_177(
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
// 129|    { [] }

///|
fn yy_action_178(
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
// 125|    "(" kind ")" { $2 }

///|
fn yy_action_179(
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
// 257|    IDENT ":" kind {
// 258|    { name: $1, kind: Some($3), loc: span($sloc) }
// 259|  }

///|
fn yy_action_180(
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
// 254|    IDENT {
// 255|    { name: $1, kind: None, loc: span($sloc) }
// 256|  }

///|
fn yy_action_181(
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
// 77|    { [] }

///|
fn yy_action_182(
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
    DOT => (T_DOT, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    COLONCOLON => (T_COLONCOLON, YYObj_Void)
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
    NT_top_level_declarations => Shift(yy_state_2)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER =>
      Reduce(0, NT_top_level_declarations, yy_action_182)
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
    T_OFFER => Shift(yy_state_3)
    T_LET => Shift(yy_state_268)
    T_FN => Shift(yy_state_274)
    T_ENUM => Shift(yy_state_276)
    T_STRUCT => Shift(yy_state_291)
    T_TYPE => Shift(yy_state_309)
    NT_offer_value_declaration => Shift(yy_state_313)
    NT_top_level_let_declaration => Shift(yy_state_314)
    NT_function_declaration => Shift(yy_state_315)
    NT_type_alias_declaration => Shift(yy_state_316)
    NT_enum_declaration => Shift(yy_state_317)
    NT_struct_declaration => Shift(yy_state_318)
    NT_top_level_declaration => Shift(yy_state_319)
    T_EOF => Shift(yy_state_320)
    _ => Error
  }
}

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_4)
    _ => Error
  }
}

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_5)
    _ => Error
  }
}

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_60)
    _ => Error
  }
}

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    NT_non_empty_type_parameter_list => Shift(yy_state_23)
    NT_type_parameter => Shift(yy_state_53)
    _ => Error
  }
}

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_8)
    T_RBRACKET | T_COMMA => Reduce(1, NT_type_parameter, yy_action_181)
    _ => Error
  }
}

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_kind => Shift(yy_state_9)
    T_LPAREN => Shift(yy_state_10)
    T_LBRACKET => Shift(yy_state_13)
    T_IDENT => Shift(yy_state_18)
    _ => Error
  }
}

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter, yy_action_180)
}

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    NT_kind => Shift(yy_state_11)
    T_LBRACKET => Shift(yy_state_13)
    T_IDENT => Shift(yy_state_18)
    _ => Error
  }
}

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_12)
    _ => Error
  }
}

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind, yy_action_179)
}

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    T_LBRACKET => Shift(yy_state_13)
    NT_kind => Shift(yy_state_14)
    NT_non_empty_kind_list => Shift(yy_state_15)
    T_IDENT => Shift(yy_state_18)
    NT_kind_list => Shift(yy_state_19)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_178)
    _ => Error
  }
}

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_177)
}

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_16)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_176)
    _ => Error
  }
}

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    T_LBRACKET => Shift(yy_state_13)
    NT_kind => Shift(yy_state_17)
    T_IDENT => Shift(yy_state_18)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_kind_list, yy_action_175)
    _ => Error
  }
}

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_174)
}

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_173)
}

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_20)
    _ => Error
  }
}

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_21)
    _ => Error
  }
}

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    T_LBRACKET => Shift(yy_state_13)
    T_IDENT => Shift(yy_state_18)
    NT_kind => Shift(yy_state_22)
    _ => Error
  }
}

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_172)
}

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_24)
    T_COMMA => Shift(yy_state_51)
    _ => Error
  }
}

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_25)
    _ => Error
  }
}

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    NT_non_empty_type_list => Shift(yy_state_27)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_56)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_171)
    _ => Error
  }
}

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_170)
}

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_28)
    T_RPAREN | T_RBRACKET => Reduce(1, NT_type_list, yy_action_169)
    _ => Error
  }
}

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_29)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    _ => Error
  }
}

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_168)
}

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_non_empty_type_list => Shift(yy_state_27)
    T_LPAREN => Shift(yy_state_30)
    NT_type_list => Shift(yy_state_31)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_54)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_171)
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
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_33)
    _ => Error
  }
}

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    NT_type => Shift(yy_state_34)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    _ => Error
  }
}

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_type, yy_action_167)
}

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_primary, yy_action_166)
}

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_application, yy_action_165)
}

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_38)
    _ => Error
  }
}

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    NT_non_empty_type_parameter_list => Shift(yy_state_39)
    NT_type_parameter => Shift(yy_state_53)
    _ => Error
  }
}

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_40)
    T_COMMA => Shift(yy_state_51)
    _ => Error
  }
}

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_41)
    _ => Error
  }
}

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_type => Shift(yy_state_42)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    _ => Error
  }
}

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type_lambda, yy_action_164)
}

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_163)
}

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_45)
    T_THIN_ARROW => Shift(yy_state_49)
    T_IDENT
    | T_EOF
    | T_STRUCT
    | T_ENUM
    | T_FN
    | T_LET
    | T_TYPE
    | T_OFFER
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_RBRACKET
    | T_COMMA
    | T_EQUAL => Reduce(1, NT_type, yy_action_162)
    _ => Error
  }
}

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    NT_non_empty_type_list => Shift(yy_state_27)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_list => Shift(yy_state_46)
    NT_type_lambda => Shift(yy_state_48)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_171)
    _ => Error
  }
}

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_47)
    _ => Error
  }
}

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_application, yy_action_161)
}

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_160)
}

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_50)
    _ => Error
  }
}

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type, yy_action_159)
}

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    NT_type_parameter => Shift(yy_state_52)
    T_RBRACKET | T_COMMA =>
      Reduce(2, NT_non_empty_type_parameter_list, yy_action_158)
    _ => Error
  }
}

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_list, yy_action_157)
}

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_list, yy_action_156)
}

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_55)
    T_COMMA => Reduce(1, NT_non_empty_type_list, yy_action_170)
    _ => Error
  }
}

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_primary, yy_action_155)
}

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_57)
    _ => Error
  }
}

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_58)
    _ => Error
  }
}

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_59)
    _ => Error
  }
}

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_function_type, yy_action_154)
}

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_61)
    _ => Error
  }
}

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_267)
    _ => Error
  }
}

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_63)
    _ => Error
  }
}

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_64)
    _ => Error
  }
}

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_65)
    _ => Error
  }
}

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_builtin_expression, yy_action_153)
}

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_parameters => Shift(yy_state_67)
    T_LBRACKET => Shift(yy_state_243)
    T_LPAREN => Reduce(0, NT_type_parameters, yy_action_152)
    _ => Error
  }
}

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_68)
    _ => Error
  }
}

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_69)
    NT_function_literal_parameter_modifiers => Shift(yy_state_70)
    NT_function_literal_parameter => Shift(yy_state_75)
    NT_non_empty_function_literal_parameters => Shift(yy_state_76)
    NT_function_literal_parameters => Shift(yy_state_79)
    T_RPAREN => Reduce(0, NT_function_literal_parameters, yy_action_150)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_151)
    _ => Error
  }
}

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_literal_parameter_modifiers, yy_action_149)
}

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_71)
    _ => Error
  }
}

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_type_annotation => Shift(yy_state_72)
    T_COLON => Shift(yy_state_73)
    T_RPAREN | T_COMMA => Reduce(0, NT_local_type_annotation, yy_action_148)
    _ => Error
  }
}

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_literal_parameter, yy_action_147)
}

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_74)
    _ => Error
  }
}

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_type_annotation, yy_action_146)
}

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_function_literal_parameters, yy_action_145)
}

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_77)
    T_RPAREN => Reduce(1, NT_function_literal_parameters, yy_action_144)
    _ => Error
  }
}

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_69)
    NT_function_literal_parameter_modifiers => Shift(yy_state_70)
    NT_function_literal_parameter => Shift(yy_state_78)
    T_IDENT => Reduce(0, NT_function_literal_parameter_modifiers, yy_action_151)
    _ => Error
  }
}

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_function_literal_parameters, yy_action_143)
}

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_80)
    _ => Error
  }
}

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_81)
    NT_return_type_annotation => Shift(yy_state_83)
    T_LBRACE => Reduce(0, NT_return_type_annotation, yy_action_142)
    _ => Error
  }
}

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_82)
    _ => Error
  }
}

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_return_type_annotation, yy_action_141)
}

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block_expression => Shift(yy_state_84)
    T_LBRACE => Shift(yy_state_85)
    _ => Error
  }
}

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_literal, yy_action_140)
}

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_local_items => Shift(yy_state_86)
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
    | T_LBRACE => Reduce(0, NT_local_items, yy_action_139)
    _ => Error
  }
}

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_3)
    T_BUILTIN => Shift(yy_state_62)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_offer_value_declaration => Shift(yy_state_226)
    NT_function_declaration => Shift(yy_state_227)
    NT_local_pattern_let_declaration => Shift(yy_state_228)
    NT_local_let_declaration => Shift(yy_state_229)
    NT_local_item => Shift(yy_state_230)
    NT_expression => Shift(yy_state_231)
    T_LET => Shift(yy_state_233)
    T_FN => Shift(yy_state_242)
    _ => Error
  }
}

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_183)
    _ => Error
  }
}

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_179)
    _ => Error
  }
}

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_138)
}

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_137)
}

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_136)
}

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_135)
}

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_134)
}

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    T_RPAREN => Shift(yy_state_95)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_177)
    _ => Error
  }
}

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_primary_expression, yy_action_133)
}

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_132)
}

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_arguments => Shift(yy_state_101)
    T_COLONCOLON => Reduce(0, NT_type_arguments, yy_action_130)
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
    | T_UNDERSCORE => Reduce(1, NT_primary_expression, yy_action_131)
    _ => Error
  }
}

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    NT_non_empty_type_list => Shift(yy_state_27)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_99)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_171)
    _ => Error
  }
}

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_100)
    _ => Error
  }
}

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_arguments, yy_action_129)
}

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONCOLON => Shift(yy_state_102)
    _ => Error
  }
}

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_103)
    T_LBRACE => Shift(yy_state_165)
    _ => Error
  }
}

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_104)
    NT_variant_type_arguments => Shift(yy_state_107)
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
    | T_UNDERSCORE => Reduce(0, NT_variant_type_arguments, yy_action_128)
    _ => Error
  }
}

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    NT_non_empty_type_list => Shift(yy_state_27)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type_list => Shift(yy_state_105)
    T_RBRACKET => Reduce(0, NT_type_list, yy_action_171)
    _ => Error
  }
}

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_106)
    _ => Error
  }
}

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_arguments, yy_action_127)
}

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_108)
    NT_variant_arguments => Shift(yy_state_164)
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
    | T_COMMA
    | T_DOT
    | T_UNDERSCORE => Reduce(0, NT_variant_arguments, yy_action_126)
    _ => Error
  }
}

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    NT_non_empty_positional_argument_list => Shift(yy_state_109)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_163)
    _ => Error
  }
}

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_110)
    T_RPAREN => Shift(yy_state_162)
    _ => Error
  }
}

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_161)
    T_RPAREN | T_COMMA =>
      Reduce(2, NT_non_empty_positional_argument_list, yy_action_125)
    _ => Error
  }
}

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_124)
}

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_123)
}

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_122)
}

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expression, yy_action_121)
}

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_120)
}

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_160)
    _ => Error
  }
}

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_118)
    _ => Error
  }
}

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(2, NT_expression, yy_action_119)
    _ => Error
  }
}

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_120)
    _ => Error
  }
}

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expression, yy_action_118)
}

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_call_argument => Shift(yy_state_122)
    NT_non_empty_argument_list => Shift(yy_state_123)
    T_IDENT => Shift(yy_state_126)
    NT_expression => Shift(yy_state_157)
    NT_argument_list => Shift(yy_state_158)
    T_RPAREN => Reduce(0, NT_argument_list, yy_action_117)
    _ => Error
  }
}

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_argument_list, yy_action_116)
}

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_124)
    T_RPAREN => Reduce(1, NT_argument_list, yy_action_115)
    _ => Error
  }
}

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_call_argument => Shift(yy_state_125)
    T_IDENT => Shift(yy_state_126)
    NT_expression => Shift(yy_state_157)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_argument_list, yy_action_114)
    _ => Error
  }
}

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_argument_list, yy_action_113)
}

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_arguments => Shift(yy_state_101)
    T_EQUAL => Shift(yy_state_127)
    T_COLONCOLON => Reduce(0, NT_type_arguments, yy_action_130)
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
    | T_COMMA
    | T_DOT => Reduce(1, NT_primary_expression, yy_action_131)
    _ => Error
  }
}

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_128)
    _ => Error
  }
}

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RPAREN | T_COMMA => Reduce(3, NT_call_argument, yy_action_112)
    _ => Error
  }
}

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_130)
    _ => Error
  }
}

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_111)
    _ => Error
  }
}

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_132)
    _ => Error
  }
}

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_110)
    _ => Error
  }
}

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_134)
    _ => Error
  }
}

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_109)
    _ => Error
  }
}

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_136)
    _ => Error
  }
}

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_108)
    _ => Error
  }
}

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_138)
    _ => Error
  }
}

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_107)
    _ => Error
  }
}

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_140)
    _ => Error
  }
}

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_106)
    _ => Error
  }
}

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_142)
    _ => Error
  }
}

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_105)
    _ => Error
  }
}

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_144)
    _ => Error
  }
}

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_104)
    _ => Error
  }
}

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_146)
    _ => Error
  }
}

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_103)
    _ => Error
  }
}

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_148)
    _ => Error
  }
}

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
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
    | T_EQEQ
    | T_BANGEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_102)
    _ => Error
  }
}

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_150)
    _ => Error
  }
}

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
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
    | T_EQEQ
    | T_BANGEQ
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_101)
    _ => Error
  }
}

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_152)
    _ => Error
  }
}

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
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
    | T_AMPAMP
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_100)
    _ => Error
  }
}

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_154)
    _ => Error
  }
}

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
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
    | T_BARBAR
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_99)
    _ => Error
  }
}

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_156)
    _ => Error
  }
}

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
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
    | T_BANG
    | T_PIPE
    | T_RPAREN
    | T_LBRACE
    | T_RBRACE
    | T_COMMA
    | T_UNDERSCORE => Reduce(3, NT_expression, yy_action_98)
    _ => Error
  }
}

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RPAREN | T_COMMA => Reduce(1, NT_call_argument, yy_action_97)
    _ => Error
  }
}

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_159)
    _ => Error
  }
}

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_expression, yy_action_96)
}

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
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
    | T_COMMA
    | T_UNDERSCORE => Reduce(2, NT_expression, yy_action_95)
    _ => Error
  }
}

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RPAREN | T_COMMA =>
      Reduce(3, NT_non_empty_positional_argument_list, yy_action_94)
    _ => Error
  }
}

///|
fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_arguments, yy_action_93)
}

///|
fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RPAREN | T_COMMA =>
      Reduce(1, NT_non_empty_positional_argument_list, yy_action_92)
    _ => Error
  }
}

///|
fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_qualified_expression, yy_action_91)
}

///|
fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_166)
    NT_struct_literal_field => Shift(yy_state_171)
    NT_non_empty_struct_literal_fields => Shift(yy_state_172)
    NT_struct_literal_fields => Shift(yy_state_175)
    T_RBRACE => Reduce(0, NT_struct_literal_fields, yy_action_90)
    _ => Error
  }
}

///|
fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_167)
    T_COLON => Shift(yy_state_169)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_literal_field, yy_action_89)
    _ => Error
  }
}

///|
fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_168)
    _ => Error
  }
}

///|
fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_literal_field, yy_action_88)
}

///|
fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_170)
    _ => Error
  }
}

///|
fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RBRACE | T_COMMA => Reduce(3, NT_struct_literal_field, yy_action_87)
    _ => Error
  }
}

///|
fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_literal_fields, yy_action_86)
}

///|
fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_173)
    T_RBRACE => Reduce(1, NT_struct_literal_fields, yy_action_85)
    _ => Error
  }
}

///|
fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_166)
    NT_struct_literal_field => Shift(yy_state_174)
    T_RBRACE | T_COMMA =>
      Reduce(2, NT_non_empty_struct_literal_fields, yy_action_84)
    _ => Error
  }
}

///|
fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_literal_fields, yy_action_83)
}

///|
fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_176)
    _ => Error
  }
}

///|
fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_qualified_expression, yy_action_82)
}

///|
fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RPAREN => Shift(yy_state_178)
    _ => Error
  }
}

///|
fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_primary_expression, yy_action_81)
}

///|
fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_85)
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    NT_block_expression => Shift(yy_state_180)
    _ => Error
  }
}

///|
fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_181)
    _ => Error
  }
}

///|
fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_85)
    NT_block_expression => Shift(yy_state_182)
    _ => Error
  }
}

///|
fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_if_expression, yy_action_80)
}

///|
fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_LBRACE => Shift(yy_state_184)
    _ => Error
  }
}

///|
fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_match_arms => Shift(yy_state_185)
    T_INT | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_RBRACE | T_UNDERSCORE =>
      Reduce(0, NT_match_arms, yy_action_79)
    _ => Error
  }
}

///|
fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_pattern => Shift(yy_state_186)
    T_IDENT => Shift(yy_state_187)
    T_FALSE => Shift(yy_state_194)
    T_TRUE => Shift(yy_state_195)
    T_STRING => Shift(yy_state_196)
    T_INT => Shift(yy_state_197)
    T_UNDERSCORE => Shift(yy_state_198)
    NT_pattern => Shift(yy_state_221)
    NT_match_arm => Shift(yy_state_224)
    T_RBRACE => Shift(yy_state_225)
    _ => Error
  }
}

///|
fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_78)
}

///|
fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONCOLON => Shift(yy_state_188)
    T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(1, NT_pattern, yy_action_77)
    _ => Error
  }
}

///|
fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_189)
    T_IDENT => Shift(yy_state_205)
    _ => Error
  }
}

///|
fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_190)
    T_IDENT => Shift(yy_state_191)
    NT_struct_pattern_field => Shift(yy_state_199)
    NT_non_empty_struct_pattern_fields => Shift(yy_state_200)
    NT_struct_pattern_fields => Shift(yy_state_203)
    T_RBRACE => Reduce(0, NT_struct_pattern_fields, yy_action_76)
    _ => Error
  }
}

///|
fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_pattern_field, yy_action_75)
}

///|
fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_192)
    T_RBRACE | T_COMMA => Reduce(1, NT_struct_pattern_field, yy_action_74)
    _ => Error
  }
}

///|
fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_pattern => Shift(yy_state_186)
    T_IDENT => Shift(yy_state_187)
    NT_pattern => Shift(yy_state_193)
    T_FALSE => Shift(yy_state_194)
    T_TRUE => Shift(yy_state_195)
    T_STRING => Shift(yy_state_196)
    T_INT => Shift(yy_state_197)
    T_UNDERSCORE => Shift(yy_state_198)
    _ => Error
  }
}

///|
fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_pattern_field, yy_action_73)
}

///|
fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_72)
}

///|
fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_71)
}

///|
fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_70)
}

///|
fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_69)
}

///|
fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_pattern, yy_action_68)
}

///|
fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_struct_pattern_fields, yy_action_67)
}

///|
fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_201)
    T_RBRACE => Reduce(1, NT_struct_pattern_fields, yy_action_66)
    _ => Error
  }
}

///|
fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNDERSCORE => Shift(yy_state_190)
    T_IDENT => Shift(yy_state_191)
    NT_struct_pattern_field => Shift(yy_state_202)
    T_RBRACE | T_COMMA =>
      Reduce(2, NT_non_empty_struct_pattern_fields, yy_action_65)
    _ => Error
  }
}

///|
fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_struct_pattern_fields, yy_action_64)
}

///|
fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_204)
    _ => Error
  }
}

///|
fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_pattern, yy_action_63)
}

///|
fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_206)
    NT_variant_type_binders => Shift(yy_state_212)
    T_LPAREN | T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(0, NT_variant_type_binders, yy_action_62)
    _ => Error
  }
}

///|
fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_207)
    NT_non_empty_ident_list => Shift(yy_state_208)
    _ => Error
  }
}

///|
fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_ident_list, yy_action_61)
}

///|
fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_209)
    T_RBRACKET => Shift(yy_state_211)
    _ => Error
  }
}

///|
fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_210)
    T_RBRACKET | T_COMMA => Reduce(2, NT_non_empty_ident_list, yy_action_60)
    _ => Error
  }
}

///|
fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_ident_list, yy_action_59)
}

///|
fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_variant_type_binders, yy_action_58)
}

///|
fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_213)
    NT_pattern_arguments => Shift(yy_state_220)
    T_RPAREN | T_RBRACE | T_COMMA | T_FAT_ARROW =>
      Reduce(0, NT_pattern_arguments, yy_action_57)
    _ => Error
  }
}

///|
fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_pattern => Shift(yy_state_186)
    T_IDENT => Shift(yy_state_187)
    T_FALSE => Shift(yy_state_194)
    T_TRUE => Shift(yy_state_195)
    T_STRING => Shift(yy_state_196)
    T_INT => Shift(yy_state_197)
    T_UNDERSCORE => Shift(yy_state_198)
    NT_pattern => Shift(yy_state_214)
    NT_non_empty_pattern_list => Shift(yy_state_215)
    NT_pattern_list => Shift(yy_state_218)
    T_RPAREN => Reduce(0, NT_pattern_list, yy_action_56)
    _ => Error
  }
}

///|
fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_pattern_list, yy_action_55)
}

///|
fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_216)
    T_RPAREN => Reduce(1, NT_pattern_list, yy_action_54)
    _ => Error
  }
}

///|
fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_pattern => Shift(yy_state_186)
    T_IDENT => Shift(yy_state_187)
    T_FALSE => Shift(yy_state_194)
    T_TRUE => Shift(yy_state_195)
    T_STRING => Shift(yy_state_196)
    T_INT => Shift(yy_state_197)
    T_UNDERSCORE => Shift(yy_state_198)
    NT_pattern => Shift(yy_state_217)
    T_RPAREN | T_COMMA => Reduce(2, NT_non_empty_pattern_list, yy_action_53)
    _ => Error
  }
}

///|
fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_pattern_list, yy_action_52)
}

///|
fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_219)
    _ => Error
  }
}

///|
fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_pattern_arguments, yy_action_51)
}

///|
fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_pattern, yy_action_50)
}

///|
fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_222)
    _ => Error
  }
}

///|
fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_223)
    _ => Error
  }
}

///|
fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_INT | T_STRING | T_IDENT | T_FALSE | T_TRUE | T_RBRACE | T_UNDERSCORE =>
      Reduce(3, NT_match_arm, yy_action_49)
    _ => Error
  }
}

///|
fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_match_arms, yy_action_48)
}

///|
fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_match_expression, yy_action_47)
}

///|
fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_46)
}

///|
fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_45)
}

///|
fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_44)
}

///|
fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_local_item, yy_action_43)
}

///|
fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_local_items, yy_action_42)
}

///|
fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_RBRACE => Shift(yy_state_232)
    _ => Error
  }
}

///|
fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block_expression, yy_action_41)
}

///|
fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_pattern => Shift(yy_state_234)
    T_IDENT => Shift(yy_state_237)
    _ => Error
  }
}

///|
fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_235)
    _ => Error
  }
}

///|
fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_236)
    _ => Error
  }
}

///|
fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
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
    | T_LBRACE => Reduce(4, NT_local_pattern_let_declaration, yy_action_40)
    _ => Error
  }
}

///|
fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_73)
    T_COLONCOLON => Shift(yy_state_238)
    NT_local_type_annotation => Shift(yy_state_239)
    T_EQUAL => Reduce(0, NT_local_type_annotation, yy_action_148)
    _ => Error
  }
}

///|
fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_189)
    _ => Error
  }
}

///|
fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_240)
    _ => Error
  }
}

///|
fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_241)
    _ => Error
  }
}

///|
fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
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
    | T_LBRACE => Reduce(5, NT_local_let_declaration, yy_action_39)
    _ => Error
  }
}

///|
fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_243)
    NT_type_parameters => Shift(yy_state_246)
    T_IDENT | T_LPAREN => Reduce(0, NT_type_parameters, yy_action_152)
    _ => Error
  }
}

///|
fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    NT_type_parameter => Shift(yy_state_53)
    NT_non_empty_type_parameter_list => Shift(yy_state_244)
    _ => Error
  }
}

///|
fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_51)
    T_RBRACKET => Shift(yy_state_245)
    _ => Error
  }
}

///|
fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameters, yy_action_38)
}

///|
fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_68)
    T_IDENT => Shift(yy_state_247)
    _ => Error
  }
}

///|
fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_248)
    NT_parameters => Shift(yy_state_263)
    _ => Error
  }
}

///|
fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_249)
    T_AUTO => Shift(yy_state_251)
    NT_parameter_modifiers => Shift(yy_state_253)
    NT_parameter => Shift(yy_state_257)
    NT_non_empty_parameter_list => Shift(yy_state_258)
    T_RPAREN => Shift(yy_state_262)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_37)
    _ => Error
  }
}

///|
fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AUTO => Shift(yy_state_250)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_36)
    _ => Error
  }
}

///|
fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_35)
}

///|
fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_252)
    T_IDENT => Reduce(1, NT_parameter_modifiers, yy_action_34)
    _ => Error
  }
}

///|
fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameter_modifiers, yy_action_33)
}

///|
fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_254)
    _ => Error
  }
}

///|
fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_255)
    _ => Error
  }
}

///|
fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_256)
    _ => Error
  }
}

///|
fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_parameter, yy_action_32)
}

///|
fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_parameter_list, yy_action_31)
}

///|
fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_259)
    T_RPAREN => Shift(yy_state_261)
    _ => Error
  }
}

///|
fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_249)
    T_AUTO => Shift(yy_state_251)
    NT_parameter_modifiers => Shift(yy_state_253)
    NT_parameter => Shift(yy_state_260)
    T_IDENT => Reduce(0, NT_parameter_modifiers, yy_action_37)
    _ => Error
  }
}

///|
fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_parameter_list, yy_action_30)
}

///|
fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parameters, yy_action_29)
}

///|
fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_parameters, yy_action_28)
}

///|
fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_THIN_ARROW => Shift(yy_state_264)
    _ => Error
  }
}

///|
fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_265)
    _ => Error
  }
}

///|
fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_85)
    NT_block_expression => Shift(yy_state_266)
    _ => Error
  }
}

///|
fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_function_declaration, yy_action_27)
}

///|
fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
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
    | T_BANG
    | T_LBRACE => Reduce(6, NT_offer_value_declaration, yy_action_26)
    _ => Error
  }
}

///|
fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_269)
    _ => Error
  }
}

///|
fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_270)
    _ => Error
  }
}

///|
fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_271)
    _ => Error
  }
}

///|
fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_272)
    _ => Error
  }
}

///|
fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BUILTIN => Shift(yy_state_62)
    T_FN => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_85)
    T_MATCH => Shift(yy_state_87)
    T_IF => Shift(yy_state_88)
    NT_builtin_expression => Shift(yy_state_89)
    NT_function_literal => Shift(yy_state_90)
    NT_match_expression => Shift(yy_state_91)
    NT_if_expression => Shift(yy_state_92)
    NT_block_expression => Shift(yy_state_93)
    T_LPAREN => Shift(yy_state_94)
    NT_qualified_expression => Shift(yy_state_96)
    T_IDENT => Shift(yy_state_97)
    T_FALSE => Shift(yy_state_111)
    T_TRUE => Shift(yy_state_112)
    T_STRING => Shift(yy_state_113)
    T_INT => Shift(yy_state_114)
    NT_primary_expression => Shift(yy_state_115)
    T_BANG => Shift(yy_state_116)
    T_MINUS => Shift(yy_state_117)
    NT_expression => Shift(yy_state_273)
    _ => Error
  }
}

///|
fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_119)
    T_LPAREN => Shift(yy_state_121)
    T_PERCENT => Shift(yy_state_129)
    T_SLASH => Shift(yy_state_131)
    T_STAR => Shift(yy_state_133)
    T_MINUS => Shift(yy_state_135)
    T_PLUS => Shift(yy_state_137)
    T_GTEQ => Shift(yy_state_139)
    T_GT => Shift(yy_state_141)
    T_LTEQ => Shift(yy_state_143)
    T_LT => Shift(yy_state_145)
    T_BANGEQ => Shift(yy_state_147)
    T_EQEQ => Shift(yy_state_149)
    T_AMPAMP => Shift(yy_state_151)
    T_BARBAR => Shift(yy_state_153)
    T_PIPE => Shift(yy_state_155)
    T_EOF | T_STRUCT | T_ENUM | T_FN | T_LET | T_TYPE | T_OFFER =>
      Reduce(6, NT_top_level_let_declaration, yy_action_25)
    _ => Error
  }
}

///|
fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_243)
    NT_type_parameters => Shift(yy_state_275)
    T_IDENT => Reduce(0, NT_type_parameters, yy_action_152)
    _ => Error
  }
}

///|
fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_247)
    _ => Error
  }
}

///|
fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_277)
    _ => Error
  }
}

///|
fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_243)
    NT_type_parameters => Shift(yy_state_278)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_152)
    _ => Error
  }
}

///|
fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_279)
    _ => Error
  }
}

///|
fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_enum_variants => Shift(yy_state_280)
    T_IDENT | T_RBRACE => Reduce(0, NT_enum_variants, yy_action_24)
    _ => Error
  }
}

///|
fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_281)
    NT_enum_variant => Shift(yy_state_289)
    T_RBRACE => Shift(yy_state_290)
    _ => Error
  }
}

///|
fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_243)
    T_LPAREN => Shift(yy_state_282)
    NT_type_parameters => Shift(yy_state_285)
    T_IDENT | T_RBRACE => Reduce(1, NT_enum_variant, yy_action_23)
    _ => Error
  }
}

///|
fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_non_empty_type_list => Shift(yy_state_283)
    _ => Error
  }
}

///|
fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_28)
    T_RPAREN => Shift(yy_state_284)
    _ => Error
  }
}

///|
fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_enum_variant, yy_action_22)
}

///|
fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_286)
    T_IDENT | T_RBRACE => Reduce(2, NT_enum_variant, yy_action_21)
    _ => Error
  }
}

///|
fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    NT_type => Shift(yy_state_26)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_non_empty_type_list => Shift(yy_state_287)
    _ => Error
  }
}

///|
fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_28)
    T_RPAREN => Shift(yy_state_288)
    _ => Error
  }
}

///|
fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_enum_variant, yy_action_20)
}

///|
fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_enum_variants, yy_action_19)
}

///|
fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_enum_declaration, yy_action_18)
}

///|
fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_292)
    _ => Error
  }
}

///|
fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_243)
    NT_type_parameters => Shift(yy_state_293)
    T_LBRACE => Reduce(0, NT_type_parameters, yy_action_152)
    _ => Error
  }
}

///|
fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_294)
    _ => Error
  }
}

///|
fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_295)
    T_IDENT | T_TYPE | T_OFFER | T_RBRACE =>
      Reduce(0, NT_struct_members, yy_action_17)
    _ => Error
  }
}

///|
fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OFFER => Shift(yy_state_296)
    NT_field_offer_modifier => Shift(yy_state_297)
    T_TYPE => Shift(yy_state_301)
    NT_field_declaration => Shift(yy_state_305)
    NT_type_member_declaration => Shift(yy_state_306)
    NT_struct_member => Shift(yy_state_307)
    T_RBRACE => Shift(yy_state_308)
    T_IDENT => Reduce(0, NT_field_offer_modifier, yy_action_16)
    _ => Error
  }
}

///|
fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_field_offer_modifier, yy_action_15)
}

///|
fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_298)
    _ => Error
  }
}

///|
fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_299)
    _ => Error
  }
}

///|
fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_300)
    _ => Error
  }
}

///|
fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_field_declaration, yy_action_14)
}

///|
fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_302)
    _ => Error
  }
}

///|
fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_303)
    _ => Error
  }
}

///|
fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    T_LBRACKET => Shift(yy_state_13)
    T_IDENT => Shift(yy_state_18)
    NT_kind => Shift(yy_state_304)
    _ => Error
  }
}

///|
fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_member_declaration, yy_action_13)
}

///|
fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_12)
}

///|
fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member, yy_action_11)
}

///|
fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_struct_members, yy_action_10)
}

///|
fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_struct_declaration, yy_action_9)
}

///|
fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_310)
    _ => Error
  }
}

///|
fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_311)
    _ => Error
  }
}

///|
fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_6)
    T_LPAREN => Shift(yy_state_30)
    T_IDENT => Shift(yy_state_35)
    NT_type_primary => Shift(yy_state_36)
    T_TYPE => Shift(yy_state_37)
    NT_function_type => Shift(yy_state_43)
    NT_type_application => Shift(yy_state_44)
    NT_type_lambda => Shift(yy_state_48)
    NT_type => Shift(yy_state_312)
    _ => Error
  }
}

///|
fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_alias_declaration, yy_action_8)
}

///|
fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_7)
}

///|
fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_6)
}

///|
fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_5)
}

///|
fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_4)
}

///|
fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_3)
}

///|
fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_top_level_declaration, yy_action_2)
}

///|
fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_level_declarations, yy_action_1)
}

///|
fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_source_file, yy_action_0)
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
        (T_DOT, TK_DOT),
        (T_COLON, TK_COLON),
        (T_COLONCOLON, TK_COLONCOLON),
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
