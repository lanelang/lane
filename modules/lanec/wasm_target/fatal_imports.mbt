///|
fn fatal_write_import_contract() -> @wasm_abi.ImportContract {
  {
    module_name: "wasi_snapshot_preview1",
    field_name: "fd_write",
    parameters: [Direct(I32), GuestAddress, Direct(I32), GuestAddress],
    result: Direct(I32),
  }
}

///|
fn process_exit_import_contract() -> @wasm_abi.ImportContract {
  {
    module_name: "wasi_snapshot_preview1",
    field_name: "proc_exit",
    parameters: [Direct(I32)],
    result: Unit,
  }
}
