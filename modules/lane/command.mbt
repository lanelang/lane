///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(file~ : String, libs~ : Array[String], lib_dirs~ : Array[String])
  Fmt(files~ : Array[String], check~ : Bool)
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
    ],
  )
}

///|
fn parse_lane_command() -> Result[LaneCommand, String] {
  let matches = lane_command_spec().parse() catch {
    error => return Err("\{error}")
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
    Some(("fmt", child)) =>
      Ok(Fmt(files=values(child, "files"), check=flag(child, "check")))
    _ => Err("unknown lane command")
  }
}

///|
priv struct RunTarget {
  file : String
  entry : String
}

///|
fn parse_run_target(target : String) -> Result[RunTarget, String] {
  let parts = target.split(":").collect()
  if parts.length() != 2 || parts[0].is_empty() || parts[1].is_empty() {
    return Err("run target must be FILE:ENTRY")
  }
  Ok({ file: parts[0].to_owned(), entry: parts[1].to_owned() })
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
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> Result[String, String] {
  guard matches.values.get(name) is Some(values) else {
    return Err("missing argument: " + name)
  }
  guard values.get(0) is Some(value) else {
    return Err("missing argument: " + name)
  }
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
