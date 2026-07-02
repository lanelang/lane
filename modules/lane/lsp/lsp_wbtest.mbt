///|
fn request(id : Int, method_name : String, params : Json) -> @jsonrpc.Message {
  @jsonrpc.new_call(@jsonrpc.ID::number(id.to_int64()), method_name, params)
}

///|
fn open_params(uri : String, text : String) -> Json {
  {
    "textDocument": {
      "uri": uri,
      "languageId": "lane",
      "version": 1,
      "text": text,
    },
  }
}

///|
fn change_params(uri : String, text : String) -> Json {
  {
    "textDocument": { "uri": uri, "version": 2 },
    "contentChanges": [{ "text": text }],
  }
}

///|
fn position_params(uri : String, line : Int, character : Int) -> Json {
  {
    "textDocument": { "uri": uri },
    "position": { "line": line, "character": character },
  }
}

///|
fn range_params(
  uri : String,
  start_line : Int,
  start_character : Int,
  end_line : Int,
  end_character : Int,
) -> Json {
  {
    "textDocument": { "uri": uri },
    "range": {
      "start": { "line": start_line, "character": start_character },
      "end": { "line": end_line, "character": end_character },
    },
  }
}

///|
fn diagnostic_publication_uris(result : HandlerResult) -> String {
  let uris = []
  for message in result.outgoing {
    match message.to_json() {
      {
        "method": String("textDocument/publishDiagnostics"),
        "params": { "uri": String(uri), .. },
        ..
      } => uris.push(uri)
      _ => ()
    }
  }
  uris.join(",")
}

///|
async test "initialize returns full document sync capability" {
  let state = ServerState::ServerState()
  let result = state.handle_message(request(1, "initialize", null))
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": {
        "capabilities": {
          "textDocumentSync": 1,
          "definitionProvider": true,
          "hoverProvider": true,
          "inlayHintProvider": true,
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
async test "hover reports invalid params as an LSP request shape error" {
  let state = ServerState::ServerState()
  let result = state.handle_message(request(7, "textDocument/hover", {}))
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 7,
      "error": {
        "code": -32602,
        "message": "invalid textDocument/hover params: expected `textDocument.uri`, `position.line`, and `position.character`; this is an LSP client request shape error, not a Lane source error",
      },
    },
  ])
}

///|
test "inlay hint validation reports duplicate positions as compiler bugs" {
  let location : @compile.AnalysisLocation = {
    source_id: "file:///Main.lane",
    span: @basic.SourceSpan::dummy(),
  }
  let hints : Array[@compile.InlayHintEntry] = [
    { location, kind: TypeHint, label: ": Int" },
    { location, kind: ParameterHint, label: "value=" },
  ]
  match validate_inlay_hint_positions(hints) {
    Err(message) =>
      inspect(
        message,
        content="internal Lane compiler bug: multiple inlay hints were produced at file:///Main.lane:1:1 (`: Int` and `value=`)",
      )
    Ok(_) => abort("expected duplicate inlay hint validation failure")
  }
}

///|
async test "inlay hint returns inferred binder type hints" {
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
            #|pub fn answer(seed : Int) -> Int {
            #|  let local = seed
            #|  match local {
            #|    value => value
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
      "textDocument/inlayHint",
      range_params("file:///Main.lane", 0, 0, 8, 0),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 3, "character": 11 },
          "label": ": Int",
          "kind": 1,
        },
        {
          "position": { "line": 5, "character": 9 },
          "label": ": Int",
          "kind": 1,
        },
      ],
    },
  ])
}

///|
async test "inlay hint returns parameter name hints at argument starts" {
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
            #|pub fn choose(left : Int, right : Int) -> Int {
            #|  left
            #|}
            #|
            #|pub fn answer(seed : Int) -> Int {
            #|  let local = choose(seed, 1)
            #|  local
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/inlayHint",
      range_params("file:///Main.lane", 0, 0, 10, 0),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 7, "character": 11 },
          "label": ": Int",
          "kind": 1,
        },
        {
          "position": { "line": 7, "character": 21 },
          "label": "left=",
          "kind": 2,
        },
        {
          "position": { "line": 7, "character": 27 },
          "label": "right=",
          "kind": 2,
        },
      ],
    },
  ])
}

