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
  Exec(program~ : String, no_jit~ : Bool)
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
    no_basic~ : Bool,
    no_jit~ : Bool
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
        positionals=[source_positional_arg()],
      ),
      Command(
        "run",
        about="Run a selected top-level entry from a single Lane source file.",
        options=[lib_option(), lib_dir_option()],
        flags=[no_basic_flag(), no_jit_flag()],
        positionals=[run_target_positional_arg()],
      ),
      Command(
        "explore",
        about="Write an HTML report for every curated compiler stage.",
        options=[
          lib_option(),
          lib_dir_option(),
          output_option("Write the HTML compiler-stage report here."),
        ],
        flags=[no_basic_flag()],
        positionals=[run_target_positional_arg()],
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
        positionals=[source_positional_arg()],
      ),
      Command("inspect", about="Dump a compiled Lane module artifact.", positionals=[
        artifact_positional_arg("artifact", "Artifact to dump."),
      ]),
      Command(
        "link",
        about="Link compiled Lane module object artifacts.",
        options=[
          link_entry_option(),
          output_option(
            "Write the linked program artifact here, conventionally `.lbp`.",
          ),
        ],
        flags=[verbose_flag()],
        positionals=[
          PositionArg(
            "objects",
            num_args=ValueRange(lower=1),
            about="Supply one object artifact for every module reachable from the selected entry.",
          ),
        ],
      ),
      Command(
        "exec",
        about="Run a linked Lane program artifact.",
        flags=[no_jit_flag()],
        positionals=[
          artifact_positional_arg("program", "Linked program artifact to run."),
        ],
      ),
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
        positionals=[
          PositionArg(
            "files",
            num_args=ValueRange(lower=1),
            about="Lane source files to format.",
          ),
        ],
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
      Ok(
        Check(
          file=single_value(child, "file"),
          libs=values(child, "lib"),
          lib_dirs=values(child, "lib-dir"),
          no_basic=flag(child, "no-basic"),
          deny=flag(child, "deny"),
        ),
      )
    Some(("run", child)) =>
      match parse_run_target(single_value(child, "target")) {
        Ok(target) =>
          Ok(
            Run(
              file=target.file,
              entry=target.entry,
              libs=values(child, "lib"),
              lib_dirs=values(child, "lib-dir"),
              no_basic=flag(child, "no-basic"),
              no_jit=flag(child, "no-jit"),
            ),
          )
        Err(message) => Err(message)
      }
    Some(("explore", child)) => {
      let target_text = single_value(child, "target")
      match parse_run_target(target_text) {
        Ok(target) =>
          Ok(
            Explore(
              file=target.file,
              entry=target.entry,
              libs=values(child, "lib"),
              lib_dirs=values(child, "lib-dir"),
              no_basic=flag(child, "no-basic"),
              output=single_value(child, "output"),
            ),
          )
        Err(_) => Err(InvalidExploreTarget(target=target_text))
      }
    }
    Some(("compile", child)) =>
      Ok(
        Compile(
          file=single_value(child, "file"),
          interfaces=values(child, "interface"),
          interface_output=single_value(child, "interface-output"),
          object_output=single_value(child, "object-output"),
          verbose=flag(child, "verbose"),
        ),
      )
    Some(("inspect", child)) =>
      Ok(Inspect(artifact=single_value(child, "artifact")))
    Some(("link", child)) => {
      let entry_text = single_value(child, "entry")
      match parse_public_entry_name(entry_text) {
        Ok(entry) =>
          Ok(
            Link(
              objects=values(child, "objects"),
              entry~,
              output=single_value(child, "output"),
              verbose=flag(child, "verbose"),
            ),
          )
        Err(_) => Err(InvalidLinkEntry(entry=entry_text))
      }
    }
    Some(("exec", child)) => {
      let program = single_value(child, "program")
      if program.contains(":") {
        Err(InvalidExecTarget(target=program))
      } else {
        Ok(Exec(program~, no_jit=flag(child, "no-jit")))
      }
    }
    Some(("fmt", child)) =>
      Ok(Fmt(files=values(child, "files"), check=flag(child, "check")))
    Some(("lsp", child)) => Ok(Lsp(stdio=flag(child, "stdio")))
    _ =>
      abort(
        "internal Lane CLI bug: argparse returned an unrecognized required subcommand",
      )
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
fn source_positional_arg() -> @argparse.PositionArg {
  PositionArg(
    "file",
    num_args=@argparse.ValueRange::single(),
    about="Lane source file to read.",
  )
}

///|
fn run_target_positional_arg() -> @argparse.PositionArg {
  PositionArg(
    "target",
    num_args=@argparse.ValueRange::single(),
    about="Source file and entry to select, as FILE:ENTRY.",
  )
}

///|
fn artifact_positional_arg(
  name : String,
  about : String,
) -> @argparse.PositionArg {
  PositionArg(name, num_args=@argparse.ValueRange::single(), about~)
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
fn no_jit_flag() -> @argparse.FlagArg {
  FlagArg(
    "no-jit",
    long="no-jit",
    about="Execute generated WebAssembly with the Wasmoon interpreter.",
  )
}

///|
fn interface_option() -> @argparse.OptionArg {
  OptionArg(
    "interface",
    short='i',
    long="interface",
    action=Append,
    about="Module interface artifact to import, conventionally `.lmi`.",
  )
}

///|
fn interface_output_option() -> @argparse.OptionArg {
  OptionArg(
    "interface-output",
    short='I',
    long="interface-output",
    required=true,
    about="Write the module interface artifact here, conventionally `.lmi`.",
  )
}

///|
fn object_output_option() -> @argparse.OptionArg {
  OptionArg(
    "object-output",
    short='o',
    long="object-output",
    required=true,
    about="Write the module object artifact here, conventionally `.lmo`.",
  )
}

///|
fn output_option(about : String) -> @argparse.OptionArg {
  OptionArg("output", short='o', long="output", required=true, about~)
}

///|
fn link_entry_option() -> @argparse.OptionArg {
  OptionArg(
    "entry",
    long="entry",
    required=true,
    about="Select the exported entry for the linked executable artifact, such as Main.main.",
  )
}

///|
fn verbose_flag() -> @argparse.FlagArg {
  FlagArg("verbose", long="verbose", about="Print successful artifact writes.")
}

///|
fn single_value(matches : @argparse.Matches, name : String) -> String {
  guard matches.values.get(name) is Some(values) else {
    abort("internal Lane CLI bug: argparse omitted required argument `\{name}`")
  }
  guard values is [value] else {
    abort(
      "internal Lane CLI bug: argparse produced a non-single value for `\{name}`",
    )
  }
  value
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
