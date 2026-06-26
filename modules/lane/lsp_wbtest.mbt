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
fn position_params(uri : String, line : Int, character : Int) -> Json {
  Json::object({
    "textDocument": Json::object({ "uri": Json::string(uri) }),
    "position": Json::object({
      "line": int_json(line),
      "character": int_json(character),
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
        "capabilities": {
          "textDocumentSync": 1,
          "definitionProvider": true,
          "hoverProvider": true,
          "semanticTokensProvider": {
            "legend": {
              "tokenTypes": ["variable", "parameter"],
              "tokenModifiers": [],
            },
            "full": true,
          },
        },
        "serverInfo": { "name": "lane", "version": "0.1.0" },
      },
    },
  ])
}

///|
test "position params accept parsed json numbers" {
  let text =
    #|{"textDocument":{"uri":"file:///Main.lane"},"position":{"line":4,"character":23}}
  let params = @json.parse(text)
  match text_document_position_params(params) {
    Some(params) => {
      inspect(params.uri, content="file:///Main.lane")
      inspect(params.line, content="4")
      inspect(params.character, content="23")
    }
    None => abort("expected position params")
  }
}

///|
async test "semantic tokens full returns variables and parameters" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|pub fn choose(first : Bool, second : Bool) -> Int {
            #|  let result = first
            #|  if second {
            #|    result
            #|  } else {
            #|    0
            #|  }
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/semanticTokens/full",
      Json::object({
        "textDocument": Json::object({
          "uri": Json::string("file:///Main.lane"),
        }),
      }),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "data": [
          2, 14, 5, 1, 0, 0, 14, 6, 1, 0, 1, 6, 6, 0, 0, 0, 9, 5, 1, 0, 1, 5, 6,
          1, 0, 1, 4, 6, 0, 0,
        ],
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
test "file URI paths are percent encoded" {
  inspect(
    path_to_file_uri("/tmp/Lane Workspace/中.lane"),
    content="file:///tmp/Lane%20Workspace/%E4%B8%AD.lane",
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
async test "definition returns encoded URI for discovered library source" {
  let workspace = ".tmp-lsp encoded-中"
  let main_path = workspace + "/Main.lane"
  let lib_path = workspace + "/Lib File 中.lane"
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
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "initialize",
        Json::object({ "rootUri": Json::string(path_to_file_uri(workspace)) }),
      ),
    ),
  )
  ignore(
    state.handle_message(
      request(
        2,
        "textDocument/didOpen",
        open_params(
          path_to_file_uri(main_path),
          (
            #|module Main
            #|
            #|import Lib.*
            #|
            #|pub let answer : Int = value
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      3,
      "textDocument/definition",
      position_params(path_to_file_uri(main_path), 4, 23),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 3,
      "result": {
        "uri": "file://.tmp-lsp%20encoded-%E4%B8%AD/Lib%20File%20%E4%B8%AD.lane",
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 13 },
        },
      },
    },
  ])
}

///|
async test "definition resolves same-file value references" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|pub let value : Int = 42
            #|
            #|pub let answer : Int = value
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/definition",
      position_params("file:///Main.lane", 4, 23),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "uri": "file:///Main.lane",
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 13 },
        },
      },
    },
  ])
}

///|
async test "hover returns checked value type" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|pub let value : Int = 42
            #|
            #|pub let answer : Int = value
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/hover",
      position_params("file:///Main.lane", 4, 23),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "contents": { "kind": "markdown", "value": "```lane\nvalue : Int\n```" },
        "range": {
          "start": { "line": 4, "character": 23 },
          "end": { "line": 4, "character": 28 },
        },
      },
    },
  ])
}

///|
async test "hover returns declaration detail" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|pub let value : Int = 42
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/hover",
      position_params("file:///Main.lane", 2, 10),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "contents": { "kind": "markdown", "value": "```lane\nvalue : Int\n```" },
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 13 },
        },
      },
    },
  ])
}

///|
async test "hover returns type reference summary" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|struct Point {
            #|  x : Int
            #|}
            #|
            #|pub let point : Point = Point::{ x: 1 }
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/hover",
      position_params("file:///Main.lane", 6, 17),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "contents": { "kind": "markdown", "value": "```lane\ntype Point\n```" },
        "range": {
          "start": { "line": 6, "character": 16 },
          "end": { "line": 6, "character": 21 },
        },
      },
    },
  ])
}

///|
async test "definition resolves workspace library references" {
  let workspace = ".tmp-lsp-definition"
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
  ignore(
    state.handle_message(
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
    ),
  )
  let result = state.handle_message(
    request(
      3,
      "textDocument/definition",
      position_params("file://" + main_path, 4, 23),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 3,
      "result": {
        "uri": "file://.tmp-lsp-definition/Lib.lane",
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 13 },
        },
      },
    },
  ])
}

///|
async test "definition uses partial analysis when unrelated diagnostics exist" {
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(
        1,
        "textDocument/didOpen",
        open_params(
          "file:///Main.lane",
          (
            #|module Main
            #|
            #|pub let value : Int = 42
            #|
            #|pub let answer : Int = value
            #|
            #|pub let bad : Int = missing
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/definition",
      position_params("file:///Main.lane", 4, 23),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "uri": "file:///Main.lane",
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 13 },
        },
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
