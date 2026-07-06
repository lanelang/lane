///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(
    file~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    deny~ : Bool
  )
  Compile(
    file~ : String,
    interfaces~ : Array[String],
    emit_interface~ : String?,
    emit_object~ : String?,
    verbose~ : Bool
  )
  Fmt(files~ : Array[String], check~ : Bool, deny~ : Bool)
  Inspect(artifact~ : String)
  Link(
    objects~ : Array[String],
    entry~ : String,
    output~ : String,
    verbose~ : Bool
  )
  Lsp(stdio~ : Bool)
  RunObj(program~ : String)
  Run(
    file~ : String,
    entry~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String]
  )
}

///|
fn lane_command_spec() -> Command {
  Command(
    "lane",
    about="Lane2 native command line tool.",
    subcommand_required=true,
    subcommands=[
      Command(
        "check",
        about="Check a single Lane source file.",
        options=[lib_option(), lib_dir_option()],
        flags=[
          FlagArg(
            "deny",
            long="deny",
            about="Treat warnings as check failures.",
          ),
        ],
        positionals=[PositionArg("file")],
      ),
      Command(
        "run",
        about="Run a selected top-level entry from a single Lane source file.",
        options=[lib_option(), lib_dir_option()],
        positionals=[PositionArg("target")],
      ),
      Command(
        "compile",
        about="Compile one Lane source file into module interface/object artifacts.",
        options=[
          interface_option(),
          emit_interface_option(),
          emit_object_option(),
        ],
        flags=[verbose_flag()],
        positionals=[PositionArg("file")],
      ),
      Command("inspect", about="Dump a compiled Lane module artifact.", positionals=[
        PositionArg("artifact"),
      ]),
      Command(
        "link",
        about="Link compiled Lane module object artifacts.",
        options=[link_entry_option(), output_option()],
        flags=[verbose_flag()],
        positionals=[PositionArg("objects", num_args=ValueRange(lower=1))],
      ),
      Command("runobj", about="Run a linked Lane program artifact.", positionals=[
        PositionArg("program"),
      ]),
      Command(
        "fmt",
        about="Format Lane source files.",
        flags=[
          FlagArg(
            "check",
            long="check",
            about="Report files that are not formatted without writing them.",
          ),
          FlagArg(
            "deny",
            long="deny",
            about="Treat formatting changes as failures without writing them.",
          ),
        ],
        positionals=[PositionArg("files", num_args=ValueRange(lower=1))],
      ),
      Command("lsp", about="Run the Lane language server.", flags=[
        FlagArg(
          "stdio",
          long="stdio",
          hidden=true,
          about="Use stdio transport.",
        ),
      ]),
    ],
  )
}

///|
fn parse_lane_command() -> Result[LaneCommand, CliError] {
  let matches = lane_command_spec().parse() catch {
    error => return Err(InvalidCommand(message="\{error}"))
  }
  match matches.subcommand {
    Some(("check", child)) =>
      match required_value(child, "file") {
        Ok(file) =>
          Ok(
            Check(
              file~,
              libs=values(child, "lib"),
              lib_dirs=values(child, "lib-dir"),
              deny=flag(child, "deny"),
            ),
          )
        Err(message) => Err(message)
      }
    Some(("run", child)) =>
      match required_value(child, "target") {
        Ok(target_text) =>
          match parse_run_target(target_text) {
            Ok(target) =>
              Ok(
                Run(
                  file=target.file,
                  entry=target.entry,
                  libs=values(child, "lib"),
                  lib_dirs=values(child, "lib-dir"),
                ),
              )
            Err(message) => Err(message)
          }
        Err(message) => Err(message)
      }
    Some(("compile", child)) =>
      match required_value(child, "file") {
        Ok(file) =>
          Ok(
            Compile(
              file~,
              interfaces=values(child, "interface"),
              emit_interface=optional_value(child, "emit-interface"),
              emit_object=optional_value(child, "emit-object"),
              verbose=flag(child, "verbose"),
            ),
          )
        Err(message) => Err(message)
      }
    Some(("inspect", child)) =>
      match required_value(child, "artifact") {
        Ok(artifact) => Ok(Inspect(artifact~))
        Err(message) => Err(message)
      }
    Some(("link", child)) =>
      match (required_value(child, "entry"), required_value(child, "output")) {
        (Ok(entry_text), Ok(output)) =>
          match public_entry_name_to_internal(entry_text) {
            Ok(entry) =>
              Ok(
                Link(
                  objects=values(child, "objects"),
                  entry~,
                  output~,
                  verbose=flag(child, "verbose"),
                ),
              )
            Err(_) => Err(InvalidLinkEntry(entry=entry_text))
          }
        (Err(message), _) | (_, Err(message)) => Err(message)
      }
    Some(("runobj", child)) =>
      match required_value(child, "program") {
        Ok(program) =>
          if program.contains(":") {
            Err(InvalidRunObjTarget(target=program))
          } else {
            Ok(RunObj(program~))
          }
        Err(message) => Err(message)
      }
    Some(("fmt", child)) =>
      Ok(
        Fmt(
          files=values(child, "files"),
          check=flag(child, "check"),
          deny=flag(child, "deny"),
        ),
      )
    Some(("lsp", child)) => Ok(Lsp(stdio=flag(child, "stdio")))
    _ => Err(UnknownCommand)
  }
}

