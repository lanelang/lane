///|
async fn send_lsp_message(output : &@io.Writer, message : Json) -> Unit {
  let body = message.stringify()
  output.write("Content-Length: \{@utf8.encode(body).length()}\r\n\r\n")
  output.write(body)
}

///|
async fn receive_lsp_message(input : &@io.Reader) -> Json {
  guard input.read_until("\n") is Some(header) else {
    abort("expected a framed LSP message")
  }
  guard header.trim().to_owned().find(":") is Some(separator) else {
    abort("expected a Content-Length header")
  }
  guard header
    .unsafe_substring(start=0, end=separator)
    .trim()
    .to_owned()
    .to_lower() ==
    "content-length" else {
    abort("expected a Content-Length header")
  }
  let length_text = header
    .unsafe_substring(start=separator + 1, end=header.length())
    .trim()
    .to_owned()
  let length = @string.parse_int(length_text, base=10)
  guard input.read_until("\n") is Some(separator_line) &&
    separator_line.trim().to_owned() == "" else {
    abort("expected the blank line after Content-Length")
  }
  @json.parse(@utf8.decode(input.read_exactly(length)))
}

///|
fn lsp_call(id : Int, method_name : String, params : Json) -> Json {
  { "jsonrpc": "2.0", "id": id, "method": method_name, "params": params }
}

///|
fn lsp_notification(method_name : String, params : Json) -> Json {
  { "jsonrpc": "2.0", "method": method_name, "params": params }
}

///|
fn lsp_document(uri : String, text : String) -> Json {
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
fn lsp_document_change(uri : String, text : String) -> Json {
  {
    "textDocument": { "uri": uri, "version": 2 },
    "contentChanges": [{ "text": text }],
  }
}

///|
fn lsp_position(uri : String, line : Int, character : Int) -> Json {
  {
    "textDocument": { "uri": uri },
    "position": { "line": line, "character": character },
  }
}

///|
fn lsp_range(uri : String, end_line : Int, end_character : Int) -> Json {
  {
    "textDocument": { "uri": uri },
    "range": {
      "start": { "line": 0, "character": 0 },
      "end": { "line": end_line, "character": end_character },
    },
  }
}

///|
async test "public server runs a complete editing session" {
  let (server_input, client_input) = @io.pipe()
  let (client_output, server_output) = @io.pipe()
  let uri = "file:///Main.lane"
  let initial_source =
    #|module Main
    #|
    #|pub let value : I64 = 42
    #|
    #|pub let answer : I64 = value
  let changed_source =
    #|module Main
    #|
    #|pub let value : Bool = true
    #|
    #|pub let answer : Bool = value
  @async.with_task_group(group => {
    let server = group.spawn(() => {
      let termination = run_server(server_input, server_output)
      server_output.close()
      termination
    })
    let observed = []
    send_lsp_message(client_input, lsp_call(1, "initialize", null))
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("initialized", {}))
    send_lsp_message(
      client_input,
      lsp_notification(
        "textDocument/didOpen",
        lsp_document(uri, initial_source),
      ),
    )
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_call(2, "textDocument/completion", lsp_position(uri, 4, 29)),
    )
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_notification(
        "textDocument/didChange",
        lsp_document_change(uri, changed_source),
      ),
    )
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_call(3, "textDocument/hover", lsp_position(uri, 4, 25)),
    )
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_call(4, "shutdown", null))
    observed.push(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("exit", null))
    client_input.close()
    assert_true(client_output.read_until("\n") is None)
    assert_eq(server.wait(), GracefulExit)
    json_inspect(observed, content=[
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
      {
        "jsonrpc": "2.0",
        "method": "textDocument/publishDiagnostics",
        "params": { "uri": "file:///Main.lane", "diagnostics": [] },
      },
      {
        "jsonrpc": "2.0",
        "id": 2,
        "result": {
          "isIncomplete": false,
          "items": [
            {
              "label": "value",
              "kind": 6,
              "detail": "value : I64",
              "sortText": "20:value",
              "textEdit": {
                "range": {
                  "start": { "line": 4, "character": 23 },
                  "end": { "line": 4, "character": 28 },
                },
                "newText": "value",
              },
            },
          ],
        },
      },
      {
        "jsonrpc": "2.0",
        "method": "textDocument/publishDiagnostics",
        "params": { "uri": "file:///Main.lane", "diagnostics": [] },
      },
      {
        "jsonrpc": "2.0",
        "id": 3,
        "result": {
          "contents": {
            "kind": "markdown",
            "value": "```lane\nvalue : Bool\n```",
          },
          "range": {
            "start": { "line": 4, "character": 24 },
            "end": { "line": 4, "character": 29 },
          },
        },
      },
      { "jsonrpc": "2.0", "id": 4, "result": null },
    ])
  })
}

