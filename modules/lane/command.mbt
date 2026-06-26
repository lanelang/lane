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
    emit_object~ : String?
  )
  Fmt(files~ : Array[String], check~ : Bool, deny~ : Bool)
  Link(interfaces~ : Array[String], objects~ : Array[String], root~ : String?)
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
        positionals=[PositionArg("file")],
      ),
      Command("link", about="Link compiled Lane module object artifacts.", options=[
        interface_option(),
        object_option(),
        root_option(),
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
            ),
          )
        Err(message) => Err(message)
      }
    Some(("link", child)) =>
      Ok(
        Link(
          interfaces=values(child, "interface"),
          objects=values(child, "object"),
          root=optional_value(child, "root"),
        ),
      )
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
fn emit_interface_option() -> @argparse.OptionArg {
  OptionArg(
    "emit-interface",
    long="emit-interface",
    about="Write module interface text artifact.",
  )
}

///|
fn emit_object_option() -> @argparse.OptionArg {
  OptionArg(
    "emit-object",
    long="emit-object",
    about="Write module object text artifact.",
  )
}

///|
fn object_option() -> @argparse.OptionArg {
  OptionArg(
    "object",
    long="object",
    action=Append,
    about="Compiled Lane module object text artifact to link.",
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
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  guard matches.flags.get(name) is Some(value) else { return false }
  value
}
