///|
fn read_test_prelude() -> String {
  read_prelude(Some("../stdlib")) catch {
    _ => abort("failed to read prelude")
  }
}

///|
test "stdlib option resolves prelude path" {
  inspect(
    prelude_path(Some("/tmp/lane-lib")),
    content="/tmp/lane-lib/prelude.lane",
  )
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
    render_entry_value(runtime.lookup(entry.value), entry.type_),
    content="3 : Int",
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
  inspect(
    render_entry_value(runtime.lookup(entry.value), entry.type_),
    content="<function> : (Int) -> Int",
  )
}

///|
test "render primitive entry values with source type annotations" {
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::bool(true),
      Primitive(Bool),
    ),
    content="true : Bool",
  )
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::string("lane"),
      Primitive(String),
    ),
    content="\"lane\" : String",
  )
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::unit(),
      Primitive(Unit),
    ),
    content="() : Unit",
  )
}