///|
async test "inlay hint returns implicit auto offer hints at call end" {
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
            #|pub struct Add[A] {
            #|  add : (A, A) -> A
            #|}
            #|
            #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
            #|  op.add(a, b)
            #|}
            #|
            #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
            #|
            #|pub fn answer(seed : Int) -> Int {
            #|  let local = seed + 1
            #|  local
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/inlayHint",
      range_params("file:///Main.lane", 0, 0, 16, 0),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 13, "character": 11 },
          "label": ": Int",
          "kind": 1,
        },
        {
          "position": { "line": 13, "character": 22 },
          "label": ", op=int_add_ops",
          "kind": 2,
        },
      ],
    },
  ])
}

///|
async test "semantic tokens full is not provided by lane lsp" {
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
    request(2, "textDocument/semanticTokens/full", {
      "textDocument": { "uri": "file:///Main.lane" },
    }),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "error": {
        "code": -32601,
        "message": "method not found: textDocument/semanticTokens/full; lane lsp supports initialize, shutdown, exit, textDocument/didOpen, textDocument/didChange, textDocument/didClose, textDocument/definition, textDocument/hover, and textDocument/inlayHint",
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
            "message": "cannot find type `Missing`",
            "code": "E2000",
            "relatedInformation": [
              {
                "location": {
                  "uri": "file:///bad.lane",
                  "range": {
                    "start": { "line": 1, "character": 13 },
                    "end": { "line": 1, "character": 20 },
                  },
                },
                "message": "no type named `Missing` is visible here",
              },
              {
                "location": {
                  "uri": "file:///bad.lane",
                  "range": {
                    "start": { "line": 1, "character": 13 },
                    "end": { "line": 1, "character": 20 },
                  },
                },
                "message": "note: Lane resolves type names from the current module and explicitly imported public types",
              },
              {
                "location": {
                  "uri": "file:///bad.lane",
                  "range": {
                    "start": { "line": 1, "character": 13 },
                    "end": { "line": 1, "character": 20 },
                  },
                },
                "message": "help: declare `Missing`, import the module that exports it, or qualify the type as `Module.Missing`",
              },
            ],
          },
        ],
      },
    },
  ])
}

///|
async test "didOpen checks against workspace library sources" {
  let workspace = ".tmp-lsp-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
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
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://\{main_path}",
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
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp-workspace/Lib.lane",
        "diagnostics": [],
      },
    },
  ])
}

///|
async test "didOpen publishes workspace diagnostics to their source URI" {
  let workspace = ".tmp-lsp-diagnostic-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub let value : Missing = 42
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
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://\{main_path}",
        (
          #|module Main
          #|
          #|import Lib.*
          #|
          #|pub let answer : Int = 1
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
        "uri": "file://.tmp-lsp-diagnostic-workspace/Main.lane",
        "diagnostics": [],
      },
    },
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp-diagnostic-workspace/Lib.lane",
        "diagnostics": [
          {
            "range": {
              "start": { "line": 2, "character": 16 },
              "end": { "line": 2, "character": 23 },
            },
            "severity": 1,
            "source": "lane",
            "message": "cannot find type `Missing`",
            "code": "E2000",
            "relatedInformation": [
              {
                "location": {
                  "uri": "file://.tmp-lsp-diagnostic-workspace/Lib.lane",
                  "range": {
                    "start": { "line": 2, "character": 16 },
                    "end": { "line": 2, "character": 23 },
                  },
                },
                "message": "no type named `Missing` is visible here",
              },
              {
                "location": {
                  "uri": "file://.tmp-lsp-diagnostic-workspace/Lib.lane",
                  "range": {
                    "start": { "line": 2, "character": 16 },
                    "end": { "line": 2, "character": 23 },
                  },
                },
                "message": "note: Lane resolves type names from the current module and explicitly imported public types",
              },
              {
                "location": {
                  "uri": "file://.tmp-lsp-diagnostic-workspace/Lib.lane",
                  "range": {
                    "start": { "line": 2, "character": 16 },
                    "end": { "line": 2, "character": 23 },
                  },
                },
                "message": "help: declare `Missing`, import the module that exports it, or qualify the type as `Module.Missing`",
              },
            ],
          },
        ],
      },
    },
  ])
}

