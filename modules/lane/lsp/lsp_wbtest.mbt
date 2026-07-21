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
fn completion_params(
  uri : String,
  line : Int,
  character : Int,
  trigger_character : String?,
) -> Json {
  let params : Map[String, Json] = {
    "textDocument": { "uri": uri },
    "position": { "line": line, "character": character },
  }
  if trigger_character is Some(character) {
    params["context"] = { "triggerCharacter": character }
  }
  params.to_json()
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
          "completionProvider": {
            "triggerCharacters": [".", ":"],
            "resolveProvider": false,
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
async test "hover reports invalid params as an LSP request shape error" {
  let state = ServerState::ServerState()
  let result = state.handle_message(
    request(7, "textDocument/hover", Json::empty_object()),
  )
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
  let location : @analysis.AnalysisLocation = {
    source_id: "file:///Main.lane",
    span: @basic.SourceSpan::dummy(),
  }
  let hints : Array[@analysis.InlayHintEntry] = [
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
async test "analysis requests traverse explicit generic application" {
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
            #|pub struct Box {
            #|  value : Int
            #|}
            #|
            #|pub fn[A] id(value : A) -> A {
            #|  value
            #|}
            #|
            #|pub let answer : Box = id[Box](Box::{ value: 1 })
          ),
        ),
      ),
    ),
  )
  let callee_definition = state.handle_message(
    request(
      2,
      "textDocument/definition",
      position_params("file:///Main.lane", 10, 23),
    ),
  )
  json_inspect(
    callee_definition.outgoing.map(fn(message) { message.to_json() }),
    content=[
      {
        "jsonrpc": "2.0",
        "id": 2,
        "result": {
          "uri": "file:///Main.lane",
          "range": {
            "start": { "line": 6, "character": 10 },
            "end": { "line": 6, "character": 12 },
          },
        },
      },
    ],
  )
  let argument_definition = state.handle_message(
    request(
      3,
      "textDocument/definition",
      position_params("file:///Main.lane", 10, 26),
    ),
  )
  json_inspect(
    argument_definition.outgoing.map(fn(message) { message.to_json() }),
    content=[
      {
        "jsonrpc": "2.0",
        "id": 3,
        "result": {
          "uri": "file:///Main.lane",
          "range": {
            "start": { "line": 2, "character": 11 },
            "end": { "line": 2, "character": 14 },
          },
        },
      },
    ],
  )
  let hover = state.handle_message(
    request(
      4,
      "textDocument/hover",
      position_params("file:///Main.lane", 10, 23),
    ),
  )
  json_inspect(hover.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 4,
      "result": {
        "contents": {
          "kind": "markdown",
          "value": "```lane\nid : forall [A : Type]. (A) -> A\n```",
        },
        "range": {
          "start": { "line": 10, "character": 23 },
          "end": { "line": 10, "character": 25 },
        },
      },
    },
  ])
  let inlay = state.handle_message(
    request(
      5,
      "textDocument/inlayHint",
      range_params("file:///Main.lane", 0, 0, 12, 0),
    ),
  )
  json_inspect(inlay.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 5,
      "result": [
        {
          "position": { "line": 10, "character": 31 },
          "label": "value=",
          "kind": 2,
        },
      ],
    },
  ])
}

///|
async test "inlay hint anchors field arguments before the full argument" {
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
            #|pub struct Box {
            #|  field : Int
            #|}
            #|
            #|pub fn take(arg : Int) -> Int {
            #|  arg
            #|}
            #|
            #|pub fn answer(value : Box) -> Int {
            #|  let local = take(value.field)
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
      range_params("file:///Main.lane", 0, 0, 14, 0),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 11, "character": 11 },
          "label": ": Int",
          "kind": 1,
        },
        {
          "position": { "line": 11, "character": 19 },
          "label": "arg=",
          "kind": 2,
        },
      ],
    },
  ])
}

