///|
let prelude_file_name : String = "prelude.lane"

///|
fn read_prelude(stdlib : String?) -> String raise {
  @fs.read_file_to_string(prelude_path(stdlib), encoding="utf8")
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
