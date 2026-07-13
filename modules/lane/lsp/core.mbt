///|
let server_name : String = "lane"

///|
priv struct DocumentSnapshot {
  uri : String
  text : String
}

///|
priv struct ServerState {
  documents : Map[String, DocumentSnapshot]
  mut workspace_root : String?
  mut shutdown_requested : Bool
}

///|
priv struct HandlerResult {
  outgoing : Array[@jsonrpc.Message]
  exit_requested : Bool
}

///|
fn ServerState::ServerState() -> ServerState {
  { documents: Map([]), workspace_root: None, shutdown_requested: false }
}

///|
async fn ServerState::handle_message(
  self : ServerState,
  message : @jsonrpc.Message,
) -> HandlerResult {
  match message {
    Request(request) => self.handle_request(request)
    BatchRequest(requests) => self.handle_batch_request(requests)
    Response(_) | BatchResponse(_) => { outgoing: [], exit_requested: false }
  }
}

///|
async fn ServerState::handle_batch_request(
  self : ServerState,
  requests : Array[@jsonrpc.Request],
) -> HandlerResult {
  let outgoing = []
  let mut exit_requested = false
  for request in requests {
    let result = self.handle_request(request)
    outgoing.append(result.outgoing)
    exit_requested = exit_requested || result.exit_requested
  }
  { outgoing, exit_requested }
}

///|
async fn ServerState::handle_request(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  match request.method_ {
    "initialize" => self.handle_initialize(request)
    "shutdown" => self.handle_shutdown(request)
    "exit" => self.handle_exit()
    "textDocument/didOpen" => self.handle_did_open(request)
    "textDocument/didChange" => self.handle_did_change(request)
    "textDocument/didClose" => self.handle_did_close(request)
    "textDocument/definition" => self.handle_definition(request)
    "textDocument/hover" => self.handle_hover(request)
    "textDocument/inlayHint" => self.handle_inlay_hint(request)
    "textDocument/completion" => self.handle_completion(request)
    method_name => self.method_not_found(request, method_name)
  }
}

///|
fn ServerState::handle_initialize(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  self.workspace_root = workspace_root_from_initialize_params(request.params)
  respond(request, Ok(initialize_result()))
}

///|
fn initialize_result() -> Json {
  {
    "capabilities": {
      "textDocumentSync": 1,
      "definitionProvider": true,
      "hoverProvider": true,
      "inlayHintProvider": true,
      "completionProvider": {
        "triggerCharacters": [".", ":"],
        "resolveProvider": false,
      },
    },
    "serverInfo": { "name": server_name, "version": "0.1.0" },
  }
}

///|
fn ServerState::handle_shutdown(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  self.shutdown_requested = true
  respond(request, Ok(null))
}

///|
fn ServerState::handle_exit(self : ServerState) -> HandlerResult {
  { outgoing: [], exit_requested: self.shutdown_requested }
}

///|
async fn ServerState::handle_did_open(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard document_from_did_open(request.params) is Some(document) else {
    return respond(request, Err(invalid_params(invalid_did_open_params())))
  }
  self.documents[document.uri] = document
  {
    outgoing: self
    .workspace_analysis()
    .check(document)
    .map(fn(publication) {
      publish_diagnostics(
        publication.uri,
        publication.diagnostics,
        sources=publication.sources,
      )
    }),
    exit_requested: false,
  }
}

///|
async fn ServerState::handle_did_change(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard document_from_did_change(request.params) is Some(document) else {
    return respond(request, Err(invalid_params(invalid_did_change_params())))
  }
  self.documents[document.uri] = document
  {
    outgoing: self
    .workspace_analysis()
    .check(document)
    .map(fn(publication) {
      publish_diagnostics(
        publication.uri,
        publication.diagnostics,
        sources=publication.sources,
      )
    }),
    exit_requested: false,
  }
}

///|
fn ServerState::handle_did_close(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard uri_from_text_document_params(request.params) is Some(uri) else {
    return respond(request, Err(invalid_params(invalid_did_close_params())))
  }
  self.documents.remove(uri)
  { outgoing: [publish_diagnostics(uri, [])], exit_requested: false }
}

