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
