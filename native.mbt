///|
let prelude_file_name : String = "prelude.lane"

///|
#cfg(any(target="native", target="llvm"))
extern "c" fn native_exit(code : Int) = "exit"

///|
fn read_source_file(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8")
}

///|
fn read_prelude(stdlib : String?) -> String raise {
  read_source_file(prelude_path(stdlib))
}

///|
fn prelude_path(stdlib : String?) -> String {
  stdlib_root(stdlib) + "/" + prelude_file_name
}

///|
fn stdlib_root(stdlib : String?) -> String {
  match stdlib {
    Some(root) => root
    None =>
      match @sys.get_env_var("LANE_STDLIB") {
        Some(root) => root
        None => default_stdlib_root()
      }
  }
}

///|
fn default_stdlib_root() -> String {
  match @sys.get_env_var("HOME") {
    Some(home) => home + "/.lane/lib"
    None => ".lane/lib"
  }
}

///|
fn exit_success() -> Unit {
  native_exit(0)
}

///|
fn exit_failure() -> Unit {
  native_exit(1)
}

///|
fn[T] fail_with_message(message : String) -> T {
  println(message)
  exit_failure()
  abort(message)
}