///|
async fn ServerState::handle_definition(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard text_document_position_params(request.params) is Some(params) else {
    return respond(
      request,
      Err(invalid_params(invalid_position_params("textDocument/definition"))),
    )
  }
  guard self.document_for_uri(params.uri) is Some(document) else {
    return respond(request, Ok(null))
  }
  let analysis = self.workspace_analysis().analyze(document)
  let line = params.line + 1
  let column = params.character + 1
  match analysis.definition_at(params.uri, line, column) {
    Some(location) => respond(request, Ok(location_json(location)))
    None => respond(request, Ok(null))
  }
}

///|
async fn ServerState::handle_hover(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard text_document_position_params(request.params) is Some(params) else {
    return respond(
      request,
      Err(invalid_params(invalid_position_params("textDocument/hover"))),
    )
  }
  guard self.document_for_uri(params.uri) is Some(document) else {
    return respond(request, Ok(null))
  }
  let analysis = self.workspace_analysis().analyze(document)
  let line = params.line + 1
  let column = params.character + 1
  match analysis.hover_at(params.uri, line, column) {
    Some(hover) => respond(request, Ok(hover_json(hover)))
    None => respond(request, Ok(null))
  }
}

///|
async fn ServerState::handle_inlay_hint(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard text_document_range_params(request.params) is Some(params) else {
    return respond(
      request,
      Err(invalid_params(invalid_range_params("textDocument/inlayHint"))),
    )
  }
  guard self.document_for_uri(params.uri) is Some(document) else {
    return respond(request, Ok(([] : Array[Json]).to_json()))
  }
  let analysis = self.workspace_analysis().analyze(document)
  let hints = analysis.inlay_hints_in_range(
    params.uri,
    params.start.line + 1,
    params.start.character + 1,
    params.end.line + 1,
    params.end.character + 1,
  )
  match validate_inlay_hint_positions(hints) {
    Err(message) => return respond(request, Err(internal_lsp_error(message)))
    Ok(_) => ()
  }
  respond(request, Ok(hints.map(inlay_hint_json).to_json()))
}

///|
async fn ServerState::handle_completion(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard text_document_completion_params(request.params) is Some(params) else {
    return respond(
      request,
      Err(invalid_params(invalid_position_params("textDocument/completion"))),
    )
  }
  guard self.document_for_uri(params.uri) is Some(document) else {
    return respond(request, Ok(completion_list_json([])))
  }
  let trigger = match params.trigger_character {
    Some(character) => @analysis.CompletionTrigger::TriggerCharacter(character)
    None => Manual
  }
  let entries = self
    .workspace_analysis()
    .complete(document, params.line + 1, params.character + 1, trigger)
  respond(request, Ok(completion_list_json(entries)))
}

///|
fn ServerState::document_for_uri(
  self : ServerState,
  uri : String,
) -> DocumentSnapshot? {
  match self.documents.get(uri) {
    Some(document) => Some(document)
    None => None
  }
}

///|
fn ServerState::workspace_analysis(self : ServerState) -> LspWorkspaceAnalysis {
  LspWorkspaceAnalysis(self.workspace_root, self.documents)
}

///|
fn ServerState::method_not_found(
  _self : ServerState,
  request : @jsonrpc.Request,
  method_name : String,
) -> HandlerResult {
  respond(
    request,
    Err({
      code: -32601,
      message: method_not_found_message(method_name),
      data: None,
    }),
  )
}

///|
fn invalid_did_open_params() -> String {
  "invalid textDocument/didOpen params: expected `textDocument.uri` and `textDocument.text`; this is an LSP client request shape error, not a Lane source error"
}

///|
fn invalid_did_change_params() -> String {
  "invalid textDocument/didChange params: expected `textDocument.uri` and `contentChanges[0].text`; this is an LSP client request shape error, not a Lane source error"
}

///|
fn invalid_did_close_params() -> String {
  "invalid textDocument/didClose params: expected `textDocument.uri`; this is an LSP client request shape error, not a Lane source error"
}

///|
fn invalid_position_params(method_name : String) -> String {
  "invalid \{method_name} params: expected `textDocument.uri`, `position.line`, and `position.character`; this is an LSP client request shape error, not a Lane source error"
}

///|
fn invalid_range_params(method_name : String) -> String {
  "invalid \{method_name} params: expected `textDocument.uri`, `range.start.line`, `range.start.character`, `range.end.line`, and `range.end.character`; this is an LSP client request shape error, not a Lane source error"
}

