///|
fn lsp_test_prelude() -> String {
  (
    #|struct Add[T] {
    #|  add : (T, T) -> T
    #|}
    #|
    #|fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
    #|  op.add(a, b)
    #|}
    #|
    #|fn int_add(a : Int, b : Int) -> Int {
    #|  builtin("%i64_add")(a, b)
    #|}
    #|
    #|offer int_add_ops : Add[Int] = Add::{ add: int_add }
  )
}

///|
fn request(id : Int, method_name : String, params : Json) -> @jsonrpc.Message {
  @jsonrpc.new_call(@jsonrpc.ID::number(id.to_int64()), method_name, params)
}

///|
fn open_params(uri : String, text : String) -> Json {
  Json::object({
    "textDocument": Json::object({
      "uri": Json::string(uri),
      "languageId": Json::string("lane"),
      "version": int_json(1),
      "text": Json::string(text),
    }),
  })
}

///|
test "initialize returns full document sync capability" {
  let state = ServerState::ServerState(lsp_test_prelude())
  let result = state.handle_message(request(1, "initialize", Json::null()))
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": {
        "capabilities": { "textDocumentSync": 1 },
        "serverInfo": { "name": "lane_lsp", "version": "0.1.0" },
      },
    },
  ])
}

///|
test "stdlib option resolves prelude path" {
  inspect(
    prelude_path(Some("/tmp/lane-lib")),
    content="/tmp/lane-lib/prelude.lane",
  )
}

///|
test "didOpen publishes compiler diagnostics" {
  let state = ServerState::ServerState(lsp_test_prelude())
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params("file:///bad.lane", "let answer : Missing = 1\n"),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file:///bad.lane",
        "diagnostics": [
          {
            "range": {
              "start": { "line": 13, "character": 13 },
              "end": { "line": 13, "character": 20 },
            },
            "severity": 1,
            "source": "lane",
            "message": "unresolved_type Missing",
          },
        ],
      },
    },
  ])
}
