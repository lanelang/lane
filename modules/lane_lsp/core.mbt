///|
let server_name : String = "lane_lsp"

///|
pub(all) struct DocumentSnapshot {
  uri : String
  version : Int
  text : String
} derive(Debug, Eq)

///|
pub struct ServerState {
  documents : Map[String, DocumentSnapshot]
  mut workspace_root : String?
  mut shutdown_requested : Bool
}

///|
pub(all) struct HandlerResult {
  outgoing : Array[@jsonrpc.Message]
  exit_requested : Bool
} derive(Debug, Eq)

///|
pub fn ServerState::ServerState() -> ServerState {
  { documents: {}, workspace_root: None, shutdown_requested: false }
}

///|
pub fn ServerState::handle_message(
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
fn ServerState::handle_batch_request(
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
fn ServerState::handle_request(
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
    "capabilities": Json::object({ "textDocumentSync": int_json(1) }),
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
fn ServerState::handle_did_open(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard document_from_did_open(request.params) is Some(document) else {
    return respond(request, Err(invalid_params("invalid didOpen params")))
  }
  self.documents[document.uri] = document
  {
    outgoing: [publish_diagnostics(document.uri, self.check(document))],
    exit_requested: false,
  }
}

///|
fn ServerState::handle_did_change(
  self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
  guard document_from_did_change(request.params) is Some(document) else {
    return respond(request, Err(invalid_params("invalid didChange params")))
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
    return respond(request, Err(invalid_params("invalid didClose params")))
  }
  self.documents.remove(uri)
  { outgoing: [publish_diagnostics(uri, [])], exit_requested: false }
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
      message: "method not found: " + method_name,
      data: None,
    }),
  )
}

///|
fn ServerState::check(
  self : ServerState,
  document : DocumentSnapshot,
) -> Array[@compile.CompileDiagnostic] {
  @compile.check_sources(
    document.text,
    self.workspace_library_sources(document.uri),
  ).diagnostics
}

///|
fn ServerState::workspace_library_sources(
  self : ServerState,
  current_uri : String,
) -> Array[String] {
  guard self.workspace_root is Some(root) else { return [] }
  let current_path = file_uri_to_path(current_uri)
  let opened_paths = []
  let sources = self.open_document_library_sources(
    root, current_path, opened_paths,
  )
  discover_lane_sources(root, current_path, opened_paths, sources) catch {
    _ => sources
  }
}

///|
fn ServerState::open_document_library_sources(
  self : ServerState,
  root : String,
  current_path : String?,
  opened_paths : Array[String],
) -> Array[String] {
  let sources = []
  for _, document in self.documents {
    guard file_uri_to_path(document.uri) is Some(path) else { continue }
    if Some(path) != current_path &&
      path.has_suffix(".lane") &&
      path_is_under_workspace(path, root) {
      opened_paths.push(path)
      sources.push(document.text)
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
fn discover_lane_sources(
  root : String,
  excluded_path : String?,
  opened_paths : Array[String],
  sources : Array[String],
) -> Array[String] raise @fs.IOError {
  append_lane_sources(root, excluded_path, opened_paths, sources)
  sources
}

///|
fn append_lane_sources(
  path : String,
  excluded_path : String?,
  opened_paths : Array[String],
  sources : Array[String],
) -> Unit raise @fs.IOError {
  let entries = @fs.read_dir(path)
  entries.sort()
  for entry in entries {
    if should_skip_workspace_entry(entry) {
      continue
    }
    let child = path + "/" + entry
    if @fs.is_dir(child) {
      append_lane_sources(child, excluded_path, opened_paths, sources)
    } else if @fs.is_file(child) && child.has_suffix(".lane") {
      if Some(child) != excluded_path && !opened_paths.contains(child) {
        sources.push(@fs.read_file_to_string(child, encoding="utf8"))
      }
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
      "diagnostics": Json::array(diagnostics.map(compile_diagnostic_json)),
    }),
  )
}

///|
fn compile_diagnostic_json(diagnostic : @compile.CompileDiagnostic) -> Json {
  Json::object({
    "range": diagnostic_range_json(diagnostic.span),
    "severity": diagnostic_severity_json(diagnostic.severity),
    "source": Json::string("lane"),
    "message": Json::string(diagnostic.message),
  })
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