///|
async test "inlay hint anchors implicit auto offers by call syntax" {
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
            #|offer int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
            #|
            #|pub fn answer(seed : Int) -> Int {
            #|  let local = seed + 1
            #|  let explicit = op_add(seed, 1)
            #|  explicit
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
      range_params("file:///Main.lane", 0, 0, 17, 0),
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
        {
          "position": { "line": 14, "character": 14 },
          "label": ": Int",
          "kind": 1,
        },
        {
          "position": { "line": 14, "character": 24 },
          "label": "a=",
          "kind": 2,
        },
        {
          "position": { "line": 14, "character": 30 },
          "label": "b=",
          "kind": 2,
        },
        {
          "position": { "line": 14, "character": 31 },
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
        "message": "method not found: textDocument/semanticTokens/full; lane lsp supports initialize, shutdown, exit, textDocument/didOpen, textDocument/didChange, textDocument/didClose, textDocument/definition, textDocument/hover, textDocument/inlayHint, and textDocument/completion",
      },
    },
  ])
}

///|
async test "completion returns a completion list for module trigger" {
  let workspace = ".tmp-lsp-completion"
  let main_path = "\{workspace}/Main.lane"
  let lib_path = "\{workspace}/Lib.lane"
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  @fs.mkdir(workspace)
  @fs.write_file(
    lib_path,
    (
      #|module Lib
      #|
      #|pub fn answer() -> Int {
      #|  42
      #|}
    ),
    create_mode=CreateOrTruncate,
  )
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(0, "initialize", { "rootUri": "file://\{workspace}" }),
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
            #|import Lib
            #|
            #|pub fn use() -> Int {
            #|  Lib.answer()
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      3,
      "textDocument/completion",
      completion_params("file://\{main_path}", 5, 6, Some(".")),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 3,
      "result": {
        "isIncomplete": false,
        "items": [
          {
            "label": "answer",
            "kind": 3,
            "detail": "answer : () -> Int",
            "sortText": "20:answer",
            "textEdit": {
              "range": {
                "start": { "line": 5, "character": 6 },
                "end": { "line": 5, "character": 6 },
              },
              "newText": "answer",
            },
          },
        ],
      },
    },
  ])
}

///|
async test "completion returns lexical entries for manual requests" {
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
            #|  ans
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/completion",
      completion_params("file:///Main.lane", 3, 5, None),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "isIncomplete": false,
        "items": [
          {
            "label": "answer",
            "kind": 3,
            "detail": "fn answer",
            "sortText": "20:answer",
            "textEdit": {
              "range": {
                "start": { "line": 3, "character": 2 },
                "end": { "line": 3, "character": 5 },
              },
              "newText": "answer",
            },
          },
        ],
      },
    },
  ])
}

///|
async test "semantic snapshot is reused until workspace sources change" {
  let uri = "file:///Main.lane"
  let source =
    #|module Main
    #|
    #|pub fn answer(seed : Int) -> Int {
    #|  ans
    #|}
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "textDocument/didOpen", open_params(uri, source)),
    ),
  )
  let revisions = []
  ignore(
    state.handle_message(
      request(2, "textDocument/completion", completion_params(uri, 3, 5, None)),
    ),
  )
  revisions.push(state.semantic_workspace.revision())
  ignore(
    state.handle_message(
      request(3, "textDocument/completion", completion_params(uri, 3, 5, None)),
    ),
  )
  revisions.push(state.semantic_workspace.revision())
  ignore(
    state.handle_message(
      request(4, "textDocument/didChange", change_params(uri, source + "\n")),
    ),
  )
  revisions.push(state.semantic_workspace.revision())
  ignore(
    state.handle_message(
      request(5, "textDocument/completion", completion_params(uri, 3, 5, None)),
    ),
  )
  revisions.push(state.semantic_workspace.revision())
  ignore(
    state.handle_message(
      request(6, "textDocument/didClose", { "textDocument": { "uri": uri } }),
    ),
  )
  revisions.push(state.semantic_workspace.revision())
  debug_inspect(revisions, content="[1, 1, 2, 2, 3]")
}

