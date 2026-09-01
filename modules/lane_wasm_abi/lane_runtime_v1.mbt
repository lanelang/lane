///|
pub(all) enum LaneRuntimeV1Import {
  RunCommand
} derive(Debug, Eq)

///|
pub fn LaneRuntimeV1Import::contract(
  self : LaneRuntimeV1Import,
) -> ImportContract {
  match self {
    RunCommand =>
      {
        module_name: "lane_runtime_v1",
        field_name: "run_command",
        parameters: [GuestAddress, Direct(I32), GuestAddress],
        result: Direct(I32),
      }
  }
}

///|
pub fn lane_runtime_v1_imports() -> Array[LaneRuntimeV1Import] {
  [RunCommand]
}

///|
pub fn lane_runtime_v1_contract(field_name : String) -> ImportContract? {
  for import_ in lane_runtime_v1_imports() {
    let contract = import_.contract()
    if contract.field_name == field_name {
      return Some(contract)
    }
  }
  None
}

///|
pub(all) struct RunCommandEnvironmentEntry {
  key : String
  value : String
} derive(Debug, Eq)

///|
pub(all) struct RunCommandRequest {
  executable : String
  arguments : Array[String]
  working_directory : String?
  environment : Array[RunCommandEnvironmentEntry]
  inherit_environment : Bool
} derive(Debug, Eq)

///|
pub(all) suberror RunCommandFrameError {
  InvalidRunCommandFrame(detail~ : String)
} derive(Debug, Eq)

///|
pub(all) enum RunCommandTermination {
  Exited(code~ : Int)
  Signaled(signal~ : Int)
} derive(Debug, Eq)

///|
pub(all) enum RunCommandHostStatus {
  Succeeded
  InvalidRequest
  ExecutableNotFound
  PermissionDenied
  SystemFailure
} derive(Debug, Eq)

///|
pub fn RunCommandHostStatus::wire_code(self : RunCommandHostStatus) -> Int {
  match self {
    Succeeded => 0
    InvalidRequest => 1
    ExecutableNotFound => 2
    PermissionDenied => 3
    SystemFailure => 4
  }
}

///|
pub fn RunCommandTermination::response_words(
  self : RunCommandTermination,
) -> (Int, Int) {
  match self {
    Exited(code~) => (0, code)
    Signaled(signal~) => (1, signal)
  }
}

///|
pub fn run_command_response_size() -> Int {
  8
}

///|
fn checked_frame_range(
  frame : Bytes,
  offset : Int,
  length : Int,
  subject : String,
) -> Unit raise RunCommandFrameError {
  if offset < 0 ||
    length < 0 ||
    offset > frame.length() ||
    length > frame.length() - offset {
    raise InvalidRunCommandFrame(
      detail="\{subject} is outside the request frame",
    )
  }
}

///|
fn frame_i32(
  frame : Bytes,
  offset : Int,
  subject : String,
) -> Int raise RunCommandFrameError {
  checked_frame_range(frame, offset, 4, subject)
  match frame[offset:] {
    [i32le(value), ..] => value
    _ => raise InvalidRunCommandFrame(detail="\{subject} is truncated")
  }
}

///|
fn frame_string(
  frame : Bytes,
  offset : Int,
  length : Int,
  subject : String,
) -> String raise RunCommandFrameError {
  checked_frame_range(frame, offset, length, subject)
  let bytes = frame[offset:offset + length].to_owned()
  for byte in bytes {
    if byte == b'\x00' {
      raise InvalidRunCommandFrame(detail="\{subject} contains a NUL byte")
    }
  }
  @utf8.decode(bytes) catch {
    _ => raise InvalidRunCommandFrame(detail="\{subject} is not valid UTF-8")
  }
}

///|
fn checked_table(
  frame : Bytes,
  offset : Int,
  count : Int,
  entry_size : Int,
  subject : String,
) -> Unit raise RunCommandFrameError {
  if count < 0 {
    raise InvalidRunCommandFrame(detail="\{subject} has a negative entry count")
  }
  checked_frame_range(frame, offset, 0, subject)
  if count > (frame.length() - offset) / entry_size {
    raise InvalidRunCommandFrame(detail="\{subject} is truncated")
  }
}

///|
pub fn decode_run_command_request(
  frame : Bytes,
) -> Result[RunCommandRequest, RunCommandFrameError] {
  try {
    guard frame[:]
      is [
        i32le(flags),
        i32le(executable_offset),
        i32le(executable_length),
        i32le(arguments_offset),
        i32le(argument_count),
        i32le(working_directory_offset),
        i32le(working_directory_length),
        i32le(environment_offset),
        i32le(environment_count),
        ..,
      ] else {
      raise InvalidRunCommandFrame(detail="the request header is truncated")
    }
    if flags < 0 || flags > 1 {
      raise InvalidRunCommandFrame(detail="the request contains unknown flags")
    }
    let executable = frame_string(
      frame, executable_offset, executable_length, "the executable",
    )
    if executable is "" {
      raise InvalidRunCommandFrame(detail="the executable is empty")
    }
    checked_table(
      frame, arguments_offset, argument_count, 8, "the argument table",
    )
    let arguments = []
    for index in 0..<argument_count {
      let entry = arguments_offset + index * 8
      arguments.push(
        frame_string(
          frame,
          frame_i32(frame, entry, "argument offset"),
          frame_i32(frame, entry + 4, "argument length"),
          "argument \{index}",
        ),
      )
    }
    let working_directory = if working_directory_offset == -1 {
      if working_directory_length != 0 {
        raise InvalidRunCommandFrame(
          detail="an absent working directory must have length zero",
        )
      }
      None
    } else {
      let directory = frame_string(
        frame, working_directory_offset, working_directory_length, "the working directory",
      )
      if directory is "" {
        raise InvalidRunCommandFrame(detail="the working directory is empty")
      }
      Some(directory)
    }
    checked_table(
      frame, environment_offset, environment_count, 16, "the environment table",
    )
    let environment : Array[RunCommandEnvironmentEntry] = []
    for index in 0..<environment_count {
      let entry = environment_offset + index * 16
      let key = frame_string(
        frame,
        frame_i32(frame, entry, "environment key offset"),
        frame_i32(frame, entry + 4, "environment key length"),
        "environment key \{index}",
      )
      if key is "" || key.contains("=") {
        raise InvalidRunCommandFrame(
          detail="environment key \{index} must be non-empty and contain no `=`",
        )
      }
      environment.push({
        key,
        value: frame_string(
          frame,
          frame_i32(frame, entry + 8, "environment value offset"),
          frame_i32(frame, entry + 12, "environment value length"),
          "environment value \{index}",
        ),
      })
    }
    Ok({
      executable,
      arguments,
      working_directory,
      environment,
      inherit_environment: flags == 1,
    })
  } catch {
    error => Err(error)
  }
}
