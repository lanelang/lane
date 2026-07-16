///|
test "runtime registry resolves imports by complete direct ABI signature" {
  let registry = RuntimeRegistry::new()
  registry.register(
    RuntimeBinding::new(
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
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_parameters=[Int],
      expected_result=Int,
    )
    is Ok(_),
  )
  assert_true(
    registry.resolve(
      "lane.test.missing",
      expected_abi_major=1,
      expected_parameters=[Int],
      expected_result=Int,
    )
    is Err(UnresolvedImport(symbol="lane.test.missing")),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=2,
      expected_parameters=[Int],
      expected_result=Int,
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
      expected_result=Int,
    )
    is Err(
      ParameterKindsMismatch(
        symbol="lane.test.identity",
        expected=[],
        actual=[Int]
      )
    ),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_parameters=[Int],
      expected_result=Bool,
    )
    is Err(
      ResultKindMismatch(symbol="lane.test.identity", expected=Bool, actual=Int)
    ),
  )
}
