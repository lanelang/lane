///|
enum CliFileAction {
  Read
  Write
  Resolve
  Check
  Compile
  Run
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
priv struct CommandReportField {
  name : String
  value : String
}

///|
priv struct CommandSuggestion {
  message : String
  command : String?
}

///|
priv struct CommandReport {
  code : String?
  title : String
  fields : Array[CommandReportField]
  details : Array[String]
  suggestions : Array[CommandSuggestion]
}

///|
enum CliError {
  InvalidCommand(message~ : String)
  UnknownCommand
  MissingArgument(name~ : String)
  InvalidRunTarget(target~ : String)
  InvalidExploreTarget(target~ : String)
  InvalidExecTarget(target~ : String)
  InvalidLinkEntry(entry~ : String)
  FileIo(action~ : CliFileAction, path~ : String, reason~ : HostFileErrorReason)
  ArtifactLoad(path~ : String, kind~ : String, message~ : String)
  ExecutionImageLowering(message~ : String)
  ExecutionImageLoad(message~ : String)
  ExecutionFailed(message~ : String)
  DuplicateObjectArtifact(module_path_text~ : String)
  RootLibraryInput(root~ : String, library~ : String)
  EntryNotFound(
    name~ : String,
    entries~ : Array[@buslane_lowering.BuslaneEntry]
  )
  EntryAmbiguous(
    name~ : String,
    entries~ : Array[@buslane_lowering.BuslaneEntry]
  )
  EntryNotExecutable(
    name~ : String,
    type_~ : @buslane.Type,
    reason~ : EntryExecutableError
  )
  NotFormatted(path~ : String)
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
  self.to_command_report().render_human()
}

///|
fn CliError::to_command_report(self : CliError) -> CommandReport {
  match self {
    InvalidCommand(message~) =>
      command_report(
        code="E6000",
        title="invalid lane command line",
        fields=[command_report_field("parser message", message)],
        details=["This is a CLI usage error, not a Lane source error."],
        suggestions=[
          command_suggestion(
            "Run `lane --help` or `lane <command> --help` to see valid forms.",
          ),
        ],
      )
    UnknownCommand =>
      command_report(
        code="E6001",
        title="unknown lane command",
        details=[
          "The requested subcommand is not supported by this `lane` binary.", "Available commands include check, run, explore, compile, inspect, link, exec, fmt, and lsp.",
        ],
        suggestions=[
          command_suggestion("Example:", command="lane check Main.lane"),
        ],
      )
    MissingArgument(name~) =>
      command_report(
        code="E6003",
        title="missing required CLI argument `\{name}`",
        details=["This is a CLI usage error, not a Lane source error."],
        suggestions=[
          command_suggestion(
            "Run `lane --help` or `lane <command> --help` to see the required arguments.",
          ),
        ],
      )
    InvalidRunTarget(target~) =>
      command_report(
        code="E6002",
        title="invalid run target `\{target}`",
        fields=[command_report_field("expected", "FILE:ENTRY")],
        details=[
          "`lane run` compiles one source file and then selects a public entry from it.",
        ],
        suggestions=[
          command_suggestion("Example:", command="lane run Main.lane:main"),
        ],
      )
    InvalidExploreTarget(target~) =>
      command_report(
        code="E6014",
        title="invalid explore target `\{target}`",
        fields=[command_report_field("expected", "FILE:ENTRY")],
        suggestions=[
          command_suggestion(
            "Example:",
            command="lane explore Main.lane:main -o report.html",
          ),
        ],
      )
    InvalidExecTarget(target~) =>
      command_report(
        code="E6008",
        title="invalid exec target `\{target}`",
        fields=[command_report_field("expected", "FILE.lbp")],
        details=[
          "`lane exec` executes the entry selected when the linked program artifact was produced.",
        ],
        suggestions=[
          command_suggestion("Example:", command="lane exec program.lbp"),
        ],
      )
    InvalidLinkEntry(entry~) =>
      command_report(
        code="E6010",
        title="invalid link entry `\{entry}`",
        fields=[command_report_field("expected", "Module.value")],
        details=[
          "`lane link` selects one exported entry before producing a linked program artifact.",
        ],
        suggestions=[
          command_suggestion(
            "Example:",
            command="lane link --entry Main.main -o program.lbp Main.lmo",
          ),
        ],
      )
    FileIo(action~, path~, reason~) =>
      command_report(
        title="couldn't \{action.to_human_text()} `\{path}`: \{reason.to_human_text()}",
      )
    ArtifactLoad(path~, kind~, message~) =>
      command_report(title="couldn't load \{kind} `\{path}`", fields=[
        command_report_field("reason", message),
      ])
    ExecutionImageLowering(message~) =>
      command_report(
        code="E6011",
        title="couldn't lower the linked program to LoisVM bytecode",
        fields=[command_report_field("reason", message)],
      )
    ExecutionImageLoad(message~) =>
      command_report(
        code="E6012",
        title="couldn't load the LoisVM execution image",
        fields=[command_report_field("reason", message)],
      )
    ExecutionFailed(message~) =>
      command_report(code="E6013", title="LoisVM execution failed", fields=[
        command_report_field("reason", message),
      ])
    DuplicateObjectArtifact(module_path_text~) =>
      command_report(
        code="E6007",
        title="duplicate module object artifact",
        fields=[command_report_field("module", module_path_text)],
        details=[
          "Each module in a link input set must come from exactly one object artifact.",
        ],
        suggestions=[
          command_suggestion(
            "Remove the duplicate object path and run `lane link` again.",
          ),
        ],
      )
    RootLibraryInput(root~, library~) =>
      command_report(
        code="E6008",
        title="root source was also passed as an explicit library",
        fields=[
          command_report_field("root", root),
          command_report_field("library", library),
        ],
        details=[
          "`lane check` and `lane run` compile the root source separately from library inputs.",
          "`--lib-dir` discovery silently skips the root source, but explicit `--lib` keeps mistakes visible.",
        ],
        suggestions=[
          command_suggestion(
            "Remove the duplicate `--lib \{library}` argument.",
          ),
        ],
      )
    EntryNotFound(name~, entries~) =>
      command_report(
        code="E6005",
        title="entry `\{name}` was not found",
        fields=[
          command_report_field(
            "available public entries",
            available_entries_text(entries),
          ),
        ],
        suggestions=[
          command_suggestion(
            "Use one of the listed public entries, or export the value with `pub` before compiling.",
          ),
        ],
      )
    EntryAmbiguous(name~, entries~) =>
      command_report(
        code="E6006",
        title="entry name `\{name}` is ambiguous",
        fields=[
          command_report_field(
            "available public entries",
            available_entries_text(entries),
          ),
        ],
        suggestions=[
          command_suggestion(
            "Qualify the requested entry with its module path when possible.",
          ),
        ],
      )
    EntryNotExecutable(name~, type_~, reason~) =>
      command_report(
        code="E6009",
        title="entry `\{name}` is not executable",
        fields=[
          command_report_field("requested type", render_buslane_type(type_)),
          command_report_field("expected", "() -> Unit or () -> Unit ! Io"),
        ],
        details=[reason.to_human_note()],
        suggestions=[
          command_suggestion("Export a `pub fn main() -> Unit` entry."),
          command_suggestion(
            "Use `lane inspect <artifact>` to inspect public entries and artifact metadata.",
          ),
        ],
      )
    NotFormatted(path~) => command_report(title="\{path}: not formatted")
    Internal(message~) =>
      command_report(
        code="E6200",
        title="internal Lane compiler/runtime error",
        fields=[command_report_field("invariant", message)],
        details=["This is not expected after a successful Lane typecheck."],
        suggestions=[
          command_suggestion(
            "Please file a compiler bug with the source file, command, and this diagnostic.",
          ),
        ],
      )
  }
}

///|
fn EntryExecutableError::to_human_note(self : EntryExecutableError) -> String {
  match self {
    EntryIsNotFunction =>
      "The selected public entry is a value, not a function."
    EntryHasParameters(count~) =>
      "The selected function expects \{count} argument(s)."
    EntryReturnsNonUnit(result~) =>
      "The selected function returns `\{render_buslane_type(result)}`, not `Unit`."
    EntryHasUnsupportedEffects(effect~) =>
      "The selected function has unsupported effect set `\{render_buslane_effect(effect)}`."
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
fn command_report(
  code? : String,
  title~ : String,
  fields? : Array[CommandReportField] = [],
  details? : Array[String] = [],
  suggestions? : Array[CommandSuggestion] = [],
) -> CommandReport {
  { code, title, fields, details, suggestions }
}

///|
fn command_report_field(name : String, value : String) -> CommandReportField {
  { name, value }
}

///|
fn command_suggestion(message : String, command? : String) -> CommandSuggestion {
  { message, command }
}

///|
fn CommandReport::render_human(self : CommandReport) -> String {
  let lines = [self.render_header()]
  for field in self.fields {
    lines.push("  \{field.name}: \{field.value}")
  }
  if !self.details.is_empty() {
    if !self.fields.is_empty() {
      lines.push("")
    }
    for detail in self.details {
      lines.push(detail)
    }
  }
  if !self.suggestions.is_empty() {
    if !self.fields.is_empty() || !self.details.is_empty() {
      lines.push("")
    }
    for suggestion in self.suggestions {
      lines.push(suggestion.message)
      if suggestion.command is Some(command) {
        lines.push("  \{command}")
      }
    }
  }
  lines.join("\n")
}

///|
fn CommandReport::render_header(self : CommandReport) -> String {
  match self.code {
    Some(code) => "error[\{code}]: \{self.title}"
    None => "error: \{self.title}"
  }
}

///|
fn available_entries_text(
  entries : Array[@buslane_lowering.BuslaneEntry],
) -> String {
  let names = entries.map(display_entry)
  if names.is_empty() {
    "(none)"
  } else {
    names.join(", ")
  }
}
