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
  guard json_field(json, name) is Some(Number(value, repr~)) else {
    return None
  }
  match repr {
    Some(text) => Some(@string.parse_int(text, base=10)) catch { _ => None }
    None => {
      let int_value = value.to_int()
      if int_value.to_double() == value {
        Some(int_value)
      } else {
        None
      }
    }
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
  Some({ uri, text })
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
  Some({ uri, text })
}

///|
fn uri_from_text_document_params(params : Json) -> String? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  json_string_field(text_document, "uri")
}

///|
priv struct TextDocumentPositionParams {
  uri : String
  line : Int
  character : Int
}

///|
priv struct LspPosition {
  line : Int
  character : Int
}

///|
priv struct TextDocumentRangeParams {
  uri : String
  start : LspPosition
  end : LspPosition
}

///|
fn text_document_position_params(params : Json) -> TextDocumentPositionParams? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  guard json_position_field(params, "position") is Some(position) else {
    return None
  }
  let uri = json_string_field(text_document, "uri")
  guard uri is Some(uri) else { return None }
  Some({ uri, line: position.line, character: position.character })
}

///|
fn text_document_range_params(params : Json) -> TextDocumentRangeParams? {
  guard json_field(params, "textDocument") is Some(text_document) else {
    return None
  }
  guard json_field(params, "range") is Some(range) else { return None }
  let uri = json_string_field(text_document, "uri")
  let start = json_position_field(range, "start")
  let end = json_position_field(range, "end")
  guard uri is Some(uri) && start is Some(start) && end is Some(end) else {
    return None
  }
  Some({ uri, start, end })
}

///|
fn json_position_field(json : Json, name : String) -> LspPosition? {
  guard json_field(json, name) is Some(position) else { return None }
  let line = json_int_field(position, "line")
  let character = json_int_field(position, "character")
  guard line is Some(line) && character is Some(character) else { return None }
  Some({ line, character })
}