///|
async test "public server returns imported argument inlays" {
  let (server_input, client_input) = @io.pipe()
  let (client_output, server_output) = @io.pipe()
  let provider_uri = "file:///Provider.lane"
  let consumer_uri = "file:///Main.lane"
  let provider =
    #|module Provider
    #|
    #|pub struct Witness {
    #|  value : I64
    #|}
    #|
    #|pub offer fn choose(auto witness : Witness) -> I64 {
    #|  witness.value
    #|}
    #|
    #|pub fn concat(left : String, right : String) -> String {
    #|  if true { left } else { right }
    #|}
  let consumer =
    #|module Main
    #|import Provider.{ Witness, choose, concat }
    #|
    #|offer local_witness : Witness = Witness::{ value: 42 }
    #|pub let answer : I64 = choose()
    #|
    #|pub fn wrapped(value : String) -> String {
    #|  "(" |> concat(value) |> concat(")")
    #|}
  @async.with_task_group(group => {
    let server = group.spawn(() => {
      let termination = run_server(server_input, server_output)
      server_output.close()
      termination
    })
    send_lsp_message(client_input, lsp_call(1, "initialize", null))
    ignore(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("initialized", {}))
    send_lsp_message(
      client_input,
      lsp_notification(
        "textDocument/didOpen",
        lsp_document(provider_uri, provider),
      ),
    )
    ignore(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_notification(
        "textDocument/didOpen",
        lsp_document(consumer_uri, consumer),
      ),
    )
    ignore(receive_lsp_message(client_output))
    ignore(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_call(2, "textDocument/inlayHint", lsp_range(consumer_uri, 10, 0)),
    )
    json_inspect(receive_lsp_message(client_output), content={
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 4, "character": 30 },
          "label": "witness=local_witness",
          "kind": 2,
        },
        {
          "position": { "line": 7, "character": 16 },
          "label": "right=",
          "kind": 2,
        },
        {
          "position": { "line": 7, "character": 33 },
          "label": "right=",
          "kind": 2,
        },
      ],
    })
    send_lsp_message(client_input, lsp_call(3, "shutdown", null))
    ignore(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("exit", null))
    client_input.close()
    assert_true(client_output.read_until("\n") is None)
    assert_eq(server.wait(), GracefulExit)
  })
}

///|
async test "public server composes nested implicit argument inlays" {
  let (server_input, client_input) = @io.pipe()
  let (client_output, server_output) = @io.pipe()
  let uri = "file:///Main.lane"
  let source =
    #|module Main
    #|
    #|pub struct Compare[A] {
    #|  less_than : (A, A) -> Bool
    #|}
    #|
    #|pub fn[A] op_less(left : A, right : A, auto op : Compare[A]) -> Bool {
    #|  op.less_than(left, right)
    #|}
    #|
    #|pub fn assert_true(value : Bool, auto info : Unit) -> Unit {
    #|  if value { info } else { info }
    #|}
    #|
    #|offer char_compare : Compare[Char] = Compare::{ less_than: fn(_left : Char, _right : Char) { false } }
    #|offer source_info : Unit = ()
    #|
    #|pub fn answer() -> Unit {
    #|  assert_true('你' < '😀')
    #|}
  @async.with_task_group(group => {
    let server = group.spawn(() => {
      let termination = run_server(server_input, server_output)
      server_output.close()
      termination
    })
    send_lsp_message(client_input, lsp_call(1, "initialize", null))
    ignore(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("initialized", {}))
    send_lsp_message(
      client_input,
      lsp_notification("textDocument/didOpen", lsp_document(uri, source)),
    )
    ignore(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_call(2, "textDocument/inlayHint", lsp_range(uri, 20, 0)),
    )
    json_inspect(receive_lsp_message(client_output), content={
      "jsonrpc": "2.0",
      "id": 2,
      "result": [
        {
          "position": { "line": 18, "character": 14 },
          "label": "value=",
          "kind": 2,
        },
        {
          "position": { "line": 18, "character": 24 },
          "label": ", op=char_compare, info=source_info",
          "kind": 2,
        },
      ],
    })
    send_lsp_message(
      client_input,
      lsp_notification(
        "textDocument/didChange",
        lsp_document_change(uri, source + "\n"),
      ),
    )
    ignore(receive_lsp_message(client_output))
    send_lsp_message(
      client_input,
      lsp_call(3, "textDocument/inlayHint", lsp_range(uri, 20, 0)),
    )
    json_inspect(receive_lsp_message(client_output), content={
      "jsonrpc": "2.0",
      "id": 3,
      "result": [
        {
          "position": { "line": 18, "character": 14 },
          "label": "value=",
          "kind": 2,
        },
        {
          "position": { "line": 18, "character": 24 },
          "label": ", op=char_compare, info=source_info",
          "kind": 2,
        },
      ],
    })
    send_lsp_message(client_input, lsp_call(4, "shutdown", null))
    ignore(receive_lsp_message(client_output))
    send_lsp_message(client_input, lsp_notification("exit", null))
    client_input.close()
    assert_true(client_output.read_until("\n") is None)
    assert_eq(server.wait(), GracefulExit)
  })
}

///|
async test "public server reports exit before shutdown as premature" {
  let (server_input, client_input) = @io.pipe()
  let (_client_output, server_output) = @io.pipe()
  @async.with_task_group(group => {
    let server = group.spawn(() => run_server(server_input, server_output))
    send_lsp_message(client_input, lsp_notification("exit", null))
    client_input.close()
    assert_eq(server.wait(), PrematureExit)
  })
}

///|
async test "public server distinguishes transport closure" {
  let (server_input, client_input) = @io.pipe()
  let (_client_output, server_output) = @io.pipe()
  client_input.close()
  assert_eq(run_server(server_input, server_output), TransportClosed)
}
