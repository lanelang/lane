///|
enum CliFileAction {
  Read
  Write
  Resolve
  Check
  Compile
  Run
  RunObject
  Format
  Inspect
  Link
} derive(Debug, Eq)

///|
enum HostFileErrorReason {
  NotFound
  PermissionDenied
  IsDirectory
  Other
} derive(Debug, Eq)

///|
enum EntryExecutableError {
  EntryIsNotFunction
  EntryHasParameters(count~ : Int)
  EntryReturnsNonUnit(result~ : @buslane.Type)
  EntryHasUnsupportedEffects(effect~ : @buslane.Effect)
} derive(Debug)

///|
enum CliError {
  InvalidCommand(message~ : String)
  UnknownCommand
  MissingArgument(name~ : String)
  InvalidRunTarget(target~ : String)
  InvalidRunObjTarget(target~ : String)
  FileIo(action~ : CliFileAction, path~ : String, reason~ : HostFileErrorReason)
  ArtifactLoad(path~ : String, kind~ : String, message~ : String)
  DuplicateObjectArtifact(module_path_text~ : String)
  RootLibraryInput(root~ : String, library~ : String)
  EntryNotFound(name~ : String, entries~ : Array[@elaborate.BuslaneEntry])
  EntryAmbiguous(name~ : String, entries~ : Array[@elaborate.BuslaneEntry])
  EntryNotExecutable(
    name~ : String,
    type_~ : @buslane.Type,
    reason~ : EntryExecutableError
  )
  NotFormatted(path~ : String)
  FormatDiagnostics(
    path~ : String,
    diagnostics~ : Array[@format.FormatDiagnostic]
  )
  Internal(message~ : String)
} derive(Debug)

///|
fn host_file_error_reason(error : String) -> HostFileErrorReason {
  if error.contains("No such file or directory") {
    NotFound
  } else if error.contains("Permission denied") {
    PermissionDenied
  } else if error.contains("Is a directory") {
    IsDirectory
  } else {
    Other
  }
}

///|
fn CliError::file_io(
  action : CliFileAction,
  path : String,
  error : String,
) -> CliError {
  FileIo(action~, path~, reason=host_file_error_reason(error))
}

