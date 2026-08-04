///|
using @prettyprinter {render}

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
  render(program, width=100)
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
  render(type_, width=100)
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
    NEXT_UNIQUE(index) => "next_unique#\{index}"
    LITERAL(_) => "literal"
    NAME(_) => "name"
    EOF => "eof"
    BUSLANE => "buslane"
    METADATA => "metadata"
    TYPE => "type"
    TYPE_PARAMETER => "type_parameter"
    VALUE => "value"
    DATACON => "datacon"
    EFFECT_DECL => "effect"
    OPERATION => "operation"
    FUNCTION_KIND => "function"
    PARAMETER_KIND => "parameter"
    LOCAL_KIND => "local"
    MATCH_BINDER_KIND => "match_binder"
    TYPE_KIND => "Type"
    EFFECT_KIND => "Effect"
    UNIT_TYPE => "Unit"
    BOOL_TYPE => "Bool"
    I64_TYPE => "I64"
    I32_TYPE => "I32"
    CHAR_TYPE => "Char"
    F32_TYPE => "F32"
    F64_TYPE => "F64"
    STRING_TYPE => "String"
    BYTE_TYPE => "Byte"
    BYTES_TYPE => "Bytes"
    IO => "Io"
    FORALL => "forall"
    IN => "in"
    AS => "as"
    FINAL => "final"
    UNDERSCORE => "_"
    LET => "let"
    LETREC => "letrec"
    EXTERNAL => "external"
    FN => "fn"
    PERFORM => "perform"
    HANDLE => "handle"
    RESUME => "resume"
    MATCH => "match"
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
    ARROW => "->"
    BANG => "!"
    DOT => "."
  }
}
