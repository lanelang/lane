///|
using @compiler_diag {type CompilerDiagnosticSources}

///|
enum LaneCommandOutcome {
  Succeeded
  UserErrors(Array[CliError])
  CompileDiagnostics(
    diagnostics~ : Array[@compiler_diag.CompilerDiagnostic],
    sources~ : CompilerDiagnosticSources,
    success~ : Bool
  )
}

///|
async fn main {
  match parse_lane_command() {
    Ok(command) => {
      let outcome = match command {
        Check(file~, libs~, lib_dirs~, deny~) =>
          lane_check(file, libs, lib_dirs, deny)
        Compile(file~, interfaces~, emit_interface~, emit_object~, verbose~) =>
          lane_compile(file, interfaces, emit_interface, emit_object, verbose)
        Fmt(files~, check~, deny~) => lane_fmt(files, check, deny)
        Inspect(artifact~) => lane_inspect(artifact)
        Link(objects~, entry~, output~, verbose~) =>
          lane_link(objects, entry, output, verbose)
        Lsp(stdio~) => lsp_command(stdio)
        RunObj(program~) => lane_runobj(program)
        Run(file~, entry~, libs~, lib_dirs~) =>
          lane_run(file, entry, libs, lib_dirs)
      }
      match outcome {
        Succeeded => ()
        UserErrors(errors) => {
          render_cli_errors(errors)
          @sys.exit(1)
        }
        CompileDiagnostics(diagnostics~, sources~, success~) => {
          print_diagnostics_with_sources(diagnostics, sources)
          if !success {
            @sys.exit(1)
          }
        }
      }
    }
    Err(error) => {
      println(error.render_human())
      @sys.exit(1)
    }
  }
}

///|
fn LaneCommandOutcome::user_error(error : CliError) -> LaneCommandOutcome {
  UserErrors([error])
}

///|
fn LaneCommandOutcome::compile_diagnostics(
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  sources : CompilerDiagnosticSources,
  success : Bool,
) -> LaneCommandOutcome {
  CompileDiagnostics(diagnostics~, sources~, success~)
}

///|
fn render_cli_errors(errors : Array[CliError]) -> Unit {
  for error in errors {
    println(error.render_human())
  }
}
