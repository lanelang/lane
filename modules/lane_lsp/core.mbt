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
  prelude : String
  documents : Map[String, DocumentSnapshot]
  mut shutdown_requested : Bool
}

///|
pub(all) struct HandlerResult {
  outgoing : Array[@jsonrpc.Message]
  exit_requested : Bool
} derive(Debug, Eq)

///|
pub fn ServerState::ServerState(prelude : String) -> ServerState {
  { prelude, documents: {}, shutdown_requested: false }
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
  _self : ServerState,
  request : @jsonrpc.Request,
) -> HandlerResult {
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
    outgoing: [publish_diagnostics(document.uri, self.check(document.text))],
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
    outgoing: [publish_diagnostics(document.uri, self.check(document.text))],
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
  text : String,
) -> Array[@compile.CompileDiagnostic] {
  @compile.check_with_prelude(self.prelude, text).diagnostics
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