///|
async test "completion routes colon triggers to owner members" {
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
            #|enum Option[A] {
            #|  none()
            #|  some(A)
            #|}
            #|
            #|pub fn use() -> Option[Int] {
            #|  Option::some(1)
            #|}
          ),
        ),
      ),
    ),
  )
  let result = state.handle_message(
    request(
      2,
      "textDocument/completion",
      completion_params("file:///Main.lane", 8, 10, Some(":")),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "isIncomplete": false,
        "items": [
          {
            "label": "none",
            "kind": 20,
            "detail": "variant Option::none",
            "sortText": "20:none",
            "textEdit": {
              "range": {
                "start": { "line": 8, "character": 10 },
                "end": { "line": 8, "character": 10 },
              },
              "newText": "none()",
            },
          },
          {
            "label": "some",
            "kind": 20,
            "detail": "variant Option::some",
            "sortText": "20:some",
            "textEdit": {
              "range": {
                "start": { "line": 8, "character": 10 },
                "end": { "line": 8, "character": 10 },
              },
              "newText": "some",
            },
          },
        ],
      },
    },
  ])
}

///|
async test "completion reports invalid params as an LSP request shape error" {
  let state = ServerState::ServerState()
  let result = state.handle_message(
    request(4, "textDocument/completion", Json::empty_object()),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 4,
      "error": {
        "code": -32602,
        "message": "invalid textDocument/completion params: expected `textDocument.uri`, `position.line`, and `position.character`; this is an LSP client request shape error, not a Lane source error",
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
            "severity": 1,
            "message": "cannot find type `Missing`\nno type named `Missing` is visible here",
            "source": "lane",
            "code": "E2000",
            "range": {
              "start": { "line": 1, "character": 13 },
              "end": { "line": 1, "character": 20 },
            },
            "data": {
              "notes": [
                "Lane resolves type names from the current module and explicitly imported public types",
              ],
              "helps": [
                "declare `Missing`, import the module that exports it, or qualify the type as `Module.Missing`",
              ],
            },
          },
        ],
      },
    },
  ])
}

///|
test "lsp diagnostics convert text offsets before transport" {
  let input : @module_frontend.SourceInput = {
    source_id: "file:///unicode.lane",
    text: (
      #|module Main
      #|// 中文 before import
      #|import Builtins.{
      #|  read_int
      #|}
      #|pub let answer : Int = 1
    ),
  }
  let result = @compile.check_source_inputs(input, [])
  let sources = compiler_diagnostic_sources_from_inputs([input])
  json_inspect(
    result.diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
    content=[
      {
        "severity": 1,
        "message": "missing imported module `Builtins`\nno explicit input provides this module",
        "source": "lane",
        "code": "E4002",
        "range": {
          "start": { "line": 2, "character": 7 },
          "end": { "line": 2, "character": 15 },
        },
        "data": {
          "notes": [
            "Lane only compiles explicitly provided source files and interface artifacts",
          ],
          "helps": [
            "pass an input whose declared module is `Builtins`, or change the import to one of the listed modules",
          ],
          "facts": [
            {
              "name": "considered source module",
              "value": "`Main`",
              "hasSpan": false,
            },
          ],
          "suggestions": [
            {
              "message": "check the imported module name against the listed explicit inputs",
              "applicability": "maybe-incorrect",
            },
          ],
        },
      },
    ],
  )
}

