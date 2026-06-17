///|
using @argparse {type Command}

///|
fn lsp_command_spec() -> Command {
  Command(
    "lane_lsp",
    about="Lane2 native language server.",
    flags=[
      FlagArg("stdio", long="stdio", hidden=true, about="Use stdio transport."),
    ],
    options=[
      OptionArg(
        "stdlib",
        long="stdlib",
        env="LANE_STDLIB",
        about="Path to the Lane standard library root.",
      ),
    ],
  )
}

///|
fn parse_lsp_stdlib() -> String? raise {
  optional_value(lsp_command_spec().parse(), "stdlib")
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  guard matches.values.get(name) is Some(values) else { return None }
  values.get(0)
}
