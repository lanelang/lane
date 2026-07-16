///|
test "generated LoisVM Wasm text parses as WAT" {
  let body : @bytecode.FunctionBody = {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let module_ = match @compiler.compile(image) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{to_repr(error)}")
  }
  let wat = @compiler.module_to_wat(module_)
  ignore(@wat.parse(wat)) catch {
    error => fail(@wat.format_wat_error(error, wat))
  }
}
