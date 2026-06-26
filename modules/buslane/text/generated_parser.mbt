///|
pub(all) enum Token {
  INT(String)
  STRING(String)
  TYPE_ID(Int)
  TPARAM_ID(Int)
  VALUE_ID(Int)
  DATACON_ID(Int)
  EOF
  BUSLANE
  METADATA
  TYPE
  TYPE_PARAMETER
  VALUE
  DATACON
  PARAMETERS
  CONSTRUCTORS
  OWNER
  HIDDEN
  PAYLOAD
  FUNCTION_KIND
  PARAMETER_KIND
  LOCAL_KIND
  MATCH_BINDER_KIND
  TYPE_KIND
  UNIT_TYPE
  BOOL_TYPE
  INT_TYPE
  STRING_TYPE
  KIND_FN
  APPLY
  TYPE_FN
  FN_TYPE
  FORALL
  LET
  LETREC
  EXTERNAL
  FN
  CALL
  TYPE_APPLY
  CONSTRUCT
  LET_IN
  LETREC_IN
  MATCH
  ALT
  DEFAULT
  LITERAL_ALT
  TRUE
  FALSE
  INT_LITERAL
  STRING_LITERAL
  UNIT_LITERAL
  LBRACE
  RBRACE
  LBRACKET
  RBRACKET
  LPAREN
  RPAREN
  COMMA
  COLON
  SEMI
  EQUAL
  FAT_ARROW
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    INT(_) => TK_INT
    STRING(_) => TK_STRING
    TYPE_ID(_) => TK_TYPE_ID
    TPARAM_ID(_) => TK_TPARAM_ID
    VALUE_ID(_) => TK_VALUE_ID
    DATACON_ID(_) => TK_DATACON_ID
    EOF => TK_EOF
    BUSLANE => TK_BUSLANE
    METADATA => TK_METADATA
    TYPE => TK_TYPE
    TYPE_PARAMETER => TK_TYPE_PARAMETER
    VALUE => TK_VALUE
    DATACON => TK_DATACON
    PARAMETERS => TK_PARAMETERS
    CONSTRUCTORS => TK_CONSTRUCTORS
    OWNER => TK_OWNER
    HIDDEN => TK_HIDDEN
    PAYLOAD => TK_PAYLOAD
    FUNCTION_KIND => TK_FUNCTION_KIND
    PARAMETER_KIND => TK_PARAMETER_KIND
    LOCAL_KIND => TK_LOCAL_KIND
    MATCH_BINDER_KIND => TK_MATCH_BINDER_KIND
    TYPE_KIND => TK_TYPE_KIND
    UNIT_TYPE => TK_UNIT_TYPE
    BOOL_TYPE => TK_BOOL_TYPE
    INT_TYPE => TK_INT_TYPE
    STRING_TYPE => TK_STRING_TYPE
    KIND_FN => TK_KIND_FN
    APPLY => TK_APPLY
    TYPE_FN => TK_TYPE_FN
    FN_TYPE => TK_FN_TYPE
    FORALL => TK_FORALL
    LET => TK_LET
    LETREC => TK_LETREC
    EXTERNAL => TK_EXTERNAL
    FN => TK_FN
    CALL => TK_CALL
    TYPE_APPLY => TK_TYPE_APPLY
    CONSTRUCT => TK_CONSTRUCT
    LET_IN => TK_LET_IN
    LETREC_IN => TK_LETREC_IN
    MATCH => TK_MATCH
    ALT => TK_ALT
    DEFAULT => TK_DEFAULT
    LITERAL_ALT => TK_LITERAL_ALT
    TRUE => TK_TRUE
    FALSE => TK_FALSE
    INT_LITERAL => TK_INT_LITERAL
    STRING_LITERAL => TK_STRING_LITERAL
    UNIT_LITERAL => TK_UNIT_LITERAL
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
    LBRACKET => TK_LBRACKET
    RBRACKET => TK_RBRACKET
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    COMMA => TK_COMMA
    COLON => TK_COLON
    SEMI => TK_SEMI
    EQUAL => TK_EQUAL
    FAT_ARROW => TK_FAT_ARROW
  }
}