///|
test "lsp generic operator conflict keeps diagnostic message concise" {
  let input : @module_frontend.SourceInput = {
    source_id: "file:///generic-operator.lane",
    text: (
      #|module Main
      #|struct Add[T] {
      #|  add : (T, T) -> T
      #|}
      #|fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
      #|  op.add(a, b)
      #|}
      #|offer int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
      #|pub let x : Int = 1 + true
    ),
  }
  let result = @compile.check_source_inputs(input, [])
  let diagnostics = result.diagnostics.filter(fn(diagnostic) {
    diagnostic.code == Some("E3006")
  })
  let sources = compiler_diagnostic_sources_from_inputs([input])
  json_inspect(
    diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
    content=[
      {
        "severity": 1,
        "message": "type mismatch\nexpected `Int`, found `Bool`",
        "source": "lane",
        "code": "E3006",
        "range": {
          "start": { "line": 8, "character": 22 },
          "end": { "line": 8, "character": 26 },
        },
        "data": {
          "notes": [
            "Lane does not insert implicit conversions between different types",
          ],
          "helps": [
            "make this argument agree with the type inferred earlier, or pass explicit generic arguments",
          ],
        },
      },
    ],
  )
}

///|
test "lsp diagnostics transport unused local warnings" {
  let input : @module_frontend.SourceInput = {
    source_id: "file:///unused.lane",
    text: (
      #|module Main
      #|pub fn answer() -> Int {
      #|  let unused = 1
      #|  0
      #|}
    ),
  }
  let result = @compile.check_source_inputs(input, [])
  let sources = compiler_diagnostic_sources_from_inputs([input])
  json_inspect(
    result.diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
    content=[
      {
        "severity": 2,
        "message": "unused local value binding\n`unused` is never used",
        "source": "lane",
        "code": "W2001",
        "range": {
          "start": { "line": 2, "character": 6 },
          "end": { "line": 2, "character": 12 },
        },
        "data": { "helps": ["prefix the name with `_` if this is intentional"] },
      },
    ],
  )
}

///|
test "lsp duplicate top-level value diagnostic points at names" {
  let input : @module_frontend.SourceInput = {
    source_id: "file:///duplicate.lane",
    text: (
      #|module Main
      #|let answer : Int = 1
      #|let answer : Int = 2
    ),
  }
  let result = @compile.check_source_inputs(input, [])
  let sources = compiler_diagnostic_sources_from_inputs([input])
  json_inspect(
    result.diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
    content=[
      {
        "severity": 1,
        "message": "conflicting top-level value `answer`\n`answer` conflicts with an existing value named `answer`",
        "source": "lane",
        "code": "E2005",
        "range": {
          "start": { "line": 2, "character": 4 },
          "end": { "line": 2, "character": 10 },
        },
        "data": {
          "notes": ["a Lane module has one top-level value namespace"],
          "helps": [
            "rename one of the declarations or remove the duplicate import",
          ],
        },
        "relatedInformation": [
          {
            "location": {
              "uri": "file:///duplicate.lane",
              "range": {
                "start": { "line": 1, "character": 4 },
                "end": { "line": 1, "character": 10 },
              },
            },
            "message": "previous definition of `answer` is here",
          },
        ],
      },
    ],
  )
}

///|
test "lsp duplicate imported top-level value diagnostic points across sources" {
  let main : @module_frontend.SourceInput = {
    source_id: "file:///Main.lane",
    text: (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = 2
    ),
  }
  let lib : @module_frontend.SourceInput = {
    source_id: "file:///Lib.lane",
    text: (
      #|module Lib
      #|pub let answer : Int = 1
    ),
  }
  let result = @compile.check_source_inputs(main, [lib])
  let sources = compiler_diagnostic_sources_from_inputs([main, lib])
  json_inspect(
    result.diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
    content=[
      {
        "severity": 1,
        "message": "conflicting top-level value `answer`\n`answer` conflicts with an existing value named `answer`",
        "source": "lane",
        "code": "E2005",
        "range": {
          "start": { "line": 2, "character": 8 },
          "end": { "line": 2, "character": 14 },
        },
        "data": {
          "notes": ["a Lane module has one top-level value namespace"],
          "helps": [
            "rename one of the declarations or remove the duplicate import",
          ],
        },
        "relatedInformation": [
          {
            "location": {
              "uri": "file:///Lib.lane",
              "range": {
                "start": { "line": 1, "character": 8 },
                "end": { "line": 1, "character": 14 },
              },
            },
            "message": "previous definition of `answer` is here",
          },
        ],
      },
    ],
  )
}

