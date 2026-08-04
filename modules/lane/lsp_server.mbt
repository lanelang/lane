///|
async fn lsp_command(_stdio : Bool) -> LaneCommandOutcome {
  @async.pause()
  match @lsp.run_server(@stdio.stdin, @stdio.stdout) {
    GracefulExit | TransportClosed => Succeeded
    PrematureExit => FailedSilently
  }
}
