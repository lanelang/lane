
pub(all) enum Token {
  LITERAL(Literal)
  NAME((String, Int))
  TYPE_ID(Int)
  TPARAM_ID(Int)
  VALUE_ID(Int)
  DATACON_ID(Int)
  EFFECT_ID(Int)
  OPERATION_ID(Int)
  NEXT_UNIQUE(Int)
  EOF
  BUSLANE
  METADATA
  TYPE
  TYPE_PARAMETER
  VALUE
  DATACON
  EFFECT_DECL
  OPERATION
  FUNCTION_KIND
  PARAMETER_KIND
  LOCAL_KIND
  MATCH_BINDER_KIND
  TYPE_KIND
  EFFECT_KIND
  UNIT_TYPE
  BOOL_TYPE
  I64_TYPE
  I32_TYPE
  CHAR_TYPE
  F32_TYPE
  F64_TYPE
  STRING_TYPE
  BYTE_TYPE
  BYTES_TYPE
  IO
  FORALL
  IN
  AS
  FINAL
  UNDERSCORE
  LET
  LETREC
  EXTERNAL
  FN
  PERFORM
  HANDLE
  RESUME
  MATCH
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
  ARROW
  BANG
  DOT
} derive(Debug)

pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    LITERAL(_) => TK_LITERAL
    NAME(_) => TK_NAME
    TYPE_ID(_) => TK_TYPE_ID
    TPARAM_ID(_) => TK_TPARAM_ID
    VALUE_ID(_) => TK_VALUE_ID
    DATACON_ID(_) => TK_DATACON_ID
    EFFECT_ID(_) => TK_EFFECT_ID
    OPERATION_ID(_) => TK_OPERATION_ID
    NEXT_UNIQUE(_) => TK_NEXT_UNIQUE
    EOF => TK_EOF
    BUSLANE => TK_BUSLANE
    METADATA => TK_METADATA
    TYPE => TK_TYPE
    TYPE_PARAMETER => TK_TYPE_PARAMETER
    VALUE => TK_VALUE
    DATACON => TK_DATACON
    EFFECT_DECL => TK_EFFECT_DECL
    OPERATION => TK_OPERATION
    FUNCTION_KIND => TK_FUNCTION_KIND
    PARAMETER_KIND => TK_PARAMETER_KIND
    LOCAL_KIND => TK_LOCAL_KIND
    MATCH_BINDER_KIND => TK_MATCH_BINDER_KIND
    TYPE_KIND => TK_TYPE_KIND
    EFFECT_KIND => TK_EFFECT_KIND
    UNIT_TYPE => TK_UNIT_TYPE
    BOOL_TYPE => TK_BOOL_TYPE
    I64_TYPE => TK_I64_TYPE
    I32_TYPE => TK_I32_TYPE
    CHAR_TYPE => TK_CHAR_TYPE
    F32_TYPE => TK_F32_TYPE
    F64_TYPE => TK_F64_TYPE
    STRING_TYPE => TK_STRING_TYPE
    BYTE_TYPE => TK_BYTE_TYPE
    BYTES_TYPE => TK_BYTES_TYPE
    IO => TK_IO
    FORALL => TK_FORALL
    IN => TK_IN
    AS => TK_AS
    FINAL => TK_FINAL
    UNDERSCORE => TK_UNDERSCORE
    LET => TK_LET
    LETREC => TK_LETREC
    EXTERNAL => TK_EXTERNAL
    FN => TK_FN
    PERFORM => TK_PERFORM
    HANDLE => TK_HANDLE
    RESUME => TK_RESUME
    MATCH => TK_MATCH
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
    ARROW => TK_ARROW
    BANG => TK_BANG
    DOT => TK_DOT
  }
}

pub(all) enum TokenKind {
  TK_LITERAL
  TK_NAME
  TK_TYPE_ID
  TK_TPARAM_ID
  TK_VALUE_ID
  TK_DATACON_ID
  TK_EFFECT_ID
  TK_OPERATION_ID
  TK_NEXT_UNIQUE
  TK_EOF
  TK_BUSLANE
  TK_METADATA
  TK_TYPE
  TK_TYPE_PARAMETER
  TK_VALUE
  TK_DATACON
  TK_EFFECT_DECL
  TK_OPERATION
  TK_FUNCTION_KIND
  TK_PARAMETER_KIND
  TK_LOCAL_KIND
  TK_MATCH_BINDER_KIND
  TK_TYPE_KIND
  TK_EFFECT_KIND
  TK_UNIT_TYPE
  TK_BOOL_TYPE
  TK_I64_TYPE
  TK_I32_TYPE
  TK_CHAR_TYPE
  TK_F32_TYPE
  TK_F64_TYPE
  TK_STRING_TYPE
  TK_BYTE_TYPE
  TK_BYTES_TYPE
  TK_IO
  TK_FORALL
  TK_IN
  TK_AS
  TK_FINAL
  TK_UNDERSCORE
  TK_LET
  TK_LETREC
  TK_EXTERNAL
  TK_FN
  TK_PERFORM
  TK_HANDLE
  TK_RESUME
  TK_MATCH
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
  TK_ARROW
  TK_BANG
  TK_DOT
} derive(Eq, Hash, Compare)

pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_LITERAL => "LITERAL"
      TK_NAME => "NAME"
      TK_TYPE_ID => "TYPE_ID"
      TK_TPARAM_ID => "TPARAM_ID"
      TK_VALUE_ID => "VALUE_ID"
      TK_DATACON_ID => "DATACON_ID"
      TK_EFFECT_ID => "EFFECT_ID"
      TK_OPERATION_ID => "OPERATION_ID"
      TK_NEXT_UNIQUE => "NEXT_UNIQUE"
      TK_EOF => "EOF"
      TK_BUSLANE => "\"buslane\""
      TK_METADATA => "\"metadata\""
      TK_TYPE => "\"type\""
      TK_TYPE_PARAMETER => "\"type_parameter\""
      TK_VALUE => "\"value\""
      TK_DATACON => "\"datacon\""
      TK_EFFECT_DECL => "\"effect\""
      TK_OPERATION => "\"operation\""
      TK_FUNCTION_KIND => "\"function\""
      TK_PARAMETER_KIND => "\"parameter\""
      TK_LOCAL_KIND => "\"local\""
      TK_MATCH_BINDER_KIND => "\"match_binder\""
      TK_TYPE_KIND => "\"Type\""
      TK_EFFECT_KIND => "\"Effect\""
      TK_UNIT_TYPE => "\"Unit\""
      TK_BOOL_TYPE => "\"Bool\""
      TK_I64_TYPE => "\"I64\""
      TK_I32_TYPE => "\"I32\""
      TK_CHAR_TYPE => "\"Char\""
      TK_F32_TYPE => "\"F32\""
      TK_F64_TYPE => "\"F64\""
      TK_STRING_TYPE => "\"String\""
      TK_BYTE_TYPE => "\"Byte\""
      TK_BYTES_TYPE => "\"Bytes\""
      TK_IO => "\"Io\""
      TK_FORALL => "\"forall\""
      TK_IN => "\"in\""
      TK_AS => "\"as\""
      TK_FINAL => "\"final\""
      TK_UNDERSCORE => "\"_\""
      TK_LET => "\"let\""
      TK_LETREC => "\"letrec\""
      TK_EXTERNAL => "\"external\""
      TK_FN => "\"fn\""
      TK_PERFORM => "\"perform\""
      TK_HANDLE => "\"handle\""
      TK_RESUME => "\"resume\""
      TK_MATCH => "\"match\""
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
      TK_ARROW => "\"->\""
      TK_BANG => "\"!\""
      TK_DOT => "\".\""
    }
  )
}