///|
test "lsp diagnostic conversion keeps required range for unmapped source" {
  let diagnostic : @compiler_diag.CompilerDiagnostic = {
    source_id: Some("file:///missing.lane"),
    message: "diagnostic source is not open",
    span: None,
    severity: Error,
    code: Some("E9999"),
    labels: [
      {
        span: @compiler_diag.compiler_local_span(@basic.SourceSpan::dummy()),
        message: "original label could not be mapped",
        style: Primary,
      },
    ],
    notes: [],
    helps: [],
    facts: [],
    suggestions: [],
  }
  json_inspect(
    compile_diagnostic_json(diagnostic, CompilerDiagnosticSources()),
    content={
      "severity": 1,
      "message": "diagnostic source is not open",
      "source": "lane",
      "code": "E9999",
      "range": {
        "start": { "line": 0, "character": 0 },
        "end": { "line": 0, "character": 0 },
      },
      "data": { "notes": ["original label could not be mapped"] },
    },
  )
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
            "severity": 1,
            "message": "cannot find type `Missing`\nno type named `Missing` is visible here",
            "source": "lane",
            "code": "E2000",
            "range": {
              "start": { "line": 2, "character": 16 },
              "end": { "line": 2, "character": 23 },
            },
            "data": {
              "notes": [
                "Lane resolves type names from the current module and explicitly imported public types",
              ],
              "helps": [
                "declare `Missing`, import the module that exports it, or qualify the type as `Module.Missing`",
              ],
            },
          },
        ],
      },
    },
  ])
}

///|
async test "workspace edits publish diagnostics only for affected sources" {
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
      change_params(
        "file://\{main_path}",
        @fs.read_file(main_path).text() + "\n",
      ),
    ),
  )
  let lib_result = state.handle_message(
    request(
      5,
      "textDocument/didChange",
      change_params("file://\{lib_path}", @fs.read_file(lib_path).text() + "\n"),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, lib_path)
  inspect(
    diagnostic_publication_uris(main_result),
    content="file://.tmp-lsp-stable-workspace/Main.lane",
  )
  inspect(
    diagnostic_publication_uris(lib_result),
    content="file://.tmp-lsp-stable-workspace/Lib.lane",
  )
}

///|
async test "workspace diagnostics include disconnected modules" {
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
    content="file://.tmp-lsp-import-closure-workspace/Main.lane,file://.tmp-lsp-import-closure-workspace/Lib.lane,file://.tmp-lsp-import-closure-workspace/Unrelated.lane",
  )
}

///|
async test "workspace diagnostics keep parse errors from every module" {
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
    content="file://.tmp-lsp-reachable-parse-workspace/Main.lane,file://.tmp-lsp-reachable-parse-workspace/Lib.lane,file://.tmp-lsp-reachable-parse-workspace/Unrelated.lane",
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
  let analysis = LspWorkspaceAnalysis(Some(workspace), Map([]))
  let sources = analysis.analysis_sources(document)
  let inputs = match
    @module_frontend.import_reachable_source_inputs(
      sources.root,
      sources.libraries,
    ) {
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
async test "hover returns checked handler resume type" {
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
            #|pub effect Console {
            #|  read() -> Int
            #|}
            #|pub effect State {
            #|  get() -> Int
            #|}
            #|pub fn answer() -> Int ! State {
            #|  handle Console::read!() with {
            #|    Console::read(resume) => resume(0)
            #|  } final value {
            #|    let _state : Int = State::get!()
            #|    value
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
      "textDocument/hover",
      position_params("file:///Main.lane", 10, 19),
    ),
  )
  json_inspect(result.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "id": 2,
      "result": {
        "contents": {
          "kind": "markdown",
          "value": "```lane\nresume : (Int) -> Int ! State\n```",
        },
        "range": {
          "start": { "line": 10, "character": 18 },
          "end": { "line": 10, "character": 24 },
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
