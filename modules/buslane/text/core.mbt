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
    EFFECT_ID(index) => "effect#\{index}"
    OPERATION_ID(index) => "operation#\{index}"
    INT(value) => value
    DOUBLE(value) => value
    STRING(_) => "string"
    EOF => "eof"
    BUSLANE => "buslane"
    METADATA => "metadata"
    TYPE => "type"
    TYPE_PARAMETER => "type_parameter"
    VALUE => "value"
    DATACON => "datacon"
    EFFECT_DECL => "effect"
    OPERATION => "operation"
    NAME => "name"
    UNIQUE => "unique"
    PARAMETERS => "parameters"
    CONSTRUCTORS => "constructors"
    OPERATIONS => "operations"
    OWNER => "owner"
    HIDDEN => "hidden"
    PAYLOAD => "payload"
    RESULT => "result"
    FUNCTION_KIND => "function"
    PARAMETER_KIND => "parameter"
    LOCAL_KIND => "local"
    MATCH_BINDER_KIND => "match_binder"
    TYPE_KIND => "Type"
    EFFECT_KIND => "Effect"
    UNIT_TYPE => "Unit"
    BOOL_TYPE => "Bool"
    INT_TYPE => "Int"
    DOUBLE_TYPE => "Double"
    STRING_TYPE => "String"
    KIND_FN => "kind_fn"
    EMPTY_EFFECT => "empty_effect"
    IO_EFFECT => "io_effect"
    EFFECT_SINGLETON => "effect_singleton"
    EFFECT_UNION => "effect_union"
    APPLY => "apply"
    TYPE_FN => "type_fn"
    FN_TYPE => "fn_type"
    FORALL => "forall"
    LET => "let"
    LETREC => "letrec"
    EXTERNAL => "external"
    FN => "fn"
    CALL => "call"
    PERFORM => "perform"
    HANDLE => "handle"
    RESUME => "resume"
    HANDLER => "handler"
    OP_ALT => "op_alt"
    FINAL => "final"
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
    DOUBLE_LITERAL => "double"
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
      (if info.flavor is External {
        text("external") + space + text("type")
      } else {
        text("type")
      }) +
      space +
      type_id_doc({ index, }) +
      space +
      name_doc(info.name) +
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
      name_doc(info.name) +
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
      name_doc(info.name) +
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
      name_doc(info.name) +
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
  for index in 0..<metadata.effects.length() {
    let info = metadata.effects[index]
    docs.push(
      (if info.flavor is External {
        text("external") + space + text("effect")
      } else {
        text("effect")
      }) +
      space +
      effect_id_doc({ index, }) +
      space +
      name_doc(info.name) +
      space +
      text("parameters") +
      space +
      type_parameter_ids_doc(info.parameters) +
      space +
      text("operations") +
      space +
      operation_ids_doc(info.operations) +
      text(";"),
    )
  }
  for index in 0..<metadata.operations.length() {
    let info = metadata.operations[index]
    docs.push(
      text("operation") +
      space +
      operation_id_doc({ index, }) +
      space +
      name_doc(info.name) +
      space +
      text("owner") +
      space +
      effect_id_doc(info.owner) +
      space +
      text("hidden") +
      space +
      type_parameter_ids_doc(info.hidden_type_parameters) +
      space +
      text("payload") +
      space +
      types_doc(info.payload_types) +
      space +
      text("result") +
      space +
      type_doc(info.result_type) +
      text(";"),
    )
  }
  text("metadata") + space + canonical_block(docs)
}

///|
fn name_doc(name : @buslane.BuslaneName) -> Document {
  text("name") +
  space +
  text(quote_string(name.occurrence)) +
  space +
  text("unique") +
  space +
  text(name.unique.value.to_string())
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
    Effect => text("Effect")
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
      call_doc("apply", [type_doc(callee), generic_arguments_doc(arguments)])
    TypeLambda(parameters, body) =>
      call_doc("type_fn", [type_parameter_ids_doc(parameters), type_doc(body)])
    Function(parameters, result, effect) =>
      match effect {
        Empty => call_doc("fn_type", [types_doc(parameters), type_doc(result)])
        _ =>
          call_doc("fn_type", [
            types_doc(parameters),
            type_doc(result),
            effect_doc(effect),
          ])
      }
    Forall(parameters, body) =>
      call_doc("forall", [type_parameter_ids_doc(parameters), type_doc(body)])
  }
}

