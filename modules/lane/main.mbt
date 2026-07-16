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
        Check(file~, libs~, lib_dirs~, no_basic~, deny~) =>
          lane_check(file, libs, lib_dirs, deny, no_basic~)
        Compile(file~, interfaces~, interface_output~, object_output~, verbose~) =>
          lane_compile(
            file, interfaces, interface_output, object_output, verbose,
          )
        Fmt(files~, check~) => lane_fmt(files, check)
        Inspect(artifact~) => lane_inspect(artifact)
        Link(objects~, entry~, output~, verbose~) =>
          lane_link(objects, entry, output, verbose)
        Lsp(stdio~) => lsp_command(stdio)
        RunObj(program~, no_jit~) => lane_runobj(program, no_jit~)
        Explore(file~, entry~, libs~, lib_dirs~, no_basic~, output~) =>
          lane_explore(file, entry, libs, lib_dirs, output, no_basic~)
        Run(file~, entry~, libs~, lib_dirs~, no_basic~, no_jit~) =>
          lane_run(file, entry, libs, lib_dirs, no_basic~, no_jit~)
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
