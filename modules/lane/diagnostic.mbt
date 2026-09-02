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
enum EntryInvocationFailure {
  HasParameters(count~ : Int)
  ReturnsNonUnit(result~ : @buslane.Type)
} derive(Debug, Eq)

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
  LaneHomeNotConfigured
  InvalidRunTarget(target~ : String)
  InvalidExploreTarget(target~ : String)
  InvalidLinkExport(export_~ : String)
  DuplicateLinkExportName(name~ : String)
  ReservedLinkExportName(name~ : String)
  FileIo(action~ : CliFileAction, path~ : String, reason~ : HostFileErrorReason)
  ArtifactLoad(path~ : String, kind~ : String, message~ : String)
  ExecutionImageLowering(message~ : String)
  ExecutionImageLoad(message~ : String)
  ExecutionFailed(@lane_runtime.ExecutionError)
  DuplicateObjectArtifact(module_path_text~ : String)
  RootLibraryInput(root~ : String, library~ : String)
  EntryNotFound(name~ : String, entries~ : Array[@compile.CompiledEntry])
  EntryAmbiguous(name~ : String, entries~ : Array[@compile.CompiledEntry])
  EntryNotExecutable(
    name~ : String,
    type_~ : @buslane.Type,
    reason~ : @executable.EntryAdmissionFailure
  )
  ExportNotExecutable(
    name~ : String,
    type_~ : @buslane.Type,
    reason~ : @executable.EntryAdmissionFailure
  )
  EntryNotInvocable(
    name~ : String,
    type_~ : @buslane.Type,
    reason~ : EntryInvocationFailure
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
  match self {
    InvalidCommand(message~) => message
    error => error.to_command_report().render_human()
  }
}

///|
fn CliError::to_command_report(self : CliError) -> CommandReport {
  match self {
    InvalidCommand(_) =>
      abort(
        "internal Lane CLI bug: argparse diagnostics are not command reports",
      )
    LaneHomeNotConfigured =>
      command_report(
        code="E6015",
        title="`LANE_HOME` is not configured",
        details=[
          "Set `LANE_HOME` to the Lane installation directory so its `basic` subdirectory can be loaded.",
        ],
        suggestions=[
          command_suggestion(
            "Example:",
            command="export LANE_HOME=/path/to/lane-home",
          ),
          command_suggestion(
            "To compile without the default Basic library:",
            command="lane check --no-basic Main.lane",
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
    InvalidLinkExport(export_~) =>
      command_report(
        code="E6010",
        title="invalid link export `\{export_}`",
        fields=[command_report_field("expected", "Module.value:wasm_name")],
        details=[
          "Repeat `--export` to expose multiple functions from one WebAssembly module.",
        ],
        suggestions=[
          command_suggestion(
            "Example:",
            command="lane link --export Main.main:_start -o program.wasm Main.lmo",
          ),
        ],
      )
    DuplicateLinkExportName(name~) =>
      command_report(
        code="E6015",
        title="duplicate WebAssembly export name `\{name}`",
        details=["Every public name in one WebAssembly module must be unique."],
        suggestions=[
          command_suggestion(
            "Choose distinct names after `:` in the repeated `--export` arguments.",
          ),
        ],
      )
    ReservedLinkExportName(name~) =>
      command_report(
        code="E6016",
        title="WebAssembly export name `\{name}` is reserved",
        details=[
          "Lane emits the canonical linear memory under this public name.",
        ],
        suggestions=[
          command_suggestion(
            "Choose a different name after `:` in the `--export` argument.",
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
        title="couldn't lower the executable to a physical program",
        fields=[command_report_field("reason", message)],
      )
    ExecutionImageLoad(message~) =>
      command_report(
        code="E6012",
        title="couldn't load the WebAssembly execution image",
        fields=[command_report_field("reason", message)],
      )
    ExecutionFailed(error) => execution_failure_report(error)
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
          command_report_field(
            "expected", "() -> Unit with only effects supported by the Lane CLI",
          ),
        ],
        details=[reason.to_human_note()],
        suggestions=[
          command_suggestion(
            "Export a zero-parameter `pub fn` that returns `Unit` with only `Io`, `Panic`, or closed External Effects.",
          ),
          command_suggestion(
            "Use `lane inspect <artifact>` to inspect public entries and artifact metadata.",
          ),
        ],
      )
    ExportNotExecutable(name~, type_~, reason~) =>
      command_report(
        code="E6017",
        title="entry `\{name}` cannot be exported to WebAssembly",
        fields=[
          command_report_field("requested type", render_buslane_type(type_)),
          command_report_field(
            "expected", "parameters and result in Unit, I32, I64, F32, or F64",
          ),
        ],
        details=[reason.to_human_note()],
        suggestions=[
          command_suggestion(
            "Expose a public function with a stable Core WebAssembly scalar ABI and effects supported by the Lane CLI.",
          ),
          command_suggestion(
            "Use `lane inspect <artifact>` to inspect public entries and artifact metadata.",
          ),
        ],
      )
    EntryNotInvocable(name~, type_~, reason~) =>
      command_report(
        code="E6009",
        title="entry `\{name}` cannot be invoked by this command",
        fields=[
          command_report_field("requested type", render_buslane_type(type_)),
          command_report_field("expected", "() -> Unit"),
        ],
        details=[
          match reason {
            HasParameters(count~) =>
              "The selected function has \{count} source parameter(s), but this command does not supply arguments."
            ReturnsNonUnit(result~) =>
              "The selected function returns `\{render_buslane_type(result)}`, but this command does not consume a result value."
          },
        ],
        suggestions=[
          command_suggestion(
            "Export a zero-parameter wrapper that returns `Unit`.",
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
fn execution_failure_report(
  error : @lane_runtime.ExecutionError,
) -> CommandReport {
  command_report(code="E6013", title="WebAssembly execution failed", fields=[
    command_report_field("reason", "\{Repr(error)}"),
  ])
}

///|
fn @executable.EntryAdmissionFailure::to_human_note(
  self : @executable.EntryAdmissionFailure,
) -> String {
  match self {
    NotFunction => "The selected public entry is a value, not a function."
    UnsupportedParameter(index~, type_~) =>
      "Parameter \{index + 1} has unsupported WebAssembly export type `\{render_buslane_type(type_)}`."
    UnsupportedResult(result~) =>
      "The selected function returns unsupported WebAssembly export type `\{render_buslane_type(result)}`."
    HasUnsupportedEffects(effects~) =>
      "The selected function requires unsupported effect(s): " +
      effects.map(render_buslane_effect).join(", ") +
      "."
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
  { code, title, fields, details, suggestions, }
}

///|
fn command_report_field(name : String, value : String) -> CommandReportField {
  { name, value, }
}

///|
fn command_suggestion(message : String, command? : String) -> CommandSuggestion {
  { message, command, }
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
fn available_entries_text(entries : Array[@compile.CompiledEntry]) -> String {
  let names = entries.map(display_entry)
  if names.is_empty() {
    "(none)"
  } else {
    names.join(", ")
  }
}
