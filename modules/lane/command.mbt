///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(
    file~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    no_basic~ : Bool,
    deny~ : Bool
  )
  Compile(
    file~ : String,
    interfaces~ : Array[String],
    interface_output~ : String,
    object_output~ : String,
    verbose~ : Bool
  )
  Fmt(files~ : Array[String], check~ : Bool)
  Inspect(artifact~ : String)
  Link(
    objects~ : Array[String],
    entry~ : PublicEntryName,
    output~ : String,
    verbose~ : Bool
  )
  Lsp(stdio~ : Bool)
  Exec(program~ : String)
  Explore(
    file~ : String,
    entry~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    no_basic~ : Bool,
    output~ : String
  )
  Run(
    file~ : String,
    entry~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    no_basic~ : Bool
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
          no_basic_flag(),
          FlagArg(
            "deny",
            long="deny",
            about="Treat warnings as check failures.",
          ),
        ],
        positionals=[required_positional_arg("file")],
      ),
      Command(
        "run",
        about="Run a selected top-level entry from a single Lane source file.",
        options=[lib_option(), lib_dir_option()],
        flags=[no_basic_flag()],
        positionals=[required_positional_arg("target")],
      ),
      Command(
        "explore",
        about="Write an HTML report for every curated compiler stage.",
        options=[lib_option(), lib_dir_option(), output_option()],
        flags=[no_basic_flag()],
        positionals=[required_positional_arg("target")],
      ),
      Command(
        "compile",
        about="Compile one Lane source file into module interface/object artifacts.",
        options=[
          interface_option(),
          interface_output_option(),
          object_output_option(),
        ],
        flags=[verbose_flag()],
        positionals=[required_positional_arg("file")],
      ),
      Command("inspect", about="Dump a compiled Lane module artifact.", positionals=[
        required_positional_arg("artifact"),
      ]),
      Command(
        "link",
        about="Link compiled Lane module object artifacts.",
        options=[link_entry_option(), output_option()],
        flags=[verbose_flag()],
        positionals=[PositionArg("objects", num_args=ValueRange(lower=1))],
      ),
      Command("exec", about="Execute a linked Lane program artifact.", positionals=[
        required_positional_arg("program"),
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
              no_basic=flag(child, "no-basic"),
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
                  no_basic=flag(child, "no-basic"),
                ),
              )
            Err(message) => Err(message)
          }
        Err(message) => Err(message)
      }
    Some(("explore", child)) =>
      match (required_value(child, "target"), required_value(child, "output")) {
        (Ok(target_text), Ok(output)) =>
          match parse_run_target(target_text) {
            Ok(target) =>
              Ok(
                Explore(
                  file=target.file,
                  entry=target.entry,
                  libs=values(child, "lib"),
                  lib_dirs=values(child, "lib-dir"),
                  no_basic=flag(child, "no-basic"),
                  output~,
                ),
              )
            Err(_) => Err(InvalidExploreTarget(target=target_text))
          }
        (Err(message), _) | (_, Err(message)) => Err(message)
      }
    Some(("compile", child)) =>
      match
        (
          required_value(child, "file"),
          required_value(child, "interface-output"),
          required_value(child, "object-output"),
        ) {
        (Ok(file), Ok(interface_output), Ok(object_output)) =>
          Ok(
            Compile(
              file~,
              interfaces=values(child, "interface"),
              interface_output~,
              object_output~,
              verbose=flag(child, "verbose"),
            ),
          )
        (Err(message), _, _) | (_, Err(message), _) | (_, _, Err(message)) =>
          Err(message)
      }
    Some(("inspect", child)) =>
      match required_value(child, "artifact") {
        Ok(artifact) => Ok(Inspect(artifact~))
        Err(message) => Err(message)
      }
    Some(("link", child)) =>
      match (required_value(child, "entry"), required_value(child, "output")) {
        (Ok(entry_text), Ok(output)) =>
          match parse_public_entry_name(entry_text) {
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
    Some(("exec", child)) =>
      match required_value(child, "program") {
        Ok(program) =>
          if program.contains(":") {
            Err(InvalidExecTarget(target=program))
          } else {
            Ok(Exec(program~))
          }
        Err(message) => Err(message)
      }
    Some(("fmt", child)) =>
      Ok(Fmt(files=values(child, "files"), check=flag(child, "check")))
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
priv struct PublicEntryName {
  module_path_text : String
  value_name : String
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
fn parse_public_entry_name(name : String) -> Result[PublicEntryName, Unit] {
  let parts = name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return Err(())
  }
  for part in parts {
    if part.is_empty() {
      return Err(())
    }
  }
  let value_name = parts[parts.length() - 1]
  let module_path = parts[:parts.length() - 1].join(".")
  Ok({ module_path_text: module_path, value_name })
}

///|
fn required_positional_arg(name : String) -> @argparse.PositionArg {
  PositionArg(name, num_args=ValueRange(lower=1, upper=1))
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
fn no_basic_flag() -> @argparse.FlagArg {
  FlagArg(
    "no-basic",
    long="no-basic",
    about="Do not load the default $LANE_HOME/basic library directory.",
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
fn interface_output_option() -> @argparse.OptionArg {
  OptionArg(
    "interface-output",
    short='I',
    long="interface-output",
    about="Write module interface artifact to this path.",
  )
}

///|
fn object_output_option() -> @argparse.OptionArg {
  OptionArg(
    "object-output",
    short='o',
    long="object-output",
    about="Write module object artifact to this path.",
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
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  guard matches.flags.get(name) is Some(value) else { return false }
  value
}
