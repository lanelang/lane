///|
test "loader resolves all runtime imports atomically" {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.identity",
      abi_major=1,
      parameters=[Int],
      result=Int,
      invoke=fn(_context, arguments) {
        match arguments {
          [value] => value
          _ => Unit
        }
      },
    ),
  )
  let body : @bytecode.FunctionBody = {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(body),
      RuntimeImport({
        abi_major: 1,
        user_arity: 1,
        symbol: "lane.test.identity",
      }),
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  assert_true(load(image, registry) is Ok(_))
  let missing = @runtime.RuntimeRegistry::new()
  let error = match load(image, missing) {
    Err(error) => Some(error)
    Ok(_) => None
  }
  assert_eq(error, Some(UnresolvedImport(symbol="lane.test.identity")))
}