///|
priv struct RunTarget {
  file : String
  entry : String
}

///|
fn parse_run_target(target : String) -> Result[RunTarget, CliError] {
  let parts = target.split(":").collect()
  if parts.length() != 2 || parts[0].is_empty() || parts[1].is_empty() {
    return Err(InvalidRunTarget(target~))
  }
  Ok({ file: parts[0].to_owned(), entry: parts[1].to_owned() })
}

///|
fn public_entry_name_to_internal(name : String) -> Result[String, Unit] {
  let parts = name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return Err(())
  }
  for part in parts {
    if part.is_empty() {
      return Err(())
    }
  }
  let value = parts[parts.length() - 1]
  let module_path = parts[:parts.length() - 1].join(".")
  Ok("\{module_path}::\{value}")
}

///|
fn lib_option() -> @argparse.OptionArg {
  OptionArg(
    "lib",
    long="lib",
    action=Append,
    about="Lane library source file to include.",
  )
}

///|
fn lib_dir_option() -> @argparse.OptionArg {
  OptionArg(
    "lib-dir",
    long="lib-dir",
    action=Append,
    about="Lane library directory to include.",
  )
}

///|
fn interface_option() -> @argparse.OptionArg {
  OptionArg(
    "interface",
    short='i',
    long="interface",
    action=Append,
    about="Compiled Lane module interface artifact to import.",
  )
}

///|
fn emit_interface_option() -> @argparse.OptionArg {
  OptionArg(
    "emit-interface",
    short='t',
    long="emit-interface",
    about="Write module interface binary artifact.",
  )
}

///|
fn emit_object_option() -> @argparse.OptionArg {
  OptionArg(
    "emit-object",
    short='o',
    long="emit-object",
    about="Write module object binary artifact.",
  )
}

///|
fn output_option() -> @argparse.OptionArg {
  OptionArg("output", short='o', long="output", about="Write output artifact.")
}

///|
fn link_entry_option() -> @argparse.OptionArg {
  OptionArg(
    "entry",
    long="entry",
    about="Select the exported entry for the linked executable artifact, such as Main.main.",
  )
}

///|
fn verbose_flag() -> @argparse.FlagArg {
  FlagArg("verbose", long="verbose", about="Print successful artifact writes.")
}

///|
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> Result[String, CliError] {
  guard matches.values.get(name) is Some(values) else {
    return Err(MissingArgument(name~))
  }
  guard values.get(0) is Some(value) else { return Err(MissingArgument(name~)) }
  Ok(value)
}

///|
fn values(matches : @argparse.Matches, name : String) -> Array[String] {
  guard matches.values.get(name) is Some(values) else { return [] }
  values
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  guard matches.values.get(name) is Some(values) else { return None }
  values.get(0)
}

///|
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  guard matches.flags.get(name) is Some(value) else { return false }
  value
}
