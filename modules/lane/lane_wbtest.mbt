///|
test "parse run target from file and entry suffix" {
  let target = parse_run_target("examples/main.lane:answer")
  inspect(target.file, content="examples/main.lane")
  inspect(target.entry, content="answer")
}

///|
test "run selected public value through buslane interpreter" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
      #|let hidden : Int = 1
    ),
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
    content="42 : Int",
  )
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "selected public function entry renders as function" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub fn id(x : Int) -> Int { x }
    ),
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
