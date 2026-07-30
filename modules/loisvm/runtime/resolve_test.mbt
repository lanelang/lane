///|
test "runtime registry resolves imports by complete direct ABI signature" {
  let registry = RuntimeRegistry::new()
  registry.register(
    RuntimeBinding::new(
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
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_parameters=[I64],
      expected_result=I64,
    )
    is Ok(_),
  )
  assert_true(
    registry.resolve(
      "lane.test.missing",
      expected_abi_major=1,
      expected_parameters=[I64],
      expected_result=I64,
    )
    is Err(UnresolvedImport(symbol="lane.test.missing")),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=2,
      expected_parameters=[I64],
      expected_result=I64,
    )
    is Err(
      AbiMismatch(symbol="lane.test.identity", expected_major=2, actual_major=1)
    ),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_parameters=[],
      expected_result=I64,
    )
    is Err(
      ParameterKindsMismatch(
        symbol="lane.test.identity",
        expected=[],
        actual=[I64]
      )
    ),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_parameters=[I64],
      expected_result=Bool,
    )
    is Err(
      ResultKindMismatch(symbol="lane.test.identity", expected=Bool, actual=I64)
    ),
  )
}
