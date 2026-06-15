///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(file~ : String)
  Run(file~ : String, entry~ : String)
}

///|
fn lane_command_spec() -> Command {
  Command(
    "lane",
    about="Lane2 native command line tool.",
    subcommand_required=true,
    subcommands=[
      Command("check", about="Check a single Lane source file.", positionals=[
        PositionArg("file"),
      ]),
      Command(
        "run",
        about="Run a selected top-level entry from a single Lane source file.",
        options=[OptionArg("entry", long="entry", required=true)],
        positionals=[PositionArg("file")],
      ),
    ],
  )
}

///|
fn parse_lane_command() -> LaneCommand raise {
  let matches = lane_command_spec().parse()
  match matches.subcommand {
    Some(("check", child)) => Check(file=required_value(child, "file"))
    Some(("run", child)) =>
      Run(
        file=required_value(child, "file"),
        entry=required_value(child, "entry"),
      )
    _ => fail_with_message("unknown lane command")
  }
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
