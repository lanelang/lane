///|
async fn lsp_command(_stdio : Bool) -> LaneCommandOutcome {
  @async.pause()
  @lsp.run_server(@stdio.stdin, @stdio.stdout)
  Succeeded
}
