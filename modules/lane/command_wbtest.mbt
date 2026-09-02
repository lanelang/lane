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
      lane_subcommand_values(["exec", "program.wasm:answer"]),
      lane_subcommand_values(["inspect", "Main.lane"]),
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
      #|  ("exec", { "target": ["program.wasm:answer"] }),
      #|  ("inspect", { "input": ["Main.lane"] }),
      #|]
    ),
  )
}

///|
test "exec target preserves a Windows drive separator" {
  guard parse_exec_target("C:\\lane\\program.wasm:answer") is Ok(target) else {
    abort("expected exec target")
  }
  assert_eq(target.file, "C:\\lane\\program.wasm")
  assert_eq(target.entry, "answer")
}