///|
pub(all) enum TokenKind {
  TK_INT
  TK_STRING
  TK_TYPE_ID
  TK_TPARAM_ID
  TK_VALUE_ID
  TK_DATACON_ID
  TK_EOF
  TK_BUSLANE
  TK_METADATA
  TK_TYPE
  TK_TYPE_PARAMETER
  TK_VALUE
  TK_DATACON
  TK_PARAMETERS
  TK_CONSTRUCTORS
  TK_OWNER
  TK_HIDDEN
  TK_PAYLOAD
  TK_FUNCTION_KIND
  TK_PARAMETER_KIND
  TK_LOCAL_KIND
  TK_MATCH_BINDER_KIND
  TK_TYPE_KIND
  TK_UNIT_TYPE
  TK_BOOL_TYPE
  TK_INT_TYPE
  TK_STRING_TYPE
  TK_KIND_FN
  TK_APPLY
  TK_TYPE_FN
  TK_FN_TYPE
  TK_FORALL
  TK_LET
  TK_LETREC
  TK_EXTERNAL
  TK_FN
  TK_CALL
  TK_TYPE_APPLY
  TK_CONSTRUCT
  TK_LET_IN
  TK_LETREC_IN
  TK_MATCH
  TK_ALT
  TK_DEFAULT
  TK_LITERAL_ALT
  TK_TRUE
  TK_FALSE
  TK_INT_LITERAL
  TK_STRING_LITERAL
  TK_UNIT_LITERAL
  TK_LBRACE
  TK_RBRACE
  TK_LBRACKET
  TK_RBRACKET
  TK_LPAREN
  TK_RPAREN
  TK_COMMA
  TK_COLON
  TK_SEMI
  TK_EQUAL
  TK_FAT_ARROW
} derive(Eq, Hash, Compare)

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_INT => "INT"
      TK_STRING => "STRING"
      TK_TYPE_ID => "TYPE_ID"
      TK_TPARAM_ID => "TPARAM_ID"
      TK_VALUE_ID => "VALUE_ID"
      TK_DATACON_ID => "DATACON_ID"
      TK_EOF => "EOF"
      TK_BUSLANE => "\"buslane\""
      TK_METADATA => "\"metadata\""
      TK_TYPE => "\"type\""
      TK_TYPE_PARAMETER => "\"type_parameter\""
      TK_VALUE => "\"value\""
      TK_DATACON => "\"datacon\""
      TK_PARAMETERS => "\"parameters\""
      TK_CONSTRUCTORS => "\"constructors\""
      TK_OWNER => "\"owner\""
      TK_HIDDEN => "\"hidden\""
      TK_PAYLOAD => "\"payload\""
      TK_FUNCTION_KIND => "\"function\""
      TK_PARAMETER_KIND => "\"parameter\""
      TK_LOCAL_KIND => "\"local\""
      TK_MATCH_BINDER_KIND => "\"match_binder\""
      TK_TYPE_KIND => "\"Type\""
      TK_UNIT_TYPE => "\"Unit\""
      TK_BOOL_TYPE => "\"Bool\""
      TK_INT_TYPE => "\"Int\""
      TK_STRING_TYPE => "\"String\""
      TK_KIND_FN => "\"kind_fn\""
      TK_APPLY => "\"apply\""
      TK_TYPE_FN => "\"type_fn\""
      TK_FN_TYPE => "\"fn_type\""
      TK_FORALL => "\"forall\""
      TK_LET => "\"let\""
      TK_LETREC => "\"letrec\""
      TK_EXTERNAL => "\"external\""
      TK_FN => "\"fn\""
      TK_CALL => "\"call\""
      TK_TYPE_APPLY => "\"type_apply\""
      TK_CONSTRUCT => "\"construct\""
      TK_LET_IN => "\"let_in\""
      TK_LETREC_IN => "\"letrec_in\""
      TK_MATCH => "\"match\""
      TK_ALT => "\"alt\""
      TK_DEFAULT => "\"default\""
      TK_LITERAL_ALT => "\"literal\""
      TK_TRUE => "\"true\""
      TK_FALSE => "\"false\""
      TK_INT_LITERAL => "\"int\""
      TK_STRING_LITERAL => "\"string\""
      TK_UNIT_LITERAL => "\"unit\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_LBRACKET => "\"[\""
      TK_RBRACKET => "\"]\""
      TK_LPAREN => "\"(\""
      TK_RPAREN => "\")\""
      TK_COMMA => "\",\""
      TK_COLON => "\":\""
      TK_SEMI => "\";\""
      TK_EQUAL => "\"=\""
      TK_FAT_ARROW => "\"=>\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_INT => to_repr("INT")
    TK_STRING => to_repr("STRING")
    TK_TYPE_ID => to_repr("TYPE_ID")
    TK_TPARAM_ID => to_repr("TPARAM_ID")
    TK_VALUE_ID => to_repr("VALUE_ID")
    TK_DATACON_ID => to_repr("DATACON_ID")
    TK_EOF => to_repr("EOF")
    TK_BUSLANE => to_repr("buslane")
    TK_METADATA => to_repr("metadata")
    TK_TYPE => to_repr("type")
    TK_TYPE_PARAMETER => to_repr("type_parameter")
    TK_VALUE => to_repr("value")
    TK_DATACON => to_repr("datacon")
    TK_PARAMETERS => to_repr("parameters")
    TK_CONSTRUCTORS => to_repr("constructors")
    TK_OWNER => to_repr("owner")
    TK_HIDDEN => to_repr("hidden")
    TK_PAYLOAD => to_repr("payload")
    TK_FUNCTION_KIND => to_repr("function")
    TK_PARAMETER_KIND => to_repr("parameter")
    TK_LOCAL_KIND => to_repr("local")
    TK_MATCH_BINDER_KIND => to_repr("match_binder")
    TK_TYPE_KIND => to_repr("Type")
    TK_UNIT_TYPE => to_repr("Unit")
    TK_BOOL_TYPE => to_repr("Bool")
    TK_INT_TYPE => to_repr("Int")
    TK_STRING_TYPE => to_repr("String")
    TK_KIND_FN => to_repr("kind_fn")
    TK_APPLY => to_repr("apply")
    TK_TYPE_FN => to_repr("type_fn")
    TK_FN_TYPE => to_repr("fn_type")
    TK_FORALL => to_repr("forall")
    TK_LET => to_repr("let")
    TK_LETREC => to_repr("letrec")
    TK_EXTERNAL => to_repr("external")
    TK_FN => to_repr("fn")
    TK_CALL => to_repr("call")
    TK_TYPE_APPLY => to_repr("type_apply")
    TK_CONSTRUCT => to_repr("construct")
    TK_LET_IN => to_repr("let_in")
    TK_LETREC_IN => to_repr("letrec_in")
    TK_MATCH => to_repr("match")
    TK_ALT => to_repr("alt")
    TK_DEFAULT => to_repr("default")
    TK_LITERAL_ALT => to_repr("literal")
    TK_TRUE => to_repr("true")
    TK_FALSE => to_repr("false")
    TK_INT_LITERAL => to_repr("int")
    TK_STRING_LITERAL => to_repr("string")
    TK_UNIT_LITERAL => to_repr("unit")
    TK_LBRACE => to_repr("{")
    TK_RBRACE => to_repr("}")
    TK_LBRACKET => to_repr("[")
    TK_RBRACKET => to_repr("]")
    TK_LPAREN => to_repr("(")
    TK_RPAREN => to_repr(")")
    TK_COMMA => to_repr(",")
    TK_COLON => to_repr(":")
    TK_SEMI => to_repr(";")
    TK_EQUAL => to_repr("=")
    TK_FAT_ARROW => to_repr("=>")
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
priv suberror YYObj_Int {
  YYObj_Int(Int)
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
priv suberror YYObj_Array_TopTerm_ {
  YYObj_Array_TopTerm_(Array[TopTerm])
}

///|
priv suberror YYObj_Array_ValueId_ {
  YYObj_Array_ValueId_(Array[ValueId])
}

///|
priv suberror YYObj_Array_DataConId_ {
  YYObj_Array_DataConId_(Array[DataConId])
}

///|
priv suberror YYObj_Array_Alternative_ {
  YYObj_Array_Alternative_(Array[Alternative])
}

///|
priv suberror YYObj_Array_TypeParameterId_ {
  YYObj_Array_TypeParameterId_(Array[TypeParameterId])
}

///|
priv suberror YYObj_Array_RecursiveBinding_ {
  YYObj_Array_RecursiveBinding_(Array[RecursiveBinding])
}

///|
priv suberror YYObj_Array_MetadataDeclaration_ {
  YYObj_Array_MetadataDeclaration_(Array[MetadataDeclaration])
}

///|
priv suberror YYObj_AltCon {
  YYObj_AltCon(AltCon)
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_TypeId {
  YYObj_TypeId(TypeId)
}

///|
priv suberror YYObj_Literal {
  YYObj_Literal(Literal)
}

///|
priv suberror YYObj_Program {
  YYObj_Program(Program)
}

///|
priv suberror YYObj_TopTerm {
  YYObj_TopTerm(TopTerm)
}

///|
priv suberror YYObj_ValueId {
  YYObj_ValueId(ValueId)
}

///|
priv suberror YYObj_DataConId {
  YYObj_DataConId(DataConId)
}

///|
priv suberror YYObj_ValueKind {
  YYObj_ValueKind(ValueKind)
}

///|
priv suberror YYObj_Alternative {
  YYObj_Alternative(Alternative)
}

///|
priv suberror YYObj_PrimitiveType {
  YYObj_PrimitiveType(PrimitiveType)
}

///|
priv suberror YYObj_TypeParameterId {
  YYObj_TypeParameterId(TypeParameterId)
}

///|
priv suberror YYObj_MetadataRegistry {
  YYObj_MetadataRegistry(MetadataRegistry)
}

///|
priv suberror YYObj_RecursiveBinding {
  YYObj_RecursiveBinding(RecursiveBinding)
}

///|
priv suberror YYObj_MetadataDeclaration {
  YYObj_MetadataDeclaration(MetadataDeclaration)
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
  T_TYPE_ID
  T_TPARAM_ID
  T_VALUE_ID
  T_DATACON_ID
  T_EOF
  T_BUSLANE
  T_METADATA
  T_TYPE
  T_TYPE_PARAMETER
  T_VALUE
  T_DATACON
  T_PARAMETERS
  T_CONSTRUCTORS
  T_OWNER
  T_HIDDEN
  T_PAYLOAD
  T_FUNCTION_KIND
  T_PARAMETER_KIND
  T_LOCAL_KIND
  T_MATCH_BINDER_KIND
  T_TYPE_KIND
  T_UNIT_TYPE
  T_BOOL_TYPE
  T_INT_TYPE
  T_STRING_TYPE
  T_KIND_FN
  T_APPLY
  T_TYPE_FN
  T_FN_TYPE
  T_FORALL
  T_LET
  T_LETREC
  T_EXTERNAL
  T_FN
  T_CALL
  T_TYPE_APPLY
  T_CONSTRUCT
  T_LET_IN
  T_LETREC_IN
  T_MATCH
  T_ALT
  T_DEFAULT
  T_LITERAL_ALT
  T_TRUE
  T_FALSE
  T_INT_LITERAL
  T_STRING_LITERAL
  T_UNIT_LITERAL
  T_LBRACE
  T_RBRACE
  T_LBRACKET
  T_RBRACKET
  T_LPAREN
  T_RPAREN
  T_COMMA
  T_COLON
  T_SEMI
  T_EQUAL
  T_FAT_ARROW
  NT_buslane_program
  NT_buslane_type
  NT_metadata
  NT_metadata_declarations
  NT_metadata_declaration
  NT_top_terms
  NT_top_term
  NT_recursive_bindings
  NT_recursive_binding
  NT_expr
  NT_alternatives
  NT_alternative
  NT_alt_con
  NT_literal
  NT_kind
  NT_type
  NT_primitive_type
  NT_value_kind
  NT_kind_list
  NT_non_empty_kind_list
  NT_type_list
  NT_non_empty_type_list
  NT_expr_list
  NT_non_empty_expr_list
  NT_type_parameter_id_list
  NT_non_empty_type_parameter_id_list
  NT_value_id_list
  NT_non_empty_value_id_list
  NT_data_con_id_list
  NT_non_empty_data_con_id_list
  NT_type_id
  NT_type_parameter_id
  NT_value_id
  NT_data_con_id
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
// 76|    "buslane" "{" metadata top_terms "}" EOF {
// 77|    { metadata: $3, terms: $4 }
// 78|  }

///|
fn yy_action_0(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_MetadataRegistry(_dollar3)
  guard _args[3].0 is YYObj_Array_TopTerm_(_dollar4)
  YYObj_Program(
    {
      ()
      { metadata: _dollar3, terms: _dollar4 }
    },
  )
}

// file:///./parser.mbty
// 113|    top_terms top_term { comma_push($1, $2) }

///|
fn yy_action_1(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopTerm_(_dollar1)
  guard _args[1].0 is YYObj_TopTerm(_dollar2)
  YYObj_Array_TopTerm_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 117|    "let" value_id "=" expr ";" { Let($2, $4) }

///|
fn yy_action_2(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  YYObj_TopTerm(
    {
      ()
      Let(_dollar2, _dollar4)
    },
  )
}

// file:///./parser.mbty
// 118|    "letrec" "{" recursive_bindings "}" { LetRec($3) }

///|
fn yy_action_3(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_RecursiveBinding_(_dollar3)
  YYObj_TopTerm(
    {
      ()
      LetRec(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 128|    value_id "=" expr ";" { { id: $1, rhs: $3 } }

///|
fn yy_action_4(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_RecursiveBinding(
    {
      ()
      { id: _dollar1, rhs: _dollar3 }
    },
  )
}

// file:///./parser.mbty
// 154|    "match" "(" expr "," value_id "," type ")" "{" alternatives "}" {
// 155|    Match({ scrutinee: $3, binder: $5, result_type: $7, alternatives: $10 })
// 156|  }

///|
fn yy_action_5(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_ValueId(_dollar5)
  guard _args[6].0 is YYObj_Type(_dollar7)
  guard _args[9].0 is YYObj_Array_Alternative_(_dollar10)
  YYObj_Expr(
    {
      ()
      Match({
        scrutinee: _dollar3,
        binder: _dollar5,
        result_type: _dollar7,
        alternatives: _dollar10,
      })
    },
  )
}

// file:///./parser.mbty
// 161|    alternatives alternative { comma_push($1, $2) }

///|
fn yy_action_6(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_Alternative_(_dollar1)
  guard _args[1].0 is YYObj_Alternative(_dollar2)
  YYObj_Array_Alternative_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 124|    recursive_bindings recursive_binding { comma_push($1, $2) }

///|
fn yy_action_7(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_RecursiveBinding_(_dollar1)
  guard _args[1].0 is YYObj_RecursiveBinding(_dollar2)
  YYObj_Array_RecursiveBinding_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 142|    "construct" "(" data_con_id "," type_list "," type_list "," expr_list ")" {
// 143|    Construct({
// 144|      data_constructor: $3,
// 145|      type_arguments: $5,
// 146|      hidden_witnesses: $7,
// 147|      payloads: $9,
// 148|    })
// 149|  }

///|
fn yy_action_8(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  guard _args[6].0 is YYObj_Array_Type_(_dollar7)
  guard _args[8].0 is YYObj_Array_Expr_(_dollar9)
  YYObj_Expr(
    {
      ()
      Construct({
        data_constructor: _dollar3,
        type_arguments: _dollar5,
        hidden_witnesses: _dollar7,
        payloads: _dollar9,
      })
    },
  )
}

// file:///./parser.mbty
// 236|    "[" "]" { [] }

///|
fn yy_action_9(
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
// 237|    "[" non_empty_expr_list "]" { $2 }

///|
fn yy_action_10(
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
// 132|    value_id { Ref($1) }

///|
fn yy_action_11(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Expr(
    {
      ()
      Ref(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 133|    literal { Literal($1) }

///|
fn yy_action_12(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Literal(_dollar1)
  YYObj_Expr(
    {
      ()
      Literal(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 134|    "fn" "(" value_id_list "," type ")" "{" expr "}" {
// 135|    Function({ parameters: $3, result_type: $5, body: $8 })
// 136|  }

///|
fn yy_action_13(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_ValueId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  guard _args[7].0 is YYObj_Expr(_dollar8)
  YYObj_Expr(
    {
      ()
      Function({ parameters: _dollar3, result_type: _dollar5, body: _dollar8 })
    },
  )
}

// file:///./parser.mbty
// 137|    "call" "(" expr "," expr_list ")" { Call($3, $5) }

///|
fn yy_action_14(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  YYObj_Expr(
    {
      ()
      Call(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 138|    "type_fn" "(" type_parameter_id_list ")" "{" expr "}" {
// 139|    TypeLambda($3, $6)
// 140|  }

///|
fn yy_action_15(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  YYObj_Expr(
    {
      ()
      TypeLambda(_dollar3, _dollar6)
    },
  )
}

// file:///./parser.mbty
// 141|    "type_apply" "(" expr "," type_list ")" { TypeApply($3, $5) }

///|
fn yy_action_16(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  YYObj_Expr(
    {
      ()
      TypeApply(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 242|    non_empty_expr_list "," expr { comma_push($1, $3) }

///|
fn yy_action_17(
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
// 241|    expr { [ $1 ] }

///|
fn yy_action_18(
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
// 150|    "let_in" "(" value_id "," expr "," expr ")" { Let($3, $5, $7) }

///|
fn yy_action_19(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  YYObj_Expr(
    {
      ()
      Let(_dollar3, _dollar5, _dollar7)
    },
  )
}

// file:///./parser.mbty
// 151|    "letrec_in" "(" "{" recursive_bindings "}" "," expr ")" {
// 152|    LetRec($4, $7)
// 153|  }

///|
fn yy_action_20(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[3].0 is YYObj_Array_RecursiveBinding_(_dollar4)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  YYObj_Expr(
    {
      ()
      LetRec(_dollar4, _dollar7)
    },
  )
}

// file:///./parser.mbty
// 165|    "alt" "(" alt_con "," type_parameter_id_list "," value_id_list ")" "=>" expr ";" {
// 166|    { alt_constructor: $3, type_binders: $5, value_binders: $7, body: $10 }
// 167|  }

///|
fn yy_action_21(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_AltCon(_dollar3)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_ValueId_(_dollar7)
  guard _args[9].0 is YYObj_Expr(_dollar10)
  YYObj_Alternative(
    {
      ()
      {
        alt_constructor: _dollar3,
        type_binders: _dollar5,
        value_binders: _dollar7,
        body: _dollar10,
      }
    },
  )
}

// file:///./parser.mbty
// 256|    "[" "]" { [] }

///|
fn yy_action_22(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_ValueId_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 257|    "[" non_empty_value_id_list "]" { $2 }

///|
fn yy_action_23(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_ValueId_(_dollar2)
  YYObj_Array_ValueId_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 262|    non_empty_value_id_list "," value_id { comma_push($1, $3) }

///|
fn yy_action_24(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValueId_(_dollar1)
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  YYObj_Array_ValueId_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 261|    value_id { [ $1 ] }

///|
fn yy_action_25(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Array_ValueId_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 171|    "default" { Default }

///|
fn yy_action_26(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_AltCon(
    {
      ()
      Default
    },
  )
}

// file:///./parser.mbty
// 172|    "literal" "(" literal ")" { Literal($3) }

///|
fn yy_action_27(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Literal(_dollar3)
  YYObj_AltCon(
    {
      ()
      Literal(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 173|    "datacon" "(" data_con_id ")" { DataCon($3) }

///|
fn yy_action_28(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  YYObj_AltCon(
    {
      ()
      DataCon(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 160|    { [] }

///|
fn yy_action_29(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_Alternative_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 177|    "unit" "(" ")" { Unit }

///|
fn yy_action_30(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Literal(
    {
      ()
      Unit
    },
  )
}

// file:///./parser.mbty
// 178|    TRUE { Bool(true) }

///|
fn yy_action_31(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Literal(
    {
      ()
      Bool(true)
    },
  )
}

// file:///./parser.mbty
// 179|    FALSE { Bool(false) }

///|
fn yy_action_32(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Literal(
    {
      ()
      Bool(false)
    },
  )
}

// file:///./parser.mbty
// 180|    "int" "(" INT ")" { Int(@string.parse_int64($3, base=10) catch { _ => 0L }) }

///|
fn yy_action_33(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Literal(
    {
      ()
      Int(@string.parse_int64(_dollar3, base=10) catch { _ => 0L })
    },
  )
}

// file:///./parser.mbty
// 181|    "string" "(" STRING ")" { String($3) }

///|
fn yy_action_34(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Literal(
    {
      ()
      String(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 123|    { [] }

///|
fn yy_action_35(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_RecursiveBinding_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 119|    "external" value_id ";" { External($2) }

///|
fn yy_action_36(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  YYObj_TopTerm(
    {
      ()
      External(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 112|    { [] }

///|
fn yy_action_37(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_TopTerm_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 86|    "metadata" "{" metadata_declarations "}" {
// 87|    make_metadata($3)
// 88|  }

///|
fn yy_action_38(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_MetadataDeclaration_(_dollar3)
  YYObj_MetadataRegistry(
    {
      ()
      make_metadata(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 93|    metadata_declarations metadata_declaration { comma_push($1, $2) }

///|
fn yy_action_39(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_MetadataDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_MetadataDeclaration(_dollar2)
  YYObj_Array_MetadataDeclaration_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 97|    "type" type_id "parameters" type_parameter_id_list "constructors" data_con_id_list ";" {
// 98|    TypeInfoDecl($2, { parameters: $4, constructors: $6 })
// 99|  }

///|
fn yy_action_40(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_TypeId(_dollar2)
  guard _args[3].0 is YYObj_Array_TypeParameterId_(_dollar4)
  guard _args[5].0 is YYObj_Array_DataConId_(_dollar6)
  YYObj_MetadataDeclaration(
    {
      ()
      TypeInfoDecl(_dollar2, { parameters: _dollar4, constructors: _dollar6 })
    },
  )
}

// file:///./parser.mbty
// 266|    "[" "]" { [] }

///|
fn yy_action_41(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_DataConId_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 267|    "[" non_empty_data_con_id_list "]" { $2 }

///|
fn yy_action_42(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_DataConId_(_dollar2)
  YYObj_Array_DataConId_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 272|    non_empty_data_con_id_list "," data_con_id { comma_push($1, $3) }

///|
fn yy_action_43(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_DataConId_(_dollar1)
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  YYObj_Array_DataConId_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 271|    data_con_id { [ $1 ] }

///|
fn yy_action_44(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_DataConId(_dollar1)
  YYObj_Array_DataConId_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 100|    "type_parameter" type_parameter_id ":" kind ";" {
// 101|    TypeParameterInfoDecl($2, { kind: $4 })
// 102|  }

///|
fn yy_action_45(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_TypeParameterId(_dollar2)
  guard _args[3].0 is YYObj_Kind(_dollar4)
  YYObj_MetadataDeclaration(
    {
      ()
      TypeParameterInfoDecl(_dollar2, { kind: _dollar4 })
    },
  )
}

// file:///./parser.mbty
// 186|    "kind_fn" "(" kind_list "," kind ")" { Function($3, $5) }

///|
fn yy_action_46(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_Kind_(_dollar3)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  YYObj_Kind(
    {
      ()
      Function(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 216|    "[" "]" { [] }

///|
fn yy_action_47(
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
// 217|    "[" non_empty_kind_list "]" { $2 }

///|
fn yy_action_48(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  YYObj_Array_Kind_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 185|    "Type" { Type }

///|
fn yy_action_49(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Kind(
    {
      ()
      Type
    },
  )
}

// file:///./parser.mbty
// 222|    non_empty_kind_list "," kind { comma_push($1, $3) }

///|
fn yy_action_50(
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
// 221|    kind { [ $1 ] }

///|
fn yy_action_51(
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
// 103|    "value" value_id value_kind ":" type ";" {
// 104|    ValueInfoDecl($2, { kind: $3, type_: $5 })
// 105|  }

///|
fn yy_action_52(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[2].0 is YYObj_ValueKind(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_MetadataDeclaration(
    {
      ()
      ValueInfoDecl(_dollar2, { kind: _dollar3, type_: _dollar5 })
    },
  )
}

// file:///./parser.mbty
// 207|    "function" { Function }

///|
fn yy_action_53(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      Function
    },
  )
}

// file:///./parser.mbty
// 208|    "value" { Value }

///|
fn yy_action_54(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      Value
    },
  )
}

// file:///./parser.mbty
// 209|    "external" { External }

///|
fn yy_action_55(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      External
    },
  )
}

// file:///./parser.mbty
// 210|    "parameter" { Parameter }

///|
fn yy_action_56(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      Parameter
    },
  )
}

// file:///./parser.mbty
// 211|    "local" { Local }

///|
fn yy_action_57(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      Local
    },
  )
}

// file:///./parser.mbty
// 212|    "match_binder" { MatchBinder }

///|
fn yy_action_58(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_ValueKind(
    {
      ()
      MatchBinder
    },
  )
}

// file:///./parser.mbty
// 284|    VALUE_ID { { index: $1 } }

///|
fn yy_action_59(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_ValueId(
    {
      ()
      { index: _dollar1 }
    },
  )
}

// file:///./parser.mbty
// 106|    "datacon" data_con_id "owner" type_id "hidden" type_parameter_id_list "payload" type_list ";" {
// 107|    DataConInfoDecl($2, { owner: $4, hidden_type_parameters: $6, payload_types: $8 })
// 108|  }

///|
fn yy_action_60(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_DataConId(_dollar2)
  guard _args[3].0 is YYObj_TypeId(_dollar4)
  guard _args[5].0 is YYObj_Array_TypeParameterId_(_dollar6)
  guard _args[7].0 is YYObj_Array_Type_(_dollar8)
  YYObj_MetadataDeclaration(
    {
      ()
      DataConInfoDecl(_dollar2, {
        owner: _dollar4,
        hidden_type_parameters: _dollar6,
        payload_types: _dollar8,
      })
    },
  )
}

// file:///./parser.mbty
// 288|    DATACON_ID { { index: $1 } }

///|
fn yy_action_61(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_DataConId(
    {
      ()
      { index: _dollar1 }
    },
  )
}

// file:///./parser.mbty
// 92|    { [] }

///|
fn yy_action_62(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_MetadataDeclaration_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 82|    type EOF { $1 }

///|
fn yy_action_63(
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
// 195|    "fn_type" "(" type_list "," type ")" { Function($3, $5) }

///|
fn yy_action_64(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type(
    {
      ()
      Function(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 226|    "[" "]" { [] }

///|
fn yy_action_65(
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
// 227|    "[" non_empty_type_list "]" { $2 }

///|
fn yy_action_66(
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
// 190|    primitive_type { Primitive($1) }

///|
fn yy_action_67(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_PrimitiveType(_dollar1)
  YYObj_Type(
    {
      ()
      Primitive(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 191|    type_parameter_id { Parameter($1) }

///|
fn yy_action_68(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Type(
    {
      ()
      Parameter(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 192|    type_id { Constructor($1) }

///|
fn yy_action_69(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeId(_dollar1)
  YYObj_Type(
    {
      ()
      Constructor(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 193|    "apply" "(" type "," type_list ")" { Apply($3, $5) }

///|
fn yy_action_70(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Type(_dollar3)
  guard _args[4].0 is YYObj_Array_Type_(_dollar5)
  YYObj_Type(
    {
      ()
      Apply(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 194|    "type_fn" "(" type_parameter_id_list "," type ")" { TypeLambda($3, $5) }

///|
fn yy_action_71(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type(
    {
      ()
      TypeLambda(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 232|    non_empty_type_list "," type { comma_push($1, $3) }

///|
fn yy_action_72(
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
// 231|    type { [ $1 ] }

///|
fn yy_action_73(
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
// 196|    "forall" "(" type_parameter_id_list "," type ")" { Forall($3, $5) }

///|
fn yy_action_74(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type(
    {
      ()
      Forall(_dollar3, _dollar5)
    },
  )
}

// file:///./parser.mbty
// 246|    "[" "]" { [] }

///|
fn yy_action_75(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_TypeParameterId_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 247|    "[" non_empty_type_parameter_id_list "]" { $2 }

///|
fn yy_action_76(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameterId_(_dollar2)
  YYObj_Array_TypeParameterId_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 252|    non_empty_type_parameter_id_list "," type_parameter_id { comma_push($1, $3) }

///|
fn yy_action_77(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameterId_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameterId(_dollar3)
  YYObj_Array_TypeParameterId_(
    {
      ()
      comma_push(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 251|    type_parameter_id { [ $1 ] }

///|
fn yy_action_78(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Array_TypeParameterId_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 200|    "Unit" { Unit }

///|
fn yy_action_79(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_PrimitiveType(
    {
      ()
      Unit
    },
  )
}

// file:///./parser.mbty
// 201|    "Bool" { Bool }

///|
fn yy_action_80(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_PrimitiveType(
    {
      ()
      Bool
    },
  )
}

// file:///./parser.mbty
// 202|    "Int" { Int }

///|
fn yy_action_81(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_PrimitiveType(
    {
      ()
      Int
    },
  )
}

// file:///./parser.mbty
// 203|    "String" { String }

///|
fn yy_action_82(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_PrimitiveType(
    {
      ()
      String
    },
  )
}

// file:///./parser.mbty
// 276|    TYPE_ID { { index: $1 } }

///|
fn yy_action_83(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeId(
    {
      ()
      { index: _dollar1 }
    },
  )
}

// file:///./parser.mbty
// 280|    TPARAM_ID { { index: $1 } }

///|
fn yy_action_84(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeParameterId(
    {
      ()
      { index: _dollar1 }
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
    TYPE_ID(data) => (T_TYPE_ID, YYObj_Int(data))
    TPARAM_ID(data) => (T_TPARAM_ID, YYObj_Int(data))
    VALUE_ID(data) => (T_VALUE_ID, YYObj_Int(data))
    DATACON_ID(data) => (T_DATACON_ID, YYObj_Int(data))
    EOF => (T_EOF, YYObj_Void)
    BUSLANE => (T_BUSLANE, YYObj_Void)
    METADATA => (T_METADATA, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    TYPE_PARAMETER => (T_TYPE_PARAMETER, YYObj_Void)
    VALUE => (T_VALUE, YYObj_Void)
    DATACON => (T_DATACON, YYObj_Void)
    PARAMETERS => (T_PARAMETERS, YYObj_Void)
    CONSTRUCTORS => (T_CONSTRUCTORS, YYObj_Void)
    OWNER => (T_OWNER, YYObj_Void)
    HIDDEN => (T_HIDDEN, YYObj_Void)
    PAYLOAD => (T_PAYLOAD, YYObj_Void)
    FUNCTION_KIND => (T_FUNCTION_KIND, YYObj_Void)
    PARAMETER_KIND => (T_PARAMETER_KIND, YYObj_Void)
    LOCAL_KIND => (T_LOCAL_KIND, YYObj_Void)
    MATCH_BINDER_KIND => (T_MATCH_BINDER_KIND, YYObj_Void)
    TYPE_KIND => (T_TYPE_KIND, YYObj_Void)
    UNIT_TYPE => (T_UNIT_TYPE, YYObj_Void)
    BOOL_TYPE => (T_BOOL_TYPE, YYObj_Void)
    INT_TYPE => (T_INT_TYPE, YYObj_Void)
    STRING_TYPE => (T_STRING_TYPE, YYObj_Void)
    KIND_FN => (T_KIND_FN, YYObj_Void)
    APPLY => (T_APPLY, YYObj_Void)
    TYPE_FN => (T_TYPE_FN, YYObj_Void)
    FN_TYPE => (T_FN_TYPE, YYObj_Void)
    FORALL => (T_FORALL, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    LETREC => (T_LETREC, YYObj_Void)
    EXTERNAL => (T_EXTERNAL, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    CALL => (T_CALL, YYObj_Void)
    TYPE_APPLY => (T_TYPE_APPLY, YYObj_Void)
    CONSTRUCT => (T_CONSTRUCT, YYObj_Void)
    LET_IN => (T_LET_IN, YYObj_Void)
    LETREC_IN => (T_LETREC_IN, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
    ALT => (T_ALT, YYObj_Void)
    DEFAULT => (T_DEFAULT, YYObj_Void)
    LITERAL_ALT => (T_LITERAL_ALT, YYObj_Void)
    TRUE => (T_TRUE, YYObj_Void)
    FALSE => (T_FALSE, YYObj_Void)
    INT_LITERAL => (T_INT_LITERAL, YYObj_Void)
    STRING_LITERAL => (T_STRING_LITERAL, YYObj_Void)
    UNIT_LITERAL => (T_UNIT_LITERAL, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    LBRACKET => (T_LBRACKET, YYObj_Void)
    RBRACKET => (T_RBRACKET, YYObj_Void)
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    EQUAL => (T_EQUAL, YYObj_Void)
    FAT_ARROW => (T_FAT_ARROW, YYObj_Void)
  }
}

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_type => Shift(yy_state_1)
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    NT_type => Shift(yy_state_49)
    _ => Error
  }
}

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameter_id, yy_action_84)
}

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_id, yy_action_83)
}

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_82)
}

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_81)
}

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_80)
}

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_79)
}

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_9)
    _ => Error
  }
}

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_17)
    _ => Error
  }
}

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_11)
    NT_non_empty_type_parameter_id_list => Shift(yy_state_12)
    T_RBRACKET => Shift(yy_state_16)
    _ => Error
  }
}

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_id_list, yy_action_78)
}

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_13)
    T_RBRACKET => Shift(yy_state_15)
    _ => Error
  }
}

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_14)
    _ => Error
  }
}

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_id_list, yy_action_77)
}

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_id_list, yy_action_76)
}

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_parameter_id_list, yy_action_75)
}

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_18)
    _ => Error
  }
}

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    NT_type => Shift(yy_state_19)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    _ => Error
  }
}

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_20)
    _ => Error
  }
}

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_74)
}

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_22)
    _ => Error
  }
}

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_45)
    _ => Error
  }
}

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    NT_type => Shift(yy_state_24)
    NT_non_empty_type_list => Shift(yy_state_25)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    T_RBRACKET => Shift(yy_state_44)
    _ => Error
  }
}

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_73)
}

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_26)
    T_RBRACKET => Shift(yy_state_43)
    _ => Error
  }
}

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    NT_type => Shift(yy_state_27)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    _ => Error
  }
}

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_72)
}

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_29)
    _ => Error
  }
}

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_30)
    _ => Error
  }
}

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_31)
    _ => Error
  }
}

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    NT_type => Shift(yy_state_32)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    _ => Error
  }
}

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_33)
    _ => Error
  }
}

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_71)
}

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_35)
    _ => Error
  }
}

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type => Shift(yy_state_36)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    _ => Error
  }
}

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_37)
    _ => Error
  }
}

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_38)
    _ => Error
  }
}

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_39)
    _ => Error
  }
}

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_70)
}

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_69)
}

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_68)
}

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_67)
}

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_list, yy_action_66)
}

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_list, yy_action_65)
}

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_46)
    _ => Error
  }
}

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    NT_type => Shift(yy_state_47)
    _ => Error
  }
}

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_48)
    _ => Error
  }
}

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_64)
}

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_50)
    _ => Error
  }
}

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_buslane_type, yy_action_63)
}

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_program => Shift(yy_state_52)
    T_BUSLANE => Shift(yy_state_53)
    _ => Error
  }
}

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_54)
    _ => Error
  }
}

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_METADATA => Shift(yy_state_55)
    NT_metadata => Shift(yy_state_116)
    _ => Error
  }
}

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_56)
    _ => Error
  }
}

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_metadata_declarations => Shift(yy_state_57)
    T_TYPE | T_TYPE_PARAMETER | T_VALUE | T_DATACON | T_RBRACE =>
      Reduce(0, NT_metadata_declarations, yy_action_62)
    _ => Error
  }
}

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON => Shift(yy_state_58)
    T_VALUE => Shift(yy_state_68)
    T_TYPE_PARAMETER => Shift(yy_state_81)
    T_TYPE => Shift(yy_state_100)
    NT_metadata_declaration => Shift(yy_state_114)
    T_RBRACE => Shift(yy_state_115)
    _ => Error
  }
}

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_59)
    NT_data_con_id => Shift(yy_state_60)
    _ => Error
  }
}

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_con_id, yy_action_61)
}

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER => Shift(yy_state_61)
    _ => Error
  }
}

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_62)
    _ => Error
  }
}

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_HIDDEN => Shift(yy_state_63)
    _ => Error
  }
}

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_64)
    _ => Error
  }
}

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PAYLOAD => Shift(yy_state_65)
    _ => Error
  }
}

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_66)
    _ => Error
  }
}

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_67)
    _ => Error
  }
}

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_metadata_declaration, yy_action_60)
}

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_70)
    _ => Error
  }
}

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_id, yy_action_59)
}

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MATCH_BINDER_KIND => Shift(yy_state_71)
    T_LOCAL_KIND => Shift(yy_state_72)
    T_PARAMETER_KIND => Shift(yy_state_73)
    T_EXTERNAL => Shift(yy_state_74)
    T_VALUE => Shift(yy_state_75)
    T_FUNCTION_KIND => Shift(yy_state_76)
    NT_value_kind => Shift(yy_state_77)
    _ => Error
  }
}

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_58)
}

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_57)
}

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_56)
}

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_55)
}

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_54)
}

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_53)
}

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_78)
    _ => Error
  }
}

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    NT_type => Shift(yy_state_79)
    _ => Error
  }
}

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_80)
    _ => Error
  }
}

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_metadata_declaration, yy_action_52)
}

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_82)
    _ => Error
  }
}

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_83)
    _ => Error
  }
}

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_84)
    T_TYPE_KIND => Shift(yy_state_91)
    NT_kind => Shift(yy_state_98)
    _ => Error
  }
}

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_85)
    _ => Error
  }
}

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_86)
    NT_kind_list => Shift(yy_state_94)
    _ => Error
  }
}

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_84)
    NT_kind => Shift(yy_state_87)
    NT_non_empty_kind_list => Shift(yy_state_88)
    T_TYPE_KIND => Shift(yy_state_91)
    T_RBRACKET => Shift(yy_state_93)
    _ => Error
  }
}

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_51)
}

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_89)
    T_RBRACKET => Shift(yy_state_92)
    _ => Error
  }
}

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_84)
    NT_kind => Shift(yy_state_90)
    T_TYPE_KIND => Shift(yy_state_91)
    _ => Error
  }
}

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_50)
}

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_49)
}

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind_list, yy_action_48)
}

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_kind_list, yy_action_47)
}

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_95)
    _ => Error
  }
}

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_84)
    T_TYPE_KIND => Shift(yy_state_91)
    NT_kind => Shift(yy_state_96)
    _ => Error
  }
}

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_97)
    _ => Error
  }
}

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_kind, yy_action_46)
}

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_99)
    _ => Error
  }
}

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_metadata_declaration, yy_action_45)
}

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_101)
    _ => Error
  }
}

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PARAMETERS => Shift(yy_state_102)
    _ => Error
  }
}

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_103)
    _ => Error
  }
}

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CONSTRUCTORS => Shift(yy_state_104)
    _ => Error
  }
}

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_105)
    NT_data_con_id_list => Shift(yy_state_112)
    _ => Error
  }
}

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_59)
    NT_data_con_id => Shift(yy_state_106)
    NT_non_empty_data_con_id_list => Shift(yy_state_107)
    T_RBRACKET => Shift(yy_state_111)
    _ => Error
  }
}

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_data_con_id_list, yy_action_44)
}

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_108)
    T_RBRACKET => Shift(yy_state_110)
    _ => Error
  }
}

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_59)
    NT_data_con_id => Shift(yy_state_109)
    _ => Error
  }
}

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_data_con_id_list, yy_action_43)
}

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_data_con_id_list, yy_action_42)
}

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_data_con_id_list, yy_action_41)
}

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_113)
    _ => Error
  }
}

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_metadata_declaration, yy_action_40)
}

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_metadata_declarations, yy_action_39)
}

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_metadata, yy_action_38)
}

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_top_terms => Shift(yy_state_117)
    T_LET | T_LETREC | T_EXTERNAL | T_RBRACE =>
      Reduce(0, NT_top_terms, yy_action_37)
    _ => Error
  }
}

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERNAL => Shift(yy_state_118)
    T_LETREC => Shift(yy_state_121)
    T_LET => Shift(yy_state_245)
    NT_top_term => Shift(yy_state_250)
    T_RBRACE => Shift(yy_state_251)
    _ => Error
  }
}

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_119)
    _ => Error
  }
}

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_120)
    _ => Error
  }
}

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_top_term, yy_action_36)
}

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_122)
    _ => Error
  }
}

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_123)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_35)
    _ => Error
  }
}

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_124)
    NT_recursive_binding => Shift(yy_state_239)
    T_RBRACE => Shift(yy_state_244)
    _ => Error
  }
}

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_125)
    _ => Error
  }
}

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    NT_expr => Shift(yy_state_242)
    _ => Error
  }
}

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_127)
    _ => Error
  }
}

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_128)
    _ => Error
  }
}

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_129)
    _ => Error
  }
}

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_literal, yy_action_34)
}

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_131)
    _ => Error
  }
}

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_132)
    _ => Error
  }
}

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_133)
    _ => Error
  }
}

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_literal, yy_action_33)
}

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_32)
}

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_31)
}

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_137)
    _ => Error
  }
}

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_138)
    _ => Error
  }
}

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_literal, yy_action_30)
}

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_140)
    _ => Error
  }
}

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    NT_expr => Shift(yy_state_141)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_142)
    _ => Error
  }
}

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_143)
    _ => Error
  }
}

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_144)
    _ => Error
  }
}

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    NT_type => Shift(yy_state_145)
    _ => Error
  }
}

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_146)
    _ => Error
  }
}

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_147)
    _ => Error
  }
}

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_alternatives => Shift(yy_state_148)
    T_ALT | T_RBRACE => Reduce(0, NT_alternatives, yy_action_29)
    _ => Error
  }
}

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ALT => Shift(yy_state_149)
    NT_alternative => Shift(yy_state_240)
    T_RBRACE => Shift(yy_state_241)
    _ => Error
  }
}

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_150)
    _ => Error
  }
}

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON => Shift(yy_state_151)
    T_LITERAL_ALT => Shift(yy_state_155)
    T_DEFAULT => Shift(yy_state_159)
    NT_alt_con => Shift(yy_state_160)
    _ => Error
  }
}

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_152)
    _ => Error
  }
}

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_59)
    NT_data_con_id => Shift(yy_state_153)
    _ => Error
  }
}

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_154)
    _ => Error
  }
}

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_alt_con, yy_action_28)
}

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_156)
    _ => Error
  }
}

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    NT_literal => Shift(yy_state_157)
    _ => Error
  }
}

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_158)
    _ => Error
  }
}

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_alt_con, yy_action_27)
}

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_alt_con, yy_action_26)
}

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_161)
    _ => Error
  }
}

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_162)
    _ => Error
  }
}

