///|
pub fn program_to_text(program : @buslane.Program) -> String {
  let lines = ["buslane {"]
  write_metadata(lines, program.metadata)
  for term in program.terms {
    write_top_term(lines, term, indent=1)
  }
  lines.push("}")
  lines.join("\n")
}

///|
pub fn parse_program_text(text : String) -> Result[@buslane.Program, String] {
  let tokens = tokens_from_string(text) catch {
    BuslaneTextLexerError(message) => return Err(message)
  }
  let yacc_tokens = tokens.map(fn(item) {
    let (token, loc) = item
    (token, loc, loc)
  })
  let program = buslane_program(yacc_tokens) catch {
    UnexpectedEndOfInput(_, _) => return Err("unexpected end of Buslane text")
    UnexpectedToken(token, _, _) =>
      return Err("unexpected Buslane text token " + token_label(token))
  }
  Ok(program)
}

///|
pub fn type_to_text(type_ : @buslane.Type) -> String {
  type_text(type_)
}

///|
pub fn parse_type_text(text : String) -> Result[@buslane.Type, String] {
  let tokens = tokens_from_string(text) catch {
    BuslaneTextLexerError(message) => return Err(message)
  }
  let yacc_tokens = tokens.map(fn(item) {
    let (token, loc) = item
    (token, loc, loc)
  })
  let type_ = buslane_type(yacc_tokens) catch {
    UnexpectedEndOfInput(_, _) => return Err("unexpected end of Buslane type")
    UnexpectedToken(token, _, _) =>
      return Err("unexpected Buslane type token " + token_label(token))
  }
  Ok(type_)
}

///|
fn token_label(token : Token) -> String {
  match token {
    TYPE_ID(index) => "type#\{index}"
    TPARAM_ID(index) => "tparam#\{index}"
    VALUE_ID(index) => "value#\{index}"
    DATACON_ID(index) => "datacon#\{index}"
    INT(value) => value
    STRING(_) => "string"
    EOF => "eof"
    BUSLANE => "buslane"
    METADATA => "metadata"
    TYPE => "type"
    TYPE_PARAMETER => "type_parameter"
    VALUE => "value"
    DATACON => "datacon"
    PARAMETERS => "parameters"
    CONSTRUCTORS => "constructors"
    OWNER => "owner"
    HIDDEN => "hidden"
    PAYLOAD => "payload"
    FUNCTION_KIND => "function"
    PARAMETER_KIND => "parameter"
    LOCAL_KIND => "local"
    MATCH_BINDER_KIND => "match_binder"
    TYPE_KIND => "Type"
    UNIT_TYPE => "Unit"
    BOOL_TYPE => "Bool"
    INT_TYPE => "Int"
    STRING_TYPE => "String"
    KIND_FN => "kind_fn"
    APPLY => "apply"
    TYPE_FN => "type_fn"
    FN_TYPE => "fn_type"
    FORALL => "forall"
    LET => "let"
    LETREC => "letrec"
    EXTERNAL => "external"
    FN => "fn"
    CALL => "call"
    TYPE_APPLY => "type_apply"
    CONSTRUCT => "construct"
    LET_IN => "let_in"
    LETREC_IN => "letrec_in"
    MATCH => "match"
    ALT => "alt"
    DEFAULT => "default"
    LITERAL_ALT => "literal"
    TRUE => "true"
    FALSE => "false"
    INT_LITERAL => "int"
    STRING_LITERAL => "string"
    UNIT_LITERAL => "unit"
    LBRACE => "{"
    RBRACE => "}"
    LBRACKET => "["
    RBRACKET => "]"
    LPAREN => "("
    RPAREN => ")"
    COMMA => ","
    COLON => ":"
    SEMI => ";"
    EQUAL => "="
    FAT_ARROW => "=>"
  }
}

