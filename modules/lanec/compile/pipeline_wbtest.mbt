///|
test "compile source records intrinsic and runtime import origins" {
  let result = compile_source_for_test(
    (
      #|module Test
      #|pub let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let _host : (I64) -> I64 = extern("lane.test", "lane.test.host")
      #|let _private_value : I64 = 1
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  debug_inspect(
    (
      result.externals.builtins.map(fn(external) { external.intrinsic().name() }),
      result.externals.runtime_imports.map(fn(import_) {
        (import_.contract.module_name, import_.contract.field_name)
      }),
    ),
    content=(
      #|(["%i64_add"], [("lane.test", "lane.test.host")])
    ),
  )
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="i64_add",
  )
  guard result.program is Some(_) else { abort("expected Buslane program") }
}

///|
test "compile verifies handler around effectful function call" {
  let result = compile_source_for_test(
    (
      #|module Test
      #|effect Console {
      #|  read() -> I64
      #|}
      #|fn read_int() -> I64 ! Console {
      #|  Console::read!()
      #|}
      #|pub fn program() -> I64 {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  guard result.program is Some(program) else {
    abort("expected Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}
