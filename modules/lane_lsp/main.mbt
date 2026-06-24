///|
async fn main {
  @async.pause()
  parse_lsp_command() catch {
    _ => abort("failed to parse command line")
  }
  run_server(ServerState::ServerState())
}

///|
async fn run_server(state : ServerState) -> Unit {
  while read_protocol_message(@stdio.stdin) is Some(message) {
    let result = state.handle_message(message)
    for outgoing in result.outgoing {
      write_protocol_message(@stdio.stdout, outgoing)
    }
    if result.exit_requested {
      break
    }
  }
}
