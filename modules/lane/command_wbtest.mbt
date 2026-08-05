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
      #|  runobj   Run a linked Lane program artifact.
      #|  exec     Compatibility alias for `lane runobj`.
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
