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
async test "initialize returns full document sync capability" {
  let state = ServerState::ServerState()
  let result = state.handle_message(request(1, "initialize", Json::null()))
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": {
        "capabilities": { "textDocumentSync": 1 },
        "serverInfo": { "name": "lane", "version": "0.1.0" },
      },
    },
  ])
}

///|
async test "didOpen publishes compiler diagnostics" {
  let state = ServerState::ServerState()
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file:///bad.lane",
        (
          #|module Test
          #|let answer : Missing = 1
        ),
      ),
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
              "start": { "line": 1, "character": 13 },
              "end": { "line": 1, "character": 20 },
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

///|
async test "didOpen checks against workspace library sources" {
  let workspace = ".tmp-lsp-workspace"
  let main_path = workspace + "/Main.lane"
  let lib_path = workspace + "/Lib.lane"
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub let value : Int = 42
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    main_path,
    (
      #|module Main
      #|
      #|pub let stale : Int = 0
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "initialize",
        Json::object({ "rootUri": Json::string("file://" + workspace) }),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://" + main_path,
        (
          #|module Main
          #|
          #|import Lib.*
          #|
          #|pub let answer : Int = value
        ),
      ),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp-workspace/Main.lane",
        "diagnostics": [],
      },
    },
  ])
}

///|
test "file URI paths are percent decoded" {
  debug_inspect(
    file_uri_to_path("file:///tmp/Lane%20Workspace/%E4%B8%AD.lane"),
    content=(
      #|Some("/tmp/Lane Workspace/中.lane")
    ),
  )
}

///|
async test "workspace libraries prefer unsaved open document snapshots" {
  let workspace = ".tmp-lsp workspace"
  let main_path = workspace + "/Main.lane"
  let lib_path = workspace + "/Lib.lane"
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub let stale : Int = 0
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    main_path,
    (
      #|module Main
      #|
      #|pub let stale : Int = 0
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "initialize",
        Json::object({ "rootUri": Json::string("file://.tmp-lsp%20workspace") }),
      ),
    ),
  )
  ignore(
    state.handle_message(
      request(
        2,
        "textDocument/didOpen",
        open_params(
          "file://.tmp-lsp%20workspace/Lib.lane",
          (
            #|module Lib
            #|
            #|pub let value : Int = 42
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      3,
      "textDocument/didOpen",
      open_params(
        "file://.tmp-lsp%20workspace/Main.lane",
        (
          #|module Main
          #|
          #|import Lib.*
          #|
          #|pub let answer : Int = value
        ),
      ),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp%20workspace/Main.lane",
        "diagnostics": [],
      },
    },
  ])
}

///|
async fn cleanup_workspace_fixture(
  workspace : String,
  main_path : String,
  lib_path : String,
) -> Unit {
  @fs.remove(main_path) catch {
    _ => ()
  }
  @fs.remove(lib_path) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
}