///|
fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_163)
    _ => Error
  }
}

///|
fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_164)
    NT_value_id_list => Shift(yy_state_171)
    _ => Error
  }
}

///|
fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_165)
    NT_non_empty_value_id_list => Shift(yy_state_166)
    T_RBRACKET => Shift(yy_state_170)
    _ => Error
  }
}

///|
fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_value_id_list, yy_action_25)
}

///|
fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_167)
    T_RBRACKET => Shift(yy_state_169)
    _ => Error
  }
}

///|
fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_168)
    _ => Error
  }
}

///|
fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_value_id_list, yy_action_24)
}

///|
fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_value_id_list, yy_action_23)
}

///|
fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value_id_list, yy_action_22)
}

///|
fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_172)
    _ => Error
  }
}

///|
fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_173)
    _ => Error
  }
}

///|
fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    NT_expr => Shift(yy_state_174)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_175)
    _ => Error
  }
}

///|
fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(11, NT_alternative, yy_action_21)
}

///|
fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_177)
    _ => Error
  }
}

///|
fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_178)
    _ => Error
  }
}

///|
fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_179)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_35)
    _ => Error
  }
}

///|
fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_124)
    T_RBRACE => Shift(yy_state_180)
    NT_recursive_binding => Shift(yy_state_239)
    _ => Error
  }
}