///|
fn CliError::render_human(self : CliError) -> String {
  match self {
    InvalidCommand(message~) =>
      cli_detail_error(
        "E6000",
        "invalid lane command line",
        ["the command-line parser reported: \{message}"],
        ["this is a CLI usage error, not a Lane source error"],
        ["run `lane --help` or `lane <command> --help` to see valid forms"],
      )
    UnknownCommand =>
      cli_detail_error(
        "E6001",
        "unknown lane command",
        ["the requested subcommand is not supported by this `lane` binary"],
        [
          "available commands include check, run, compile, inspect, link, runobj, fmt, and lsp",
        ],
        ["try: lane check Main.lane"],
      )
    MissingArgument(name~) =>
      cli_detail_error(
        "E6003",
        "missing required CLI argument",
        ["argument `\{name}` was not provided"],
        ["this is a CLI usage error, not a Lane source error"],
        [
          "run `lane --help` or `lane <command> --help` to see the required arguments",
        ],
      )
    InvalidRunTarget(target~) =>
      cli_detail_error(
        "E6002",
        "invalid run target",
        ["expected `FILE:ENTRY`, got `\{target}`"],
        [
          "`lane run` compiles one source file and then selects a public entry from it",
        ],
        ["try: lane run Main.lane:main"],
      )
    InvalidRunObjTarget(target~) =>
      cli_detail_error(
        "E6008",
        "invalid runobj target",
        ["expected `FILE:Module.value`, got `\{target}`"],
        [
          "`lane runobj` loads one linked program artifact and selects a public entry from it",
        ],
        ["try: lane runobj program.lbp:Main.main"],
      )
    FileIo(action~, path~, reason~) =>
      "error: couldn't \{action.to_human_text()} `\{path}`: \{reason.to_human_text()}"
    ArtifactLoad(path~, kind~, message~) =>
      "error: couldn't load \{kind} `\{path}`: \{message}"
    DuplicateObjectArtifact(module_path_text~) =>
      cli_detail_error(
        "E6007",
        "duplicate module object artifact",
        ["module `\{module_path_text}` was provided more than once"],
        [
          "each module in a link input set must come from exactly one object artifact",
        ],
        ["remove the duplicate object path and run `lane link` again"],
      )
    RootLibraryInput(root~, library~) =>
      cli_detail_error(
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
    EntryNotFound(name~, entries~) =>
      cli_detail_error(
        "E6005",
        "entry was not found in the linked program",
        ["requested entry `\{display_entry_name(name)}` does not exist"],
        [available_entries_note(entries)],
        [
          "use one of the listed public entries, or export the value with `pub` before compiling",
        ],
      )
    EntryAmbiguous(name~, entries~) =>
      cli_detail_error(
        "E6006",
        "entry name is ambiguous",
        ["more than one linked entry is named `\{display_entry_name(name)}`"],
        [available_entries_note(entries)],
        ["qualify the requested entry with its module path when possible"],
      )
    EntryNotExecutable(name~, type_~, reason~) =>
      cli_detail_error(
        "E6009",
        "entry is not executable",
        [
          "requested entry `\{display_entry_name(name)}` has type `\{render_buslane_type(type_)}`",
        ],
        [
          "`lane run` and `lane runobj` execute only public zero-argument functions returning `Unit`",
          reason.to_human_note(),
        ],
        [
          "export a `pub fn main() -> Unit` entry, or use supported runtime effects such as `Stdlib.Io.Write`",
        ],
      )
    NotFormatted(path~) => "\{path}: not formatted"
    FormatDiagnostics(path~, diagnostics~) =>
      diagnostics
      .map(fn(diagnostic) {
        let rendered = @prettyprinter.render(diagnostic, width=100)
        "\{path}: \{rendered}"
      })
      .join("\n")
    Internal(message~) =>
      cli_detail_error(
        "E6200",
        "internal Lane compiler/runtime error",
        ["compiler/runtime invariant failed: \{message}"],
        ["this is not expected after a successful Lane typecheck"],
        [
          "please file a compiler bug with the source file, command, and this diagnostic",
        ],
      )
  }
}

///|
fn EntryExecutableError::to_human_note(self : EntryExecutableError) -> String {
  match self {
    EntryIsNotFunction => "the selected public entry is a value, not a function"
    EntryHasParameters(count~) =>
      "the selected function expects \{count} argument(s)"
    EntryReturnsNonUnit(result~) =>
      "the selected function returns `\{render_buslane_type(result)}`, not `Unit`"
    EntryHasUnsupportedEffects(effect~) =>
      "the selected function has unsupported effect set `\{render_buslane_effect(effect)}`"
  }
}

///|
fn CliFileAction::to_human_text(self : CliFileAction) -> String {
  match self {
    Read => "read"
    Write => "write"
    Resolve => "resolve"
    Check => "check"
    Compile => "compile"
    Run => "run"
    RunObject => "run object"
    Format => "format"
    Inspect => "inspect"
    Link => "link"
  }
}

///|
fn HostFileErrorReason::to_human_text(self : HostFileErrorReason) -> String {
  match self {
    NotFound => "No such file or directory"
    PermissionDenied => "Permission denied"
    IsDirectory => "Is a directory"
    Other => "host file operation failed"
  }
}

///|
fn render_buslane_type(type_ : @buslane.Type) -> String {
  @prettyprinter.render(type_, width=100)
}

///|
fn render_buslane_effect(effect : @buslane.Effect) -> String {
  @prettyprinter.render(effect, width=100)
}

///|
fn cli_detail_error(
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
fn available_entries_note(entries : Array[@elaborate.BuslaneEntry]) -> String {
  let names = entry_names(entries)
  if names.is_empty() {
    "the linked program exports no public entries"
  } else {
    let joined = names.join(", ")
    "available public entries: \{joined}"
  }
}
