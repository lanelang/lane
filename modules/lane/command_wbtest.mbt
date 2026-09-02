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
        "link", "--export", "Main.main:_start", "--export", "Main.answer:answer",
        "--output", "program.wasm", "Main.lmo",
      ]),
      lane_subcommand_values(["exec", "--entry", "answer", "program.wasm"]),
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
      #|      "export": ["Main.main:_start", "Main.answer:answer"],
      #|      "output": ["program.wasm"],
      #|      "objects": ["Main.lmo"],
      #|    },
      #|  ),
      #|  ("exec", { "entry": ["answer"], "program": ["program.wasm"] }),
      #|]
    ),
  )
}

///|
test "exec keeps the program path independent from entry selection" {
  assert_eq(
    lane_subcommand_values([
      "exec", "--entry", "answer", "C:\\lane\\program.wasm",
    ]),
    ("exec", { "entry": ["answer"], "program": ["C:\\lane\\program.wasm"] }),
  )
}
