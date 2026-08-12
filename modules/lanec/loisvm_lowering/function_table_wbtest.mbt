///|
fn test_function_table_image(
  entry : @bytecode.FunctionId,
  functions : Array[@vmcfg.FunctionEntry],
) -> @vmcfg.Image {
  {
    entry,
    initializer: None,
    functions,
    data_family_count: 0,
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn test_function_body(
  instructions : Array[@vmcfg.Instruction],
) -> @vmcfg.FunctionEntry {
  Body({
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  })
}

///|
test "function-table canonicalization rejects provenance cardinality drift" {
  let result : Result[
    CanonicalizedFunctionTable,
    FunctionTableCanonicalizationError,
  ] = Ok(
    canonicalize_function_table(test_function_table_image({ value: 1 }, []), [
      InitializerOrchestrator,
    ]),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(OriginCountMismatch(functions=0, origins=1)))
}

///|
test "function-table canonicalization rejects an invalid function reference" {
  let import_ : @bytecode.RuntimeImport = {
    abi_major: 1,
    parameters: [],
    result: Unit,
    symbol: "lane.test.import",
  }
  let result : Result[
    CanonicalizedFunctionTable,
    FunctionTableCanonicalizationError,
  ] = Ok(
    canonicalize_function_table(
      test_function_table_image({ value: 2 }, [RuntimeImport(import_)]),
      [RuntimeImport(source={ index: 0 }, symbol=import_.symbol)],
    ),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidFunctionReference(function={ value: 2 })))
}

///|
test "function-table canonicalization retains only the transitive function closure" {
  let canonical = canonicalize_function_table(
    test_function_table_image({ value: 1 }, [
      test_function_body([CallDirect({ value: 3 }, None, [], [], None)]),
      test_function_body([]),
      test_function_body([]),
    ]),
    [InitializerOrchestrator, CallableAdapter, LayoutConstructor],
  )
  debug_inspect(
    (canonical.image, canonical.provenance),
    content=(
      #|(
      #|  {
      #|    entry: { value: 1 },
      #|    initializer: None,
      #|    functions: [
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [CallDirect({ value: 2 }, None, [], [], None)],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|        },
      #|      ),
      #|    ],
      #|    data_family_count: 0,
      #|    globals: [],
      #|    layouts: [],
      #|    object_shapes: [],
      #|    constants: [],
      #|  },
      #|  [
      #|    { function: { value: 1 }, origins: [InitializerOrchestrator] },
      #|    { function: { value: 2 }, origins: [LayoutConstructor] },
      #|  ],
      #|)
    ),
  )
}

///|
test "function-table canonicalization shares structurally identical callable adapters" {
  let canonical = canonicalize_function_table(
    {
      ..test_function_table_image({ value: 1 }, [
        test_function_body([CallDirect({ value: 2 }, None, [], [], None)]),
        test_function_body([]),
        test_function_body([CallDirect({ value: 4 }, None, [], [], None)]),
        test_function_body([]),
      ]),
      initializer: Some({ value: 3 }),
    },
    [CallableAdapter, CallableAdapter, CallableAdapter, CallableAdapter],
  )
  debug_inspect(
    (canonical.image.functions, canonical.provenance),
    content=(
      #|(
      #|  [
      #|    Body(
      #|      {
      #|        values: [],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [CallDirect({ value: 2 }, None, [], [], None)],
      #|            terminator: Return(None),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    Body(
      #|      {
      #|        values: [],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|      },
      #|    ),
      #|  ],
      #|  [
      #|    {
      #|      function: { value: 1 },
      #|      origins: [CallableAdapter, CallableAdapter],
      #|    },
      #|    {
      #|      function: { value: 2 },
      #|      origins: [CallableAdapter, CallableAdapter],
      #|    },
      #|  ],
      #|)
    ),
  )
}
