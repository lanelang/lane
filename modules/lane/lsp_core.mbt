///|
let server_name : String = "lane"

///|
struct DocumentSnapshot {
  uri : String
  version : Int
  text : String
} derive(Debug, Eq)

///|
struct ServerState {
  documents : Map[String, DocumentSnapshot]
  mut workspace_root : String?
  mut shutdown_requested : Bool
}

///|
struct HandlerResult {
  outgoing : Array[@jsonrpc.Message]
  exit_requested : Bool
} derive(Debug, Eq)

///|
fn ServerState::ServerState() -> ServerState {
  { documents: {}, workspace_root: None, shutdown_requested: false }
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
  Json::object({
    "capabilities": Json::object({
      "textDocumentSync": int_json(1),
      "definitionProvider": Json::boolean(true),
      "hoverProvider": Json::boolean(true),
    }),
    "serverInfo": Json::object({
      "name": Json::string(server_name),
      "version": Json::string("0.1.0"),
    }),
  })
}

///|
fn ServerState::handle_shutdown(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  self.shutdown_requested = true
  respond(request, Ok(Json::null()))
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
    outgoing: [publish_diagnostics(document.uri, self.check(document))],
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
    outgoing: [publish_diagnostics(document.uri, self.check(document))],
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
    return respond(request, Ok(Json::null()))
  }
  let analysis = self.analyze(document)
  let line = params.line + 1
  let column = params.character + 1
  match analysis.definition_at(params.uri, line, column) {
    Some(location) => respond(request, Ok(location_json(location)))
    None => respond(request, Ok(Json::null()))
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
    return respond(request, Ok(Json::null()))
  }
  let analysis = self.analyze(document)
  let line = params.line + 1
  let column = params.character + 1
  match analysis.hover_at(params.uri, line, column) {
    Some(hover) => respond(request, Ok(hover_json(hover)))
    None => respond(request, Ok(Json::null()))
  }
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
fn method_not_found_message(method_name : String) -> String {
  "method not found: \{method_name}; lane lsp supports initialize, shutdown, exit, textDocument/didOpen, textDocument/didChange, textDocument/didClose, textDocument/definition, and textDocument/hover"
}

///|
async fn ServerState::check(
  self : ServerState,
  document : DocumentSnapshot,
) -> Array[@compile.CompileDiagnostic] {
  self.analyze(document).diagnostics
}

///|
async fn ServerState::analyze(
  self : ServerState,
  document : DocumentSnapshot,
) -> @compile.AnalysisResult {
  @compile.analyze_source_inputs(
    { source_id: document.uri, text: document.text },
    self.workspace_library_sources(document.uri),
  )
}

///|
async fn ServerState::workspace_library_sources(
  self : ServerState,
  current_uri : String,
) -> Array[@compile.SourceInput] {
  guard self.workspace_root is Some(root) else { return [] }
  let current_path = file_uri_to_path(current_uri)
  let current_identity = match current_path {
    Some(path) => Some(lsp_source_identity(path))
    None => None
  }
  let library_identities = []
  let sources = self.open_document_library_sources(
    root, current_identity, library_identities,
  )
  append_lane_sources(root, current_identity, library_identities, sources) catch {
    _ => ()
  }
  sources
}

///|
async fn ServerState::open_document_library_sources(
  self : ServerState,
  root : String,
  current_identity : String?,
  library_identities : Array[String],
) -> Array[@compile.SourceInput] {
  let sources : Array[@compile.SourceInput] = []
  for _, document in self.documents {
    guard file_uri_to_path(document.uri) is Some(path) else { continue }
    let identity = lsp_source_identity(path)
    if Some(identity) != current_identity &&
      !library_identities.contains(identity) &&
      path.has_suffix(".lane") &&
      path_is_under_workspace(path, root) {
      library_identities.push(identity)
      sources.push({ source_id: document.uri, text: document.text })
    }
  }
  sources
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
  "file://" + percent_encode_path(path)
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
  path == root || path.has_prefix(root + "/")
}

///|
async fn lsp_source_identity(path : String) -> String {
  @fs.realpath(path) catch {
    _ => path
  }
}