///|
fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_181)
    _ => Error
  }
}

///|
fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    NT_expr => Shift(yy_state_182)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_183)
    _ => Error
  }
}

///|
fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expr, yy_action_20)
}

///|
fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_185)
    _ => Error
  }
}

///|
fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_186)
    _ => Error
  }
}

///|
fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_187)
    _ => Error
  }
}

///|
fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    NT_expr => Shift(yy_state_188)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_189)
    _ => Error
  }
}

///|
fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    NT_expr => Shift(yy_state_190)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_191)
    _ => Error
  }
}

///|
fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expr, yy_action_19)
}

///|
fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_193)
    _ => Error
  }
}

///|
fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_59)
    NT_data_con_id => Shift(yy_state_194)
    _ => Error
  }
}

///|
fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_195)
    _ => Error
  }
}

///|
fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_196)
    _ => Error
  }
}

///|
fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_197)
    _ => Error
  }
}

///|
fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_198)
    _ => Error
  }
}

///|
fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_199)
    _ => Error
  }
}

///|
fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_200)
    NT_expr_list => Shift(yy_state_237)
    _ => Error
  }
}

///|
fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    NT_expr => Shift(yy_state_201)
    NT_non_empty_expr_list => Shift(yy_state_202)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    T_RBRACKET => Shift(yy_state_236)
    _ => Error
  }
}