///|
async test "workspace diagnostics are independent of triggering document" {
  let workspace = ".tmp-lsp-stable-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub let value : Missing = 42
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    main_path,
    (
      #|module Main
      #|
      #|import Lib.*
      #|
      #|pub let answer : Int = value
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  ignore(
    state.handle_message(
      request(
        2,
        "textDocument/didOpen",
        open_params("file://\{main_path}", @fs.read_file(main_path).text()),
      ),
    ),
  )
  ignore(
    state.handle_message(
      request(
        3,
        "textDocument/didOpen",
        open_params("file://\{lib_path}", @fs.read_file(lib_path).text()),
      ),
    ),
  )
  let main_result = state.handle_message(
    request(
      4,
      "textDocument/didChange",
      change_params("file://\{main_path}", @fs.read_file(main_path).text()),
    ),
  )
  let lib_result = state.handle_message(
    request(
      5,
      "textDocument/didChange",
      change_params("file://\{lib_path}", @fs.read_file(lib_path).text()),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  inspect(
    diagnostic_publication_uris(main_result),
    content="file://.tmp-lsp-stable-workspace/Main.lane,file://.tmp-lsp-stable-workspace/Lib.lane",
  )
  inspect(
    diagnostic_publication_uris(lib_result),
    content="file://.tmp-lsp-stable-workspace/Lib.lane",
  )
}

///|
async test "workspace diagnostics ignore modules outside import closure" {
  let workspace = ".tmp-lsp-import-closure-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  let unrelated_path = "\{workspace}/Unrelated.lane"
  @fs.remove(main_path) catch {
    _ => ()
  }
  @fs.remove(lib_path) catch {
    _ => ()
  }
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
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
    unrelated_path,
    (
      #|module Unrelated
      #|
      #|pub let broken : =
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    main_path,
    (
      #|module Main
      #|
      #|import Lib.*
      #|
      #|pub let answer : Int = value
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params("file://\{main_path}", @fs.read_file(main_path).text()),
    ),
  )
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  inspect(
    diagnostic_publication_uris(result),
    content="file://.tmp-lsp-import-closure-workspace/Main.lane,file://.tmp-lsp-import-closure-workspace/Lib.lane",
  )
}

///|
async test "workspace diagnostics keep reachable parse errors" {
  let workspace = ".tmp-lsp-reachable-parse-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  let unrelated_path = "\{workspace}/Unrelated.lane"
  @fs.remove(main_path) catch {
    _ => ()
  }
  @fs.remove(lib_path) catch {
    _ => ()
  }
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub let broken : =
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    unrelated_path,
    (
      #|module Unrelated
      #|
      #|pub let also_broken : =
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    main_path,
    (
      #|module Main
      #|
      #|import Lib.*
      #|
      #|pub let answer : Int = value
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params("file://\{main_path}", @fs.read_file(main_path).text()),
    ),
  )
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  inspect(
    diagnostic_publication_uris(result),
    content="file://.tmp-lsp-reachable-parse-workspace/Main.lane,file://.tmp-lsp-reachable-parse-workspace/Lib.lane",
  )
}

///|
async test "workspace analysis selects root import closure without json rpc" {
  let workspace = ".tmp-lsp-analysis-input-workspace"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  let unrelated_path = "\{workspace}/Unrelated.lane"
  @fs.remove(main_path) catch {
    _ => ()
  }
  @fs.remove(lib_path) catch {
    _ => ()
  }
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
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
    unrelated_path,
    (
      #|module Unrelated
      #|
      #|pub let broken : =
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let main_text =
    #|module Main
    #|
    #|import Lib.*
    #|
    #|pub let answer : Int = value
  let document = { uri: "file://\{main_path}", text: main_text }
  let analysis = LspWorkspaceAnalysis(Some(workspace), {})
  let sources = analysis.analysis_sources(document)
  let inputs = match
    @compile.import_reachable_source_inputs(sources.root, sources.libraries) {
    Ok(inputs) => inputs
    Err(_) => abort("expected import-reachable inputs")
  }
  @fs.remove(unrelated_path) catch {
    _ => ()
  }
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  inspect(
    inputs.map(fn(input) { input.source_id }).join(","),
    content="file://.tmp-lsp-analysis-input-workspace/Main.lane,file://.tmp-lsp-analysis-input-workspace/Lib.lane",
  )
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
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
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
      request(1, "initialize", { "rootUri": "file://.tmp-lsp%20workspace" }),
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
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp%20workspace/Lib.lane",
        "diagnostics": [],
      },
    },
  ])
}

