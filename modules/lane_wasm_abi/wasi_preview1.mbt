///|
pub(all) enum WasiPreview1Import {
  FdWrite
  ProcExit
} derive(Debug, Eq)

///|
pub fn WasiPreview1Import::contract(
  self : WasiPreview1Import,
) -> ImportContract {
  match self {
    FdWrite =>
      {
        module_name: "wasi_snapshot_preview1",
        field_name: "fd_write",
        parameters: [Direct(I32), GuestAddress, Direct(I32), GuestAddress],
        result: Direct(I32),
      }
    ProcExit =>
      {
        module_name: "wasi_snapshot_preview1",
        field_name: "proc_exit",
        parameters: [Direct(I32)],
        result: Unit,
      }
  }
}

///|
pub fn wasi_preview1_imports() -> Array[WasiPreview1Import] {
  [FdWrite, ProcExit]
}

///|
pub fn wasi_preview1_contract(field_name : String) -> ImportContract? {
  for import_ in wasi_preview1_imports() {
    let contract = import_.contract()
    if contract.field_name == field_name {
      return Some(contract)
    }
  }
  None
}