///|
fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_expr_list, yy_action_18)
}

///|
fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_203)
    T_RBRACKET => Shift(yy_state_235)
    _ => Error
  }
}

///|
fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    NT_expr => Shift(yy_state_204)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_expr_list, yy_action_17)
}

///|
fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_206)
    _ => Error
  }
}

///|
fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    NT_expr => Shift(yy_state_207)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_208)
    _ => Error
  }
}

///|
fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_23)
    NT_type_list => Shift(yy_state_209)
    _ => Error
  }
}

///|
fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_210)
    _ => Error
  }
}

///|
fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_16)
}

///|
fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_212)
    _ => Error
  }
}

///|
fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_10)
    NT_type_parameter_id_list => Shift(yy_state_213)
    _ => Error
  }
}

///|
fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_214)
    _ => Error
  }
}

///|
fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_215)
    _ => Error
  }
}

///|
fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    NT_expr => Shift(yy_state_216)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_217)
    _ => Error
  }
}

///|
fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_expr, yy_action_15)
}

///|
fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_219)
    _ => Error
  }
}

///|
fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    NT_expr => Shift(yy_state_220)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_221)
    _ => Error
  }
}

///|
fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_200)
    NT_expr_list => Shift(yy_state_222)
    _ => Error
  }
}

///|
fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_223)
    _ => Error
  }
}