///|
#cfg(not(platform="windows"))
async test "workspace libraries exclude current document by realpath" {
  let workspace = ".tmp-lsp-realpath-workspace"
  let main_path = "\{workspace}/Main.lane"
  let main_alias_path = "\{workspace}/MainAlias.lane"
  cleanup_workspace_fixture(workspace, main_path, main_alias_path)
  @fs.mkdir(workspace)
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
  @fs.symlink(main_alias_path, target="Main.lane")
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://\{main_alias_path}",
        (
          #|module Main
          #|
          #|pub let answer : Int = 42
          #|
        ),
      ),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, main_alias_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp-realpath-workspace/MainAlias.lane",
        "diagnostics": [],
      },
    },
  ])
}

///|
async test "definition returns encoded URI for discovered library source" {
  let workspace = ".tmp-lsp encoded-中"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib File 中.lane"
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
      request(1, "initialize", { "rootUri": path_to_file_uri(workspace) }),
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
async test "hover returns effect and operation declaration detail" {
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
            #|effect Prompt {
            #|  choose[A](A, A) -> A
            #|}
          ),
        ),
      ),
    ),
  )
  let effect_result = state.handle_message(
    request(2, "textDocument/hover", position_params("file:///Main.lane", 2, 8)),
  )
  json_inspect(effect_result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "contents": {
          "kind": "markdown",
          "value": "```lane\neffect Prompt\n```",
        },
        "range": {
          "start": { "line": 2, "character": 7 },
          "end": { "line": 2, "character": 13 },
        },
      },
    },
  ])
  let operation_result = state.handle_message(
    request(3, "textDocument/hover", position_params("file:///Main.lane", 3, 4)),
  )
  json_inspect(
    operation_result.outgoing.map(fn(message) { message.to_json() }),
    content=[
      {
        "jsonrpc": "2.0",
        "id": 3,
        "result": {
          "contents": {
            "kind": "markdown",
            "value": "```lane\noperation Prompt::choose[A : Type](A, A) -> A\n```",
          },
          "range": {
            "start": { "line": 3, "character": 2 },
            "end": { "line": 3, "character": 8 },
          },
        },
      },
    ],
  )
}

///|
async test "definition resolves operation call references" {
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
            #|effect Prompt {
            #|  choose[A](A, A) -> A
            #|}
            #|
            #|fn pick() -> Int ! Prompt {
            #|  Prompt::choose![Int](1, 2)
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/definition",
      position_params("file:///Main.lane", 7, 12),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "uri": "file:///Main.lane",
        "range": {
          "start": { "line": 3, "character": 2 },
          "end": { "line": 3, "character": 8 },
        },
      },
    },
  ])
}

///|
async test "definition resolves handler operation arm references" {
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
            #|effect Prompt {
            #|  choose[A](A, A) -> A
            #|}
            #|
            #|fn handled() -> Int {
            #|  handle Prompt::choose![Int](1, 2) with {
            #|    Prompt::choose[A](left, right, resume) => resume(left)
            #|  } final value { value }
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/definition",
      position_params("file:///Main.lane", 8, 14),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "uri": "file:///Main.lane",
        "range": {
          "start": { "line": 3, "character": 2 },
          "end": { "line": 3, "character": 8 },
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
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
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
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  ignore(
    state.handle_message(
      request(
        2,
        "textDocument/didOpen",
        open_params(
          "file://\{main_path}",
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
      position_params("file://\{main_path}", 4, 23),
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