///|
fn method_not_found_message(method_name : String) -> String {
  "method not found: \{method_name}; lane lsp supports initialize, shutdown, exit, textDocument/didOpen, textDocument/didChange, textDocument/didClose, textDocument/definition, textDocument/hover, textDocument/inlayHint, and textDocument/completion"
}

///|
fn workspace_root_from_initialize_params(params : Json) -> String? {
  match workspace_root_uri(params) {
    Some(uri) => file_uri_to_path(uri)
    None => None
  }
}

///|
fn workspace_root_uri(params : Json) -> String? {
  guard params is Object(fields) else { return None }
  match fields.get("rootUri") {
    Some(String(uri)) => Some(uri)
    _ =>
      match fields.get("workspaceFolders") {
        Some(Array(folders)) =>
          match folders.get(0) {
            Some(Object(folder_fields)) =>
              match folder_fields.get("uri") {
                Some(String(uri)) => Some(uri)
                _ => None
              }
            _ => None
          }
        _ => None
      }
  }
}

///|
fn file_uri_to_path(uri : String) -> String? {
  let prefix = "file://"
  guard uri.has_prefix(prefix) else { return None }
  let path = uri.unsafe_substring(start=prefix.length(), end=uri.length())
  let path = if path.has_prefix("localhost/") {
    path.unsafe_substring(start="localhost".length(), end=path.length())
  } else {
    path
  }
  percent_decode_path(path)
}

///|
fn path_to_file_uri(path : String) -> String {
  "file://\{percent_encode_path(path)}"
}

