///|
using @prettyprinter {
  type Document,
  char,
  hardline,
  nest,
  render,
  separate,
  space,
  surround,
  text,
}

///|
pub struct CanonicalTextWriter {
  priv marker : Unit
}

///|
pub fn CanonicalTextWriter::CanonicalTextWriter() -> CanonicalTextWriter {
  { marker: () }
}

///|
pub fn CanonicalTextWriter::write_program(
  self : CanonicalTextWriter,
  program : @buslane.Program,
) -> String {
  ignore(self.marker)
  render(program_doc(program), width=100)
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
pub fn CanonicalTextWriter::write_type(
  self : CanonicalTextWriter,
  type_ : @buslane.Type,
) -> String {
  ignore(self.marker)
  render(type_doc(type_), width=100)
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
fn program_doc(program : @buslane.Program) -> Document {
  text("buslane") +
  space +
  canonical_block(
    [metadata_doc(program.metadata)] + program.terms.map(top_term_doc),
  )
}

///|
fn metadata_doc(metadata : @buslane.MetadataRegistry) -> Document {
  let docs = []
  for index in 0..<metadata.types.length() {
    let info = metadata.types[index]
    docs.push(
      text("type") +
      space +
      type_id_doc({ index, }) +
      space +
      text("parameters") +
      space +
      type_parameter_ids_doc(info.parameters) +
      space +
      text("constructors") +
      space +
      data_con_ids_doc(info.constructors) +
      text(";"),
    )
  }
  for index in 0..<metadata.type_parameters.length() {
    let info = metadata.type_parameters[index]
    docs.push(
      text("type_parameter") +
      space +
      type_parameter_id_doc({ index, }) +
      space +
      text(":") +
      space +
      kind_doc(info.kind) +
      text(";"),
    )
  }
  for index in 0..<metadata.values.length() {
    let info = metadata.values[index]
    docs.push(
      text("value") +
      space +
      value_id_doc({ index, }) +
      space +
      value_kind_doc(info.kind) +
      space +
      text(":") +
      space +
      type_doc(info.type_) +
      text(";"),
    )
  }
  for index in 0..<metadata.data_constructors.length() {
    let info = metadata.data_constructors[index]
    docs.push(
      text("datacon") +
      space +
      data_con_id_doc({ index, }) +
      space +
      text("owner") +
      space +
      type_id_doc(info.owner) +
      space +
      text("hidden") +
      space +
      type_parameter_ids_doc(info.hidden_type_parameters) +
      space +
      text("payload") +
      space +
      types_doc(info.payload_types) +
      text(";"),
    )
  }
  text("metadata") + space + canonical_block(docs)
}

///|
fn top_term_doc(term : @buslane.TopTerm) -> Document {
  match term {
    Let(id, expr) =>
      text("let") +
      space +
      value_id_doc(id) +
      space +
      text("=") +
      space +
      expr_doc(expr) +
      text(";")
    LetRec(bindings) =>
      text("letrec") + space + canonical_block(bindings.map(binding_doc))
    External(id) => text("external") + space + value_id_doc(id) + text(";")
  }
}

///|
fn canonical_block(docs : Array[Document]) -> Document {
  if docs.is_empty() {
    text("{") + hardline + text("}")
  } else {
    text("{") + nest(hardline + separate(hardline, docs)) + hardline + text("}")
  }
}

///|
fn kind_doc(kind : @buslane.Kind) -> Document {
  match kind {
    Type => text("Type")
    Function(parameters, result) =>
      call_doc("kind_fn", [kinds_doc(parameters), kind_doc(result)])
  }
}

///|
fn kinds_doc(kinds : Array[@buslane.Kind]) -> Document {
  bracketed(kinds.map(kind_doc))
}

///|
fn type_doc(type_ : @buslane.Type) -> Document {
  match type_ {
    Primitive(primitive) => primitive_doc(primitive)
    Parameter(id) => type_parameter_id_doc(id)
    Constructor(id) => type_id_doc(id)
    Apply(callee, arguments) =>
      call_doc("apply", [type_doc(callee), types_doc(arguments)])
    TypeLambda(parameters, body) =>
      call_doc("type_fn", [type_parameter_ids_doc(parameters), type_doc(body)])
    Function(parameters, result) =>
      call_doc("fn_type", [types_doc(parameters), type_doc(result)])
    Forall(parameters, body) =>
      call_doc("forall", [type_parameter_ids_doc(parameters), type_doc(body)])
  }
}

///|
fn types_doc(types : Array[@buslane.Type]) -> Document {
  bracketed(types.map(type_doc))
}

///|
fn primitive_doc(primitive : @buslane.PrimitiveType) -> Document {
  match primitive {
    Unit => text("Unit")
    Bool => text("Bool")
    Int => text("Int")
    String => text("String")
  }
}

///|
fn expr_doc(expr : @buslane.Expr) -> Document {
  match expr {
    Ref(id) => value_id_doc(id)
    Literal(literal) => literal_doc(literal)
    Function(function) =>
      call_doc("fn", [
        value_ids_doc(function.parameters),
        type_doc(function.result_type),
      ]) +
      space +
      inline_block(expr_doc(function.body))
    Call(callee, arguments) =>
      call_doc("call", [expr_doc(callee), exprs_doc(arguments)])
    TypeLambda(parameters, body) =>
      call_doc("type_fn", [type_parameter_ids_doc(parameters)]) +
      space +
      inline_block(expr_doc(body))
    TypeApply(callee, arguments) =>
      call_doc("type_apply", [expr_doc(callee), types_doc(arguments)])
    Construct(construct) =>
      call_doc("construct", [
        data_con_id_doc(construct.data_constructor),
        types_doc(construct.type_arguments),
        types_doc(construct.hidden_witnesses),
        exprs_doc(construct.payloads),
      ])
    Let(id, initializer, body) =>
      call_doc("let_in", [
        value_id_doc(id),
        expr_doc(initializer),
        expr_doc(body),
      ])
    LetRec(bindings, body) =>
      call_doc("letrec_in", [bindings_doc(bindings), expr_doc(body)])
    Match(match_) =>
      call_doc("match", [
        expr_doc(match_.scrutinee),
        value_id_doc(match_.binder),
        type_doc(match_.result_type),
      ]) +
      space +
      inline_block(alternatives_doc(match_.alternatives))
  }
}

///|
fn exprs_doc(exprs : Array[@buslane.Expr]) -> Document {
  bracketed(exprs.map(expr_doc))
}

///|
fn bindings_doc(bindings : Array[@buslane.RecursiveBinding]) -> Document {
  surround(char('{'), char('}'), separate(space, bindings.map(binding_doc)))
}

///|
fn binding_doc(binding : @buslane.RecursiveBinding) -> Document {
  value_id_doc(binding.id) +
  space +
  text("=") +
  space +
  expr_doc(binding.rhs) +
  text(";")
}

///|
fn alternatives_doc(alternatives : Array[@buslane.Alternative]) -> Document {
  if alternatives.is_empty() {
    text("")
  } else {
    separate(text(";") + space, alternatives.map(alternative_doc)) + text(";")
  }
}

///|
fn alternative_doc(alternative : @buslane.Alternative) -> Document {
  call_doc("alt", [
    alt_con_doc(alternative.alt_constructor),
    type_parameter_ids_doc(alternative.type_binders),
    value_ids_doc(alternative.value_binders),
  ]) +
  space +
  text("=>") +
  space +
  expr_doc(alternative.body)
}

///|
fn alt_con_doc(alt : @buslane.AltCon) -> Document {
  match alt {
    Default => text("default")
    Literal(literal) => call_doc("literal", [literal_doc(literal)])
    DataCon(id) => call_doc("datacon", [data_con_id_doc(id)])
  }
}

///|
fn literal_doc(literal : @buslane.Literal) -> Document {
  match literal {
    Unit => call_doc("unit", [])
    Bool(value) => text(if value { "true" } else { "false" })
    Int(value) => call_doc("int", [text(value.to_string())])
    String(value) => call_doc("string", [text(quote_string(value))])
  }
}

///|
fn type_id_doc(id : @buslane.TypeId) -> Document {
  text("type#") + text(id.index.to_string())
}

///|
fn type_parameter_id_doc(id : @buslane.TypeParameterId) -> Document {
  text("tparam#") + text(id.index.to_string())
}

///|
fn value_id_doc(id : @buslane.ValueId) -> Document {
  text("value#") + text(id.index.to_string())
}

///|
fn data_con_id_doc(id : @buslane.DataConId) -> Document {
  text("datacon#") + text(id.index.to_string())
}

///|
fn type_parameter_ids_doc(ids : Array[@buslane.TypeParameterId]) -> Document {
  bracketed(ids.map(type_parameter_id_doc))
}

///|
fn value_ids_doc(ids : Array[@buslane.ValueId]) -> Document {
  bracketed(ids.map(value_id_doc))
}

///|
fn data_con_ids_doc(ids : Array[@buslane.DataConId]) -> Document {
  bracketed(ids.map(data_con_id_doc))
}

///|
fn value_kind_doc(kind : @buslane.ValueKind) -> Document {
  match kind {
    Function => text("function")
    Value => text("value")
    External => text("external")
    Parameter => text("parameter")
    Local => text("local")
    MatchBinder => text("match_binder")
  }
}

///|
fn call_doc(name : String, arguments : Array[Document]) -> Document {
  text(name) + surround(char('('), char(')'), comma_separated(arguments))
}

///|
fn bracketed(docs : Array[Document]) -> Document {
  surround(char('['), char(']'), comma_separated(docs))
}

///|
fn comma_separated(docs : Array[Document]) -> Document {
  separate(text(",") + space, docs)
}

///|
fn inline_block(doc : Document) -> Document {
  surround(text("{ "), text(" }"), doc)
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
