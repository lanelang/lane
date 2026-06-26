///|
using @argparse {type Command}

///|
enum LaneCommand {
  Check(
    file~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    interfaces~ : Array[String],
    interface_dirs~ : Array[String],
    deny~ : Bool
  )
  Compile(
    file~ : String,
    libs~ : Array[String],
    lib_dirs~ : Array[String],
    interfaces~ : Array[String],
    interface_dirs~ : Array[String],
    out~ : String?,
    out_dir~ : String?
  )
  Fmt(files~ : Array[String], check~ : Bool, deny~ : Bool)
  Link(
    file~ : String?,
    artifacts~ : Array[String],
    artifact_dirs~ : Array[String],
    root~ : String?,
    libs~ : Array[String],
    lib_dirs~ : Array[String]
  )
  Lsp(stdio~ : Bool)
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
        options=[
          lib_option(),
          lib_dir_option(),
          interface_option(),
          interface_dir_option(),
        ],
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
        about="Compile a Lane source file and its explicit library modules.",
        options=[
          lib_option(),
          lib_dir_option(),
          interface_option(),
          interface_dir_option(),
          out_option(),
          out_dir_option(),
        ],
        positionals=[PositionArg("file")],
      ),
      Command(
        "link",
        about="Link a Lane source file or a compiled module artifact.",
        options=[
          lib_option(),
          lib_dir_option(),
          artifact_option(),
          artifact_dir_option(),
          root_option(),
        ],
        positionals=[PositionArg("file", num_args=ValueRange(lower=0, upper=1))],
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
              interfaces=values(child, "interface"),
              interface_dirs=values(child, "interface-dir"),
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
              libs=values(child, "lib"),
              lib_dirs=values(child, "lib-dir"),
              interfaces=values(child, "interface"),
              interface_dirs=values(child, "interface-dir"),
              out=optional_value(child, "out"),
              out_dir=optional_value(child, "out-dir"),
            ),
          )
        Err(message) => Err(message)
      }
    Some(("link", child)) =>
      match optional_single_value(child, "file") {
        Ok(file) =>
          Ok(
            Link(
              file~,
              artifacts=values(child, "artifact"),
              artifact_dirs=values(child, "artifact-dir"),
              root=optional_value(child, "root"),
              libs=values(child, "lib"),
              lib_dirs=values(child, "lib-dir"),
            ),
          )
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
fn interface_option() -> @argparse.OptionArg {
  OptionArg(
    "interface",
    long="interface",
    action=Append,
    about="Compiled Lane module interface artifact to import.",
  )
}

///|
fn interface_dir_option() -> @argparse.OptionArg {
  OptionArg(
    "interface-dir",
    long="interface-dir",
    action=Append,
    about="Directory containing compiled Lane module interface artifacts.",
  )
}

///|
fn out_option() -> @argparse.OptionArg {
  OptionArg("out", long="out", about="Write compiled module artifact JSON.")
}

///|
fn out_dir_option() -> @argparse.OptionArg {
  OptionArg(
    "out-dir",
    long="out-dir",
    about="Write separate module interface/object artifacts into DIR.",
  )
}

///|
fn artifact_option() -> @argparse.OptionArg {
  OptionArg(
    "artifact",
    long="artifact",
    action=Append,
    about="Compiled module artifact JSON to link.",
  )
}

///|
fn artifact_dir_option() -> @argparse.OptionArg {
  OptionArg(
    "artifact-dir",
    long="artifact-dir",
    action=Append,
    about="Directory containing compiled module interface/object artifacts.",
  )
}

///|
fn root_option() -> @argparse.OptionArg {
  OptionArg("root", long="root", about="Root module for artifact linking.")
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
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  guard matches.values.get(name) is Some(values) else { return None }
  values.get(0)
}

///|
fn optional_single_value(
  matches : @argparse.Matches,
  name : String,
) -> Result[String?, String] {
  guard matches.values.get(name) is Some(values) else { return Ok(None) }
  if values.length() > 1 {
    return Err("too many values for: " + name)
  }
  Ok(values.get(0))
}

///|
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  guard matches.flags.get(name) is Some(value) else { return false }
  value
}
