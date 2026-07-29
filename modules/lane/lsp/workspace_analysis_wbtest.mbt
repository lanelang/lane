///|
async test "workspace scan failure is reported without stopping message handling" {
  let workspace = ".tmp-lsp-missing-workspace"
  @fs.remove(workspace) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let failed_open = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://\{workspace}/Main.lane",
        "module Main\n\npub let answer : Int = 42",
      ),
    ),
  )
  assert_false(state.workspace_loaded)
  assert_eq(state.semantic_workspace.sources(), [])
  json_inspect(failed_open.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "window/showMessage",
      "params": {
        "type": 1,
        "message": "Lane could not scan workspace root `.tmp-lsp-missing-workspace`; the workspace was not loaded.",
      },
    },
    {
      "jsonrpc": "2.0",
      "method": "window/logMessage",
      "params": {
        "type": 1,
        "message": "Workspace scan failed: could not read directory `.tmp-lsp-missing-workspace`.",
      },
    },
  ])
  let shutdown = state.handle_message(request(3, "shutdown", null))
  json_inspect(shutdown.outgoing.map(fn(message) { message.to_json() }), content=[
    { "jsonrpc": "2.0", "id": 3, "result": null },
  ])
}

///|
#cfg(not(platform="windows"))
async test "workspace scan records a failed child and loads remaining sources" {
  let workspace = ".tmp-lsp-partial-workspace"
  let main_path = "\{workspace}/Main.lane"
  let broken_path = "\{workspace}/Broken.lane"
  cleanup_workspace_fixture(workspace, main_path, broken_path)
  @fs.mkdir(workspace)
  @fs.symlink(broken_path, target="Missing.lane")
  let state = ServerState::ServerState()
  ignore(
    state.handle_message(
      request(1, "initialize", { "rootUri": "file://\{workspace}" }),
    ),
  )
  let opened = state.handle_message(
    request(
      2,
      "textDocument/didOpen",
      open_params(
        "file://\{main_path}",
        "module Main\n\npub let answer : Int = 42",
      ),
    ),
  )
  cleanup_workspace_fixture(workspace, main_path, broken_path)
  assert_true(state.workspace_loaded)
  assert_eq(state.semantic_workspace.sources(), [
    {
      source_id: "file://.tmp-lsp-partial-workspace/Main.lane",
      text: "module Main\n\npub let answer : Int = 42",
    },
  ])
  json_inspect(opened.outgoing.map(fn(message) { message.to_json() }), content=[
    {
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file://.tmp-lsp-partial-workspace/Main.lane",
        "diagnostics": [],
      },
    },
    {
      "jsonrpc": "2.0",
      "method": "window/logMessage",
      "params": {
        "type": 2,
        "message": "Workspace scan skipped `.tmp-lsp-partial-workspace/Broken.lane`: could not inspect entry.",
      },
    },
  ])
}
