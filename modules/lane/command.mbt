///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(file~ : String, libs~ : Array[String], lib_dirs~ : Array[String])
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
        positionals=[PositionArg("file")],
      ),
      Command(
        "run",
        about="Run a selected top-level entry from a single Lane source file.",
        options=[lib_option(), lib_dir_option()],
        positionals=[PositionArg("target")],
      ),
    ],
  )
}

///|
fn parse_lane_command() -> LaneCommand raise {
  let matches = lane_command_spec().parse()
  match matches.subcommand {
    Some(("check", child)) =>
      Check(
        file=required_value(child, "file"),
        libs=values(child, "lib"),
        lib_dirs=values(child, "lib-dir"),
      )
    Some(("run", child)) => {
      let target = parse_run_target(required_value(child, "target"))
      Run(
        file=target.file,
        entry=target.entry,
        libs=values(child, "lib"),
        lib_dirs=values(child, "lib-dir"),
      )
    }
    _ => fail_with_message("unknown lane command")
  }
}

///|
priv struct RunTarget {
  file : String
  entry : String
}

///|
fn parse_run_target(target : String) -> RunTarget {
  let parts = target.split(":").collect()
  if parts.length() != 2 || parts[0].is_empty() || parts[1].is_empty() {
    fail_with_message("run target must be FILE:ENTRY")
  }
  { file: parts[0].to_owned(), entry: parts[1].to_owned() }
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
fn required_value(matches : @argparse.Matches, name : String) -> String {
  guard matches.values.get(name) is Some(values) else {
    fail_with_message("missing argument: " + name)
  }
  guard values.get(0) is Some(value) else {
    fail_with_message("missing argument: " + name)
  }
  value
}

///|
fn values(matches : @argparse.Matches, name : String) -> Array[String] {
  guard matches.values.get(name) is Some(values) else { return [] }
  values
}
