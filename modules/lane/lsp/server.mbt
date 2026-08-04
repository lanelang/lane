///|
pub async fn run_server(input : &@io.Reader, output : &@io.Writer) -> Unit {
  let state = ServerState()
  while read_protocol_message(input) is Some(message) {
    let result = state.handle_message(message)
    for outgoing in result.outgoing {
      write_protocol_message(output, outgoing)
    }
    match result.transition {
      Continue => ()
      Exit(_) => break
    }
  }
}
