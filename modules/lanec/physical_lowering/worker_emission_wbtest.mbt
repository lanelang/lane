///|
fn adapter_worker_origin(contract : Int) -> PhysicalFunctionOrigin {
  CallableAdapter(contract={ value: contract, }, reason={
    source: { value: 0, },
    target: { value: 1, },
    differences: [Invocation],
  })
}

///|
test "runtime ABI worker emission facts follow finalized functions" {
  let contract = adapter_worker_origin(0)
  let repeated_origin_in_one_function = runtime_abi_worker_emission_summary([
    { function: { value: 1, }, origins: [contract, contract], },
  ])
  let repeated_contract_in_two_functions = runtime_abi_worker_emission_summary([
    { function: { value: 1, }, origins: [contract], },
    { function: { value: 2, }, origins: [contract], },
  ])
  let distinct_contracts = runtime_abi_worker_emission_summary([
    { function: { value: 1, }, origins: [contract], },
    { function: { value: 2, }, origins: [adapter_worker_origin(1)], },
  ])
  assert_eq(
    (
      repeated_origin_in_one_function, repeated_contract_in_two_functions, distinct_contracts,
    ),
    (
      { emission_count: 1, duplicate_count: 0, },
      { emission_count: 2, duplicate_count: 1, },
      { emission_count: 2, duplicate_count: 0, },
    ),
  )
}