///|
fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_14)
}

///|
fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_225)
    _ => Error
  }
}

///|
fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_164)
    NT_value_id_list => Shift(yy_state_226)
    _ => Error
  }
}

///|
fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_227)
    _ => Error
  }
}

///|
fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_INT_TYPE => Shift(yy_state_5)
    T_BOOL_TYPE => Shift(yy_state_6)
    T_UNIT_TYPE => Shift(yy_state_7)
    T_FORALL => Shift(yy_state_8)
    T_FN_TYPE => Shift(yy_state_21)
    T_TYPE_FN => Shift(yy_state_28)
    T_APPLY => Shift(yy_state_34)
    NT_type_id => Shift(yy_state_40)
    NT_type_parameter_id => Shift(yy_state_41)
    NT_primitive_type => Shift(yy_state_42)
    NT_type => Shift(yy_state_228)
    _ => Error
  }
}

///|
fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_229)
    _ => Error
  }
}

///|
fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_230)
    _ => Error
  }
}

///|
fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_expr => Shift(yy_state_231)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    _ => Error
  }
}

///|
fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_232)
    _ => Error
  }
}

///|
fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_expr, yy_action_13)
}

///|
fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expr, yy_action_12)
}

///|
fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expr, yy_action_11)
}

///|
fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expr_list, yy_action_10)
}

