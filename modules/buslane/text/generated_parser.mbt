
pub(all) enum Token {
  INT(String)
  DOUBLE(String)
  STRING(String)
  TYPE_ID(Int)
  TPARAM_ID(Int)
  VALUE_ID(Int)
  DATACON_ID(Int)
  EFFECT_ID(Int)
  OPERATION_ID(Int)
  EOF
  BUSLANE
  METADATA
  TYPE
  TYPE_PARAMETER
  VALUE
  DATACON
  EFFECT_DECL
  OPERATION
  NAME
  UNIQUE
  PARAMETERS
  CONSTRUCTORS
  OPERATIONS
  OWNER
  HIDDEN
  PAYLOAD
  RESULT
  FUNCTION_KIND
  PARAMETER_KIND
  LOCAL_KIND
  MATCH_BINDER_KIND
  TYPE_KIND
  EFFECT_KIND
  UNIT_TYPE
  BOOL_TYPE
  INT_TYPE
  DOUBLE_TYPE
  STRING_TYPE
  KIND_FN
  EMPTY_EFFECT
  EFFECT_SINGLETON
  EFFECT_UNION
  APPLY
  TYPE_FN
  FN_TYPE
  FORALL
  LET
  LETREC
  EXTERNAL
  FN
  CALL
  PERFORM
  HANDLE
  RESUME
  HANDLER
  OP_ALT
  FINAL
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
  DOUBLE_LITERAL
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

pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    INT(_) => TK_INT
    DOUBLE(_) => TK_DOUBLE
    STRING(_) => TK_STRING
    TYPE_ID(_) => TK_TYPE_ID
    TPARAM_ID(_) => TK_TPARAM_ID
    VALUE_ID(_) => TK_VALUE_ID
    DATACON_ID(_) => TK_DATACON_ID
    EFFECT_ID(_) => TK_EFFECT_ID
    OPERATION_ID(_) => TK_OPERATION_ID
    EOF => TK_EOF
    BUSLANE => TK_BUSLANE
    METADATA => TK_METADATA
    TYPE => TK_TYPE
    TYPE_PARAMETER => TK_TYPE_PARAMETER
    VALUE => TK_VALUE
    DATACON => TK_DATACON
    EFFECT_DECL => TK_EFFECT_DECL
    OPERATION => TK_OPERATION
    NAME => TK_NAME
    UNIQUE => TK_UNIQUE
    PARAMETERS => TK_PARAMETERS
    CONSTRUCTORS => TK_CONSTRUCTORS
    OPERATIONS => TK_OPERATIONS
    OWNER => TK_OWNER
    HIDDEN => TK_HIDDEN
    PAYLOAD => TK_PAYLOAD
    RESULT => TK_RESULT
    FUNCTION_KIND => TK_FUNCTION_KIND
    PARAMETER_KIND => TK_PARAMETER_KIND
    LOCAL_KIND => TK_LOCAL_KIND
    MATCH_BINDER_KIND => TK_MATCH_BINDER_KIND
    TYPE_KIND => TK_TYPE_KIND
    EFFECT_KIND => TK_EFFECT_KIND
    UNIT_TYPE => TK_UNIT_TYPE
    BOOL_TYPE => TK_BOOL_TYPE
    INT_TYPE => TK_INT_TYPE
    DOUBLE_TYPE => TK_DOUBLE_TYPE
    STRING_TYPE => TK_STRING_TYPE
    KIND_FN => TK_KIND_FN
    EMPTY_EFFECT => TK_EMPTY_EFFECT
    EFFECT_SINGLETON => TK_EFFECT_SINGLETON
    EFFECT_UNION => TK_EFFECT_UNION
    APPLY => TK_APPLY
    TYPE_FN => TK_TYPE_FN
    FN_TYPE => TK_FN_TYPE
    FORALL => TK_FORALL
    LET => TK_LET
    LETREC => TK_LETREC
    EXTERNAL => TK_EXTERNAL
    FN => TK_FN
    CALL => TK_CALL
    PERFORM => TK_PERFORM
    HANDLE => TK_HANDLE
    RESUME => TK_RESUME
    HANDLER => TK_HANDLER
    OP_ALT => TK_OP_ALT
    FINAL => TK_FINAL
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
    DOUBLE_LITERAL => TK_DOUBLE_LITERAL
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

pub(all) enum TokenKind {
  TK_INT
  TK_DOUBLE
  TK_STRING
  TK_TYPE_ID
  TK_TPARAM_ID
  TK_VALUE_ID
  TK_DATACON_ID
  TK_EFFECT_ID
  TK_OPERATION_ID
  TK_EOF
  TK_BUSLANE
  TK_METADATA
  TK_TYPE
  TK_TYPE_PARAMETER
  TK_VALUE
  TK_DATACON
  TK_EFFECT_DECL
  TK_OPERATION
  TK_NAME
  TK_UNIQUE
  TK_PARAMETERS
  TK_CONSTRUCTORS
  TK_OPERATIONS
  TK_OWNER
  TK_HIDDEN
  TK_PAYLOAD
  TK_RESULT
  TK_FUNCTION_KIND
  TK_PARAMETER_KIND
  TK_LOCAL_KIND
  TK_MATCH_BINDER_KIND
  TK_TYPE_KIND
  TK_EFFECT_KIND
  TK_UNIT_TYPE
  TK_BOOL_TYPE
  TK_INT_TYPE
  TK_DOUBLE_TYPE
  TK_STRING_TYPE
  TK_KIND_FN
  TK_EMPTY_EFFECT
  TK_EFFECT_SINGLETON
  TK_EFFECT_UNION
  TK_APPLY
  TK_TYPE_FN
  TK_FN_TYPE
  TK_FORALL
  TK_LET
  TK_LETREC
  TK_EXTERNAL
  TK_FN
  TK_CALL
  TK_PERFORM
  TK_HANDLE
  TK_RESUME
  TK_HANDLER
  TK_OP_ALT
  TK_FINAL
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
  TK_DOUBLE_LITERAL
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

pub impl Show for TokenKind with output(self, logger) {
  logger.write_string(
    match self {
      TK_INT => "INT"
      TK_DOUBLE => "DOUBLE"
      TK_STRING => "STRING"
      TK_TYPE_ID => "TYPE_ID"
      TK_TPARAM_ID => "TPARAM_ID"
      TK_VALUE_ID => "VALUE_ID"
      TK_DATACON_ID => "DATACON_ID"
      TK_EFFECT_ID => "EFFECT_ID"
      TK_OPERATION_ID => "OPERATION_ID"
      TK_EOF => "EOF"
      TK_BUSLANE => "\"buslane\""
      TK_METADATA => "\"metadata\""
      TK_TYPE => "\"type\""
      TK_TYPE_PARAMETER => "\"type_parameter\""
      TK_VALUE => "\"value\""
      TK_DATACON => "\"datacon\""
      TK_EFFECT_DECL => "\"effect\""
      TK_OPERATION => "\"operation\""
      TK_NAME => "\"name\""
      TK_UNIQUE => "\"unique\""
      TK_PARAMETERS => "\"parameters\""
      TK_CONSTRUCTORS => "\"constructors\""
      TK_OPERATIONS => "\"operations\""
      TK_OWNER => "\"owner\""
      TK_HIDDEN => "\"hidden\""
      TK_PAYLOAD => "\"payload\""
      TK_RESULT => "\"result\""
      TK_FUNCTION_KIND => "\"function\""
      TK_PARAMETER_KIND => "\"parameter\""
      TK_LOCAL_KIND => "\"local\""
      TK_MATCH_BINDER_KIND => "\"match_binder\""
      TK_TYPE_KIND => "\"Type\""
      TK_EFFECT_KIND => "\"Effect\""
      TK_UNIT_TYPE => "\"Unit\""
      TK_BOOL_TYPE => "\"Bool\""
      TK_INT_TYPE => "\"Int\""
      TK_DOUBLE_TYPE => "\"Double\""
      TK_STRING_TYPE => "\"String\""
      TK_KIND_FN => "\"kind_fn\""
      TK_EMPTY_EFFECT => "\"empty_effect\""
      TK_EFFECT_SINGLETON => "\"effect_singleton\""
      TK_EFFECT_UNION => "\"effect_union\""
      TK_APPLY => "\"apply\""
      TK_TYPE_FN => "\"type_fn\""
      TK_FN_TYPE => "\"fn_type\""
      TK_FORALL => "\"forall\""
      TK_LET => "\"let\""
      TK_LETREC => "\"letrec\""
      TK_EXTERNAL => "\"external\""
      TK_FN => "\"fn\""
      TK_CALL => "\"call\""
      TK_PERFORM => "\"perform\""
      TK_HANDLE => "\"handle\""
      TK_RESUME => "\"resume\""
      TK_HANDLER => "\"handler\""
      TK_OP_ALT => "\"op_alt\""
      TK_FINAL => "\"final\""
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
      TK_DOUBLE_LITERAL => "\"double\""
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
    }
  )
}

pub impl Debug for TokenKind with to_repr(self) {
    match self {
      TK_INT => to_repr("INT")
      TK_DOUBLE => to_repr("DOUBLE")
      TK_STRING => to_repr("STRING")
      TK_TYPE_ID => to_repr("TYPE_ID")
      TK_TPARAM_ID => to_repr("TPARAM_ID")
      TK_VALUE_ID => to_repr("VALUE_ID")
      TK_DATACON_ID => to_repr("DATACON_ID")
      TK_EFFECT_ID => to_repr("EFFECT_ID")
      TK_OPERATION_ID => to_repr("OPERATION_ID")
      TK_EOF => to_repr("EOF")
      TK_BUSLANE => to_repr("buslane")
      TK_METADATA => to_repr("metadata")
      TK_TYPE => to_repr("type")
      TK_TYPE_PARAMETER => to_repr("type_parameter")
      TK_VALUE => to_repr("value")
      TK_DATACON => to_repr("datacon")
      TK_EFFECT_DECL => to_repr("effect")
      TK_OPERATION => to_repr("operation")
      TK_NAME => to_repr("name")
      TK_UNIQUE => to_repr("unique")
      TK_PARAMETERS => to_repr("parameters")
      TK_CONSTRUCTORS => to_repr("constructors")
      TK_OPERATIONS => to_repr("operations")
      TK_OWNER => to_repr("owner")
      TK_HIDDEN => to_repr("hidden")
      TK_PAYLOAD => to_repr("payload")
      TK_RESULT => to_repr("result")
      TK_FUNCTION_KIND => to_repr("function")
      TK_PARAMETER_KIND => to_repr("parameter")
      TK_LOCAL_KIND => to_repr("local")
      TK_MATCH_BINDER_KIND => to_repr("match_binder")
      TK_TYPE_KIND => to_repr("Type")
      TK_EFFECT_KIND => to_repr("Effect")
      TK_UNIT_TYPE => to_repr("Unit")
      TK_BOOL_TYPE => to_repr("Bool")
      TK_INT_TYPE => to_repr("Int")
      TK_DOUBLE_TYPE => to_repr("Double")
      TK_STRING_TYPE => to_repr("String")
      TK_KIND_FN => to_repr("kind_fn")
      TK_EMPTY_EFFECT => to_repr("empty_effect")
      TK_EFFECT_SINGLETON => to_repr("effect_singleton")
      TK_EFFECT_UNION => to_repr("effect_union")
      TK_APPLY => to_repr("apply")
      TK_TYPE_FN => to_repr("type_fn")
      TK_FN_TYPE => to_repr("fn_type")
      TK_FORALL => to_repr("forall")
      TK_LET => to_repr("let")
      TK_LETREC => to_repr("letrec")
      TK_EXTERNAL => to_repr("external")
      TK_FN => to_repr("fn")
      TK_CALL => to_repr("call")
      TK_PERFORM => to_repr("perform")
      TK_HANDLE => to_repr("handle")
      TK_RESUME => to_repr("resume")
      TK_HANDLER => to_repr("handler")
      TK_OP_ALT => to_repr("op_alt")
      TK_FINAL => to_repr("final")
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
      TK_DOUBLE_LITERAL => to_repr("double")
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

pub suberror ParseError {
  UnexpectedToken(Token, (SourceSpan, SourceSpan), Array[TokenKind])
  UnexpectedEndOfInput(SourceSpan, Array[TokenKind])
} derive(Debug)

type YYObj = Error

priv suberror YYObj_Void

priv suberror YYObj_Int {
  YYObj_Int(Int)
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

priv suberror YYObj_Array_Effect_ {
  YYObj_Array_Effect_(Array[Effect])
}

priv suberror YYObj_Array_TopTerm_ {
  YYObj_Array_TopTerm_(Array[TopTerm])
}

priv suberror YYObj_Array_ValueId_ {
  YYObj_Array_ValueId_(Array[ValueId])
}

priv suberror YYObj_Array_DataConId_ {
  YYObj_Array_DataConId_(Array[DataConId])
}

priv suberror YYObj_Array_Alternative_ {
  YYObj_Array_Alternative_(Array[Alternative])
}

priv suberror YYObj_Array_OperationId_ {
  YYObj_Array_OperationId_(Array[OperationId])
}

priv suberror YYObj_Array_HandlerTable_ {
  YYObj_Array_HandlerTable_(Array[HandlerTable])
}

priv suberror YYObj_Array_GenericArgument_ {
  YYObj_Array_GenericArgument_(Array[GenericArgument])
}

priv suberror YYObj_Array_TypeParameterId_ {
  YYObj_Array_TypeParameterId_(Array[TypeParameterId])
}

priv suberror YYObj_Array_RecursiveBinding_ {
  YYObj_Array_RecursiveBinding_(Array[RecursiveBinding])
}

priv suberror YYObj_Array_MetadataDeclaration_ {
  YYObj_Array_MetadataDeclaration_(Array[MetadataDeclaration])
}

priv suberror YYObj_Array_OperationAlternative_ {
  YYObj_Array_OperationAlternative_(Array[OperationAlternative])
}

priv suberror YYObj_AltCon {
  YYObj_AltCon(AltCon)
}

priv suberror YYObj_Effect {
  YYObj_Effect(Effect)
}

priv suberror YYObj_String {
  YYObj_String(String)
}

priv suberror YYObj_TypeId {
  YYObj_TypeId(TypeId)
}

priv suberror YYObj_Literal {
  YYObj_Literal(Literal)
}

priv suberror YYObj_Program {
  YYObj_Program(Program)
}

priv suberror YYObj_TopTerm {
  YYObj_TopTerm(TopTerm)
}

priv suberror YYObj_ValueId {
  YYObj_ValueId(ValueId)
}

priv suberror YYObj_EffectId {
  YYObj_EffectId(EffectId)
}

priv suberror YYObj_DataConId {
  YYObj_DataConId(DataConId)
}

priv suberror YYObj_ValueKind {
  YYObj_ValueKind(ValueKind)
}

priv suberror YYObj_Alternative {
  YYObj_Alternative(Alternative)
}

priv suberror YYObj_BuslaneName {
  YYObj_BuslaneName(BuslaneName)
}

priv suberror YYObj_OperationId {
  YYObj_OperationId(OperationId)
}

priv suberror YYObj_HandlerTable {
  YYObj_HandlerTable(HandlerTable)
}

priv suberror YYObj_PrimitiveType {
  YYObj_PrimitiveType(PrimitiveType)
}

priv suberror YYObj_GenericArgument {
  YYObj_GenericArgument(GenericArgument)
}

priv suberror YYObj_TypeParameterId {
  YYObj_TypeParameterId(TypeParameterId)
}

priv suberror YYObj_MetadataRegistry {
  YYObj_MetadataRegistry(MetadataRegistry)
}

priv suberror YYObj_RecursiveBinding {
  YYObj_RecursiveBinding(RecursiveBinding)
}

priv suberror YYObj_ParsedBuslaneName {
  YYObj_ParsedBuslaneName(ParsedBuslaneName)
}

priv suberror YYObj_MetadataDeclaration {
  YYObj_MetadataDeclaration(MetadataDeclaration)
}

priv suberror YYObj_OperationAlternative {
  YYObj_OperationAlternative(OperationAlternative)
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
  T_TYPE_ID
  T_TPARAM_ID
  T_VALUE_ID
  T_DATACON_ID
  T_EFFECT_ID
  T_OPERATION_ID
  T_EOF
  T_BUSLANE
  T_METADATA
  T_TYPE
  T_TYPE_PARAMETER
  T_VALUE
  T_DATACON
  T_EFFECT_DECL
  T_OPERATION
  T_NAME
  T_UNIQUE
  T_PARAMETERS
  T_CONSTRUCTORS
  T_OPERATIONS
  T_OWNER
  T_HIDDEN
  T_PAYLOAD
  T_RESULT
  T_FUNCTION_KIND
  T_PARAMETER_KIND
  T_LOCAL_KIND
  T_MATCH_BINDER_KIND
  T_TYPE_KIND
  T_EFFECT_KIND
  T_UNIT_TYPE
  T_BOOL_TYPE
  T_INT_TYPE
  T_DOUBLE_TYPE
  T_STRING_TYPE
  T_KIND_FN
  T_EMPTY_EFFECT
  T_EFFECT_SINGLETON
  T_EFFECT_UNION
  T_APPLY
  T_TYPE_FN
  T_FN_TYPE
  T_FORALL
  T_LET
  T_LETREC
  T_EXTERNAL
  T_FN
  T_CALL
  T_PERFORM
  T_HANDLE
  T_RESUME
  T_HANDLER
  T_OP_ALT
  T_FINAL
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
  T_DOUBLE_LITERAL
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
  NT_buslane_type_name
  NT_buslane_type_parameter_name
  NT_buslane_value_name
  NT_buslane_data_constructor_name
  NT_buslane_effect_name
  NT_buslane_operation_name
  NT_buslane_name
  NT_top_terms
  NT_top_term
  NT_recursive_bindings
  NT_recursive_binding
  NT_expr
  NT_handler_tables
  NT_handler_table
  NT_operation_alternatives
  NT_operation_alternative
  NT_alternatives
  NT_alternative
  NT_alt_con
  NT_literal
  NT_kind
  NT_type
  NT_effect
  NT_primitive_type
  NT_value_kind
  NT_kind_list
  NT_non_empty_kind_list
  NT_type_list
  NT_non_empty_type_list
  NT_generic_argument
  NT_generic_argument_list
  NT_non_empty_generic_argument_list
  NT_effect_list
  NT_non_empty_effect_list
  NT_expr_list
  NT_non_empty_expr_list
  NT_type_parameter_id_list
  NT_non_empty_type_parameter_id_list
  NT_value_id_list
  NT_non_empty_value_id_list
  NT_data_con_id_list
  NT_non_empty_data_con_id_list
  NT_operation_id_list
  NT_non_empty_operation_id_list
  NT_type_id
  NT_type_parameter_id
  NT_value_id
  NT_data_con_id
  NT_effect_id
  NT_operation_id
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
// 97|    "buslane" "{" metadata top_terms "}" EOF {
// 98|    { metadata: $3, terms: $4 }
// 99|  }
fn yy_action_0(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_MetadataRegistry(_dollar3)
  guard _args[3].0 is YYObj_Array_TopTerm_(_dollar4)
  YYObj_Program({(); 
    { metadata: _dollar3, terms: _dollar4 }
  })
}

// file:///./parser.mbty
// 170|    top_terms top_term { comma_push($1, $2) }
fn yy_action_1(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopTerm_(_dollar1)
  guard _args[1].0 is YYObj_TopTerm(_dollar2)
  YYObj_Array_TopTerm_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 174|    "let" value_id "=" expr ";" { Let($2, $4) }
fn yy_action_2(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  YYObj_TopTerm({();  Let(_dollar2, _dollar4) })
}

// file:///./parser.mbty
// 175|    "letrec" "{" recursive_bindings "}" { LetRec($3) }
fn yy_action_3(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_RecursiveBinding_(_dollar3)
  YYObj_TopTerm({();  LetRec(_dollar3) })
}

// file:///./parser.mbty
// 185|    value_id "=" expr ";" { { id: $1, rhs: $3 } }
fn yy_action_4(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_RecursiveBinding({();  { id: _dollar1, rhs: _dollar3 } })
}

// file:///./parser.mbty
// 223|    "handle" "(" expr "," value_id "," type "," expr ")" "{" handler_tables "}" {
// 224|    Handle({
// 225|      body: $3,
// 226|      result_binder: $5,
// 227|      result_type: $7,
// 228|      final_body: $9,
// 229|      handlers: $12,
// 230|    })
// 231|  }
fn yy_action_5(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_ValueId(_dollar5)
  guard _args[6].0 is YYObj_Type(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar9)
  guard _args[11].0 is YYObj_Array_HandlerTable_(_dollar12)
  YYObj_Expr({(); 
    Handle({
      body: _dollar3,
      result_binder: _dollar5,
      result_type: _dollar7,
      final_body: _dollar9,
      handlers: _dollar12,
    })
  })
}

// file:///./parser.mbty
// 236|    handler_tables handler_table { comma_push($1, $2) }
fn yy_action_6(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_HandlerTable_(_dollar1)
  guard _args[1].0 is YYObj_HandlerTable(_dollar2)
  YYObj_Array_HandlerTable_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 240|    "handler" "(" effect ")" "{" operation_alternatives "}" {
// 241|    { handled_effect: $3, operations: $6 }
// 242|  }
fn yy_action_7(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Effect(_dollar3)
  guard _args[5].0 is YYObj_Array_OperationAlternative_(_dollar6)
  YYObj_HandlerTable({(); 
    { handled_effect: _dollar3, operations: _dollar6 }
  })
}

// file:///./parser.mbty
// 247|    operation_alternatives operation_alternative { comma_push($1, $2) }
fn yy_action_8(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_OperationAlternative_(_dollar1)
  guard _args[1].0 is YYObj_OperationAlternative(_dollar2)
  YYObj_Array_OperationAlternative_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 220|    "match" "(" expr "," value_id "," type ")" "{" alternatives "}" {
// 221|    Match({ scrutinee: $3, binder: $5, result_type: $7, alternatives: $10 })
// 222|  }
fn yy_action_9(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_ValueId(_dollar5)
  guard _args[6].0 is YYObj_Type(_dollar7)
  guard _args[9].0 is YYObj_Array_Alternative_(_dollar10)
  YYObj_Expr({(); 
    Match({ scrutinee: _dollar3, binder: _dollar5, result_type: _dollar7, alternatives: _dollar10 })
  })
}

// file:///./parser.mbty
// 264|    alternatives alternative { comma_push($1, $2) }
fn yy_action_10(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Alternative_(_dollar1)
  guard _args[1].0 is YYObj_Alternative(_dollar2)
  YYObj_Array_Alternative_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 181|    recursive_bindings recursive_binding { comma_push($1, $2) }
fn yy_action_11(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_RecursiveBinding_(_dollar1)
  guard _args[1].0 is YYObj_RecursiveBinding(_dollar2)
  YYObj_Array_RecursiveBinding_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 208|    "construct" "(" data_con_id "," generic_argument_list "," generic_argument_list "," expr_list ")" {
// 209|    Construct({
// 210|      data_constructor: $3,
// 211|      type_arguments: $5,
// 212|      hidden_witnesses: $7,
// 213|      payloads: $9,
// 214|    })
// 215|  }
fn yy_action_12(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  guard _args[6].0 is YYObj_Array_GenericArgument_(_dollar7)
  guard _args[8].0 is YYObj_Array_Expr_(_dollar9)
  YYObj_Expr({(); 
    Construct({
      data_constructor: _dollar3,
      type_arguments: _dollar5,
      hidden_witnesses: _dollar7,
      payloads: _dollar9,
    })
  })
}

// file:///./parser.mbty
// 375|    "[" "]" { [] }
fn yy_action_13(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 376|    "[" non_empty_expr_list "]" { $2 }
fn yy_action_14(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Expr_(_dollar2)
  YYObj_Array_Expr_({();  _dollar2 })
}

// file:///./parser.mbty
// 189|    value_id { Ref($1) }
fn yy_action_15(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Expr({();  Ref(_dollar1) })
}

// file:///./parser.mbty
// 190|    literal { Literal($1) }
fn yy_action_16(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Literal(_dollar1)
  YYObj_Expr({();  Literal(_dollar1) })
}

// file:///./parser.mbty
// 191|    "fn" "(" value_id_list "," type ")" "{" expr "}" {
// 192|    Function({ parameters: $3, result_type: $5, body: $8 })
// 193|  }
fn yy_action_17(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_ValueId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  guard _args[7].0 is YYObj_Expr(_dollar8)
  YYObj_Expr({(); 
    Function({ parameters: _dollar3, result_type: _dollar5, body: _dollar8 })
  })
}

// file:///./parser.mbty
// 194|    "call" "(" expr "," expr_list ")" { Call($3, $5) }
fn yy_action_18(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  YYObj_Expr({();  Call(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 195|    "perform" "(" operation_id "," generic_argument_list "," generic_argument_list "," expr_list ")" {
// 196|    Perform({
// 197|      operation: $3,
// 198|      effect_arguments: $5,
// 199|      hidden_witnesses: $7,
// 200|      payloads: $9,
// 201|    })
// 202|  }
fn yy_action_19(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_OperationId(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  guard _args[6].0 is YYObj_Array_GenericArgument_(_dollar7)
  guard _args[8].0 is YYObj_Array_Expr_(_dollar9)
  YYObj_Expr({(); 
    Perform({
      operation: _dollar3,
      effect_arguments: _dollar5,
      hidden_witnesses: _dollar7,
      payloads: _dollar9,
    })
  })
}

// file:///./parser.mbty
// 203|    "resume" "(" value_id ")" { Resume($3) }
fn yy_action_20(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  YYObj_Expr({();  Resume(_dollar3) })
}

// file:///./parser.mbty
// 204|    "type_fn" "(" type_parameter_id_list ")" "{" expr "}" {
// 205|    TypeLambda($3, $6)
// 206|  }
fn yy_action_21(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  YYObj_Expr({(); 
    TypeLambda(_dollar3, _dollar6)
  })
}

// file:///./parser.mbty
// 207|    "type_apply" "(" expr "," generic_argument_list ")" { TypeApply($3, $5) }
fn yy_action_22(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  YYObj_Expr({();  TypeApply(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 381|    non_empty_expr_list "," expr { comma_push($1, $3) }
fn yy_action_23(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 380|    expr { [ $1 ] }
fn yy_action_24(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 216|    "let_in" "(" value_id "," expr "," expr ")" { Let($3, $5, $7) }
fn yy_action_25(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  guard _args[4].0 is YYObj_Expr(_dollar5)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  YYObj_Expr({();  Let(_dollar3, _dollar5, _dollar7) })
}

// file:///./parser.mbty
// 217|    "letrec_in" "(" "{" recursive_bindings "}" "," expr ")" {
// 218|    LetRec($4, $7)
// 219|  }
fn yy_action_26(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[3].0 is YYObj_Array_RecursiveBinding_(_dollar4)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  YYObj_Expr({(); 
    LetRec(_dollar4, _dollar7)
  })
}

// file:///./parser.mbty
// 268|    "alt" "(" alt_con "," type_parameter_id_list "," value_id_list ")" "=>" expr ";" {
// 269|    { alt_constructor: $3, type_binders: $5, value_binders: $7, body: $10 }
// 270|  }
fn yy_action_27(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_AltCon(_dollar3)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_ValueId_(_dollar7)
  guard _args[9].0 is YYObj_Expr(_dollar10)
  YYObj_Alternative({(); 
    { alt_constructor: _dollar3, type_binders: _dollar5, value_binders: _dollar7, body: _dollar10 }
  })
}

// file:///./parser.mbty
// 274|    "default" { Default }
fn yy_action_28(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_AltCon({();  Default })
}

// file:///./parser.mbty
// 275|    "literal" "(" literal ")" { Literal($3) }
fn yy_action_29(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Literal(_dollar3)
  YYObj_AltCon({();  Literal(_dollar3) })
}

// file:///./parser.mbty
// 276|    "datacon" "(" data_con_id ")" { DataCon($3) }
fn yy_action_30(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  YYObj_AltCon({();  DataCon(_dollar3) })
}

// file:///./parser.mbty
// 263|    { [] }
fn yy_action_31(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Alternative_({();  [] })
}

// file:///./parser.mbty
// 251|    "op_alt" "(" operation_id "," type_parameter_id_list "," value_id_list "," value_id ")" "=>" expr ";" {
// 252|    {
// 253|      operation: $3,
// 254|      type_binders: $5,
// 255|      payload_binders: $7,
// 256|      resume_binder: $9,
// 257|      body: $12,
// 258|    }
// 259|  }
fn yy_action_32(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_OperationId(_dollar3)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_ValueId_(_dollar7)
  guard _args[8].0 is YYObj_ValueId(_dollar9)
  guard _args[11].0 is YYObj_Expr(_dollar12)
  YYObj_OperationAlternative({(); 
    {
      operation: _dollar3,
      type_binders: _dollar5,
      payload_binders: _dollar7,
      resume_binder: _dollar9,
      body: _dollar12,
    }
  })
}

// file:///./parser.mbty
// 395|    "[" "]" { [] }
fn yy_action_33(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ValueId_({();  [] })
}

// file:///./parser.mbty
// 396|    "[" non_empty_value_id_list "]" { $2 }
fn yy_action_34(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_ValueId_(_dollar2)
  YYObj_Array_ValueId_({();  _dollar2 })
}

// file:///./parser.mbty
// 401|    non_empty_value_id_list "," value_id { comma_push($1, $3) }
fn yy_action_35(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValueId_(_dollar1)
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  YYObj_Array_ValueId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 400|    value_id { [ $1 ] }
fn yy_action_36(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Array_ValueId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 246|    { [] }
fn yy_action_37(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_OperationAlternative_({();  [] })
}

// file:///./parser.mbty
// 235|    { [] }
fn yy_action_38(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_HandlerTable_({();  [] })
}

// file:///./parser.mbty
// 280|    "unit" "(" ")" { Unit }
fn yy_action_39(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Literal({();  Unit })
}

// file:///./parser.mbty
// 281|    TRUE { Bool(true) }
fn yy_action_40(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Literal({();  Bool(true) })
}

// file:///./parser.mbty
// 282|    FALSE { Bool(false) }
fn yy_action_41(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Literal({();  Bool(false) })
}

// file:///./parser.mbty
// 283|    "int" "(" INT ")" { Int(@string.parse_int64($3, base=10) catch { _ => 0L }) }
fn yy_action_42(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Literal({();  Int(@string.parse_int64(_dollar3, base=10) catch { _ => 0L }) })
}

// file:///./parser.mbty
// 284|    "double" "(" DOUBLE ")" { Double(@string.parse_double($3) catch { _ => 0.0 }) }
fn yy_action_43(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Literal({();  Double(@string.parse_double(_dollar3) catch { _ => 0.0 }) })
}

// file:///./parser.mbty
// 285|    "string" "(" STRING ")" { String($3) }
fn yy_action_44(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Literal({();  String(_dollar3) })
}

// file:///./parser.mbty
// 180|    { [] }
fn yy_action_45(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_RecursiveBinding_({();  [] })
}

// file:///./parser.mbty
// 176|    "external" value_id ";" { External($2) }
fn yy_action_46(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  YYObj_TopTerm({();  External(_dollar2) })
}

// file:///./parser.mbty
// 169|    { [] }
fn yy_action_47(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TopTerm_({();  [] })
}

// file:///./parser.mbty
// 107|    "metadata" "{" metadata_declarations "}" {
// 108|    make_metadata($3)
// 109|  }
fn yy_action_48(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_MetadataDeclaration_(_dollar3)
  YYObj_MetadataRegistry({(); 
    make_metadata(_dollar3)
  })
}

// file:///./parser.mbty
// 114|    metadata_declarations metadata_declaration { comma_push($1, $2) }
fn yy_action_49(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MetadataDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_MetadataDeclaration(_dollar2)
  YYObj_Array_MetadataDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 118|    "type" type_id buslane_type_name "parameters" type_parameter_id_list "constructors" data_con_id_list ";" {
// 119|    TypeInfoDecl($2, { name: $3, parameters: $5, constructors: $7 })
// 120|  }
fn yy_action_50(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_TypeId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_DataConId_(_dollar7)
  YYObj_MetadataDeclaration({(); 
    TypeInfoDecl(_dollar2, { name: _dollar3, parameters: _dollar5, constructors: _dollar7 })
  })
}

// file:///./parser.mbty
// 405|    "[" "]" { [] }
fn yy_action_51(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_DataConId_({();  [] })
}

// file:///./parser.mbty
// 406|    "[" non_empty_data_con_id_list "]" { $2 }
fn yy_action_52(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_DataConId_(_dollar2)
  YYObj_Array_DataConId_({();  _dollar2 })
}

// file:///./parser.mbty
// 411|    non_empty_data_con_id_list "," data_con_id { comma_push($1, $3) }
fn yy_action_53(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_DataConId_(_dollar1)
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  YYObj_Array_DataConId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 410|    data_con_id { [ $1 ] }
fn yy_action_54(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_DataConId(_dollar1)
  YYObj_Array_DataConId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 139|    buslane_name { parsed_name(TypeName, $1.occurrence, $1.unique) }
fn yy_action_55(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(TypeName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 121|    "type_parameter" type_parameter_id buslane_type_parameter_name ":" kind ";" {
// 122|    TypeParameterInfoDecl($2, { name: $3, kind: $5 })
// 123|  }
fn yy_action_56(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_TypeParameterId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  YYObj_MetadataDeclaration({(); 
    TypeParameterInfoDecl(_dollar2, { name: _dollar3, kind: _dollar5 })
  })
}

// file:///./parser.mbty
// 291|    "kind_fn" "(" kind_list "," kind ")" { Function($3, $5) }
fn yy_action_57(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Kind_(_dollar3)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  YYObj_Kind({();  Function(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 330|    "[" "]" { [] }
fn yy_action_58(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Kind_({();  [] })
}

// file:///./parser.mbty
// 331|    "[" non_empty_kind_list "]" { $2 }
fn yy_action_59(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  YYObj_Array_Kind_({();  _dollar2 })
}

// file:///./parser.mbty
// 289|    "Type" { Type }
fn yy_action_60(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind({();  Type })
}

// file:///./parser.mbty
// 290|    "Effect" { Effect }
fn yy_action_61(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind({();  Effect })
}

// file:///./parser.mbty
// 336|    non_empty_kind_list "," kind { comma_push($1, $3) }
fn yy_action_62(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 335|    kind { [ $1 ] }
fn yy_action_63(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 143|    buslane_name { parsed_name(TypeParameterName, $1.occurrence, $1.unique) }
fn yy_action_64(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(TypeParameterName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 124|    "value" value_id buslane_value_name value_kind ":" type ";" {
// 125|    ValueInfoDecl($2, { name: $3, kind: $4, type_: $6 })
// 126|  }
fn yy_action_65(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[3].0 is YYObj_ValueKind(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  YYObj_MetadataDeclaration({(); 
    ValueInfoDecl(_dollar2, { name: _dollar3, kind: _dollar4, type_: _dollar6 })
  })
}

// file:///./parser.mbty
// 321|    "function" { Function }
fn yy_action_66(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Function })
}

// file:///./parser.mbty
// 322|    "value" { Value }
fn yy_action_67(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Value })
}

// file:///./parser.mbty
// 323|    "external" { External }
fn yy_action_68(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  External })
}

// file:///./parser.mbty
// 324|    "parameter" { Parameter }
fn yy_action_69(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Parameter })
}

// file:///./parser.mbty
// 325|    "local" { Local }
fn yy_action_70(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Local })
}

// file:///./parser.mbty
// 326|    "match_binder" { MatchBinder }
fn yy_action_71(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  MatchBinder })
}

// file:///./parser.mbty
// 147|    buslane_name { parsed_name(ValueName, $1.occurrence, $1.unique) }
fn yy_action_72(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(ValueName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 433|    VALUE_ID { { index: $1 } }
fn yy_action_73(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_ValueId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 127|    "datacon" data_con_id buslane_data_constructor_name "owner" type_id "hidden" type_parameter_id_list "payload" type_list ";" {
// 128|    DataConInfoDecl($2, { name: $3, owner: $5, hidden_type_parameters: $7, payload_types: $9 })
// 129|  }
fn yy_action_74(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_DataConId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[4].0 is YYObj_TypeId(_dollar5)
  guard _args[6].0 is YYObj_Array_TypeParameterId_(_dollar7)
  guard _args[8].0 is YYObj_Array_Type_(_dollar9)
  YYObj_MetadataDeclaration({(); 
    DataConInfoDecl(_dollar2, { name: _dollar3, owner: _dollar5, hidden_type_parameters: _dollar7, payload_types: _dollar9 })
  })
}

// file:///./parser.mbty
// 151|    buslane_name { parsed_name(DataConstructorName, $1.occurrence, $1.unique) }
fn yy_action_75(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(DataConstructorName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 437|    DATACON_ID { { index: $1 } }
fn yy_action_76(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_DataConId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 130|    "effect" effect_id buslane_effect_name "parameters" type_parameter_id_list "operations" operation_id_list ";" {
// 131|    EffectInfoDecl($2, { name: $3, parameters: $5, operations: $7 })
// 132|  }
fn yy_action_77(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_EffectId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_OperationId_(_dollar7)
  YYObj_MetadataDeclaration({(); 
    EffectInfoDecl(_dollar2, { name: _dollar3, parameters: _dollar5, operations: _dollar7 })
  })
}

// file:///./parser.mbty
// 415|    "[" "]" { [] }
fn yy_action_78(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_OperationId_({();  [] })
}

// file:///./parser.mbty
// 416|    "[" non_empty_operation_id_list "]" { $2 }
fn yy_action_79(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_OperationId_(_dollar2)
  YYObj_Array_OperationId_({();  _dollar2 })
}

// file:///./parser.mbty
// 421|    non_empty_operation_id_list "," operation_id { comma_push($1, $3) }
fn yy_action_80(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_OperationId_(_dollar1)
  guard _args[2].0 is YYObj_OperationId(_dollar3)
  YYObj_Array_OperationId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 420|    operation_id { [ $1 ] }
fn yy_action_81(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OperationId(_dollar1)
  YYObj_Array_OperationId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 155|    buslane_name { parsed_name(EffectName, $1.occurrence, $1.unique) }
fn yy_action_82(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(EffectName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 133|    "operation" operation_id buslane_operation_name "owner" effect_id "hidden" type_parameter_id_list "payload" type_list "result" type ";" {
// 134|    OperationInfoDecl($2, { name: $3, owner: $5, hidden_type_parameters: $7, payload_types: $9, result_type: $11 })
// 135|  }
fn yy_action_83(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_OperationId(_dollar2)
  guard _args[2].0 is YYObj_BuslaneName(_dollar3)
  guard _args[4].0 is YYObj_EffectId(_dollar5)
  guard _args[6].0 is YYObj_Array_TypeParameterId_(_dollar7)
  guard _args[8].0 is YYObj_Array_Type_(_dollar9)
  guard _args[10].0 is YYObj_Type(_dollar11)
  YYObj_MetadataDeclaration({(); 
    OperationInfoDecl(_dollar2, { name: _dollar3, owner: _dollar5, hidden_type_parameters: _dollar7, payload_types: _dollar9, result_type: _dollar11 })
  })
}

// file:///./parser.mbty
// 159|    buslane_name { parsed_name(OperationName, $1.occurrence, $1.unique) }
fn yy_action_84(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ParsedBuslaneName(_dollar1)
  YYObj_BuslaneName({();  parsed_name(OperationName, _dollar1.occurrence, _dollar1.unique) })
}

// file:///./parser.mbty
// 163|    "name" STRING "unique" INT {
// 164|    { occurrence: $2, unique: parse_text_int($4) }
// 165|  }
fn yy_action_85(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_String(_dollar4)
  YYObj_ParsedBuslaneName({(); 
    { occurrence: _dollar2, unique: parse_text_int(_dollar4) }
  })
}

// file:///./parser.mbty
// 445|    OPERATION_ID { { index: $1 } }
fn yy_action_86(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_OperationId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 113|    { [] }
fn yy_action_87(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_MetadataDeclaration_({();  [] })
}

// file:///./parser.mbty
// 103|    type EOF { $1 }
fn yy_action_88(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 300|    "fn_type" "(" type_list "," type ")" { Function($3, $5, Empty) }
fn yy_action_89(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type({();  Function(_dollar3, _dollar5, Empty) })
}

// file:///./parser.mbty
// 301|    "fn_type" "(" type_list "," type "," effect ")" { Function($3, $5, $7) }
fn yy_action_90(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Type_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  guard _args[6].0 is YYObj_Effect(_dollar7)
  YYObj_Type({();  Function(_dollar3, _dollar5, _dollar7) })
}

// file:///./parser.mbty
// 340|    "[" "]" { [] }
fn yy_action_91(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 341|    "[" non_empty_type_list "]" { $2 }
fn yy_action_92(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Type_(_dollar2)
  YYObj_Array_Type_({();  _dollar2 })
}

// file:///./parser.mbty
// 298|    "apply" "(" type "," generic_argument_list ")" { Apply($3, $5) }
fn yy_action_93(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Type(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  YYObj_Type({();  Apply(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 355|    "[" "]" { [] }
fn yy_action_94(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 356|    "[" non_empty_generic_argument_list "]" { $2 }
fn yy_action_95(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj_Array_GenericArgument_({();  _dollar2 })
}

// file:///./parser.mbty
// 295|    primitive_type { Primitive($1) }
fn yy_action_96(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_PrimitiveType(_dollar1)
  YYObj_Type({();  Primitive(_dollar1) })
}

// file:///./parser.mbty
// 296|    type_parameter_id { Parameter($1) }
fn yy_action_97(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Type({();  Parameter(_dollar1) })
}

// file:///./parser.mbty
// 297|    type_id { Constructor($1) }
fn yy_action_98(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeId(_dollar1)
  YYObj_Type({();  Constructor(_dollar1) })
}

// file:///./parser.mbty
// 350|    "type" "(" type ")" { TypeArgument($3) }
fn yy_action_99(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_GenericArgument({();  TypeArgument(_dollar3) })
}

// file:///./parser.mbty
// 309|    "effect_union" "(" effect_list ")" { Union($3) }
fn yy_action_100(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Effect_(_dollar3)
  YYObj_Effect({();  Union(_dollar3) })
}

// file:///./parser.mbty
// 365|    "[" "]" { [] }
fn yy_action_101(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Effect_({();  [] })
}

// file:///./parser.mbty
// 366|    "[" non_empty_effect_list "]" { $2 }
fn yy_action_102(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Effect_(_dollar2)
  YYObj_Array_Effect_({();  _dollar2 })
}

// file:///./parser.mbty
// 306|    "empty_effect" "(" ")" { Empty }
fn yy_action_103(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Effect({();  Empty })
}

// file:///./parser.mbty
// 307|    type_parameter_id { Parameter($1) }
fn yy_action_104(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Effect({();  Parameter(_dollar1) })
}

// file:///./parser.mbty
// 308|    "effect_singleton" "(" effect_id "," generic_argument_list ")" { Singleton($3, $5) }
fn yy_action_105(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_EffectId(_dollar3)
  guard _args[4].0 is YYObj_Array_GenericArgument_(_dollar5)
  YYObj_Effect({();  Singleton(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 441|    EFFECT_ID { { index: $1 } }
fn yy_action_106(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_EffectId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 371|    non_empty_effect_list "," effect { comma_push($1, $3) }
fn yy_action_107(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Effect_(_dollar1)
  guard _args[2].0 is YYObj_Effect(_dollar3)
  YYObj_Array_Effect_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 370|    effect { [ $1 ] }
fn yy_action_108(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Effect(_dollar1)
  YYObj_Array_Effect_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 351|    "effect" "(" effect ")" { EffectArgument($3) }
fn yy_action_109(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Effect(_dollar3)
  YYObj_GenericArgument({();  EffectArgument(_dollar3) })
}

// file:///./parser.mbty
// 361|    non_empty_generic_argument_list "," generic_argument { comma_push($1, $3) }
fn yy_action_110(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  guard _args[2].0 is YYObj_GenericArgument(_dollar3)
  YYObj_Array_GenericArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 360|    generic_argument { [ $1 ] }
fn yy_action_111(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgument(_dollar1)
  YYObj_Array_GenericArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 299|    "type_fn" "(" type_parameter_id_list "," type ")" { TypeLambda($3, $5) }
fn yy_action_112(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type({();  TypeLambda(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 346|    non_empty_type_list "," type { comma_push($1, $3) }
fn yy_action_113(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 345|    type { [ $1 ] }
fn yy_action_114(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 302|    "forall" "(" type_parameter_id_list "," type ")" { Forall($3, $5) }
fn yy_action_115(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[4].0 is YYObj_Type(_dollar5)
  YYObj_Type({();  Forall(_dollar3, _dollar5) })
}

// file:///./parser.mbty
// 385|    "[" "]" { [] }
fn yy_action_116(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameterId_({();  [] })
}

// file:///./parser.mbty
// 386|    "[" non_empty_type_parameter_id_list "]" { $2 }
fn yy_action_117(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameterId_(_dollar2)
  YYObj_Array_TypeParameterId_({();  _dollar2 })
}

// file:///./parser.mbty
// 391|    non_empty_type_parameter_id_list "," type_parameter_id { comma_push($1, $3) }
fn yy_action_118(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameterId_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameterId(_dollar3)
  YYObj_Array_TypeParameterId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 390|    type_parameter_id { [ $1 ] }
fn yy_action_119(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Array_TypeParameterId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 313|    "Unit" { Unit }
fn yy_action_120(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Unit })
}

// file:///./parser.mbty
// 314|    "Bool" { Bool }
fn yy_action_121(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Bool })
}

// file:///./parser.mbty
// 315|    "Int" { Int }
fn yy_action_122(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Int })
}

// file:///./parser.mbty
// 316|    "Double" { Double }
fn yy_action_123(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Double })
}

// file:///./parser.mbty
// 317|    "String" { String }
fn yy_action_124(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  String })
}

// file:///./parser.mbty
// 425|    TYPE_ID { { index: $1 } }
fn yy_action_125(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 429|    TPARAM_ID { { index: $1 } }
fn yy_action_126(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeParameterId({();  { index: _dollar1 } })
}

fn yy_input(token : Token, _start_pos : SourceSpan, _end_pos : SourceSpan) -> (YYSymbol, YYObj) {
  match token {
    INT(data) => (T_INT, YYObj_String(data))
    DOUBLE(data) => (T_DOUBLE, YYObj_String(data))
    STRING(data) => (T_STRING, YYObj_String(data))
    TYPE_ID(data) => (T_TYPE_ID, YYObj_Int(data))
    TPARAM_ID(data) => (T_TPARAM_ID, YYObj_Int(data))
    VALUE_ID(data) => (T_VALUE_ID, YYObj_Int(data))
    DATACON_ID(data) => (T_DATACON_ID, YYObj_Int(data))
    EFFECT_ID(data) => (T_EFFECT_ID, YYObj_Int(data))
    OPERATION_ID(data) => (T_OPERATION_ID, YYObj_Int(data))
    EOF => (T_EOF, YYObj_Void)
    BUSLANE => (T_BUSLANE, YYObj_Void)
    METADATA => (T_METADATA, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    TYPE_PARAMETER => (T_TYPE_PARAMETER, YYObj_Void)
    VALUE => (T_VALUE, YYObj_Void)
    DATACON => (T_DATACON, YYObj_Void)
    EFFECT_DECL => (T_EFFECT_DECL, YYObj_Void)
    OPERATION => (T_OPERATION, YYObj_Void)
    NAME => (T_NAME, YYObj_Void)
    UNIQUE => (T_UNIQUE, YYObj_Void)
    PARAMETERS => (T_PARAMETERS, YYObj_Void)
    CONSTRUCTORS => (T_CONSTRUCTORS, YYObj_Void)
    OPERATIONS => (T_OPERATIONS, YYObj_Void)
    OWNER => (T_OWNER, YYObj_Void)
    HIDDEN => (T_HIDDEN, YYObj_Void)
    PAYLOAD => (T_PAYLOAD, YYObj_Void)
    RESULT => (T_RESULT, YYObj_Void)
    FUNCTION_KIND => (T_FUNCTION_KIND, YYObj_Void)
    PARAMETER_KIND => (T_PARAMETER_KIND, YYObj_Void)
    LOCAL_KIND => (T_LOCAL_KIND, YYObj_Void)
    MATCH_BINDER_KIND => (T_MATCH_BINDER_KIND, YYObj_Void)
    TYPE_KIND => (T_TYPE_KIND, YYObj_Void)
    EFFECT_KIND => (T_EFFECT_KIND, YYObj_Void)
    UNIT_TYPE => (T_UNIT_TYPE, YYObj_Void)
    BOOL_TYPE => (T_BOOL_TYPE, YYObj_Void)
    INT_TYPE => (T_INT_TYPE, YYObj_Void)
    DOUBLE_TYPE => (T_DOUBLE_TYPE, YYObj_Void)
    STRING_TYPE => (T_STRING_TYPE, YYObj_Void)
    KIND_FN => (T_KIND_FN, YYObj_Void)
    EMPTY_EFFECT => (T_EMPTY_EFFECT, YYObj_Void)
    EFFECT_SINGLETON => (T_EFFECT_SINGLETON, YYObj_Void)
    EFFECT_UNION => (T_EFFECT_UNION, YYObj_Void)
    APPLY => (T_APPLY, YYObj_Void)
    TYPE_FN => (T_TYPE_FN, YYObj_Void)
    FN_TYPE => (T_FN_TYPE, YYObj_Void)
    FORALL => (T_FORALL, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    LETREC => (T_LETREC, YYObj_Void)
    EXTERNAL => (T_EXTERNAL, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    CALL => (T_CALL, YYObj_Void)
    PERFORM => (T_PERFORM, YYObj_Void)
    HANDLE => (T_HANDLE, YYObj_Void)
    RESUME => (T_RESUME, YYObj_Void)
    HANDLER => (T_HANDLER, YYObj_Void)
    OP_ALT => (T_OP_ALT, YYObj_Void)
    FINAL => (T_FINAL, YYObj_Void)
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
    DOUBLE_LITERAL => (T_DOUBLE_LITERAL, YYObj_Void)
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

fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_type => Shift(yy_state_1)
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_90)
    _ => Error
  }
}

fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameter_id, yy_action_126)
}

fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_id, yy_action_125)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_124)
}

fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_123)
}

fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_122)
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_121)
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_120)
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_10)
    _ => Error
  }
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_18)
    _ => Error
  }
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_12)
    NT_non_empty_type_parameter_id_list => Shift(yy_state_13)
    T_RBRACKET => Shift(yy_state_17)
    _ => Error
  }
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_id_list, yy_action_119)
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_14)
    T_RBRACKET => Shift(yy_state_16)
    _ => Error
  }
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_15)
    _ => Error
  }
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_id_list, yy_action_118)
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_id_list, yy_action_117)
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_parameter_id_list, yy_action_116)
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_19)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    NT_type => Shift(yy_state_20)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_21)
    _ => Error
  }
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_115)
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_23)
    _ => Error
  }
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_24)
    NT_type_list => Shift(yy_state_83)
    _ => Error
  }
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    NT_type => Shift(yy_state_25)
    NT_non_empty_type_list => Shift(yy_state_26)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    T_RBRACKET => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_114)
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_27)
    T_RBRACKET => Shift(yy_state_81)
    _ => Error
  }
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    NT_type => Shift(yy_state_28)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_113)
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_30)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_31)
    _ => Error
  }
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_32)
    _ => Error
  }
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    NT_type => Shift(yy_state_33)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_34)
    _ => Error
  }
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_112)
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_36)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type => Shift(yy_state_37)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_38)
    _ => Error
  }
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_79)
    _ => Error
  }
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_generic_argument => Shift(yy_state_40)
    NT_non_empty_generic_argument_list => Shift(yy_state_41)
    T_EFFECT_DECL => Shift(yy_state_44)
    T_TYPE => Shift(yy_state_70)
    T_RBRACKET => Shift(yy_state_78)
    _ => Error
  }
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_generic_argument_list, yy_action_111)
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_42)
    T_RBRACKET => Shift(yy_state_77)
    _ => Error
  }
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_generic_argument => Shift(yy_state_43)
    T_EFFECT_DECL => Shift(yy_state_44)
    T_TYPE => Shift(yy_state_70)
    _ => Error
  }
}

fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_generic_argument_list, yy_action_110)
}

fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_45)
    _ => Error
  }
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_effect => Shift(yy_state_46)
    T_EFFECT_UNION => Shift(yy_state_48)
    T_EFFECT_SINGLETON => Shift(yy_state_55)
    NT_type_parameter_id => Shift(yy_state_62)
    T_EMPTY_EFFECT => Shift(yy_state_63)
    _ => Error
  }
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_47)
    _ => Error
  }
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_generic_argument, yy_action_109)
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_49)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_50)
    NT_effect_list => Shift(yy_state_68)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_UNION => Shift(yy_state_48)
    NT_effect => Shift(yy_state_51)
    NT_non_empty_effect_list => Shift(yy_state_52)
    T_EFFECT_SINGLETON => Shift(yy_state_55)
    NT_type_parameter_id => Shift(yy_state_62)
    T_EMPTY_EFFECT => Shift(yy_state_63)
    T_RBRACKET => Shift(yy_state_67)
    _ => Error
  }
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_effect_list, yy_action_108)
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_53)
    T_RBRACKET => Shift(yy_state_66)
    _ => Error
  }
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_UNION => Shift(yy_state_48)
    NT_effect => Shift(yy_state_54)
    T_EFFECT_SINGLETON => Shift(yy_state_55)
    NT_type_parameter_id => Shift(yy_state_62)
    T_EMPTY_EFFECT => Shift(yy_state_63)
    _ => Error
  }
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_effect_list, yy_action_107)
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_56)
    _ => Error
  }
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_ID => Shift(yy_state_57)
    NT_effect_id => Shift(yy_state_58)
    _ => Error
  }
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_id, yy_action_106)
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_60)
    _ => Error
  }
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_61)
    _ => Error
  }
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_effect, yy_action_105)
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect, yy_action_104)
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_64)
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
  ReduceNoLookahead(3, NT_effect, yy_action_103)
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_effect_list, yy_action_102)
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect_list, yy_action_101)
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_69)
    _ => Error
  }
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_effect, yy_action_100)
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_71)
    _ => Error
  }
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type => Shift(yy_state_72)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_73)
    _ => Error
  }
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_generic_argument, yy_action_99)
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_98)
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_97)
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_96)
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_generic_argument_list, yy_action_95)
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_generic_argument_list, yy_action_94)
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_80)
    _ => Error
  }
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_93)
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_list, yy_action_92)
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_list, yy_action_91)
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_84)
    _ => Error
  }
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_85)
    _ => Error
  }
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_86)
    T_RPAREN => Shift(yy_state_89)
    _ => Error
  }
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_UNION => Shift(yy_state_48)
    T_EFFECT_SINGLETON => Shift(yy_state_55)
    NT_type_parameter_id => Shift(yy_state_62)
    T_EMPTY_EFFECT => Shift(yy_state_63)
    NT_effect => Shift(yy_state_87)
    _ => Error
  }
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_88)
    _ => Error
  }
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_type, yy_action_90)
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_89)
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_91)
    _ => Error
  }
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_buslane_type, yy_action_88)
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_program => Shift(yy_state_93)
    T_BUSLANE => Shift(yy_state_94)
    _ => Error
  }
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_95)
    _ => Error
  }
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_METADATA => Shift(yy_state_96)
    NT_metadata => Shift(yy_state_200)
    _ => Error
  }
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_97)
    _ => Error
  }
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_metadata_declarations => Shift(yy_state_98)
    T_TYPE | T_TYPE_PARAMETER | T_VALUE | T_DATACON | T_EFFECT_DECL | T_OPERATION | T_RBRACE => Reduce(0, NT_metadata_declarations, yy_action_87)
    _ => Error
  }
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION => Shift(yy_state_99)
    T_EFFECT_DECL => Shift(yy_state_117)
    T_DATACON => Shift(yy_state_133)
    T_VALUE => Shift(yy_state_145)
    T_TYPE_PARAMETER => Shift(yy_state_160)
    T_TYPE => Shift(yy_state_182)
    NT_metadata_declaration => Shift(yy_state_198)
    T_RBRACE => Shift(yy_state_199)
    _ => Error
  }
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_100)
    NT_operation_id => Shift(yy_state_101)
    _ => Error
  }
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_operation_id, yy_action_86)
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_106)
    NT_buslane_operation_name => Shift(yy_state_107)
    _ => Error
  }
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_103)
    _ => Error
  }
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_UNIQUE => Shift(yy_state_104)
    _ => Error
  }
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_105)
    _ => Error
  }
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_buslane_name, yy_action_85)
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_operation_name, yy_action_84)
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER => Shift(yy_state_108)
    _ => Error
  }
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_ID => Shift(yy_state_57)
    NT_effect_id => Shift(yy_state_109)
    _ => Error
  }
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_HIDDEN => Shift(yy_state_110)
    _ => Error
  }
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_111)
    _ => Error
  }
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PAYLOAD => Shift(yy_state_112)
    _ => Error
  }
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_24)
    NT_type_list => Shift(yy_state_113)
    _ => Error
  }
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RESULT => Shift(yy_state_114)
    _ => Error
  }
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_115)
    _ => Error
  }
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_116)
    _ => Error
  }
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(12, NT_metadata_declaration, yy_action_83)
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_ID => Shift(yy_state_57)
    NT_effect_id => Shift(yy_state_118)
    _ => Error
  }
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_119)
    NT_buslane_effect_name => Shift(yy_state_120)
    _ => Error
  }
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_effect_name, yy_action_82)
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PARAMETERS => Shift(yy_state_121)
    _ => Error
  }
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_122)
    _ => Error
  }
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATIONS => Shift(yy_state_123)
    _ => Error
  }
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_124)
    NT_operation_id_list => Shift(yy_state_131)
    _ => Error
  }
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_100)
    NT_operation_id => Shift(yy_state_125)
    NT_non_empty_operation_id_list => Shift(yy_state_126)
    T_RBRACKET => Shift(yy_state_130)
    _ => Error
  }
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_operation_id_list, yy_action_81)
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_127)
    T_RBRACKET => Shift(yy_state_129)
    _ => Error
  }
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_100)
    NT_operation_id => Shift(yy_state_128)
    _ => Error
  }
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_operation_id_list, yy_action_80)
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_operation_id_list, yy_action_79)
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_operation_id_list, yy_action_78)
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_132)
    _ => Error
  }
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_77)
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_134)
    NT_data_con_id => Shift(yy_state_135)
    _ => Error
  }
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_con_id, yy_action_76)
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_136)
    NT_buslane_data_constructor_name => Shift(yy_state_137)
    _ => Error
  }
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_data_constructor_name, yy_action_75)
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OWNER => Shift(yy_state_138)
    _ => Error
  }
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_139)
    _ => Error
  }
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_HIDDEN => Shift(yy_state_140)
    _ => Error
  }
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_141)
    _ => Error
  }
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PAYLOAD => Shift(yy_state_142)
    _ => Error
  }
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_24)
    NT_type_list => Shift(yy_state_143)
    _ => Error
  }
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_144)
    _ => Error
  }
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_metadata_declaration, yy_action_74)
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_147)
    _ => Error
  }
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_id, yy_action_73)
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_148)
    NT_buslane_value_name => Shift(yy_state_149)
    _ => Error
  }
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_value_name, yy_action_72)
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MATCH_BINDER_KIND => Shift(yy_state_150)
    T_LOCAL_KIND => Shift(yy_state_151)
    T_PARAMETER_KIND => Shift(yy_state_152)
    T_EXTERNAL => Shift(yy_state_153)
    T_VALUE => Shift(yy_state_154)
    T_FUNCTION_KIND => Shift(yy_state_155)
    NT_value_kind => Shift(yy_state_156)
    _ => Error
  }
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_71)
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_70)
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_69)
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_68)
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_67)
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_66)
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_157)
    _ => Error
  }
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_158)
    _ => Error
  }
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_159)
    _ => Error
  }
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_metadata_declaration, yy_action_65)
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_161)
    _ => Error
  }
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_162)
    NT_buslane_type_parameter_name => Shift(yy_state_163)
    _ => Error
  }
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_type_parameter_name, yy_action_64)
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_164)
    _ => Error
  }
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_165)
    T_EFFECT_KIND => Shift(yy_state_172)
    T_TYPE_KIND => Shift(yy_state_173)
    NT_kind => Shift(yy_state_180)
    _ => Error
  }
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_166)
    _ => Error
  }
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_167)
    NT_kind_list => Shift(yy_state_176)
    _ => Error
  }
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_165)
    NT_kind => Shift(yy_state_168)
    NT_non_empty_kind_list => Shift(yy_state_169)
    T_EFFECT_KIND => Shift(yy_state_172)
    T_TYPE_KIND => Shift(yy_state_173)
    T_RBRACKET => Shift(yy_state_175)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_63)
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_170)
    T_RBRACKET => Shift(yy_state_174)
    _ => Error
  }
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_165)
    NT_kind => Shift(yy_state_171)
    T_EFFECT_KIND => Shift(yy_state_172)
    T_TYPE_KIND => Shift(yy_state_173)
    _ => Error
  }
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_62)
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_61)
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_60)
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_kind_list, yy_action_59)
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_kind_list, yy_action_58)
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_177)
    _ => Error
  }
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KIND_FN => Shift(yy_state_165)
    T_EFFECT_KIND => Shift(yy_state_172)
    T_TYPE_KIND => Shift(yy_state_173)
    NT_kind => Shift(yy_state_178)
    _ => Error
  }
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_179)
    _ => Error
  }
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_kind, yy_action_57)
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_181)
    _ => Error
  }
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_metadata_declaration, yy_action_56)
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_183)
    _ => Error
  }
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_102)
    NT_buslane_name => Shift(yy_state_184)
    NT_buslane_type_name => Shift(yy_state_185)
    _ => Error
  }
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_type_name, yy_action_55)
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PARAMETERS => Shift(yy_state_186)
    _ => Error
  }
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_187)
    _ => Error
  }
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CONSTRUCTORS => Shift(yy_state_188)
    _ => Error
  }
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_189)
    NT_data_con_id_list => Shift(yy_state_196)
    _ => Error
  }
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_134)
    NT_data_con_id => Shift(yy_state_190)
    NT_non_empty_data_con_id_list => Shift(yy_state_191)
    T_RBRACKET => Shift(yy_state_195)
    _ => Error
  }
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_data_con_id_list, yy_action_54)
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_192)
    T_RBRACKET => Shift(yy_state_194)
    _ => Error
  }
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_134)
    NT_data_con_id => Shift(yy_state_193)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_data_con_id_list, yy_action_53)
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_data_con_id_list, yy_action_52)
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_data_con_id_list, yy_action_51)
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_197)
    _ => Error
  }
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_50)
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_metadata_declarations, yy_action_49)
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_metadata, yy_action_48)
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_top_terms => Shift(yy_state_201)
    T_LET | T_LETREC | T_EXTERNAL | T_RBRACE => Reduce(0, NT_top_terms, yy_action_47)
    _ => Error
  }
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERNAL => Shift(yy_state_202)
    T_LETREC => Shift(yy_state_205)
    T_LET => Shift(yy_state_382)
    NT_top_term => Shift(yy_state_387)
    T_RBRACE => Shift(yy_state_388)
    _ => Error
  }
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_203)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_204)
    _ => Error
  }
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_top_term, yy_action_46)
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_206)
    _ => Error
  }
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_207)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_45)
    _ => Error
  }
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_208)
    NT_recursive_binding => Shift(yy_state_372)
    T_RBRACE => Shift(yy_state_381)
    _ => Error
  }
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_209)
    _ => Error
  }
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    NT_expr => Shift(yy_state_379)
    _ => Error
  }
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_211)
    _ => Error
  }
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_212)
    _ => Error
  }
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_213)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_literal, yy_action_44)
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_215)
    _ => Error
  }
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE => Shift(yy_state_216)
    _ => Error
  }
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_217)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_literal, yy_action_43)
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_219)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_220)
    _ => Error
  }
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_221)
    _ => Error
  }
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_literal, yy_action_42)
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_41)
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_40)
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_225)
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
  ReduceNoLookahead(3, NT_literal, yy_action_39)
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_228)
    _ => Error
  }
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    NT_expr => Shift(yy_state_229)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_230)
    _ => Error
  }
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_231)
    _ => Error
  }
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_232)
    _ => Error
  }
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_233)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_234)
    _ => Error
  }
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    NT_expr => Shift(yy_state_235)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_236)
    _ => Error
  }
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    _ => Error
  }
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_handler_tables => Shift(yy_state_238)
    T_HANDLER | T_RBRACE => Reduce(0, NT_handler_tables, yy_action_38)
    _ => Error
  }
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_HANDLER => Shift(yy_state_239)
    NT_handler_table => Shift(yy_state_377)
    T_RBRACE => Shift(yy_state_378)
    _ => Error
  }
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_240)
    _ => Error
  }
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_UNION => Shift(yy_state_48)
    T_EFFECT_SINGLETON => Shift(yy_state_55)
    NT_type_parameter_id => Shift(yy_state_62)
    T_EMPTY_EFFECT => Shift(yy_state_63)
    NT_effect => Shift(yy_state_241)
    _ => Error
  }
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_242)
    _ => Error
  }
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_243)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_operation_alternatives => Shift(yy_state_244)
    T_OP_ALT | T_RBRACE => Reduce(0, NT_operation_alternatives, yy_action_37)
    _ => Error
  }
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OP_ALT => Shift(yy_state_245)
    NT_operation_alternative => Shift(yy_state_375)
    T_RBRACE => Shift(yy_state_376)
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
    T_OPERATION_ID => Shift(yy_state_100)
    NT_operation_id => Shift(yy_state_247)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_248)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_249)
    _ => Error
  }
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_250)
    _ => Error
  }
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_251)
    NT_value_id_list => Shift(yy_state_258)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_252)
    NT_non_empty_value_id_list => Shift(yy_state_253)
    T_RBRACKET => Shift(yy_state_257)
    _ => Error
  }
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_value_id_list, yy_action_36)
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_254)
    T_RBRACKET => Shift(yy_state_256)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_255)
    _ => Error
  }
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_value_id_list, yy_action_35)
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_value_id_list, yy_action_34)
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value_id_list, yy_action_33)
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_259)
    _ => Error
  }
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_260)
    _ => Error
  }
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_261)
    _ => Error
  }
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_262)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    NT_expr => Shift(yy_state_263)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_264)
    _ => Error
  }
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(13, NT_operation_alternative, yy_action_32)
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_266)
    _ => Error
  }
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    NT_expr => Shift(yy_state_267)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_268)
    _ => Error
  }
}

fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_269)
    _ => Error
  }
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_270)
    _ => Error
  }
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_271)
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
  match _lookahead {
    T_LBRACE => Shift(yy_state_273)
    _ => Error
  }
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_alternatives => Shift(yy_state_274)
    T_ALT | T_RBRACE => Reduce(0, NT_alternatives, yy_action_31)
    _ => Error
  }
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ALT => Shift(yy_state_275)
    NT_alternative => Shift(yy_state_373)
    T_RBRACE => Shift(yy_state_374)
    _ => Error
  }
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_276)
    _ => Error
  }
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON => Shift(yy_state_277)
    T_LITERAL_ALT => Shift(yy_state_281)
    T_DEFAULT => Shift(yy_state_285)
    NT_alt_con => Shift(yy_state_286)
    _ => Error
  }
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_278)
    _ => Error
  }
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_134)
    NT_data_con_id => Shift(yy_state_279)
    _ => Error
  }
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_280)
    _ => Error
  }
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_alt_con, yy_action_30)
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_282)
    _ => Error
  }
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    NT_literal => Shift(yy_state_283)
    _ => Error
  }
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_alt_con, yy_action_29)
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_alt_con, yy_action_28)
}

fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_287)
    _ => Error
  }
}

fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_288)
    _ => Error
  }
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_289)
    _ => Error
  }
}

fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_251)
    NT_value_id_list => Shift(yy_state_290)
    _ => Error
  }
}

fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_291)
    _ => Error
  }
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_292)
    _ => Error
  }
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    NT_expr => Shift(yy_state_293)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_294)
    _ => Error
  }
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(11, NT_alternative, yy_action_27)
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_296)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_297)
    _ => Error
  }
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_298)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_45)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_208)
    T_RBRACE => Shift(yy_state_299)
    NT_recursive_binding => Shift(yy_state_372)
    _ => Error
  }
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_300)
    _ => Error
  }
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    NT_expr => Shift(yy_state_301)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_302)
    _ => Error
  }
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expr, yy_action_26)
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_304)
    _ => Error
  }
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_305)
    _ => Error
  }
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_306)
    _ => Error
  }
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    NT_expr => Shift(yy_state_307)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_308)
    _ => Error
  }
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    NT_expr => Shift(yy_state_309)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_310)
    _ => Error
  }
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_expr, yy_action_25)
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_312)
    _ => Error
  }
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_134)
    NT_data_con_id => Shift(yy_state_313)
    _ => Error
  }
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_314)
    _ => Error
  }
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_315)
    _ => Error
  }
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_316)
    _ => Error
  }
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_317)
    _ => Error
  }
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_318)
    _ => Error
  }
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_319)
    NT_expr_list => Shift(yy_state_370)
    _ => Error
  }
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    NT_expr => Shift(yy_state_320)
    NT_non_empty_expr_list => Shift(yy_state_321)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    T_RBRACKET => Shift(yy_state_369)
    _ => Error
  }
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_expr_list, yy_action_24)
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_322)
    T_RBRACKET => Shift(yy_state_368)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    NT_expr => Shift(yy_state_323)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_expr_list, yy_action_23)
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_325)
    _ => Error
  }
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    NT_expr => Shift(yy_state_326)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_327)
    _ => Error
  }
}

fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_328)
    _ => Error
  }
}

fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_329)
    _ => Error
  }
}

fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_22)
}

fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_331)
    _ => Error
  }
}

fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_11)
    NT_type_parameter_id_list => Shift(yy_state_332)
    _ => Error
  }
}

fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_333)
    _ => Error
  }
}

fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_334)
    _ => Error
  }
}

fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    NT_expr => Shift(yy_state_335)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_336)
    _ => Error
  }
}

fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_expr, yy_action_21)
}

fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_338)
    _ => Error
  }
}

fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_339)
    _ => Error
  }
}

fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_340)
    _ => Error
  }
}

fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_expr, yy_action_20)
}

fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_342)
    _ => Error
  }
}

fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_100)
    NT_operation_id => Shift(yy_state_343)
    _ => Error
  }
}

fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_344)
    _ => Error
  }
}

fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_345)
    _ => Error
  }
}

fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_346)
    _ => Error
  }
}

fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_39)
    NT_generic_argument_list => Shift(yy_state_347)
    _ => Error
  }
}

fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_348)
    _ => Error
  }
}

fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_319)
    NT_expr_list => Shift(yy_state_349)
    _ => Error
  }
}

fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_350)
    _ => Error
  }
}

fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_expr, yy_action_19)
}

fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_352)
    _ => Error
  }
}

fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    NT_expr => Shift(yy_state_353)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_354)
    _ => Error
  }
}

fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_319)
    NT_expr_list => Shift(yy_state_355)
    _ => Error
  }
}

fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_356)
    _ => Error
  }
}

fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_18)
}

fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_358)
    _ => Error
  }
}

fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_251)
    NT_value_id_list => Shift(yy_state_359)
    _ => Error
  }
}

fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_360)
    _ => Error
  }
}

fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_STRING_TYPE => Shift(yy_state_4)
    T_DOUBLE_TYPE => Shift(yy_state_5)
    T_INT_TYPE => Shift(yy_state_6)
    T_BOOL_TYPE => Shift(yy_state_7)
    T_UNIT_TYPE => Shift(yy_state_8)
    T_FORALL => Shift(yy_state_9)
    T_FN_TYPE => Shift(yy_state_22)
    T_TYPE_FN => Shift(yy_state_29)
    T_APPLY => Shift(yy_state_35)
    NT_type_id => Shift(yy_state_74)
    NT_type_parameter_id => Shift(yy_state_75)
    NT_primitive_type => Shift(yy_state_76)
    NT_type => Shift(yy_state_361)
    _ => Error
  }
}

fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_362)
    _ => Error
  }
}

fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_363)
    _ => Error
  }
}

fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_expr => Shift(yy_state_364)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_365)
    _ => Error
  }
}

fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_expr, yy_action_17)
}

fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expr, yy_action_16)
}

fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expr, yy_action_15)
}

fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_expr_list, yy_action_14)
}

fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_expr_list, yy_action_13)
}

fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_371)
    _ => Error
  }
}

fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_expr, yy_action_12)
}

fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_recursive_bindings, yy_action_11)
}

fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alternatives, yy_action_10)
}

fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(11, NT_expr, yy_action_9)
}

fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_operation_alternatives, yy_action_8)
}

fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_handler_table, yy_action_7)
}

fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_tables, yy_action_6)
}

fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(13, NT_expr, yy_action_5)
}

fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_380)
    _ => Error
  }
}

fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_recursive_binding, yy_action_4)
}

fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_top_term, yy_action_3)
}

fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    NT_value_id => Shift(yy_state_383)
    _ => Error
  }
}

fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_384)
    _ => Error
  }
}

fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_146)
    T_STRING_LITERAL => Shift(yy_state_210)
    T_DOUBLE_LITERAL => Shift(yy_state_214)
    T_INT_LITERAL => Shift(yy_state_218)
    T_FALSE => Shift(yy_state_222)
    T_TRUE => Shift(yy_state_223)
    T_UNIT_LITERAL => Shift(yy_state_224)
    T_HANDLE => Shift(yy_state_227)
    T_MATCH => Shift(yy_state_265)
    T_LETREC_IN => Shift(yy_state_295)
    T_LET_IN => Shift(yy_state_303)
    T_CONSTRUCT => Shift(yy_state_311)
    T_TYPE_APPLY => Shift(yy_state_324)
    T_TYPE_FN => Shift(yy_state_330)
    T_RESUME => Shift(yy_state_337)
    T_PERFORM => Shift(yy_state_341)
    T_CALL => Shift(yy_state_351)
    T_FN => Shift(yy_state_357)
    NT_literal => Shift(yy_state_366)
    NT_value_id => Shift(yy_state_367)
    NT_expr => Shift(yy_state_385)
    _ => Error
  }
}

fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_386)
    _ => Error
  }
}

fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_top_term, yy_action_2)
}

fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_terms, yy_action_1)
}

fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_389)
    _ => Error
  }
}

fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_buslane_program, yy_action_0)
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
  for term in ([(T_INT, TK_INT), (T_DOUBLE, TK_DOUBLE), (T_STRING, TK_STRING), (T_TYPE_ID, TK_TYPE_ID), (T_TPARAM_ID, TK_TPARAM_ID), (T_VALUE_ID, TK_VALUE_ID), (T_DATACON_ID, TK_DATACON_ID), (T_EFFECT_ID, TK_EFFECT_ID), (T_OPERATION_ID, TK_OPERATION_ID), (T_EOF, TK_EOF), (T_BUSLANE, TK_BUSLANE), (T_METADATA, TK_METADATA), (T_TYPE, TK_TYPE), (T_TYPE_PARAMETER, TK_TYPE_PARAMETER), (T_VALUE, TK_VALUE), (T_DATACON, TK_DATACON), (T_EFFECT_DECL, TK_EFFECT_DECL), (T_OPERATION, TK_OPERATION), (T_NAME, TK_NAME), (T_UNIQUE, TK_UNIQUE), (T_PARAMETERS, TK_PARAMETERS), (T_CONSTRUCTORS, TK_CONSTRUCTORS), (T_OPERATIONS, TK_OPERATIONS), (T_OWNER, TK_OWNER), (T_HIDDEN, TK_HIDDEN), (T_PAYLOAD, TK_PAYLOAD), (T_RESULT, TK_RESULT), (T_FUNCTION_KIND, TK_FUNCTION_KIND), (T_PARAMETER_KIND, TK_PARAMETER_KIND), (T_LOCAL_KIND, TK_LOCAL_KIND), (T_MATCH_BINDER_KIND, TK_MATCH_BINDER_KIND), (T_TYPE_KIND, TK_TYPE_KIND), (T_EFFECT_KIND, TK_EFFECT_KIND), (T_UNIT_TYPE, TK_UNIT_TYPE), (T_BOOL_TYPE, TK_BOOL_TYPE), (T_INT_TYPE, TK_INT_TYPE), (T_DOUBLE_TYPE, TK_DOUBLE_TYPE), (T_STRING_TYPE, TK_STRING_TYPE), (T_KIND_FN, TK_KIND_FN), (T_EMPTY_EFFECT, TK_EMPTY_EFFECT), (T_EFFECT_SINGLETON, TK_EFFECT_SINGLETON), (T_EFFECT_UNION, TK_EFFECT_UNION), (T_APPLY, TK_APPLY), (T_TYPE_FN, TK_TYPE_FN), (T_FN_TYPE, TK_FN_TYPE), (T_FORALL, TK_FORALL), (T_LET, TK_LET), (T_LETREC, TK_LETREC), (T_EXTERNAL, TK_EXTERNAL), (T_FN, TK_FN), (T_CALL, TK_CALL), (T_PERFORM, TK_PERFORM), (T_HANDLE, TK_HANDLE), (T_RESUME, TK_RESUME), (T_HANDLER, TK_HANDLER), (T_OP_ALT, TK_OP_ALT), (T_FINAL, TK_FINAL), (T_TYPE_APPLY, TK_TYPE_APPLY), (T_CONSTRUCT, TK_CONSTRUCT), (T_LET_IN, TK_LET_IN), (T_LETREC_IN, TK_LETREC_IN), (T_MATCH, TK_MATCH), (T_ALT, TK_ALT), (T_DEFAULT, TK_DEFAULT), (T_LITERAL_ALT, TK_LITERAL_ALT), (T_TRUE, TK_TRUE), (T_FALSE, TK_FALSE), (T_INT_LITERAL, TK_INT_LITERAL), (T_DOUBLE_LITERAL, TK_DOUBLE_LITERAL), (T_STRING_LITERAL, TK_STRING_LITERAL), (T_UNIT_LITERAL, TK_UNIT_LITERAL), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_COMMA, TK_COMMA), (T_COLON, TK_COLON), (T_SEMI, TK_SEMI), (T_EQUAL, TK_EQUAL), (T_FAT_ARROW, TK_FAT_ARROW)] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

pub fn buslane_program(tokens : Array[(Token, SourceSpan, SourceSpan)], initial_pos? : SourceSpan) -> Program raise ParseError {
  yy_parse(
    tokens,
    yy_state_92,
    (it) => {
      guard it is YYObj_Program(result)
      result
    },
    initial_pos?,
  )
}
pub fn buslane_type(tokens : Array[(Token, SourceSpan, SourceSpan)], initial_pos? : SourceSpan) -> Type raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    (it) => {
      guard it is YYObj_Type(result)
      result
    },
    initial_pos?,
  )
}
