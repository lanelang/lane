///|
pub(all) enum WasiPreview1Effect {
  Io
  Panic
} derive(Debug, Eq)

///|
pub struct WasiPreview1Import {
  priv contract : ImportContract
  priv effect : WasiPreview1Effect
} derive(Debug, Eq)

///|
fn wasi_preview1_binding(
  field_name : String,
  parameters : Array[ImportParameter],
  result : ImportResult,
  effect : WasiPreview1Effect,
) -> WasiPreview1Import {
  {
    contract: {
      module_name: "wasi_snapshot_preview1",
      field_name,
      parameters,
      result,
    },
    effect,
  }
}

///|
pub fn WasiPreview1Import::contract(
  self : WasiPreview1Import,
) -> ImportContract {
  self.contract.snapshot()
}

///|
pub fn WasiPreview1Import::effect(
  self : WasiPreview1Import,
) -> WasiPreview1Effect {
  self.effect
}

///|
pub fn WasiPreview1Import::field_name(self : WasiPreview1Import) -> String {
  self.contract.field_name
}

///|
pub fn wasi_preview1_imports() -> Array[WasiPreview1Import] {
  let i32 = ImportParameter::Direct(I32)
  let i64 = ImportParameter::Direct(I64)
  let errno = ImportResult::Direct(I32)
  [
    wasi_preview1_binding(
      "fd_write",
      [i32, GuestAddress, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "fd_read",
      [i32, GuestAddress, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "args_sizes_get",
      [GuestAddress, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("args_get", [GuestAddress, GuestAddress], errno, Io),
    wasi_preview1_binding(
      "environ_sizes_get",
      [GuestAddress, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "environ_get",
      [GuestAddress, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("proc_exit", [i32], Unit, Panic),
    wasi_preview1_binding("clock_time_get", [i32, i64, GuestAddress], errno, Io),
    wasi_preview1_binding("fd_prestat_get", [i32, GuestAddress], errno, Io),
    wasi_preview1_binding(
      "fd_prestat_dir_name",
      [i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_close", [i32], errno, Io),
    wasi_preview1_binding("random_get", [GuestAddress, i32], errno, Io),
    wasi_preview1_binding("fd_seek", [i32, i64, i32, GuestAddress], errno, Io),
    wasi_preview1_binding("fd_tell", [i32, GuestAddress], errno, Io),
    wasi_preview1_binding(
      "fd_pread",
      [i32, GuestAddress, i32, i64, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "fd_pwrite",
      [i32, GuestAddress, i32, i64, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_open",
      [i32, i32, GuestAddress, i32, i32, i64, i64, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_fdstat_get", [i32, GuestAddress], errno, Io),
    wasi_preview1_binding("clock_res_get", [i32, GuestAddress], errno, Io),
    wasi_preview1_binding("sched_yield", [], errno, Io),
    wasi_preview1_binding(
      "path_create_directory",
      [i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "fd_readdir",
      [i32, GuestAddress, i32, i64, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_sync", [i32], errno, Io),
    wasi_preview1_binding("fd_datasync", [i32], errno, Io),
    wasi_preview1_binding(
      "path_unlink_file",
      [i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_remove_directory",
      [i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_rename",
      [i32, GuestAddress, i32, i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_filestat_get", [i32, GuestAddress], errno, Io),
    wasi_preview1_binding(
      "path_filestat_get",
      [i32, i32, GuestAddress, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_filestat_set_size", [i32, i64], errno, Io),
    wasi_preview1_binding(
      "fd_filestat_set_times",
      [i32, i64, i64, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_filestat_set_times",
      [i32, i32, GuestAddress, i32, i64, i64, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding("fd_advise", [i32, i64, i64, i32], errno, Io),
    wasi_preview1_binding("fd_allocate", [i32, i64, i64], errno, Io),
    wasi_preview1_binding("fd_fdstat_set_flags", [i32, i32], errno, Io),
    wasi_preview1_binding("fd_fdstat_set_rights", [i32, i64, i64], errno, Io),
    wasi_preview1_binding("fd_renumber", [i32, i32], errno, Io),
    wasi_preview1_binding(
      "path_symlink",
      [GuestAddress, i32, i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_readlink",
      [i32, GuestAddress, i32, GuestAddress, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "path_link",
      [i32, i32, GuestAddress, i32, i32, GuestAddress, i32],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "poll_oneoff",
      [GuestAddress, GuestAddress, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "sock_recv",
      [i32, GuestAddress, i32, i32, GuestAddress, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding(
      "sock_send",
      [i32, GuestAddress, i32, i32, GuestAddress],
      errno,
      Io,
    ),
    wasi_preview1_binding("sock_shutdown", [i32, i32], errno, Io),
    wasi_preview1_binding("proc_raise", [i32], errno, Io),
    wasi_preview1_binding("sock_accept", [i32, i32, GuestAddress], errno, Io),
  ]
}

///|
pub fn wasi_preview1_import(field_name : String) -> WasiPreview1Import? {
  for import_ in wasi_preview1_imports() {
    if import_.field_name() == field_name {
      return Some(import_)
    }
  }
  None
}

///|
pub fn ImportContract::wasi_preview1_import(
  self : ImportContract,
) -> WasiPreview1Import? {
  for import_ in wasi_preview1_imports() {
    if import_.contract() == self {
      return Some(import_)
    }
  }
  None
}

///|
pub fn wasi_preview1_contract(field_name : String) -> ImportContract? {
  wasi_preview1_import(field_name).map(WasiPreview1Import::contract)
}
