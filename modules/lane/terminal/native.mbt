///|
extern "C" fn terminal_is_tty_ffi(fd : Int) -> Int = "lane_terminal_is_tty"

///|
extern "C" fn terminal_width_ffi(fd : Int) -> Int = "lane_terminal_width"

///|
fn terminal_is_tty(fd : Int) -> Bool {
  terminal_is_tty_ffi(fd) != 0
}

///|
fn terminal_width(fd : Int) -> Int? {
  let width = terminal_width_ffi(fd)
  if width > 0 {
    Some(width)
  } else {
    None
  }
}
