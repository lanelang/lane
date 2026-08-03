///|
async test "server frames initialize response through public IO boundary" {
  let (server_input, client_input) = @io.pipe()
  let (client_output, server_output) = @io.pipe()
  let body =
    #|{"jsonrpc":"2.0","id":1,"method":"initialize","params":null}
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      run_server(server_input, server_output)
      server_output.close()
    })
    client_input.write("Content-Length: \{body.length()}\r\n\r\n" + body)
    client_input.close()
    let response = client_output.read_all().text()
    guard response.split("\r\n\r\n").collect() is [header, response_body] else {
      abort("expected one framed LSP response")
    }
    inspect(header, content="Content-Length: 269")
    json_inspect(@json.parse(response_body), content={
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
    })
  })
}
