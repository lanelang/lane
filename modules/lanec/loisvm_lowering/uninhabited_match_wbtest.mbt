///|
test "empty data match lowers to unreachable bytecode" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let void_id = metadata.define_type("Void", [])
  let void_type = @buslane.Type::Constructor(void_id)
  let unit_type = @buslane.Type::Primitive(Unit)
  let read_type = test_function_type([], void_type)
  let read = metadata.define_value("read_void", Function, read_type)
  let binder = metadata.define_value("void", MatchBinder, void_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: read,
          rhs: Function({
            parameters: [],
            result_type: void_type,
            body: Call(Ref(read), []),
          }),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Call(Ref(read), []),
            binder,
            result_type: unit_type,
            alternatives: [],
          }),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(program).is_ok())
  let image = match
    lower_test_executable_to_bytecode(
      program,
      { builtins: [], runtime_imports: [] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[image.entry.value - 1] is BytecodeBody(main_body) else {
    fail("expected the entry to select the main bytecode body")
  }
  assert_true(main_body.blocks.any(block => block.terminator is Unreachable))
}
