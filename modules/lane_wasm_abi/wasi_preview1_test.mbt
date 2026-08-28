///|
test "WASI Preview 1 catalog owns complete supported import contracts" {
  debug_inspect(
    wasi_preview1_imports().map(WasiPreview1Import::contract),
    content=(
      #|[
      #|  {
      #|    module_name: "wasi_snapshot_preview1",
      #|    field_name: "fd_write",
      #|    parameters: [Direct(I32), Direct(I32), Direct(I32), Direct(I32)],
      #|    result: Direct(I32),
      #|  },
      #|  {
      #|    module_name: "wasi_snapshot_preview1",
      #|    field_name: "proc_exit",
      #|    parameters: [Direct(I32)],
      #|    result: Unit,
      #|  },
      #|]
    ),
  )
}
