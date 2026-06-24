///|
using @argparse {type Command}

///|
fn lsp_command_spec() -> Command {
  Command("lane_lsp", about="Lane2 native language server.", flags=[
    FlagArg("stdio", long="stdio", hidden=true, about="Use stdio transport."),
  ])
}

///|
fn parse_lsp_command() -> Unit raise {
  lsp_command_spec().parse() |> ignore
}
