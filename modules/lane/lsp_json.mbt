///|
fn json_field(json : Json, name : String) -> Json? {
  guard json is Object(fields) else { return None }
  fields.get(name)
}

///|
fn json_string_field(json : Json, name : String) -> String? {
  guard json_field(json, name) is Some(String(value)) else { return None }
  Some(value)
}

///|
fn json_int_field(json : Json, name : String) -> Int? {
  guard json_field(json, name) is Some(Number(_, repr~)) else { return None }
  guard repr is Some(text) else { return None }
  Some(@string.parse_int(text, base=10)) catch {
    _ => None
  }
}

///|
fn document_from_did_open(params : Json) -> DocumentSnapshot? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  let uri = json_string_field(text_document, "uri")
  let text = json_string_field(text_document, "text")
  guard uri is Some(uri) && text is Some(text) else { return None }
  Some({
    uri,
    text,
    version: json_int_field(text_document, "version").unwrap_or(0),
  })
}

///|
fn document_from_did_change(params : Json) -> DocumentSnapshot? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  guard json_field(params, "contentChanges") is Some(Array(changes)) else {
    return None
  }
  guard changes.get(0) is Some(change) else { return None }
  let uri = json_string_field(text_document, "uri")
  let text = json_string_field(change, "text")
  guard uri is Some(uri) && text is Some(text) else { return None }
  Some({
    uri,
    text,
    version: json_int_field(text_document, "version").unwrap_or(0),
  })
}

///|
fn uri_from_text_document_params(params : Json) -> String? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  json_string_field(text_document, "uri")
}

///|
struct TextDocumentPositionParams {
  uri : String
  line : Int
  character : Int
} derive(Debug, Eq)

///|
fn text_document_position_params(params : Json) -> TextDocumentPositionParams? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  guard json_field(params, "position") is Some(position) else { return None }
  let uri = json_string_field(text_document, "uri")
  let line = json_int_field(position, "line")
  let character = json_int_field(position, "character")
  guard uri is Some(uri) && line is Some(line) && character is Some(character) else {
    return None
  }
  Some({ uri, line, character })
}
