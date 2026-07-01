///|
enum LaneCommandOutcome {
  Succeeded
  UserFailure
}

///|
async fn main {
  let command = match parse_lane_command() {
    Ok(command) => command
    Err(message) => {
      println(message)
      fail("lane command failed")
    }
  }
  let outcome = match command {
    Check(file~, libs~, lib_dirs~, deny~) =>
      lane_check(file, libs, lib_dirs, deny)
    Compile(file~, interfaces~, emit_interface~, emit_object~) =>
      lane_compile(file, interfaces, emit_interface, emit_object)
    Fmt(files~, check~, deny~) => lane_fmt(files, check, deny)
    Link(objects~, output~) => lane_link(objects, output)
    Lsp(stdio~) => lsp_command(stdio)
    RunLinked(program~, entry~) => lane_runlinked(program, entry)
    Run(file~, entry~, libs~, lib_dirs~) =>
      lane_run(file, entry, libs, lib_dirs)
  }
  match outcome {
    Succeeded => ()
    UserFailure => fail("lane command failed")
  }
}
