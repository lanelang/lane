///|
async fn lane_inspect(artifact : String) -> LaneCommandOutcome {
  let bytes = read_binary_file(artifact) catch {
    error => {
      println(read_file_error(artifact, "\{error}"))
      return UserFailure
    }
  }
  match @compile.artifact_binary_to_inspect_text(bytes) {
    Ok(text) => {
      @stdio.stdout.write(text)
      Succeeded
    }
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
}
