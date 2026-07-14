///|
test "runtime registry resolves imports by symbol, ABI, and arity" {
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
      expected_arity=1,
    )
    is Ok(_),
  )
  assert_true(
    registry.resolve(
      "lane.test.missing",
      expected_abi_major=1,
      expected_arity=1,
    )
    is Err(UnresolvedImport(symbol="lane.test.missing")),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=2,
      expected_arity=1,
    )
    is Err(
      AbiMismatch(symbol="lane.test.identity", expected_major=2, actual_major=1)
    ),
  )
  assert_true(
    registry.resolve(
      "lane.test.identity",
      expected_abi_major=1,
      expected_arity=0,
    )
    is Err(ArityMismatch(symbol="lane.test.identity", expected=0, actual=1)),
  )
}
