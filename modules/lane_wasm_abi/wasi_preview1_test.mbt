///|
test "WASI Preview 1 catalog owns complete supported import contracts" {
  debug_inspect(
    wasi_preview1_imports().map(import_ => {
      let contract = import_.contract()
      (
        contract.field_name,
        contract.parameters,
        contract.result,
        import_.effect(),
      )
    }),
    content=(
      #|[
      #|  (
      #|    "fd_write",
      #|    [Direct(I32), GuestAddress, Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "fd_read",
      #|    [Direct(I32), GuestAddress, Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("args_sizes_get", [GuestAddress, GuestAddress], Direct(I32), Io),
      #|  ("args_get", [GuestAddress, GuestAddress], Direct(I32), Io),
      #|  ("environ_sizes_get", [GuestAddress, GuestAddress], Direct(I32), Io),
      #|  ("environ_get", [GuestAddress, GuestAddress], Direct(I32), Io),
      #|  ("proc_exit", [Direct(I32)], Unit, Panic),
      #|  (
      #|    "clock_time_get",
      #|    [Direct(I32), Direct(I64), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_prestat_get", [Direct(I32), GuestAddress], Direct(I32), Io),
      #|  (
      #|    "fd_prestat_dir_name",
      #|    [Direct(I32), GuestAddress, Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_close", [Direct(I32)], Direct(I32), Io),
      #|  ("random_get", [GuestAddress, Direct(I32)], Direct(I32), Io),
      #|  (
      #|    "fd_seek",
      #|    [Direct(I32), Direct(I64), Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_tell", [Direct(I32), GuestAddress], Direct(I32), Io),
      #|  (
      #|    "fd_pread",
      #|    [Direct(I32), GuestAddress, Direct(I32), Direct(I64), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "fd_pwrite",
      #|    [Direct(I32), GuestAddress, Direct(I32), Direct(I64), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_open",
      #|    [
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      Direct(I32),
      #|      Direct(I64),
      #|      Direct(I64),
      #|      Direct(I32),
      #|      GuestAddress,
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_fdstat_get", [Direct(I32), GuestAddress], Direct(I32), Io),
      #|  ("clock_res_get", [Direct(I32), GuestAddress], Direct(I32), Io),
      #|  ("sched_yield", [], Direct(I32), Io),
      #|  (
      #|    "path_create_directory",
      #|    [Direct(I32), GuestAddress, Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "fd_readdir",
      #|    [Direct(I32), GuestAddress, Direct(I32), Direct(I64), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_sync", [Direct(I32)], Direct(I32), Io),
      #|  ("fd_datasync", [Direct(I32)], Direct(I32), Io),
      #|  (
      #|    "path_unlink_file",
      #|    [Direct(I32), GuestAddress, Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_remove_directory",
      #|    [Direct(I32), GuestAddress, Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_rename",
      #|    [
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_filestat_get", [Direct(I32), GuestAddress], Direct(I32), Io),
      #|  (
      #|    "path_filestat_get",
      #|    [Direct(I32), Direct(I32), GuestAddress, Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_filestat_set_size", [Direct(I32), Direct(I64)], Direct(I32), Io),
      #|  (
      #|    "fd_filestat_set_times",
      #|    [Direct(I32), Direct(I64), Direct(I64), Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_filestat_set_times",
      #|    [
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      Direct(I64),
      #|      Direct(I64),
      #|      Direct(I32),
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "fd_advise",
      #|    [Direct(I32), Direct(I64), Direct(I64), Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "fd_allocate",
      #|    [Direct(I32), Direct(I64), Direct(I64)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_fdstat_set_flags", [Direct(I32), Direct(I32)], Direct(I32), Io),
      #|  (
      #|    "fd_fdstat_set_rights",
      #|    [Direct(I32), Direct(I64), Direct(I64)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("fd_renumber", [Direct(I32), Direct(I32)], Direct(I32), Io),
      #|  (
      #|    "path_symlink",
      #|    [GuestAddress, Direct(I32), Direct(I32), GuestAddress, Direct(I32)],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_readlink",
      #|    [
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      GuestAddress,
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "path_link",
      #|    [
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "poll_oneoff",
      #|    [GuestAddress, GuestAddress, Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "sock_recv",
      #|    [
      #|      Direct(I32),
      #|      GuestAddress,
      #|      Direct(I32),
      #|      Direct(I32),
      #|      GuestAddress,
      #|      GuestAddress,
      #|    ],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  (
      #|    "sock_send",
      #|    [Direct(I32), GuestAddress, Direct(I32), Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|  ("sock_shutdown", [Direct(I32), Direct(I32)], Direct(I32), Io),
      #|  ("proc_raise", [Direct(I32)], Direct(I32), Io),
      #|  (
      #|    "sock_accept",
      #|    [Direct(I32), Direct(I32), GuestAddress],
      #|    Direct(I32),
      #|    Io,
      #|  ),
      #|]
    ),
  )
}

///|
test "guest address contracts project to the exact core Wasm signature" {
  assert_eq(
    wasi_preview1_import("fd_write").unwrap().contract().core_contract(),
    {
      module_name: "wasi_snapshot_preview1",
      field_name: "fd_write",
      parameters: [Direct(I32), Direct(I32), Direct(I32), Direct(I32)],
      result: Direct(I32),
    },
  )
}

///|
test "WASI Preview 1 catalog snapshots do not share mutable contracts" {
  let first = wasi_preview1_import("args_get").unwrap().contract()
  first.parameters.clear()
  assert_eq(wasi_preview1_import("args_get").unwrap().contract().parameters, [
    GuestAddress,
    GuestAddress,
  ])
}