pub impl Debug for TokenKind with fn to_repr(self) {
    match self {
      TK_LITERAL => Repr("LITERAL")
      TK_NAME => Repr("NAME")
      TK_TYPE_ID => Repr("TYPE_ID")
      TK_TPARAM_ID => Repr("TPARAM_ID")
      TK_VALUE_ID => Repr("VALUE_ID")
      TK_DATACON_ID => Repr("DATACON_ID")
      TK_EFFECT_ID => Repr("EFFECT_ID")
      TK_OPERATION_ID => Repr("OPERATION_ID")
      TK_NEXT_UNIQUE => Repr("NEXT_UNIQUE")
      TK_EOF => Repr("EOF")
      TK_BUSLANE => Repr("buslane")
      TK_METADATA => Repr("metadata")
      TK_TYPE => Repr("type")
      TK_TYPE_PARAMETER => Repr("type_parameter")
      TK_VALUE => Repr("value")
      TK_DATACON => Repr("datacon")
      TK_EFFECT_DECL => Repr("effect")
      TK_OPERATION => Repr("operation")
      TK_FUNCTION_KIND => Repr("function")
      TK_PARAMETER_KIND => Repr("parameter")
      TK_LOCAL_KIND => Repr("local")
      TK_MATCH_BINDER_KIND => Repr("match_binder")
      TK_TYPE_KIND => Repr("Type")
      TK_EFFECT_KIND => Repr("Effect")
      TK_UNIT_TYPE => Repr("Unit")
      TK_BOOL_TYPE => Repr("Bool")
      TK_I64_TYPE => Repr("I64")
      TK_I32_TYPE => Repr("I32")
      TK_CHAR_TYPE => Repr("Char")
      TK_F32_TYPE => Repr("F32")
      TK_F64_TYPE => Repr("F64")
      TK_STRING_TYPE => Repr("String")
      TK_BYTE_TYPE => Repr("Byte")
      TK_BYTES_TYPE => Repr("Bytes")
      TK_IO => Repr("Io")
      TK_FORALL => Repr("forall")
      TK_IN => Repr("in")
      TK_AS => Repr("as")
      TK_FINAL => Repr("final")
      TK_UNDERSCORE => Repr("_")
      TK_LET => Repr("let")
      TK_LETREC => Repr("letrec")
      TK_EXTERNAL => Repr("external")
      TK_FN => Repr("fn")
      TK_PERFORM => Repr("perform")
      TK_HANDLE => Repr("handle")
      TK_RESUME => Repr("resume")
      TK_MATCH => Repr("match")
      TK_LBRACE => Repr("{")
      TK_RBRACE => Repr("}")
      TK_LBRACKET => Repr("[")
      TK_RBRACKET => Repr("]")
      TK_LPAREN => Repr("(")
      TK_RPAREN => Repr(")")
      TK_COMMA => Repr(",")
      TK_COLON => Repr(":")
      TK_SEMI => Repr(";")
      TK_EQUAL => Repr("=")
      TK_FAT_ARROW => Repr("=>")
      TK_ARROW => Repr("->")
      TK_BANG => Repr("!")
      TK_DOT => Repr(".")
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

priv suberror YYObj_Effect {
  YYObj_Effect(Effect)
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

priv suberror YYObj__Array_GenericArgument___Array_GenericArgument__ {
  YYObj__Array_GenericArgument___Array_GenericArgument__((Array[GenericArgument], Array[GenericArgument]))
}

priv suberror YYObj__String__Int_ {
  YYObj__String__Int_((String, Int))
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
  T_LITERAL
  T_NAME
  T_TYPE_ID
  T_TPARAM_ID
  T_VALUE_ID
  T_DATACON_ID
  T_EFFECT_ID
  T_OPERATION_ID
  T_NEXT_UNIQUE
  T_EOF
  T_BUSLANE
  T_METADATA
  T_TYPE
  T_TYPE_PARAMETER
  T_VALUE
  T_DATACON
  T_EFFECT_DECL
  T_OPERATION
  T_FUNCTION_KIND
  T_PARAMETER_KIND
  T_LOCAL_KIND
  T_MATCH_BINDER_KIND
  T_TYPE_KIND
  T_EFFECT_KIND
  T_UNIT_TYPE
  T_BOOL_TYPE
  T_I64_TYPE
  T_I32_TYPE
  T_CHAR_TYPE
  T_F32_TYPE
  T_F64_TYPE
  T_STRING_TYPE
  T_BYTE_TYPE
  T_BYTES_TYPE
  T_IO
  T_FORALL
  T_IN
  T_AS
  T_FINAL
  T_UNDERSCORE
  T_LET
  T_LETREC
  T_EXTERNAL
  T_FN
  T_PERFORM
  T_HANDLE
  T_RESUME
  T_MATCH
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
  T_ARROW
  T_BANG
  T_DOT
  NT_buslane_program
  NT_buslane_type
  NT_metadata
  NT_metadata_declarations
  NT_metadata_declaration
  NT_external_marker
  NT_buslane_name
  NT_top_terms
  NT_top_term
  NT_recursive_bindings
  NT_recursive_binding
  NT_expr
  NT_postfix_expr
  NT_atom_expr
  NT_argument_group
  NT_handler_tables
  NT_handler_table
  NT_operation_alternatives
  NT_operation_alternative
  NT_alternatives
  NT_alternative
  NT_literal
  NT_kind
  NT_type
  NT_arrow_type
  NT_parameter_types
  NT_paren_type
  NT_paren_types
  NT_applied_type
  NT_atom_type
  NT_effect
  NT_primitive_type
  NT_value_kind
  NT_generic_argument
  NT_generic_arguments
  NT_non_empty_generic_arguments
  NT_kind_list
  NT_non_empty_kind_list
  NT_type_list
  NT_non_empty_type_list
  NT_non_empty_effect_list
  NT_expr_list
  NT_non_empty_expr_list
  NT_type_parameter_ids
  NT_type_parameter_id_list
  NT_non_empty_type_parameter_ids
  NT_value_id_list
  NT_non_empty_value_id_list
  NT_data_con_ids
  NT_non_empty_data_con_ids
  NT_operation_ids
  NT_non_empty_operation_ids
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
// 77|    "buslane" "{" metadata top_terms "}" EOF {
// 78|    { metadata: $3, terms: $4 }
// 79|  }
fn yy_action_0(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_MetadataRegistry(_dollar3)
  guard _args[3].0 is YYObj_Array_TopTerm_(_dollar4)
  YYObj_Program({(); 
    { metadata: _dollar3, terms: _dollar4 }
  })
}

// file:///./parser.mbty
// 158|    top_terms top_term { comma_push($1, $2) }
fn yy_action_1(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TopTerm_(_dollar1)
  guard _args[1].0 is YYObj_TopTerm(_dollar2)
  YYObj_Array_TopTerm_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 162|    "let" value_id "=" expr { Let($2, $4) }
fn yy_action_2(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  YYObj_TopTerm({();  Let(_dollar2, _dollar4) })
}

// file:///./parser.mbty
// 163|    "letrec" "{" recursive_bindings "}" { LetRec($3) }
fn yy_action_3(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_RecursiveBinding_(_dollar3)
  YYObj_TopTerm({();  LetRec(_dollar3) })
}

// file:///./parser.mbty
// 173|    value_id "=" expr { { id: $1, rhs: $3 } }
fn yy_action_4(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_RecursiveBinding({();  { id: _dollar1, rhs: _dollar3 } })
}

// file:///./parser.mbty
// 217|    "handle" expr "as" value_id "->" type "{" handler_tables "final" "=>" expr "}" {
// 218|    Handle({
// 219|      body: $2,
// 220|      result_binder: $4,
// 221|      result_type: $6,
// 222|      final_body: $11,
// 223|      handlers: $8,
// 224|    })
// 225|  }
fn yy_action_5(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_ValueId(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[10].0 is YYObj_Expr(_dollar11)
  guard _args[7].0 is YYObj_Array_HandlerTable_(_dollar8)
  YYObj_Expr({(); 
    Handle({
      body: _dollar2,
      result_binder: _dollar4,
      result_type: _dollar6,
      final_body: _dollar11,
      handlers: _dollar8,
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
// 240|    effect "{" operation_alternatives "}" {
// 241|    { handled_effect: $1, operations: $3 }
// 242|  }
fn yy_action_7(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Effect(_dollar1)
  guard _args[2].0 is YYObj_Array_OperationAlternative_(_dollar3)
  YYObj_HandlerTable({(); 
    { handled_effect: _dollar1, operations: _dollar3 }
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
// 214|    "match" expr "as" value_id "->" type "{" alternatives "}" {
// 215|    Match({ scrutinee: $2, binder: $4, result_type: $6, alternatives: $8 })
// 216|  }
fn yy_action_9(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  guard _args[3].0 is YYObj_ValueId(_dollar4)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_Array_Alternative_(_dollar8)
  YYObj_Expr({(); 
    Match({ scrutinee: _dollar2, binder: _dollar4, result_type: _dollar6, alternatives: _dollar8 })
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
// 268|    "_" "=>" expr {
// 269|    { alt_constructor: Default, type_binders: [], value_binders: [], body: $3 }
// 270|  }
fn yy_action_11(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Alternative({(); 
    { alt_constructor: Default, type_binders: [], value_binders: [], body: _dollar3 }
  })
}

// file:///./parser.mbty
// 271|    literal "=>" expr {
// 272|    {
// 273|      alt_constructor: Literal($1),
// 274|      type_binders: [],
// 275|      value_binders: [],
// 276|      body: $3,
// 277|    }
// 278|  }
fn yy_action_12(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Literal(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Alternative({(); 
    {
      alt_constructor: Literal(_dollar1),
      type_binders: [],
      value_binders: [],
      body: _dollar3,
    }
  })
}

// file:///./parser.mbty
// 210|    "fn" "(" value_id_list ")" "->" type "{" expr "}" {
// 211|    Function({ parameters: $3, result_type: $6, body: $8 })
// 212|  }
fn yy_action_13(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_ValueId_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  guard _args[7].0 is YYObj_Expr(_dollar8)
  YYObj_Expr({(); 
    Function({ parameters: _dollar3, result_type: _dollar6, body: _dollar8 })
  })
}

// file:///./parser.mbty
// 202|    "perform" operation_id argument_group "(" expr_list ")" {
// 203|    Perform({
// 204|      operation: $2,
// 205|      effect_arguments: $3.0,
// 206|      hidden_witnesses: $3.1,
// 207|      payloads: $5,
// 208|    })
// 209|  }
fn yy_action_14(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_OperationId(_dollar2)
  guard _args[2].0 is YYObj__Array_GenericArgument___Array_GenericArgument__(_dollar3)
  guard _args[4].0 is YYObj_Array_Expr_(_dollar5)
  YYObj_Expr({(); 
    Perform({
      operation: _dollar2,
      effect_arguments: _dollar3.0,
      hidden_witnesses: _dollar3.1,
      payloads: _dollar5,
    })
  })
}

// file:///./parser.mbty
// 169|    recursive_bindings recursive_binding { comma_push($1, $2) }
fn yy_action_15(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_RecursiveBinding_(_dollar1)
  guard _args[1].0 is YYObj_RecursiveBinding(_dollar2)
  YYObj_Array_RecursiveBinding_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
// 185|    postfix_expr "(" expr_list ")" { Call($1, $3) }
fn yy_action_16(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_Expr_(_dollar3)
  YYObj_Expr({();  Call(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 186|    postfix_expr "[" generic_arguments "]" { TypeApply($1, $3) }
fn yy_action_17(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  YYObj_Expr({();  TypeApply(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 177|    postfix_expr { $1 }
fn yy_action_18(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 178|    "let" value_id "=" expr "in" expr { Let($2, $4, $6) }
fn yy_action_19(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[3].0 is YYObj_Expr(_dollar4)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  YYObj_Expr({();  Let(_dollar2, _dollar4, _dollar6) })
}

// file:///./parser.mbty
// 179|    "letrec" "{" recursive_bindings "}" "in" expr { LetRec($3, $6) }
fn yy_action_20(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_RecursiveBinding_(_dollar3)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  YYObj_Expr({();  LetRec(_dollar3, _dollar6) })
}

// file:///./parser.mbty
// 184|    atom_expr { $1 }
fn yy_action_21(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Expr({();  _dollar1 })
}

// file:///./parser.mbty
// 190|    value_id { Ref($1) }
fn yy_action_22(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Expr({();  Ref(_dollar1) })
}

// file:///./parser.mbty
// 191|    literal { Literal($1) }
fn yy_action_23(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Literal(_dollar1)
  YYObj_Expr({();  Literal(_dollar1) })
}

// file:///./parser.mbty
// 192|    "(" expr ")" { $2 }
fn yy_action_24(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Expr(_dollar2)
  YYObj_Expr({();  _dollar2 })
}

// file:///./parser.mbty
// 193|    data_con_id argument_group "(" expr_list ")" {
// 194|    Construct({
// 195|      data_constructor: $1,
// 196|      type_arguments: $2.0,
// 197|      hidden_witnesses: $2.1,
// 198|      payloads: $4,
// 199|    })
// 200|  }
fn yy_action_25(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_DataConId(_dollar1)
  guard _args[1].0 is YYObj__Array_GenericArgument___Array_GenericArgument__(_dollar2)
  guard _args[3].0 is YYObj_Array_Expr_(_dollar4)
  YYObj_Expr({(); 
    Construct({
      data_constructor: _dollar1,
      type_arguments: _dollar2.0,
      hidden_witnesses: _dollar2.1,
      payloads: _dollar4,
    })
  })
}

// file:///./parser.mbty
// 201|    "resume" value_id { Resume($2) }
fn yy_action_26(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  YYObj_Expr({();  Resume(_dollar2) })
}

// file:///./parser.mbty
// 427|    non_empty_expr_list "," expr { comma_push($1, $3) }
fn yy_action_27(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  guard _args[2].0 is YYObj_Expr(_dollar3)
  YYObj_Array_Expr_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 422|    non_empty_expr_list { $1 }
fn yy_action_28(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Expr_(_dollar1)
  YYObj_Array_Expr_({();  _dollar1 })
}

// file:///./parser.mbty
// 426|    expr { [ $1 ] }
fn yy_action_29(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Expr(_dollar1)
  YYObj_Array_Expr_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 421|    { [] }
fn yy_action_30(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Expr_({();  [] })
}

// file:///./parser.mbty
// 230|    "[" generic_arguments "]" { ($2, []) }
fn yy_action_31(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  YYObj__Array_GenericArgument___Array_GenericArgument__({();  (_dollar2, []) })
}

// file:///./parser.mbty
// 231|    "[" generic_arguments ";" generic_arguments "]" { ($2, $4) }
fn yy_action_32(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_GenericArgument_(_dollar2)
  guard _args[3].0 is YYObj_Array_GenericArgument_(_dollar4)
  YYObj__Array_GenericArgument___Array_GenericArgument__({();  (_dollar2, _dollar4) })
}

// file:///./parser.mbty
// 229|    { ([], []) }
fn yy_action_33(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj__Array_GenericArgument___Array_GenericArgument__({();  ([], []) })
}

// file:///./parser.mbty
// 213|    "fn" "[" type_parameter_id_list "]" "{" expr "}" { TypeLambda($3, $6) }
fn yy_action_34(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[5].0 is YYObj_Expr(_dollar6)
  YYObj_Expr({();  TypeLambda(_dollar3, _dollar6) })
}

// file:///./parser.mbty
// 279|    data_con_id type_parameter_ids "(" value_id_list ")" "=>" expr {
// 280|    {
// 281|      alt_constructor: DataCon($1),
// 282|      type_binders: $2,
// 283|      value_binders: $4,
// 284|      body: $7,
// 285|    }
// 286|  }
fn yy_action_35(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_DataConId(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameterId_(_dollar2)
  guard _args[3].0 is YYObj_Array_ValueId_(_dollar4)
  guard _args[6].0 is YYObj_Expr(_dollar7)
  YYObj_Alternative({(); 
    {
      alt_constructor: DataCon(_dollar1),
      type_binders: _dollar2,
      value_binders: _dollar4,
      body: _dollar7,
    }
  })
}

// file:///./parser.mbty
// 295|    "(" ")" { Unit }
fn yy_action_36(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Literal({();  Unit })
}

// file:///./parser.mbty
// 263|    { [] }
fn yy_action_37(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Alternative_({();  [] })
}

// file:///./parser.mbty
// 251|    operation_id type_parameter_ids "(" value_id_list ")" "resume" value_id "=>" expr {
// 252|    {
// 253|      operation: $1,
// 254|      type_binders: $2,
// 255|      payload_binders: $4,
// 256|      resume_binder: $7,
// 257|      body: $9,
// 258|    }
// 259|  }
fn yy_action_38(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OperationId(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeParameterId_(_dollar2)
  guard _args[3].0 is YYObj_Array_ValueId_(_dollar4)
  guard _args[6].0 is YYObj_ValueId(_dollar7)
  guard _args[8].0 is YYObj_Expr(_dollar9)
  YYObj_OperationAlternative({(); 
    {
      operation: _dollar1,
      type_binders: _dollar2,
      payload_binders: _dollar4,
      resume_binder: _dollar7,
      body: _dollar9,
    }
  })
}

// file:///./parser.mbty
// 452|    non_empty_value_id_list "," value_id { comma_push($1, $3) }
fn yy_action_39(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValueId_(_dollar1)
  guard _args[2].0 is YYObj_ValueId(_dollar3)
  YYObj_Array_ValueId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 447|    non_empty_value_id_list { $1 }
fn yy_action_40(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValueId_(_dollar1)
  YYObj_Array_ValueId_({();  _dollar1 })
}

// file:///./parser.mbty
// 451|    value_id { [ $1 ] }
fn yy_action_41(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_ValueId(_dollar1)
  YYObj_Array_ValueId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 446|    { [] }
fn yy_action_42(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_ValueId_({();  [] })
}

// file:///./parser.mbty
// 246|    { [] }
fn yy_action_43(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_OperationAlternative_({();  [] })
}

// file:///./parser.mbty
// 235|    { [] }
fn yy_action_44(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_HandlerTable_({();  [] })
}

// file:///./parser.mbty
// 296|    LITERAL { $1 }
fn yy_action_45(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Literal(_dollar1)
  YYObj_Literal({();  _dollar1 })
}

// file:///./parser.mbty
// 168|    { [] }
fn yy_action_46(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_RecursiveBinding_({();  [] })
}

// file:///./parser.mbty
// 164|    "external" value_id { External($2) }
fn yy_action_47(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  YYObj_TopTerm({();  External(_dollar2) })
}

// file:///./parser.mbty
// 157|    { [] }
fn yy_action_48(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TopTerm_({();  [] })
}

// file:///./parser.mbty
// 87|    "metadata" "{" NEXT_UNIQUE ";" metadata_declarations "}" {
// 88|    make_metadata($3, $5)
// 89|  }
fn yy_action_49(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Int(_dollar3)
  guard _args[4].0 is YYObj_Array_MetadataDeclaration_(_dollar5)
  YYObj_MetadataRegistry({(); 
    make_metadata(_dollar3, _dollar5)
  })
}

// file:///./parser.mbty
// 94|    metadata_declarations metadata_declaration { comma_push($1, $2) }
fn yy_action_50(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_MetadataDeclaration_(_dollar1)
  guard _args[1].0 is YYObj_MetadataDeclaration(_dollar2)
  YYObj_Array_MetadataDeclaration_({();  comma_push(_dollar1, _dollar2) })
}

// file:///./parser.mbty
//  98|    external_marker "type" type_id "=" buslane_name type_parameter_ids data_con_ids ";" {
//  99|    TypeInfoDecl($3, {
// 100|      name: parsed_name(TypeName, $5.occurrence, $5.unique),
// 101|      flavor: if $1 { External } else { Data },
// 102|      parameters: $6,
// 103|      constructors: $7,
// 104|    })
// 105|  }
fn yy_action_51(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_TypeId(_dollar3)
  guard _args[4].0 is YYObj_ParsedBuslaneName(_dollar5)
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[5].0 is YYObj_Array_TypeParameterId_(_dollar6)
  guard _args[6].0 is YYObj_Array_DataConId_(_dollar7)
  YYObj_MetadataDeclaration({(); 
    TypeInfoDecl(_dollar3, {
      name: parsed_name(TypeName, _dollar5.occurrence, _dollar5.unique),
      flavor: if _dollar1 { External } else { Data },
      parameters: _dollar6,
      constructors: _dollar7,
    })
  })
}

// file:///./parser.mbty
// 456|    "{" "}" { [] }
fn yy_action_52(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_DataConId_({();  [] })
}

// file:///./parser.mbty
// 457|    "{" non_empty_data_con_ids "}" { $2 }
fn yy_action_53(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_DataConId_(_dollar2)
  YYObj_Array_DataConId_({();  _dollar2 })
}

// file:///./parser.mbty
// 462|    non_empty_data_con_ids "," data_con_id { comma_push($1, $3) }
fn yy_action_54(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_DataConId_(_dollar1)
  guard _args[2].0 is YYObj_DataConId(_dollar3)
  YYObj_Array_DataConId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 461|    data_con_id { [ $1 ] }
fn yy_action_55(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_DataConId(_dollar1)
  YYObj_Array_DataConId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 106|    external_marker "type_parameter" type_parameter_id "=" buslane_name ":" kind ";" {
// 107|    TypeParameterInfoDecl($3, {
// 108|      name: parsed_name(TypeParameterName, $5.occurrence, $5.unique),
// 109|      kind: $7,
// 110|      flavor: if $1 { External } else { Algebraic },
// 111|    })
// 112|  }
fn yy_action_56(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_TypeParameterId(_dollar3)
  guard _args[4].0 is YYObj_ParsedBuslaneName(_dollar5)
  guard _args[6].0 is YYObj_Kind(_dollar7)
  guard _args[0].0 is YYObj_Bool(_dollar1)
  YYObj_MetadataDeclaration({(); 
    TypeParameterInfoDecl(_dollar3, {
      name: parsed_name(TypeParameterName, _dollar5.occurrence, _dollar5.unique),
      kind: _dollar7,
      flavor: if _dollar1 { External } else { Algebraic },
    })
  })
}

// file:///./parser.mbty
// 302|    "[" kind_list "]" "->" kind { Function($2, $5) }
fn yy_action_57(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Kind_(_dollar2)
  guard _args[4].0 is YYObj_Kind(_dollar5)
  YYObj_Kind({();  Function(_dollar2, _dollar5) })
}

// file:///./parser.mbty
// 300|    "Type" { Type }
fn yy_action_58(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind({();  Type })
}

// file:///./parser.mbty
// 301|    "Effect" { Effect }
fn yy_action_59(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Kind({();  Effect })
}

// file:///./parser.mbty
// 402|    non_empty_kind_list "," kind { comma_push($1, $3) }
fn yy_action_60(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  guard _args[2].0 is YYObj_Kind(_dollar3)
  YYObj_Array_Kind_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 397|    non_empty_kind_list { $1 }
fn yy_action_61(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Kind_(_dollar1)
  YYObj_Array_Kind_({();  _dollar1 })
}

// file:///./parser.mbty
// 401|    kind { [ $1 ] }
fn yy_action_62(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Kind(_dollar1)
  YYObj_Array_Kind_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 396|    { [] }
fn yy_action_63(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Kind_({();  [] })
}

// file:///./parser.mbty
// 128|    external_marker "effect" effect_id "=" buslane_name type_parameter_ids operation_ids ";" {
// 129|    EffectInfoDecl($3, {
// 130|      name: parsed_name(EffectName, $5.occurrence, $5.unique),
// 131|      flavor: if $1 { External } else { Algebraic },
// 132|      parameters: $6,
// 133|      operations: $7,
// 134|    })
// 135|  }
fn yy_action_64(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_EffectId(_dollar3)
  guard _args[4].0 is YYObj_ParsedBuslaneName(_dollar5)
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[5].0 is YYObj_Array_TypeParameterId_(_dollar6)
  guard _args[6].0 is YYObj_Array_OperationId_(_dollar7)
  YYObj_MetadataDeclaration({(); 
    EffectInfoDecl(_dollar3, {
      name: parsed_name(EffectName, _dollar5.occurrence, _dollar5.unique),
      flavor: if _dollar1 { External } else { Algebraic },
      parameters: _dollar6,
      operations: _dollar7,
    })
  })
}

// file:///./parser.mbty
// 466|    "{" "}" { [] }
fn yy_action_65(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_OperationId_({();  [] })
}

// file:///./parser.mbty
// 467|    "{" non_empty_operation_ids "}" { $2 }
fn yy_action_66(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_OperationId_(_dollar2)
  YYObj_Array_OperationId_({();  _dollar2 })
}

// file:///./parser.mbty
// 472|    non_empty_operation_ids "," operation_id { comma_push($1, $3) }
fn yy_action_67(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_OperationId_(_dollar1)
  guard _args[2].0 is YYObj_OperationId(_dollar3)
  YYObj_Array_OperationId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 471|    operation_id { [ $1 ] }
fn yy_action_68(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_OperationId(_dollar1)
  YYObj_Array_OperationId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 113|    "datacon" data_con_id "=" buslane_name type_parameter_ids "(" type_list ")" ":" type_id ";" {
// 114|    DataConInfoDecl($2, {
// 115|      name: parsed_name(DataConstructorName, $4.occurrence, $4.unique),
// 116|      owner: $10,
// 117|      hidden_type_parameters: $5,
// 118|      payload_types: $7,
// 119|    })
// 120|  }
fn yy_action_69(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_DataConId(_dollar2)
  guard _args[3].0 is YYObj_ParsedBuslaneName(_dollar4)
  guard _args[9].0 is YYObj_TypeId(_dollar10)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_Type_(_dollar7)
  YYObj_MetadataDeclaration({(); 
    DataConInfoDecl(_dollar2, {
      name: parsed_name(DataConstructorName, _dollar4.occurrence, _dollar4.unique),
      owner: _dollar10,
      hidden_type_parameters: _dollar5,
      payload_types: _dollar7,
    })
  })
}

// file:///./parser.mbty
// 488|    DATACON_ID { { index: $1 } }
fn yy_action_70(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_DataConId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 121|    "value" value_id "=" buslane_name value_kind ":" type ";" {
// 122|    ValueInfoDecl($2, {
// 123|      name: parsed_name(ValueName, $4.occurrence, $4.unique),
// 124|      kind: $5,
// 125|      type_: $7,
// 126|    })
// 127|  }
fn yy_action_71(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_ValueId(_dollar2)
  guard _args[3].0 is YYObj_ParsedBuslaneName(_dollar4)
  guard _args[4].0 is YYObj_ValueKind(_dollar5)
  guard _args[6].0 is YYObj_Type(_dollar7)
  YYObj_MetadataDeclaration({(); 
    ValueInfoDecl(_dollar2, {
      name: parsed_name(ValueName, _dollar4.occurrence, _dollar4.unique),
      kind: _dollar5,
      type_: _dollar7,
    })
  })
}

// file:///./parser.mbty
// 372|    "function" { Function }
fn yy_action_72(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Function })
}

// file:///./parser.mbty
// 373|    "value" { Value }
fn yy_action_73(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Value })
}

// file:///./parser.mbty
// 374|    "external" { External }
fn yy_action_74(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  External })
}

// file:///./parser.mbty
// 375|    "parameter" { Parameter }
fn yy_action_75(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Parameter })
}

// file:///./parser.mbty
// 376|    "local" { Local }
fn yy_action_76(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  Local })
}

// file:///./parser.mbty
// 377|    "match_binder" { MatchBinder }
fn yy_action_77(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_ValueKind({();  MatchBinder })
}

// file:///./parser.mbty
// 484|    VALUE_ID { { index: $1 } }
fn yy_action_78(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_ValueId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 136|    "operation" operation_id "=" buslane_name type_parameter_ids "(" type_list ")" "->" type ":" effect_id ";" {
// 137|    OperationInfoDecl($2, {
// 138|      name: parsed_name(OperationName, $4.occurrence, $4.unique),
// 139|      owner: $12,
// 140|      hidden_type_parameters: $5,
// 141|      payload_types: $7,
// 142|      result_type: $10,
// 143|    })
// 144|  }
fn yy_action_79(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_OperationId(_dollar2)
  guard _args[3].0 is YYObj_ParsedBuslaneName(_dollar4)
  guard _args[11].0 is YYObj_EffectId(_dollar12)
  guard _args[4].0 is YYObj_Array_TypeParameterId_(_dollar5)
  guard _args[6].0 is YYObj_Array_Type_(_dollar7)
  guard _args[9].0 is YYObj_Type(_dollar10)
  YYObj_MetadataDeclaration({(); 
    OperationInfoDecl(_dollar2, {
      name: parsed_name(OperationName, _dollar4.occurrence, _dollar4.unique),
      owner: _dollar12,
      hidden_type_parameters: _dollar5,
      payload_types: _dollar7,
      result_type: _dollar10,
    })
  })
}

// file:///./parser.mbty
// 407|    non_empty_type_list { $1 }
fn yy_action_80(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 406|    { [] }
fn yy_action_81(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 432|    "[" non_empty_type_parameter_ids "]" { $2 }
fn yy_action_82(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeParameterId_(_dollar2)
  YYObj_Array_TypeParameterId_({();  _dollar2 })
}

// file:///./parser.mbty
// 431|    { [] }
fn yy_action_83(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameterId_({();  [] })
}

// file:///./parser.mbty
// 153|    NAME { { occurrence: $1.0, unique: $1.1 } }
fn yy_action_84(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj__String__Int_(_dollar1)
  YYObj_ParsedBuslaneName({();  { occurrence: _dollar1.0, unique: _dollar1.1 } })
}

// file:///./parser.mbty
// 496|    OPERATION_ID { { index: $1 } }
fn yy_action_85(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_OperationId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 149|    "external" { true }
fn yy_action_86(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 148|    { false }
fn yy_action_87(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 93|    { [] }
fn yy_action_88(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_MetadataDeclaration_({();  [] })
}

// file:///./parser.mbty
// 83|    type EOF { $1 }
fn yy_action_89(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 334|    "(" type "," non_empty_type_list ")" { [$2, ..$4] }
fn yy_action_90(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  guard _args[3].0 is YYObj_Array_Type_(_dollar4)
  YYObj_Array_Type_({();  [_dollar2, .._dollar4] })
}

// file:///./parser.mbty
// 314|    parameter_types "->" applied_type "!" effect { Function($1, $3, $5) }
fn yy_action_91(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  guard _args[4].0 is YYObj_Effect(_dollar5)
  YYObj_Type({();  Function(_dollar1, _dollar3, _dollar5) })
}

// file:///./parser.mbty
// 313|    parameter_types "->" applied_type { Function($1, $3, Empty) }
fn yy_action_92(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Type({();  Function(_dollar1, _dollar3, Empty) })
}

// file:///./parser.mbty
// 339|    applied_type "[" generic_arguments "]" { Apply($1, $3) }
fn yy_action_93(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  YYObj_Type({();  Apply(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 350|    "{" "}" { Empty }
fn yy_action_94(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Effect({();  Empty })
}

// file:///./parser.mbty
// 355|    "{" non_empty_effect_list "}" { Union($2) }
fn yy_action_95(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Effect_(_dollar2)
  YYObj_Effect({();  Union(_dollar2) })
}

// file:///./parser.mbty
// 417|    non_empty_effect_list "," effect { comma_push($1, $3) }
fn yy_action_96(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Effect_(_dollar1)
  guard _args[2].0 is YYObj_Effect(_dollar3)
  YYObj_Array_Effect_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 416|    effect { [ $1 ] }
fn yy_action_97(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Effect(_dollar1)
  YYObj_Array_Effect_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 351|    "Io" { Io }
fn yy_action_98(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Effect({();  Io })
}

// file:///./parser.mbty
// 352|    type_parameter_id { Parameter($1) }
fn yy_action_99(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Effect({();  Parameter(_dollar1) })
}

// file:///./parser.mbty
// 306|    arrow_type { $1 }
fn yy_action_100(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 307|    "forall" "[" type_parameter_id_list "]" "." type { Forall($3, $6) }
fn yy_action_101(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  YYObj_Type({();  Forall(_dollar3, _dollar6) })
}

// file:///./parser.mbty
// 308|    "type" "[" type_parameter_id_list "]" "=>" type { TypeLambda($3, $6) }
fn yy_action_102(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_TypeParameterId_(_dollar3)
  guard _args[5].0 is YYObj_Type(_dollar6)
  YYObj_Type({();  TypeLambda(_dollar3, _dollar6) })
}

// file:///./parser.mbty
// 442|    non_empty_type_parameter_ids "," type_parameter_id { comma_push($1, $3) }
fn yy_action_103(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameterId_(_dollar1)
  guard _args[2].0 is YYObj_TypeParameterId(_dollar3)
  YYObj_Array_TypeParameterId_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 437|    non_empty_type_parameter_ids { $1 }
fn yy_action_104(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeParameterId_(_dollar1)
  YYObj_Array_TypeParameterId_({();  _dollar1 })
}

// file:///./parser.mbty
// 441|    type_parameter_id { [ $1 ] }
fn yy_action_105(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Array_TypeParameterId_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 436|    { [] }
fn yy_action_106(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_TypeParameterId_({();  [] })
}

// file:///./parser.mbty
// 354|    effect_id "[" non_empty_generic_arguments "]" { Singleton($1, $3) }
fn yy_action_107(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectId(_dollar1)
  guard _args[2].0 is YYObj_Array_GenericArgument_(_dollar3)
  YYObj_Effect({();  Singleton(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 381|    type { TypeArgument($1) }
fn yy_action_108(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_GenericArgument({();  TypeArgument(_dollar1) })
}

// file:///./parser.mbty
// 353|    effect_id { Singleton($1, []) }
fn yy_action_109(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_EffectId(_dollar1)
  YYObj_Effect({();  Singleton(_dollar1, []) })
}

// file:///./parser.mbty
// 382|    "!" effect { EffectArgument($2) }
fn yy_action_110(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Effect(_dollar2)
  YYObj_GenericArgument({();  EffectArgument(_dollar2) })
}

// file:///./parser.mbty
// 492|    EFFECT_ID { { index: $1 } }
fn yy_action_111(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_EffectId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 392|    non_empty_generic_arguments "," generic_argument { comma_push($1, $3) }
fn yy_action_112(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  guard _args[2].0 is YYObj_GenericArgument(_dollar3)
  YYObj_Array_GenericArgument_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 387|    non_empty_generic_arguments { $1 }
fn yy_action_113(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_GenericArgument_(_dollar1)
  YYObj_Array_GenericArgument_({();  _dollar1 })
}

// file:///./parser.mbty
// 391|    generic_argument { [ $1 ] }
fn yy_action_114(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_GenericArgument(_dollar1)
  YYObj_Array_GenericArgument_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 386|    { [] }
fn yy_action_115(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_GenericArgument_({();  [] })
}

// file:///./parser.mbty
// 312|    applied_type { $1 }
fn yy_action_116(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 329|    "(" type ")" { $2 }
fn yy_action_117(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[1].0 is YYObj_Type(_dollar2)
  YYObj_Type({();  _dollar2 })
}

// file:///./parser.mbty
// 324|    paren_type { [ $1 ] }
fn yy_action_118(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 346|    paren_type { $1 }
fn yy_action_119(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 325|    paren_types { $1 }
fn yy_action_120(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  YYObj_Array_Type_({();  _dollar1 })
}

// file:///./parser.mbty
// 412|    non_empty_type_list "," type { comma_push($1, $3) }
fn yy_action_121(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Type_(_dollar1)
  guard _args[2].0 is YYObj_Type(_dollar3)
  YYObj_Array_Type_({();  comma_push(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 411|    type { [ $1 ] }
fn yy_action_122(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Array_Type_({();  [ _dollar1 ] })
}

// file:///./parser.mbty
// 333|    "(" ")" { [] }
fn yy_action_123(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_Array_Type_({();  [] })
}

// file:///./parser.mbty
// 338|    atom_type { $1 }
fn yy_action_124(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Type(_dollar1)
  YYObj_Type({();  _dollar1 })
}

// file:///./parser.mbty
// 343|    primitive_type { Primitive($1) }
fn yy_action_125(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_PrimitiveType(_dollar1)
  YYObj_Type({();  Primitive(_dollar1) })
}

// file:///./parser.mbty
// 344|    type_parameter_id { Parameter($1) }
fn yy_action_126(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeParameterId(_dollar1)
  YYObj_Type({();  Parameter(_dollar1) })
}

// file:///./parser.mbty
// 345|    type_id { Constructor($1) }
fn yy_action_127(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeId(_dollar1)
  YYObj_Type({();  Constructor(_dollar1) })
}

// file:///./parser.mbty
// 359|    "Unit" { Unit }
fn yy_action_128(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Unit })
}

// file:///./parser.mbty
// 360|    "Bool" { Bool }
fn yy_action_129(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Bool })
}

// file:///./parser.mbty
// 361|    "I64" { I64 }
fn yy_action_130(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  I64 })
}

// file:///./parser.mbty
// 362|    "I32" { I32 }
fn yy_action_131(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  I32 })
}

// file:///./parser.mbty
// 363|    "Char" { Char }
fn yy_action_132(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Char })
}

// file:///./parser.mbty
// 364|    "F32" { F32 }
fn yy_action_133(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  F32 })
}

// file:///./parser.mbty
// 365|    "F64" { F64 }
fn yy_action_134(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  F64 })
}

// file:///./parser.mbty
// 366|    "String" { String }
fn yy_action_135(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  String })
}

// file:///./parser.mbty
// 367|    "Byte" { Byte }
fn yy_action_136(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Byte })
}

// file:///./parser.mbty
// 368|    "Bytes" { Bytes }
fn yy_action_137(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  YYObj_PrimitiveType({();  Bytes })
}

// file:///./parser.mbty
// 476|    TYPE_ID { { index: $1 } }
fn yy_action_138(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeId({();  { index: _dollar1 } })
}

// file:///./parser.mbty
// 480|    TPARAM_ID { { index: $1 } }
fn yy_action_139(_last_pos : SourceSpan, _args : ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_TypeParameterId({();  { index: _dollar1 } })
}

fn yy_input(token : Token, _start_pos : SourceSpan, _end_pos : SourceSpan) -> (YYSymbol, YYObj) {
  match token {
    LITERAL(data) => (T_LITERAL, YYObj_Literal(data))
    NAME(data) => (T_NAME, YYObj__String__Int_(data))
    TYPE_ID(data) => (T_TYPE_ID, YYObj_Int(data))
    TPARAM_ID(data) => (T_TPARAM_ID, YYObj_Int(data))
    VALUE_ID(data) => (T_VALUE_ID, YYObj_Int(data))
    DATACON_ID(data) => (T_DATACON_ID, YYObj_Int(data))
    EFFECT_ID(data) => (T_EFFECT_ID, YYObj_Int(data))
    OPERATION_ID(data) => (T_OPERATION_ID, YYObj_Int(data))
    NEXT_UNIQUE(data) => (T_NEXT_UNIQUE, YYObj_Int(data))
    EOF => (T_EOF, YYObj_Void)
    BUSLANE => (T_BUSLANE, YYObj_Void)
    METADATA => (T_METADATA, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    TYPE_PARAMETER => (T_TYPE_PARAMETER, YYObj_Void)
    VALUE => (T_VALUE, YYObj_Void)
    DATACON => (T_DATACON, YYObj_Void)
    EFFECT_DECL => (T_EFFECT_DECL, YYObj_Void)
    OPERATION => (T_OPERATION, YYObj_Void)
    FUNCTION_KIND => (T_FUNCTION_KIND, YYObj_Void)
    PARAMETER_KIND => (T_PARAMETER_KIND, YYObj_Void)
    LOCAL_KIND => (T_LOCAL_KIND, YYObj_Void)
    MATCH_BINDER_KIND => (T_MATCH_BINDER_KIND, YYObj_Void)
    TYPE_KIND => (T_TYPE_KIND, YYObj_Void)
    EFFECT_KIND => (T_EFFECT_KIND, YYObj_Void)
    UNIT_TYPE => (T_UNIT_TYPE, YYObj_Void)
    BOOL_TYPE => (T_BOOL_TYPE, YYObj_Void)
    I64_TYPE => (T_I64_TYPE, YYObj_Void)
    I32_TYPE => (T_I32_TYPE, YYObj_Void)
    CHAR_TYPE => (T_CHAR_TYPE, YYObj_Void)
    F32_TYPE => (T_F32_TYPE, YYObj_Void)
    F64_TYPE => (T_F64_TYPE, YYObj_Void)
    STRING_TYPE => (T_STRING_TYPE, YYObj_Void)
    BYTE_TYPE => (T_BYTE_TYPE, YYObj_Void)
    BYTES_TYPE => (T_BYTES_TYPE, YYObj_Void)
    IO => (T_IO, YYObj_Void)
    FORALL => (T_FORALL, YYObj_Void)
    IN => (T_IN, YYObj_Void)
    AS => (T_AS, YYObj_Void)
    FINAL => (T_FINAL, YYObj_Void)
    UNDERSCORE => (T_UNDERSCORE, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    LETREC => (T_LETREC, YYObj_Void)
    EXTERNAL => (T_EXTERNAL, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    PERFORM => (T_PERFORM, YYObj_Void)
    HANDLE => (T_HANDLE, YYObj_Void)
    RESUME => (T_RESUME, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
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
    ARROW => (T_ARROW, YYObj_Void)
    BANG => (T_BANG, YYObj_Void)
    DOT => (T_DOT, YYObj_Void)
  }
}

fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_type => Shift(yy_state_1)
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_80)
    _ => Error
  }
}

fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_parameter_id, yy_action_139)
}

fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_id, yy_action_138)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_137)
}

fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_136)
}

fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_135)
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_134)
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_133)
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_132)
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_131)
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_130)
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_129)
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primitive_type, yy_action_128)
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_type, yy_action_127)
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_type, yy_action_126)
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_type, yy_action_125)
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_applied_type, yy_action_124)
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    T_RPAREN => Shift(yy_state_19)
    NT_type => Shift(yy_state_20)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_paren_types, yy_action_123)
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_21)
    T_RPAREN => Shift(yy_state_33)
    _ => Error
  }
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_type => Shift(yy_state_22)
    NT_non_empty_type_list => Shift(yy_state_23)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_list, yy_action_122)
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_24)
    T_RPAREN => Shift(yy_state_79)
    _ => Error
  }
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_type => Shift(yy_state_25)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_list, yy_action_121)
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parameter_types, yy_action_120)
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Reduce(1, NT_parameter_types, yy_action_118)
    T_EOF | T_LBRACE | T_LBRACKET | T_RBRACKET | T_RPAREN | T_COMMA | T_COLON | T_SEMI => Reduce(1, NT_atom_type, yy_action_119)
    _ => Error
  }
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_29)
    _ => Error
  }
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    NT_paren_type => Shift(yy_state_30)
    T_LPAREN => Shift(yy_state_31)
    NT_applied_type => Shift(yy_state_76)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_type, yy_action_119)
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_type => Shift(yy_state_32)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_33)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_paren_type, yy_action_117)
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_35)
    T_EOF | T_LBRACE | T_RBRACKET | T_RPAREN | T_COMMA | T_COLON | T_SEMI => Reduce(1, NT_arrow_type, yy_action_116)
    _ => Error
  }
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_36)
    NT_non_empty_generic_arguments => Shift(yy_state_37)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_generic_arguments => Shift(yy_state_74)
    T_RBRACKET => Reduce(0, NT_generic_arguments, yy_action_115)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_generic_arguments, yy_action_114)
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_38)
    T_RBRACKET | T_SEMI => Reduce(1, NT_generic_arguments, yy_action_113)
    _ => Error
  }
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_39)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_generic_arguments, yy_action_112)
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect => Shift(yy_state_42)
    NT_effect_id => Shift(yy_state_43)
    NT_type_parameter_id => Shift(yy_state_65)
    T_IO => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_67)
    _ => Error
  }
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect_id, yy_action_111)
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_generic_argument, yy_action_110)
}

fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_44)
    T_EOF | T_LBRACE | T_RBRACE | T_RBRACKET | T_RPAREN | T_COMMA | T_COLON | T_SEMI => Reduce(1, NT_effect, yy_action_109)
    _ => Error
  }
}

fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_36)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    NT_non_empty_generic_arguments => Shift(yy_state_46)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_generic_argument, yy_action_108)
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_38)
    T_RBRACKET => Shift(yy_state_47)
    _ => Error
  }
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_effect, yy_action_107)
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_49)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_50)
    NT_non_empty_type_parameter_ids => Shift(yy_state_51)
    NT_type_parameter_id_list => Shift(yy_state_54)
    T_RBRACKET => Reduce(0, NT_type_parameter_id_list, yy_action_106)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_type_parameter_ids, yy_action_105)
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_52)
    T_RBRACKET => Reduce(1, NT_type_parameter_id_list, yy_action_104)
    _ => Error
  }
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_53)
    _ => Error
  }
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_type_parameter_ids, yy_action_103)
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_55)
    _ => Error
  }
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_56)
    _ => Error
  }
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    NT_type => Shift(yy_state_57)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_102)
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_59)
    _ => Error
  }
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_50)
    NT_non_empty_type_parameter_ids => Shift(yy_state_51)
    NT_type_parameter_id_list => Shift(yy_state_60)
    T_RBRACKET => Reduce(0, NT_type_parameter_id_list, yy_action_106)
    _ => Error
  }
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_61)
    _ => Error
  }
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_62)
    _ => Error
  }
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_type => Shift(yy_state_63)
    NT_arrow_type => Shift(yy_state_64)
    _ => Error
  }
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_type, yy_action_101)
}

fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type, yy_action_100)
}

fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect, yy_action_99)
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_effect, yy_action_98)
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_43)
    NT_type_parameter_id => Shift(yy_state_65)
    T_IO => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_67)
    NT_effect => Shift(yy_state_68)
    NT_non_empty_effect_list => Shift(yy_state_69)
    T_RBRACE => Shift(yy_state_73)
    _ => Error
  }
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_effect_list, yy_action_97)
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_70)
    T_RBRACE => Shift(yy_state_72)
    _ => Error
  }
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_43)
    NT_type_parameter_id => Shift(yy_state_65)
    T_IO => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_67)
    NT_effect => Shift(yy_state_71)
    _ => Error
  }
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_effect_list, yy_action_96)
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_effect, yy_action_95)
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_effect, yy_action_94)
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_75)
    _ => Error
  }
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_applied_type, yy_action_93)
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_35)
    T_BANG => Shift(yy_state_77)
    T_EOF | T_LBRACE | T_RBRACKET | T_RPAREN | T_COMMA | T_COLON | T_SEMI => Reduce(3, NT_arrow_type, yy_action_92)
    _ => Error
  }
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_43)
    NT_type_parameter_id => Shift(yy_state_65)
    T_IO => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_67)
    NT_effect => Shift(yy_state_78)
    _ => Error
  }
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_arrow_type, yy_action_91)
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_paren_types, yy_action_90)
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_81)
    _ => Error
  }
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_buslane_type, yy_action_89)
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_buslane_program => Shift(yy_state_83)
    T_BUSLANE => Shift(yy_state_84)
    _ => Error
  }
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_85)
    _ => Error
  }
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_METADATA => Shift(yy_state_86)
    NT_metadata => Shift(yy_state_187)
    _ => Error
  }
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_87)
    _ => Error
  }
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NEXT_UNIQUE => Shift(yy_state_88)
    _ => Error
  }
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_89)
    _ => Error
  }
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_metadata_declarations => Shift(yy_state_90)
    T_TYPE | T_TYPE_PARAMETER | T_VALUE | T_DATACON | T_EFFECT_DECL | T_OPERATION | T_EXTERNAL | T_RBRACE => Reduce(0, NT_metadata_declarations, yy_action_88)
    _ => Error
  }
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERNAL => Shift(yy_state_91)
    T_OPERATION => Shift(yy_state_92)
    T_VALUE => Shift(yy_state_111)
    T_DATACON => Shift(yy_state_126)
    NT_external_marker => Shift(yy_state_138)
    NT_metadata_declaration => Shift(yy_state_185)
    T_RBRACE => Shift(yy_state_186)
    T_TYPE | T_TYPE_PARAMETER | T_EFFECT_DECL => Reduce(0, NT_external_marker, yy_action_87)
    _ => Error
  }
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_external_marker, yy_action_86)
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_93)
    NT_operation_id => Shift(yy_state_94)
    _ => Error
  }
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_operation_id, yy_action_85)
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_95)
    _ => Error
  }
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_97)
    _ => Error
  }
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_buslane_name, yy_action_84)
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_101)
    T_LPAREN => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_50)
    NT_non_empty_type_parameter_ids => Shift(yy_state_99)
    _ => Error
  }
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_52)
    T_RBRACKET => Shift(yy_state_100)
    _ => Error
  }
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_parameter_ids, yy_action_82)
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_102)
    _ => Error
  }
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_type => Shift(yy_state_22)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_non_empty_type_list => Shift(yy_state_103)
    NT_type_list => Shift(yy_state_104)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_81)
    _ => Error
  }
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_24)
    T_RPAREN => Reduce(1, NT_type_list, yy_action_80)
    _ => Error
  }
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_105)
    _ => Error
  }
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_106)
    _ => Error
  }
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_107)
    _ => Error
  }
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_108)
    _ => Error
  }
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_109)
    _ => Error
  }
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_110)
    _ => Error
  }
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(13, NT_metadata_declaration, yy_action_79)
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_113)
    _ => Error
  }
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_id, yy_action_78)
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_114)
    _ => Error
  }
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_115)
    _ => Error
  }
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MATCH_BINDER_KIND => Shift(yy_state_116)
    T_LOCAL_KIND => Shift(yy_state_117)
    T_PARAMETER_KIND => Shift(yy_state_118)
    T_EXTERNAL => Shift(yy_state_119)
    T_VALUE => Shift(yy_state_120)
    T_FUNCTION_KIND => Shift(yy_state_121)
    NT_value_kind => Shift(yy_state_122)
    _ => Error
  }
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_77)
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_76)
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_75)
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_74)
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_73)
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_kind, yy_action_72)
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_123)
    _ => Error
  }
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_124)
    _ => Error
  }
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_125)
    _ => Error
  }
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_71)
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_127)
    NT_data_con_id => Shift(yy_state_128)
    _ => Error
  }
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_con_id, yy_action_70)
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_129)
    _ => Error
  }
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_130)
    _ => Error
  }
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_131)
    T_LPAREN => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_132)
    _ => Error
  }
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_type => Shift(yy_state_22)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_non_empty_type_list => Shift(yy_state_103)
    NT_type_list => Shift(yy_state_133)
    T_RPAREN => Reduce(0, NT_type_list, yy_action_81)
    _ => Error
  }
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_134)
    _ => Error
  }
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_135)
    _ => Error
  }
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_136)
    _ => Error
  }
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_137)
    _ => Error
  }
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(11, NT_metadata_declaration, yy_action_69)
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_DECL => Shift(yy_state_139)
    T_TYPE_PARAMETER => Shift(yy_state_153)
    T_TYPE => Shift(yy_state_171)
    _ => Error
  }
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_140)
    _ => Error
  }
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_141)
    _ => Error
  }
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_142)
    _ => Error
  }
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_143)
    T_LBRACE => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_144)
    NT_operation_ids => Shift(yy_state_151)
    _ => Error
  }
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_93)
    NT_operation_id => Shift(yy_state_145)
    NT_non_empty_operation_ids => Shift(yy_state_146)
    T_RBRACE => Shift(yy_state_150)
    _ => Error
  }
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_operation_ids, yy_action_68)
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_147)
    T_RBRACE => Shift(yy_state_149)
    _ => Error
  }
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_93)
    NT_operation_id => Shift(yy_state_148)
    _ => Error
  }
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_operation_ids, yy_action_67)
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_operation_ids, yy_action_66)
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_operation_ids, yy_action_65)
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_152)
    _ => Error
  }
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_64)
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_154)
    _ => Error
  }
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_155)
    _ => Error
  }
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_156)
    _ => Error
  }
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_157)
    _ => Error
  }
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_158)
    T_EFFECT_KIND => Shift(yy_state_163)
    T_TYPE_KIND => Shift(yy_state_164)
    NT_kind => Shift(yy_state_169)
    _ => Error
  }
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_158)
    NT_kind => Shift(yy_state_159)
    NT_non_empty_kind_list => Shift(yy_state_160)
    T_EFFECT_KIND => Shift(yy_state_163)
    T_TYPE_KIND => Shift(yy_state_164)
    NT_kind_list => Shift(yy_state_165)
    T_RBRACKET => Reduce(0, NT_kind_list, yy_action_63)
    _ => Error
  }
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_kind_list, yy_action_62)
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_161)
    T_RBRACKET => Reduce(1, NT_kind_list, yy_action_61)
    _ => Error
  }
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_158)
    NT_kind => Shift(yy_state_162)
    T_EFFECT_KIND => Shift(yy_state_163)
    T_TYPE_KIND => Shift(yy_state_164)
    _ => Error
  }
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_kind_list, yy_action_60)
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_59)
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_kind, yy_action_58)
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_166)
    _ => Error
  }
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_167)
    _ => Error
  }
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_158)
    T_EFFECT_KIND => Shift(yy_state_163)
    T_TYPE_KIND => Shift(yy_state_164)
    NT_kind => Shift(yy_state_168)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_kind, yy_action_57)
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_170)
    _ => Error
  }
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_56)
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ID => Shift(yy_state_3)
    NT_type_id => Shift(yy_state_172)
    _ => Error
  }
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_173)
    _ => Error
  }
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAME => Shift(yy_state_96)
    NT_buslane_name => Shift(yy_state_174)
    _ => Error
  }
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_175)
    T_LBRACE => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_176)
    NT_data_con_ids => Shift(yy_state_183)
    _ => Error
  }
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_127)
    NT_data_con_id => Shift(yy_state_177)
    NT_non_empty_data_con_ids => Shift(yy_state_178)
    T_RBRACE => Shift(yy_state_182)
    _ => Error
  }
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_data_con_ids, yy_action_55)
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_179)
    T_RBRACE => Shift(yy_state_181)
    _ => Error
  }
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_127)
    NT_data_con_id => Shift(yy_state_180)
    _ => Error
  }
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_data_con_ids, yy_action_54)
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_data_con_ids, yy_action_53)
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_data_con_ids, yy_action_52)
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_184)
    _ => Error
  }
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_metadata_declaration, yy_action_51)
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_metadata_declarations, yy_action_50)
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_metadata, yy_action_49)
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_top_terms => Shift(yy_state_188)
    T_LET | T_LETREC | T_EXTERNAL | T_RBRACE => Reduce(0, NT_top_terms, yy_action_48)
    _ => Error
  }
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EXTERNAL => Shift(yy_state_189)
    T_LETREC => Shift(yy_state_191)
    T_LET => Shift(yy_state_319)
    NT_top_term => Shift(yy_state_323)
    T_RBRACE => Shift(yy_state_324)
    _ => Error
  }
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_190)
    _ => Error
  }
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_term, yy_action_47)
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_192)
    _ => Error
  }
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_193)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_46)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_194)
    NT_recursive_binding => Shift(yy_state_291)
    T_RBRACE => Shift(yy_state_318)
    _ => Error
  }
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_195)
    _ => Error
  }
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_317)
    _ => Error
  }
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_45)
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    NT_expr => Shift(yy_state_198)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_199)
    _ => Error
  }
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_200)
    _ => Error
  }
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_201)
    _ => Error
  }
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_202)
    _ => Error
  }
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_203)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_handler_tables => Shift(yy_state_204)
    T_TPARAM_ID | T_EFFECT_ID | T_IO | T_FINAL | T_LBRACE => Reduce(0, NT_handler_tables, yy_action_44)
    _ => Error
  }
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_EFFECT_ID => Shift(yy_state_41)
    NT_effect_id => Shift(yy_state_43)
    NT_type_parameter_id => Shift(yy_state_65)
    T_IO => Shift(yy_state_66)
    T_LBRACE => Shift(yy_state_67)
    NT_effect => Shift(yy_state_205)
    NT_handler_table => Shift(yy_state_312)
    T_FINAL => Shift(yy_state_313)
    _ => Error
  }
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_206)
    _ => Error
  }
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_operation_alternatives => Shift(yy_state_207)
    T_OPERATION_ID | T_RBRACE => Reduce(0, NT_operation_alternatives, yy_action_43)
    _ => Error
  }
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_93)
    NT_operation_id => Shift(yy_state_208)
    NT_operation_alternative => Shift(yy_state_310)
    T_RBRACE => Shift(yy_state_311)
    _ => Error
  }
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_209)
    T_LPAREN => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_210)
    _ => Error
  }
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_211)
    NT_non_empty_value_id_list => Shift(yy_state_212)
    NT_value_id_list => Shift(yy_state_215)
    T_RPAREN => Reduce(0, NT_value_id_list, yy_action_42)
    _ => Error
  }
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_value_id_list, yy_action_41)
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_213)
    T_RPAREN => Reduce(1, NT_value_id_list, yy_action_40)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_214)
    _ => Error
  }
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_value_id_list, yy_action_39)
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_216)
    _ => Error
  }
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RESUME => Shift(yy_state_217)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_218)
    _ => Error
  }
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_219)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    NT_expr => Shift(yy_state_220)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_operation_alternative, yy_action_38)
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    NT_expr => Shift(yy_state_222)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_223)
    _ => Error
  }
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_224)
    _ => Error
  }
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_225)
    _ => Error
  }
}

fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_226)
    _ => Error
  }
}

fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_227)
    _ => Error
  }
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_alternatives => Shift(yy_state_228)
    T_LITERAL | T_DATACON_ID | T_UNDERSCORE | T_RBRACE | T_LPAREN => Reduce(0, NT_alternatives, yy_action_37)
    _ => Error
  }
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_LPAREN => Shift(yy_state_229)
    NT_data_con_id => Shift(yy_state_231)
    NT_literal => Shift(yy_state_302)
    T_UNDERSCORE => Shift(yy_state_305)
    NT_alternative => Shift(yy_state_308)
    T_RBRACE => Shift(yy_state_309)
    _ => Error
  }
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_230)
    _ => Error
  }
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_literal, yy_action_36)
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_98)
    NT_type_parameter_ids => Shift(yy_state_232)
    T_LPAREN => Reduce(0, NT_type_parameter_ids, yy_action_83)
    _ => Error
  }
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_233)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_211)
    NT_non_empty_value_id_list => Shift(yy_state_212)
    NT_value_id_list => Shift(yy_state_234)
    T_RPAREN => Reduce(0, NT_value_id_list, yy_action_42)
    _ => Error
  }
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_235)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_236)
    _ => Error
  }
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    NT_expr => Shift(yy_state_237)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_alternative, yy_action_35)
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_239)
    T_LPAREN => Shift(yy_state_294)
    _ => Error
  }
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    NT_type_parameter_id => Shift(yy_state_50)
    NT_non_empty_type_parameter_ids => Shift(yy_state_51)
    NT_type_parameter_id_list => Shift(yy_state_240)
    T_RBRACKET => Reduce(0, NT_type_parameter_id_list, yy_action_106)
    _ => Error
  }
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_241)
    _ => Error
  }
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_242)
    _ => Error
  }
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    NT_expr => Shift(yy_state_243)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_244)
    _ => Error
  }
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_atom_expr, yy_action_34)
}

fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPERATION_ID => Shift(yy_state_93)
    NT_operation_id => Shift(yy_state_246)
    _ => Error
  }
}

fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_247)
    NT_argument_group => Shift(yy_state_253)
    T_LPAREN => Reduce(0, NT_argument_group, yy_action_33)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_36)
    NT_non_empty_generic_arguments => Shift(yy_state_37)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_generic_arguments => Shift(yy_state_248)
    T_RBRACKET | T_SEMI => Reduce(0, NT_generic_arguments, yy_action_115)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_249)
    T_RBRACKET => Shift(yy_state_252)
    _ => Error
  }
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_36)
    NT_non_empty_generic_arguments => Shift(yy_state_37)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_generic_arguments => Shift(yy_state_250)
    T_RBRACKET => Reduce(0, NT_generic_arguments, yy_action_115)
    _ => Error
  }
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_251)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_argument_group, yy_action_32)
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_argument_group, yy_action_31)
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_254)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    NT_expr => Shift(yy_state_255)
    NT_non_empty_expr_list => Shift(yy_state_256)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr_list => Shift(yy_state_292)
    T_RPAREN => Reduce(0, NT_expr_list, yy_action_30)
    _ => Error
  }
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_non_empty_expr_list, yy_action_29)
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_257)
    T_RPAREN => Reduce(1, NT_expr_list, yy_action_28)
    _ => Error
  }
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    NT_expr => Shift(yy_state_258)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_expr_list, yy_action_27)
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_260)
    _ => Error
  }
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_atom_expr, yy_action_26)
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_247)
    NT_argument_group => Shift(yy_state_262)
    T_LPAREN => Reduce(0, NT_argument_group, yy_action_33)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_263)
    _ => Error
  }
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    NT_expr => Shift(yy_state_255)
    NT_non_empty_expr_list => Shift(yy_state_256)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    NT_expr_list => Shift(yy_state_264)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    T_RPAREN => Reduce(0, NT_expr_list, yy_action_30)
    _ => Error
  }
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_265)
    _ => Error
  }
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_atom_expr, yy_action_25)
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_RPAREN => Shift(yy_state_230)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_expr => Shift(yy_state_267)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
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
  ReduceNoLookahead(3, NT_atom_expr, yy_action_24)
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_expr, yy_action_23)
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_atom_expr, yy_action_22)
}

fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_postfix_expr, yy_action_21)
}

fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_273)
    _ => Error
  }
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_recursive_bindings => Shift(yy_state_274)
    T_VALUE_ID | T_RBRACE => Reduce(0, NT_recursive_bindings, yy_action_46)
    _ => Error
  }
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_194)
    T_RBRACE => Shift(yy_state_275)
    NT_recursive_binding => Shift(yy_state_291)
    _ => Error
  }
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IN => Shift(yy_state_276)
    _ => Error
  }
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    NT_expr => Shift(yy_state_277)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_20)
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_279)
    _ => Error
  }
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_280)
    _ => Error
  }
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_expr => Shift(yy_state_281)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IN => Shift(yy_state_282)
    _ => Error
  }
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_expr => Shift(yy_state_283)
    NT_postfix_expr => Shift(yy_state_284)
    _ => Error
  }
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_expr, yy_action_19)
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_285)
    T_LPAREN => Shift(yy_state_288)
    T_LITERAL | T_VALUE_ID | T_DATACON_ID | T_OPERATION_ID | T_IN | T_AS | T_UNDERSCORE | T_LET | T_LETREC | T_EXTERNAL | T_RBRACE | T_RPAREN | T_COMMA => Reduce(1, NT_expr, yy_action_18)
    _ => Error
  }
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    NT_generic_argument => Shift(yy_state_36)
    NT_non_empty_generic_arguments => Shift(yy_state_37)
    T_BANG => Shift(yy_state_40)
    NT_type => Shift(yy_state_45)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_generic_arguments => Shift(yy_state_286)
    T_RBRACKET => Reduce(0, NT_generic_arguments, yy_action_115)
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
  ReduceNoLookahead(4, NT_postfix_expr, yy_action_17)
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    NT_expr => Shift(yy_state_255)
    NT_non_empty_expr_list => Shift(yy_state_256)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr_list => Shift(yy_state_289)
    T_RPAREN => Reduce(0, NT_expr_list, yy_action_30)
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
  ReduceNoLookahead(4, NT_postfix_expr, yy_action_16)
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_recursive_bindings, yy_action_15)
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_293)
    _ => Error
  }
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_atom_expr, yy_action_14)
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_211)
    NT_non_empty_value_id_list => Shift(yy_state_212)
    NT_value_id_list => Shift(yy_state_295)
    T_RPAREN => Reduce(0, NT_value_id_list, yy_action_42)
    _ => Error
  }
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_296)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_297)
    _ => Error
  }
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TPARAM_ID => Shift(yy_state_2)
    T_TYPE_ID => Shift(yy_state_3)
    T_BYTES_TYPE => Shift(yy_state_4)
    T_BYTE_TYPE => Shift(yy_state_5)
    T_STRING_TYPE => Shift(yy_state_6)
    T_F64_TYPE => Shift(yy_state_7)
    T_F32_TYPE => Shift(yy_state_8)
    T_CHAR_TYPE => Shift(yy_state_9)
    T_I32_TYPE => Shift(yy_state_10)
    T_I64_TYPE => Shift(yy_state_11)
    T_BOOL_TYPE => Shift(yy_state_12)
    T_UNIT_TYPE => Shift(yy_state_13)
    NT_type_id => Shift(yy_state_14)
    NT_type_parameter_id => Shift(yy_state_15)
    NT_primitive_type => Shift(yy_state_16)
    NT_atom_type => Shift(yy_state_17)
    T_LPAREN => Shift(yy_state_18)
    NT_paren_types => Shift(yy_state_26)
    NT_paren_type => Shift(yy_state_27)
    NT_parameter_types => Shift(yy_state_28)
    NT_applied_type => Shift(yy_state_34)
    T_TYPE => Shift(yy_state_48)
    T_FORALL => Shift(yy_state_58)
    NT_arrow_type => Shift(yy_state_64)
    NT_type => Shift(yy_state_298)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_299)
    _ => Error
  }
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_300)
    _ => Error
  }
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_301)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_atom_expr, yy_action_13)
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_303)
    _ => Error
  }
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_304)
    _ => Error
  }
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_alternative, yy_action_12)
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_306)
    _ => Error
  }
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_307)
    _ => Error
  }
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_alternative, yy_action_11)
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alternatives, yy_action_10)
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_atom_expr, yy_action_9)
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_operation_alternatives, yy_action_8)
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_handler_table, yy_action_7)
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_handler_tables, yy_action_6)
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FAT_ARROW => Shift(yy_state_314)
    _ => Error
  }
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_315)
    _ => Error
  }
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_316)
    _ => Error
  }
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(12, NT_atom_expr, yy_action_5)
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_recursive_binding, yy_action_4)
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_top_term, yy_action_3)
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    NT_value_id => Shift(yy_state_320)
    _ => Error
  }
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_321)
    _ => Error
  }
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VALUE_ID => Shift(yy_state_112)
    T_DATACON_ID => Shift(yy_state_127)
    T_LITERAL => Shift(yy_state_196)
    T_HANDLE => Shift(yy_state_197)
    T_MATCH => Shift(yy_state_221)
    T_FN => Shift(yy_state_238)
    T_PERFORM => Shift(yy_state_245)
    T_RESUME => Shift(yy_state_259)
    NT_data_con_id => Shift(yy_state_261)
    T_LPAREN => Shift(yy_state_266)
    NT_literal => Shift(yy_state_269)
    NT_value_id => Shift(yy_state_270)
    NT_atom_expr => Shift(yy_state_271)
    T_LETREC => Shift(yy_state_272)
    T_LET => Shift(yy_state_278)
    NT_postfix_expr => Shift(yy_state_284)
    NT_expr => Shift(yy_state_322)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_top_term, yy_action_2)
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_top_terms, yy_action_1)
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_325)
    _ => Error
  }
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
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
  for term in ([(T_LITERAL, TK_LITERAL), (T_NAME, TK_NAME), (T_TYPE_ID, TK_TYPE_ID), (T_TPARAM_ID, TK_TPARAM_ID), (T_VALUE_ID, TK_VALUE_ID), (T_DATACON_ID, TK_DATACON_ID), (T_EFFECT_ID, TK_EFFECT_ID), (T_OPERATION_ID, TK_OPERATION_ID), (T_NEXT_UNIQUE, TK_NEXT_UNIQUE), (T_EOF, TK_EOF), (T_BUSLANE, TK_BUSLANE), (T_METADATA, TK_METADATA), (T_TYPE, TK_TYPE), (T_TYPE_PARAMETER, TK_TYPE_PARAMETER), (T_VALUE, TK_VALUE), (T_DATACON, TK_DATACON), (T_EFFECT_DECL, TK_EFFECT_DECL), (T_OPERATION, TK_OPERATION), (T_FUNCTION_KIND, TK_FUNCTION_KIND), (T_PARAMETER_KIND, TK_PARAMETER_KIND), (T_LOCAL_KIND, TK_LOCAL_KIND), (T_MATCH_BINDER_KIND, TK_MATCH_BINDER_KIND), (T_TYPE_KIND, TK_TYPE_KIND), (T_EFFECT_KIND, TK_EFFECT_KIND), (T_UNIT_TYPE, TK_UNIT_TYPE), (T_BOOL_TYPE, TK_BOOL_TYPE), (T_I64_TYPE, TK_I64_TYPE), (T_I32_TYPE, TK_I32_TYPE), (T_CHAR_TYPE, TK_CHAR_TYPE), (T_F32_TYPE, TK_F32_TYPE), (T_F64_TYPE, TK_F64_TYPE), (T_STRING_TYPE, TK_STRING_TYPE), (T_BYTE_TYPE, TK_BYTE_TYPE), (T_BYTES_TYPE, TK_BYTES_TYPE), (T_IO, TK_IO), (T_FORALL, TK_FORALL), (T_IN, TK_IN), (T_AS, TK_AS), (T_FINAL, TK_FINAL), (T_UNDERSCORE, TK_UNDERSCORE), (T_LET, TK_LET), (T_LETREC, TK_LETREC), (T_EXTERNAL, TK_EXTERNAL), (T_FN, TK_FN), (T_PERFORM, TK_PERFORM), (T_HANDLE, TK_HANDLE), (T_RESUME, TK_RESUME), (T_MATCH, TK_MATCH), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_COMMA, TK_COMMA), (T_COLON, TK_COLON), (T_SEMI, TK_SEMI), (T_EQUAL, TK_EQUAL), (T_FAT_ARROW, TK_FAT_ARROW), (T_ARROW, TK_ARROW), (T_BANG, TK_BANG), (T_DOT, TK_DOT)] : Array[(YYSymbol, TokenKind)]) {
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
    yy_state_82,
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