///|
fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_expr_list, yy_action_9)
}

///|
fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_238)
    _ => Error
  }
}

///|
fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_expr, yy_action_8)
}

///|
fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_recursive_bindings, yy_action_7)
}

///|
fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alternatives, yy_action_6)
}

///|
fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(11, NT_expr, yy_action_5)
}

///|
fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_243)
    _ => Error
  }
}

///|
fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_recursive_binding, yy_action_4)
}

///|
fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_top_term, yy_action_3)
}

///|
fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    NT_value_id => Shift(yy_state_246)
    _ => Error
  }
}

///|
fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_247)
    _ => Error
  }
}

///|
fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_69)
    T_STRING_LITERAL => Shift(yy_state_126)
    T_INT_LITERAL => Shift(yy_state_130)
    T_FALSE => Shift(yy_state_134)
    T_TRUE => Shift(yy_state_135)
    T_UNIT_LITERAL => Shift(yy_state_136)
    T_MATCH => Shift(yy_state_139)
    T_LETREC_IN => Shift(yy_state_176)
    T_LET_IN => Shift(yy_state_184)
    T_CONSTRUCT => Shift(yy_state_192)
    T_TYPE_APPLY => Shift(yy_state_205)
    T_TYPE_FN => Shift(yy_state_211)
    T_CALL => Shift(yy_state_218)
    T_FN => Shift(yy_state_224)
    NT_literal => Shift(yy_state_233)
    NT_value_id => Shift(yy_state_234)
    NT_expr => Shift(yy_state_248)
    _ => Error
  }
}

