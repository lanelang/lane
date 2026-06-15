///|
let prelude_path : String = "lane-std/prelude.lane"

///|
#cfg(any(target="native", target="llvm"))
extern "c" fn native_exit(code : Int) = "exit"

///|
fn read_source_file(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8")
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
