///|
fn lane_boundary_error(
  code : String,
  title : String,
  labels : Array[String],
  notes : Array[String],
  helps : Array[String],
) -> String {
  let lines = ["error[\{code}]: \{title}"]
  for label in labels {
    lines.push("  = label: \{label}")
  }
  for note in notes {
    lines.push("  = note: \{note}")
  }
  for help in helps {
    lines.push("  = help: \{help}")
  }
  lines.join("\n")
}

///|
fn cli_parse_error(message : String) -> String {
  lane_boundary_error(
    "E6000",
    "invalid lane command line",
    ["the command-line parser reported: \{message}"],
    ["this is a CLI usage error, not a Lane source error"],
    ["run `lane --help` or `lane <command> --help` to see valid forms"],
  )
}

///|
fn unknown_command_error() -> String {
  lane_boundary_error(
    "E6001",
    "unknown lane command",
    ["the requested subcommand is not supported by this `lane` binary"],
    [
      "available commands include check, run, compile, inspect, link, runlinked, fmt, and lsp",
    ],
    ["try: lane check Main.lane"],
  )
}

///|
fn run_target_error(target : String) -> String {
  lane_boundary_error(
    "E6002",
    "invalid run target",
    ["expected `FILE:ENTRY`, got `\{target}`"],
    [
      "`lane run` compiles one source file and then selects a public entry from it",
    ],
    ["try: lane run Main.lane:main"],
  )
}

///|
fn missing_argument_error(name : String) -> String {
  lane_boundary_error(
    "E6003",
    "missing required CLI argument",
    ["argument `\{name}` was not provided"],
    ["this is a CLI usage error, not a Lane source error"],
    [
      "run `lane --help` or `lane <command> --help` to see the required arguments",
    ],
  )
}

///|
fn entry_lookup_error(
  name : String,
  entries : Array[@elaborate.BuslaneEntry],
) -> String {
  lane_boundary_error(
    "E6005",
    "entry was not found in the linked program",
    ["requested entry `\{name}` does not exist"],
    [available_entries_note(entries)],
    [
      "use one of the listed public entries, or export the value with `pub` before compiling",
    ],
  )
}

///|
fn ambiguous_entry_error(
  name : String,
  entries : Array[@elaborate.BuslaneEntry],
) -> String {
  lane_boundary_error(
    "E6006",
    "entry name is ambiguous",
    ["more than one linked entry is named `\{name}`"],
    [available_entries_note(entries)],
    ["qualify the requested entry with its module path when possible"],
  )
}

///|
fn available_entries_note(entries : Array[@elaborate.BuslaneEntry]) -> String {
  let names = entry_names(entries)
  if names.is_empty() {
    "the linked program exports no public entries"
  } else {
    let joined = names.join(", ")
    "available public entries: \{joined}"
  }
}

///|
fn file_io_error(
  code : String,
  title : String,
  path : String,
  action : String,
  error : String,
) -> String {
  lane_boundary_error(
    code,
    title,
    ["while trying to \{action}: \{path}"],
    ["host error: \{error}"],
    [
      "check that the path exists and the current process has the required permissions",
    ],
  )
}

///|
fn read_file_error(path : String, error : String) -> String {
  file_io_error("E6100", "could not read file", path, "read", error)
}

///|
fn write_file_error(path : String, error : String) -> String {
  file_io_error("E6101", "could not write file", path, "write", error)
}

///|
fn resolve_file_error(path : String, error : String) -> String {
  file_io_error("E6102", "could not resolve file path", path, "resolve", error)
}

///|
fn root_library_input_error(root : String, library : String) -> String {
  lane_boundary_error(
    "E6008",
    "root source was also passed as an explicit library",
    [
      "`\{library}` resolves to the same source file as the root source `\{root}`",
    ],
    [
      "`lane check` and `lane run` compile the root source separately from library inputs",
      "`--lib-dir` discovery silently skips the root source, but explicit `--lib` keeps mistakes visible",
    ],
    ["remove the duplicate `--lib \{library}` argument"],
  )
}

///|
fn internal_compiler_error(message : String) -> String {
  lane_boundary_error(
    "E6200",
    "internal Lane compiler/runtime error",
    ["compiler/runtime invariant failed: \{message}"],
    ["this is not expected after a successful Lane typecheck"],
    [
      "please file a compiler bug with the source file, command, and this diagnostic",
    ],
  )
}
