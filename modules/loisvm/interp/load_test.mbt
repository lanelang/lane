///|
test "loader resolves all runtime imports atomically" {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.identity",
      abi_major=1,
      parameters=[I64],
      result=I64,
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
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Value(I64, Trivial, ScalarValue),
      },
    ],
    globals: [],
    functions: [
      BytecodeBody(body),
      RuntimeImport({
        abi_major: 1,
        parameters: [I64],
        result: I64,
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
  assert_eq(
    error,
    Some(RuntimeImportResolution(UnresolvedImport(symbol="lane.test.identity"))),
  )
  let wrong_parameter = @runtime.RuntimeRegistry::new()
  wrong_parameter.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.identity",
      abi_major=1,
      parameters=[Bool],
      result=I64,
      invoke=fn(_context, _arguments) { I64(0L) },
    ),
  )
  let wrong_result = @runtime.RuntimeRegistry::new()
  wrong_result.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.identity",
      abi_major=1,
      parameters=[I64],
      result=Bool,
      invoke=fn(_context, _arguments) { Bool(false) },
    ),
  )
  let parameter_error = match load(image, wrong_parameter) {
    Err(error) => Some(error)
    Ok(_) => None
  }
  let result_error = match load(image, wrong_result) {
    Err(error) => Some(error)
    Ok(_) => None
  }
  debug_inspect(
    (parameter_error, result_error),
    content=(
      #|(
      #|  Some(
      #|    RuntimeImportResolution(
      #|      ParameterKindsMismatch(
      #|        symbol="lane.test.identity",
      #|        expected=[I64],
      #|        actual=[Bool],
      #|      ),
      #|    ),
      #|  ),
      #|  Some(
      #|    RuntimeImportResolution(
      #|      ResultKindMismatch(
      #|        symbol="lane.test.identity",
      #|        expected=I64,
      #|        actual=Bool,
      #|      ),
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "loader rejects call result ownership mismatch before execution" {
  let caller : @bytecode.FunctionBody = {
    slots: [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect({ value: 2, }, None, [], [], Some({ value: 0, })),
          Release({ value: 0, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let target : @bytecode.FunctionBody = {
    slots: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstI32({ value: 0, }, 42)],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [],
        result: Value(I32, Trivial, ScalarValue),
      },
    ],
    functions: [BytecodeBody(caller), BytecodeBody(target)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let error = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(
    error,
    Some(
      InvalidBytecode(
        InvalidBytecode(
          site=Instruction({ value: 1, }, { value: 0, }, 0),
          detail="call result ABI does not match destination slot",
        ),
      ),
    ),
  )
}