///|
async fn append_lane_sources(
  path : String,
  current_identity : String?,
  library_identities : Array[String],
  sources : Array[@compile.SourceInput],
) -> Unit {
  let entries = @fs.readdir(path, sort=true)
  for entry in entries {
    if should_skip_workspace_entry(entry) {
      continue
    }
    let child = "\{path}/\{entry}"
    match @fs.kind(child) {
      Directory =>
        append_lane_sources(
          child, current_identity, library_identities, sources,
        )
      Regular if child.has_suffix(".lane") => {
        let identity = lsp_source_identity(child)
        if Some(identity) == current_identity ||
          library_identities.contains(identity) {
          continue
        }
        library_identities.push(identity)
        sources.push({
          source_id: path_to_file_uri(child),
          text: @fs.read_file(child).text(),
        })
      }
      _ => ()
    }
  }
}

///|
fn should_skip_workspace_entry(entry : String) -> Bool {
  entry.has_prefix(".") ||
  entry == "_build" ||
  entry == "build" ||
  entry == "dist"
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
fn publish_diagnostics(
  uri : String,
  diagnostics : Array[@compile.CompileDiagnostic],
) -> @jsonrpc.Message {
  @jsonrpc.new_notification(
    "textDocument/publishDiagnostics",
    Json::object({
      "uri": Json::string(uri),
      "diagnostics": Json::array(
        diagnostics.map(fn(diagnostic) {
          compile_diagnostic_json(uri, diagnostic)
        }),
      ),
    }),
  )
}

///|
fn location_json(location : @compile.AnalysisLocation) -> Json {
  Json::object({
    "uri": Json::string(location.source_id),
    "range": range_json(location.span),
  })
}

///|
fn hover_json(hover : @compile.HoverEntry) -> Json {
  Json::object({
    "contents": Json::object({
      "kind": Json::string("markdown"),
      "value": Json::string("```lane\n" + hover.contents + "\n```"),
    }),
    "range": range_json(hover.location.span),
  })
}

///|
fn compile_diagnostic_json(
  uri : String,
  diagnostic : @compile.CompileDiagnostic,
) -> Json {
  let fields = {
    "range": diagnostic_range_json(diagnostic.span),
    "severity": diagnostic_severity_json(diagnostic.severity),
    "source": Json::string("lane"),
    "message": Json::string(diagnostic.message),
  }
  match diagnostic.code {
    Some(code) => fields["code"] = Json::string(code)
    None => ()
  }
  let related = related_information_json(uri, diagnostic)
  if !related.is_empty() {
    fields["relatedInformation"] = Json::array(related)
  }
  Json::object(fields)
}

///|
fn related_information_json(
  uri : String,
  diagnostic : @compile.CompileDiagnostic,
) -> Array[Json] {
  let items : Array[Json] = []
  for label in diagnostic.labels {
    items.push(
      Json::object({
        "location": Json::object({
          "uri": Json::string(uri),
          "range": range_json(label.span),
        }),
        "message": Json::string(label.message),
      }),
    )
  }
  for note in diagnostic.notes {
    items.push(
      Json::object({
        "location": Json::object({
          "uri": Json::string(uri),
          "range": diagnostic_range_json(diagnostic.span),
        }),
        "message": Json::string("note: " + note),
      }),
    )
  }
  for help in diagnostic.helps {
    items.push(
      Json::object({
        "location": Json::object({
          "uri": Json::string(uri),
          "range": diagnostic_range_json(diagnostic.span),
        }),
        "message": Json::string("help: " + help),
      }),
    )
  }
  items
}

///|
fn diagnostic_range_json(span : @basic.SourceSpan?) -> Json {
  match span {
    Some(span) => range_json(span)
    None => range_json(@basic.SourceSpan::dummy())
  }
}

///|
fn range_json(span : @basic.SourceSpan) -> Json {
  Json::object({
    "start": position_json(span.start_line, span.start_column),
    "end": position_json(span.end_line, span.end_column),
  })
}

///|
fn position_json(line : Int, column : Int) -> Json {
  Json::object({
    "line": int_json(if line > 0 { line - 1 } else { 0 }),
    "character": int_json(if column > 0 { column - 1 } else { 0 }),
  })
}

///|
fn diagnostic_severity_json(
  severity : @compile.CompileDiagnosticSeverity,
) -> Json {
  match severity {
    Error => int_json(1)
    Warning => int_json(2)
  }
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}