///|
fn percent_encode_path(path : String) -> String {
  let output = []
  for byte in @utf8.encode(path) {
    if is_file_uri_path_byte(byte) {
      output.push(byte)
    } else {
      output.push(b'%')
      output.push(hex_digit(byte.to_int() >> 4))
      output.push(hex_digit(byte.to_int() & 0xF))
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => path
  }
}

///|
fn is_file_uri_path_byte(byte : Byte) -> Bool {
  let code = byte.to_int()
  (code >= b'a'.to_int() && code <= b'z'.to_int()) ||
  (code >= b'A'.to_int() && code <= b'Z'.to_int()) ||
  (code >= b'0'.to_int() && code <= b'9'.to_int()) ||
  byte == b'/' ||
  byte == b'-' ||
  byte == b'.' ||
  byte == b'_' ||
  byte == b'~'
}

///|
fn hex_digit(value : Int) -> Byte {
  if value < 10 {
    (b'0'.to_int() + value).to_byte()
  } else {
    (b'A'.to_int() + value - 10).to_byte()
  }
}

///|
fn percent_decode_path(path : String) -> String? {
  let input = @utf8.encode(path)
  let output = []
  let mut index = 0
  while index < input.length() {
    let byte = input[index]
    if byte == b'%' {
      guard index + 2 < input.length() else { return None }
      guard hex_byte_value(input[index + 1]) is Some(high) else { return None }
      guard hex_byte_value(input[index + 2]) is Some(low) else { return None }
      output.push(((high << 4) | low).to_byte())
      index = index + 3
    } else {
      output.push(byte)
      index = index + 1
    }
  }
  Some(@utf8.decode(Bytes::from_array(output))) catch {
    _ => None
  }
}

///|
fn hex_byte_value(byte : Byte) -> Int? {
  let code = byte.to_int()
  if code >= b'0'.to_int() && code <= b'9'.to_int() {
    Some(code - b'0'.to_int())
  } else if code >= b'a'.to_int() && code <= b'f'.to_int() {
    Some(code - b'a'.to_int() + 10)
  } else if code >= b'A'.to_int() && code <= b'F'.to_int() {
    Some(code - b'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn path_is_under_workspace(path : String, root : String) -> Bool {
  path == root || path.has_prefix("\{root}/")
}

///|
fn respond(
  request : @jsonrpc.Request,
  result : Result[Json, @jsonrpc.WireError],
) -> HandlerResult {
  match request.id {
    Some(id) =>
      { outgoing: [@jsonrpc.new_response(id, result)], exit_requested: false }
    None => { outgoing: [], exit_requested: false }
  }
}

///|
fn invalid_params(message : String) -> @jsonrpc.WireError {
  { code: -32602, message, data: None }
}

///|
fn internal_lsp_error(message : String) -> @jsonrpc.WireError {
  { code: -32603, message, data: None }
}

///|
fn location_json(location : @analysis.AnalysisLocation) -> Json {
  { "uri": location.source_id, "range": range_json(location.span) }
}

///|
fn hover_json(hover : @analysis.HoverEntry) -> Json {
  {
    "contents": {
      "kind": "markdown",
      "value": "```lane\n\{hover.contents}\n```",
    },
    "range": range_json(hover.location.span),
  }
}

///|
fn inlay_hint_json(hint : @analysis.InlayHintEntry) -> Json {
  {
    "position": inlay_hint_position_json(hint),
    "label": hint.label,
    "kind": inlay_hint_kind_json(hint.kind),
  }
}

///|
fn validate_inlay_hint_positions(
  hints : Array[@analysis.InlayHintEntry],
) -> Result[Unit, String] {
  for index in 0..<hints.length() {
    for other_index in (index + 1)..<hints.length() {
      if inlay_hint_same_position(hints[index], hints[other_index]) {
        return Err(
          inlay_hint_position_bug_message(hints[index], hints[other_index]),
        )
      }
    }
  }
  Ok(())
}

///|
fn inlay_hint_same_position(
  left : @analysis.InlayHintEntry,
  right : @analysis.InlayHintEntry,
) -> Bool {
  left.location.source_id == right.location.source_id &&
  inlay_hint_line(left) == inlay_hint_line(right) &&
  inlay_hint_column(left) == inlay_hint_column(right)
}

///|
fn inlay_hint_position_bug_message(
  left : @analysis.InlayHintEntry,
  right : @analysis.InlayHintEntry,
) -> String {
  "internal Lane compiler bug: multiple inlay hints were produced at \{left.location.source_id}:\{inlay_hint_line(left)}:\{inlay_hint_column(left)} (`\{left.label}` and `\{right.label}`)"
}

///|
fn inlay_hint_line(hint : @analysis.InlayHintEntry) -> Int {
  match hint.kind {
    TypeHint | ImplicitArgumentHint => hint.location.span.end_line
    ParameterHint => hint.location.span.start_line
  }
}

///|
fn inlay_hint_column(hint : @analysis.InlayHintEntry) -> Int {
  match hint.kind {
    TypeHint | ImplicitArgumentHint => hint.location.span.end_column
    ParameterHint => hint.location.span.start_column
  }
}

///|
fn inlay_hint_position_json(hint : @analysis.InlayHintEntry) -> Json {
  position_json(inlay_hint_line(hint), inlay_hint_column(hint))
}

///|
fn inlay_hint_kind_json(kind : @analysis.InlayHintKind) -> Json {
  match kind {
    TypeHint => 1
    ParameterHint | ImplicitArgumentHint => 2
  }
}

///|
fn completion_list_json(entries : Array[@analysis.CompletionEntry]) -> Json {
  {
    "isIncomplete": false,
    "items": entries.map(completion_item_json).to_json(),
  }
}

///|
fn completion_item_json(entry : @analysis.CompletionEntry) -> Json {
  let fields : Map[String, Json] = {
    "label": entry.label.to_json(),
    "kind": completion_item_kind_json(entry.kind),
  }
  if entry.detail is Some(detail) {
    fields["detail"] = detail.to_json()
  }
  if entry.documentation is Some(documentation) {
    fields["documentation"] = documentation.to_json()
  }
  if entry.sort_text is Some(sort_text) {
    fields["sortText"] = sort_text.to_json()
  }
  match entry.replace {
    Some(location) => {
      let new_text = match entry.insert_text {
        Some(text) => text
        None => entry.label
      }
      fields["textEdit"] = {
        "range": range_json(location.span),
        "newText": new_text,
      }
    }
    None =>
      if entry.insert_text is Some(text) {
        fields["insertText"] = text.to_json()
      }
  }
  fields.to_json()
}

///|
fn completion_item_kind_json(kind : @analysis.CompletionKind) -> Json {
  match kind {
    Value => 6
    Function => 3
    Type => 22
    TypeParameter => 25
    Effect => 7
    Operation => 3
    Field => 5
    Variant => 20
    Module => 9
    Offer => 12
  }
}