///|
fn write_metadata(
  lines : Array[String],
  metadata : @buslane.MetadataRegistry,
) -> Unit {
  lines.push("  metadata {")
  for index in 0..<metadata.types.length() {
    let info = metadata.types[index]
    lines.push(
      "    type " +
      type_id_text({ index, }) +
      " parameters " +
      type_parameter_ids_text(info.parameters) +
      " constructors " +
      data_con_ids_text(info.constructors) +
      ";",
    )
  }
  for index in 0..<metadata.type_parameters.length() {
    let info = metadata.type_parameters[index]
    lines.push(
      "    type_parameter " +
      type_parameter_id_text({ index, }) +
      " : " +
      kind_text(info.kind) +
      ";",
    )
  }
  for index in 0..<metadata.values.length() {
    let info = metadata.values[index]
    lines.push(
      "    value " +
      value_id_text({ index, }) +
      " " +
      value_kind_text(info.kind) +
      " : " +
      type_text(info.type_) +
      ";",
    )
  }
  for index in 0..<metadata.data_constructors.length() {
    let info = metadata.data_constructors[index]
    lines.push(
      "    datacon " +
      data_con_id_text({ index, }) +
      " owner " +
      type_id_text(info.owner) +
      " hidden " +
      type_parameter_ids_text(info.hidden_type_parameters) +
      " payload " +
      types_text(info.payload_types) +
      ";",
    )
  }
  lines.push("  }")
}

///|
fn write_top_term(
  lines : Array[String],
  term : @buslane.TopTerm,
  indent~ : Int,
) -> Unit {
  let pad = spaces(indent)
  match term {
    Let(id, expr) =>
      lines.push(
        pad + "let " + value_id_text(id) + " = " + expr_text(expr) + ";",
      )
    LetRec(bindings) => {
      lines.push(pad + "letrec {")
      for binding in bindings {
        lines.push(
          spaces(indent + 1) +
          value_id_text(binding.id) +
          " = " +
          expr_text(binding.rhs) +
          ";",
        )
      }
      lines.push(pad + "}")
    }
    External(id) => lines.push(pad + "external " + value_id_text(id) + ";")
  }
}

///|
fn spaces(indent : Int) -> String {
  let chunks = []
  for _ in 0..<indent {
    chunks.push("  ")
  }
  chunks.join("")
}

///|
fn kind_text(kind : @buslane.Kind) -> String {
  match kind {
    Type => "Type"
    Function(parameters, result) =>
      "kind_fn(" + kinds_text(parameters) + ", " + kind_text(result) + ")"
  }
}

///|
fn kinds_text(kinds : Array[@buslane.Kind]) -> String {
  "[" + kinds.map(kind_text).join(", ") + "]"
}

///|
fn type_text(type_ : @buslane.Type) -> String {
  match type_ {
    Primitive(primitive) => primitive_text(primitive)
    Parameter(id) => type_parameter_id_text(id)
    Constructor(id) => type_id_text(id)
    Apply(callee, arguments) =>
      "apply(" + type_text(callee) + ", " + types_text(arguments) + ")"
    TypeLambda(parameters, body) =>
      "type_fn(" +
      type_parameter_ids_text(parameters) +
      ", " +
      type_text(body) +
      ")"
    Function(parameters, result) =>
      "fn_type(" + types_text(parameters) + ", " + type_text(result) + ")"
    Forall(parameters, body) =>
      "forall(" +
      type_parameter_ids_text(parameters) +
      ", " +
      type_text(body) +
      ")"
  }
}

///|
fn types_text(types : Array[@buslane.Type]) -> String {
  "[" + types.map(type_text).join(", ") + "]"
}

///|
fn primitive_text(primitive : @buslane.PrimitiveType) -> String {
  match primitive {
    Unit => "Unit"
    Bool => "Bool"
    Int => "Int"
    String => "String"
  }
}

