///|
async fn lane_inspect(artifact : String) -> LaneCommandOutcome {
  let bytes = read_binary_file(artifact) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Inspect, artifact, "\{error}"),
      )
  }
  match @compile.artifact_binary_to_inspect_text(bytes) {
    Ok(text) => {
      @stdio.stdout.write(text)
      Succeeded
    }
    Err(message) =>
      return LaneCommandOutcome::user_error(
        ArtifactLoad(path=artifact, kind="artifact", message~),
      )
  }
}
