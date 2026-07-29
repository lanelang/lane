///|
async test "workspace scan failure does not commit partial initialization" {
  let workspace = ".tmp-lsp-missing-workspace"
  @fs.remove(workspace) catch {
    _ => ()
  }
  @fs.rmdir(workspace) catch {
    _ => ()
  }
  let state = ServerState::ServerState()
  state.workspace_root = Some(workspace)
  let document = {
    uri: "file://\{workspace}/Main.lane",
    text: "module Main\n\npub let answer : Int = 42",
  }
  let mut scan_failed = false
  ignore(state.synchronize_document(document)) catch {
    _ => scan_failed = true
  }
  assert_true(scan_failed)
  assert_false(state.workspace_loaded)
  assert_eq(state.semantic_workspace.sources(), [])
}
