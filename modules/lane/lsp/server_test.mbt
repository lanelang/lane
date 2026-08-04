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
    group.spawn_bg(() => {
      run_server(server_input, server_output)
      server_output.close()
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