///|
fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_249)
    _ => Error
  }
}

///|
fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_top_term, yy_action_2)
}

///|
fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_terms, yy_action_1)
}

///|
fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_252)
    _ => Error
  }
}

///|
fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_buslane_program, yy_action_0)
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
        (T_TYPE_ID, TK_TYPE_ID),
        (T_TPARAM_ID, TK_TPARAM_ID),
        (T_VALUE_ID, TK_VALUE_ID),
        (T_DATACON_ID, TK_DATACON_ID),
        (T_EOF, TK_EOF),
        (T_BUSLANE, TK_BUSLANE),
        (T_METADATA, TK_METADATA),
        (T_TYPE, TK_TYPE),
        (T_TYPE_PARAMETER, TK_TYPE_PARAMETER),
        (T_VALUE, TK_VALUE),
        (T_DATACON, TK_DATACON),
        (T_PARAMETERS, TK_PARAMETERS),
        (T_CONSTRUCTORS, TK_CONSTRUCTORS),
        (T_OWNER, TK_OWNER),
        (T_HIDDEN, TK_HIDDEN),
        (T_PAYLOAD, TK_PAYLOAD),
        (T_FUNCTION_KIND, TK_FUNCTION_KIND),
        (T_PARAMETER_KIND, TK_PARAMETER_KIND),
        (T_LOCAL_KIND, TK_LOCAL_KIND),
        (T_MATCH_BINDER_KIND, TK_MATCH_BINDER_KIND),
        (T_TYPE_KIND, TK_TYPE_KIND),
        (T_UNIT_TYPE, TK_UNIT_TYPE),
        (T_BOOL_TYPE, TK_BOOL_TYPE),
        (T_INT_TYPE, TK_INT_TYPE),
        (T_STRING_TYPE, TK_STRING_TYPE),
        (T_KIND_FN, TK_KIND_FN),
        (T_APPLY, TK_APPLY),
        (T_TYPE_FN, TK_TYPE_FN),
        (T_FN_TYPE, TK_FN_TYPE),
        (T_FORALL, TK_FORALL),
        (T_LET, TK_LET),
        (T_LETREC, TK_LETREC),
        (T_EXTERNAL, TK_EXTERNAL),
        (T_FN, TK_FN),
        (T_CALL, TK_CALL),
        (T_TYPE_APPLY, TK_TYPE_APPLY),
        (T_CONSTRUCT, TK_CONSTRUCT),
        (T_LET_IN, TK_LET_IN),
        (T_LETREC_IN, TK_LETREC_IN),
        (T_MATCH, TK_MATCH),
        (T_ALT, TK_ALT),
        (T_DEFAULT, TK_DEFAULT),
        (T_LITERAL_ALT, TK_LITERAL_ALT),
        (T_TRUE, TK_TRUE),
        (T_FALSE, TK_FALSE),
        (T_INT_LITERAL, TK_INT_LITERAL),
        (T_STRING_LITERAL, TK_STRING_LITERAL),
        (T_UNIT_LITERAL, TK_UNIT_LITERAL),
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_LBRACKET, TK_LBRACKET),
        (T_RBRACKET, TK_RBRACKET),
        (T_LPAREN, TK_LPAREN),
        (T_RPAREN, TK_RPAREN),
        (T_COMMA, TK_COMMA),
        (T_COLON, TK_COLON),
        (T_SEMI, TK_SEMI),
        (T_EQUAL, TK_EQUAL),
        (T_FAT_ARROW, TK_FAT_ARROW),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn buslane_program(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  initial_pos? : SourceSpan,
) -> Program raise ParseError {
  yy_parse(
    tokens,
    yy_state_51,
    it => {
      guard it is YYObj_Program(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn buslane_type(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  initial_pos? : SourceSpan,
) -> Type raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_Type(result)
      result
    },
    initial_pos?,
  )
}
