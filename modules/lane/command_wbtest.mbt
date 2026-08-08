///|
test "lane help lets argparse own usage presentation" {
  inspect(
    lane_command_spec().render_help(),
    content=(
      #|Usage: lane <command>
      #|
      #|Lane2 native command line tool.
      #|
      #|Commands:
      #|  check    Check a single Lane source file.
      #|  run      Run a selected top-level entry from a single Lane source file.
      #|  explore  Write an HTML report for every curated compiler stage.
      #|  compile  Compile one Lane source file into module interface/object artifacts.
      #|  inspect  Dump a compiled Lane module artifact.
      #|  link     Link compiled Lane module object artifacts.
      #|  exec     Run a linked Lane program artifact.
      #|  fmt      Format Lane source files.
      #|  lsp      Run the Lane language server.
      #|  help     Print help for the subcommand(s).
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}

///|
fn lane_command_parse_failure(argv : ArrayView[String]) -> String {
  try lane_command_spec().parse(argv~, env=Map([])) catch {
    error => InvalidCommand(message="\{error}").render_human()
  } noraise {
    _ => abort("expected Lane command parsing to fail")
  }
}

///|
test "argparse owns required Lane option validation" {
  inspect(
    [
      lane_command_parse_failure(["compile", "Main.lane"]),
      lane_command_parse_failure(["explore", "Main.lane:main"]),
      lane_command_parse_failure(["link", "Main.lmo"]),
    ].join("\n---\n"),
    content=(
      #|error: the following required argument was not provided: 'interface-output'
      #|
      #|Usage: lane compile --interface-output <interface-output> --object-output <object-output> [options] <file>
      #|
      #|Compile one Lane source file into module interface/object artifacts.
      #|
      #|Arguments:
      #|  file  Lane source file to read.
      #|
      #|Options:
      #|  -h, --help                                 Show help information.
      #|  --verbose                                  Print successful artifact writes.
      #|  -i, --interface <interface>                Module interface artifact to import, conventionally `.lmi`.
      #|  -I, --interface-output <interface-output>  Write the module interface artifact here, conventionally `.lmi`.
      #|  -o, --object-output <object-output>        Write the module object artifact here, conventionally `.lmo`.
      #|
      #|---
      #|error: the following required argument was not provided: 'output'
      #|
      #|Usage: lane explore --output <output> [options] <target>
      #|
      #|Write an HTML report for every curated compiler stage.
      #|
      #|Arguments:
      #|  target  Source file and entry to select, as FILE:ENTRY.
      #|
      #|Options:
      #|  -h, --help             Show help information.
      #|  --no-basic             Do not load the default $LANE_HOME/basic library directory.
      #|  --lib <lib>            Lane library source file to include.
      #|  --lib-dir <lib-dir>    Lane library directory to include.
      #|  -o, --output <output>  Write the HTML compiler-stage report here.
      #|
      #|---
      #|error: the following required argument was not provided: 'entry'
      #|
      #|Usage: lane link --entry <entry> --output <output> [options] <objects...>
      #|
      #|Link compiled Lane module object artifacts.
      #|
      #|Arguments:
      #|  objects...  Supply one object artifact for every module reachable from the selected entry.
      #|
      #|Options:
      #|  -h, --help             Show help information.
      #|  --verbose              Print successful artifact writes.
      #|  --entry <entry>        Select the exported entry for the linked executable artifact, such as Main.main.
      #|  -o, --output <output>  Write the linked program artifact here, conventionally `.lbp`.
      #|
    ),
  )
}

///|
fn lane_subcommand_values(
  argv : ArrayView[String],
) -> (String, Map[String, Array[String]]) {
  let matches = try! lane_command_spec().parse(argv~, env=Map([]))
  guard matches.subcommand is Some((name, child)) else {
    abort("expected a parsed Lane subcommand")
  }
  (name, child.values)
}

///|
test "argparse accepts complete Lane artifact commands" {
  debug_inspect(
    [
      lane_subcommand_values([
        "compile", "--interface-output", "Main.lmi", "--object-output", "Main.lmo",
        "Main.lane",
      ]),
      lane_subcommand_values([
        "explore", "--output", "report.html", "Main.lane:main",
      ]),
      lane_subcommand_values([
        "link", "--entry", "Main.main", "--output", "program.lbp", "Main.lmo",
      ]),
    ],
    content=(
      #|[
      #|  (
      #|    "compile",
      #|    {
      #|      "interface-output": ["Main.lmi"],
      #|      "object-output": ["Main.lmo"],
      #|      "file": ["Main.lane"],
      #|    },
      #|  ),
      #|  (
      #|    "explore",
      #|    { "output": ["report.html"], "target": ["Main.lane:main"] },
      #|  ),
      #|  (
      #|    "link",
      #|    {
      #|      "entry": ["Main.main"],
      #|      "output": ["program.lbp"],
      #|      "objects": ["Main.lmo"],
      #|    },
      #|  ),
      #|]
    ),
  )
}