///|
fn effect_doc(effect : @buslane.Effect) -> Document {
  match effect {
    Empty => call_doc("empty_effect", [])
    Io => call_doc("io_effect", [])
    Singleton(id, arguments) =>
      call_doc("effect_singleton", [
        effect_id_doc(id),
        generic_arguments_doc(arguments),
      ])
    Parameter(id) => type_parameter_id_doc(id)
    Union(effects) => call_doc("effect_union", [effects_doc(effects)])
  }
}

///|
fn effects_doc(effects : Array[@buslane.Effect]) -> Document {
  bracketed(effects.map(effect_doc))
}

///|
fn types_doc(types : Array[@buslane.Type]) -> Document {
  bracketed(types.map(type_doc))
}

///|
fn generic_argument_doc(argument : @buslane.GenericArgument) -> Document {
  match argument {
    TypeArgument(type_) => call_doc("type", [type_doc(type_)])
    EffectArgument(effect) => call_doc("effect", [effect_doc(effect)])
  }
}

///|
fn generic_arguments_doc(
  arguments : Array[@buslane.GenericArgument],
) -> Document {
  bracketed(arguments.map(generic_argument_doc))
}

///|
fn primitive_doc(primitive : @buslane.PrimitiveType) -> Document {
  match primitive {
    Unit => text("Unit")
    Bool => text("Bool")
    Int => text("Int")
    Double => text("Double")
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
    Perform(perform) =>
      call_doc("perform", [
        operation_id_doc(perform.operation),
        generic_arguments_doc(perform.effect_arguments),
        generic_arguments_doc(perform.hidden_witnesses),
        exprs_doc(perform.payloads),
      ])
    Resume(id) => call_doc("resume", [value_id_doc(id)])
    TypeLambda(parameters, body) =>
      call_doc("type_fn", [type_parameter_ids_doc(parameters)]) +
      space +
      inline_block(expr_doc(body))
    TypeApply(callee, arguments) =>
      call_doc("type_apply", [
        expr_doc(callee),
        generic_arguments_doc(arguments),
      ])
    Construct(construct) =>
      call_doc("construct", [
        data_con_id_doc(construct.data_constructor),
        generic_arguments_doc(construct.type_arguments),
        generic_arguments_doc(construct.hidden_witnesses),
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
    Handle(handle) =>
      call_doc("handle", [
        expr_doc(handle.body),
        value_id_doc(handle.result_binder),
        type_doc(handle.result_type),
        expr_doc(handle.final_body),
      ]) +
      space +
      inline_block(handler_tables_doc(handle.handlers))
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
fn handler_tables_doc(tables : Array[@buslane.HandlerTable]) -> Document {
  separate(space, tables.map(handler_table_doc))
}

///|
fn handler_table_doc(table : @buslane.HandlerTable) -> Document {
  call_doc("handler", [effect_doc(table.handled_effect)]) +
  space +
  inline_block(operation_alternatives_doc(table.operations))
}

///|
fn operation_alternatives_doc(
  alternatives : Array[@buslane.OperationAlternative],
) -> Document {
  separate(space, alternatives.map(operation_alternative_doc))
}

///|
fn operation_alternative_doc(
  alternative : @buslane.OperationAlternative,
) -> Document {
  call_doc("op_alt", [
    operation_id_doc(alternative.operation),
    type_parameter_ids_doc(alternative.type_binders),
    value_ids_doc(alternative.payload_binders),
    value_id_doc(alternative.resume_binder),
  ]) +
  space +
  text("=>") +
  space +
  expr_doc(alternative.body) +
  text(";")
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
    Double(value) => call_doc("double", [text(value.to_string())])
    String(value) => call_doc("string", [text(quote_string(value))])
  }
}

///|
fn type_id_doc(id : @buslane.TypeId) -> Document {
  text("type#\{id.index}")
}

///|
fn type_parameter_id_doc(id : @buslane.TypeParameterId) -> Document {
  text("tparam#\{id.index}")
}

///|
fn value_id_doc(id : @buslane.ValueId) -> Document {
  text("value#\{id.index}")
}

///|
fn data_con_id_doc(id : @buslane.DataConId) -> Document {
  text("datacon#\{id.index}")
}

///|
fn effect_id_doc(id : @buslane.EffectId) -> Document {
  text("effect#\{id.index}")
}

///|
fn operation_id_doc(id : @buslane.OperationId) -> Document {
  text("operation#\{id.index}")
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
fn operation_ids_doc(ids : Array[@buslane.OperationId]) -> Document {
  bracketed(ids.map(operation_id_doc))
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
