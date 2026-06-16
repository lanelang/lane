///|
fn read_test_prelude() -> String {
  @fs.read_file_to_string(prelude_path, encoding="utf8") catch {
    _ => abort("failed to read prelude")
  }
}

///|
test "run selected value through prelude buslane interpreter" {
  let result = @compile.compile_with_prelude(
    read_test_prelude(),
    "let answer : Int = 1 + 2\n",
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  )
  let entry = find_entry(result.entries, "answer")
  inspect(
    @prettyprinter.render(runtime.lookup(entry.value), width=100),
    content="int 3",
  )
}

///|
test "selected function entry renders as function" {
  let result = @compile.compile_with_prelude(
    read_test_prelude(),
    "fn id(x : Int) -> Int { x }\n",
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  )
  let entry = find_entry(result.entries, "id")
  assert_true(runtime.lookup(entry.value).is_function())
}
