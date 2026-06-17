///|
async fn main {
  @async.pause()
  let stdlib = parse_lsp_stdlib() catch {
    _ => abort("failed to parse command line")
  }
  let prelude = read_prelude(stdlib) catch {
    _ => abort("failed to read prelude")
  }
  run_server(ServerState(prelude))
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
