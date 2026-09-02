///|
async fn lane_inspect(input : String) -> LaneCommandOutcome {
  if input.has_suffix(".lane") {
    return lane_inspect_source(input)
  }
  let bytes = read_binary_file(input) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Inspect, input, "\{error}"),
      )
  }
  match @artifact.artifact_binary_to_inspect_text(bytes) {
    Ok(text) => {
      @stdio.stdout.write(text)
      Succeeded
    }
    Err(message) =>
      return LaneCommandOutcome::user_error(
        ArtifactLoad(path=input, kind="artifact", message~),
      )
  }
}

///|
async fn lane_inspect_source(path : String) -> LaneCommandOutcome {
  let text = read_source_file(path) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Inspect, path, "\{error}"),
      )
  }
  let parsed = @module_frontend.parse_source({ source_id: path, text, })
  guard parsed.available_module() is Some(_) else {
    let sources = @compiler_diag.CompilerDiagnosticSources()
    sources.add(path, text, Some(path))
    return LaneCommandOutcome::compile_diagnostics(
      parsed.diagnostics(),
      sources,
      false,
    )
  }
  guard parsed.module_header() is Some(header) else {
    abort("internal Lane compiler bug: parsed source has no module header")
  }
  @stdio.stdout.write("\{source_inspection(header).stringify()}\n")
  Succeeded
}

///|
fn source_inspection(header : @module_frontend.ModuleInputHeader) -> Json {
  { "schema": 1, "module": header.module_path_text, "imports": header.imports }
}