///|
fn expr_text(expr : @buslane.Expr) -> String {
  match expr {
    Ref(id) => value_id_text(id)
    Literal(literal) => literal_text(literal)
    Function(function) =>
      "fn(" +
      value_ids_text(function.parameters) +
      ", " +
      type_text(function.result_type) +
      ") { " +
      expr_text(function.body) +
      " }"
    Call(callee, arguments) =>
      "call(" + expr_text(callee) + ", " + exprs_text(arguments) + ")"
    TypeLambda(parameters, body) =>
      "type_fn(" +
      type_parameter_ids_text(parameters) +
      ") { " +
      expr_text(body) +
      " }"
    TypeApply(callee, arguments) =>
      "type_apply(" + expr_text(callee) + ", " + types_text(arguments) + ")"
    Construct(construct) =>
      "construct(" +
      data_con_id_text(construct.data_constructor) +
      ", " +
      types_text(construct.type_arguments) +
      ", " +
      types_text(construct.hidden_witnesses) +
      ", " +
      exprs_text(construct.payloads) +
      ")"
    Let(id, initializer, body) =>
      "let_in(" +
      value_id_text(id) +
      ", " +
      expr_text(initializer) +
      ", " +
      expr_text(body) +
      ")"
    LetRec(bindings, body) =>
      "letrec_in(" + bindings_text(bindings) + ", " + expr_text(body) + ")"
    Match(match_) =>
      "match(" +
      expr_text(match_.scrutinee) +
      ", " +
      value_id_text(match_.binder) +
      ", " +
      type_text(match_.result_type) +
      ") { " +
      alternatives_text(match_.alternatives) +
      " }"
  }
}

///|
fn exprs_text(exprs : Array[@buslane.Expr]) -> String {
  "[" + exprs.map(expr_text).join(", ") + "]"
}

///|
fn bindings_text(bindings : Array[@buslane.RecursiveBinding]) -> String {
  "{" +
  bindings
  .map(fn(binding) {
    value_id_text(binding.id) + " = " + expr_text(binding.rhs)
  })
  .join("; ") +
  "}"
}

///|
fn alternatives_text(alternatives : Array[@buslane.Alternative]) -> String {
  if alternatives.is_empty() {
    ""
  } else {
    alternatives
    .map(fn(alternative) {
      "alt(" +
      alt_con_text(alternative.alt_constructor) +
      ", " +
      type_parameter_ids_text(alternative.type_binders) +
      ", " +
      value_ids_text(alternative.value_binders) +
      ") => " +
      expr_text(alternative.body)
    })
    .join("; ") +
    ";"
  }
}

///|
fn alt_con_text(alt : @buslane.AltCon) -> String {
  match alt {
    Default => "default"
    Literal(literal) => "literal(" + literal_text(literal) + ")"
    DataCon(id) => "datacon(" + data_con_id_text(id) + ")"
  }
}

///|
fn literal_text(literal : @buslane.Literal) -> String {
  match literal {
    Unit => "unit()"
    Bool(value) => if value { "true" } else { "false" }
    Int(value) => "int(" + value.to_string() + ")"
    String(value) => "string(" + quote_string(value) + ")"
  }
}

///|
fn type_id_text(id : @buslane.TypeId) -> String {
  "type#" + id.index.to_string()
}

///|
fn type_parameter_id_text(id : @buslane.TypeParameterId) -> String {
  "tparam#" + id.index.to_string()
}

///|
fn value_id_text(id : @buslane.ValueId) -> String {
  "value#" + id.index.to_string()
}

///|
fn data_con_id_text(id : @buslane.DataConId) -> String {
  "datacon#" + id.index.to_string()
}

///|
fn type_parameter_ids_text(ids : Array[@buslane.TypeParameterId]) -> String {
  "[" + ids.map(type_parameter_id_text).join(", ") + "]"
}

///|
fn value_ids_text(ids : Array[@buslane.ValueId]) -> String {
  "[" + ids.map(value_id_text).join(", ") + "]"
}

///|
fn data_con_ids_text(ids : Array[@buslane.DataConId]) -> String {
  "[" + ids.map(data_con_id_text).join(", ") + "]"
}

///|
fn value_kind_text(kind : @buslane.ValueKind) -> String {
  match kind {
    Function => "function"
    Value => "value"
    External => "external"
    Parameter => "parameter"
    Local => "local"
    MatchBinder => "match_binder"
  }
}

///|
fn quote_string(value : String) -> String {
  let output = [b'"']
  for byte in @utf8.encode(value) {
    match byte {
      b'"' => {
        output.push(b'\\')
        output.push(b'"')
      }
      b'\\' => {
        output.push(b'\\')
        output.push(b'\\')
      }
      b'\n' => {
        output.push(b'\\')
        output.push(b'n')
      }
      b'\r' => {
        output.push(b'\\')
        output.push(b'r')
      }
      b'\t' => {
        output.push(b'\\')
        output.push(b't')
      }
      _ => output.push(byte)
    }
  }
  output.push(b'"')
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => "\"\""
  }
}
