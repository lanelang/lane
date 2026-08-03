///|
/// Initialization order is derived from dependencies, so a value initializer
/// may reach a value declared after it by calling a function — the one form
/// of forward reference the language admits, since functions may forward
/// reference and values may not.
test "initializers run after the values they reach through functions" {
  let source =
    #|module Test
    #|fn read_later() -> I64 {
    #|  later
    #|}
    #|pub let eager : I64 = read_later()
    #|pub let later : I64 = 7
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the module to check")
  }
}

///|
test "a value initialization cycle is a compile error" {
  let source =
    #|module Test
    #|fn read_second() -> I64 {
    #|  second
    #|}
    #|fn read_first() -> I64 {
    #|  first
    #|}
    #|pub let first : I64 = read_second()
    #|pub let second : I64 = read_first()
  let diagnostic = single_check_diagnostic(source)
  assert_diagnostic_headline(
    diagnostic, "E4004", "initialization cycle between `first`, `second`",
  )
  assert_single_help(
    diagnostic, "break the cycle by moving the shared computation into a function each initializer calls",
  )
}

///|
test "mutual recursion between functions is not an initialization cycle" {
  let source =
    #|module Test
    #|fn ping(n : I64) -> I64 {
    #|  pong(n)
    #|}
    #|fn pong(n : I64) -> I64 {
    #|  ping(n)
    #|}
    #|pub let started : I64 = ping(0)
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected mutual recursion to check")
  }
}

///|
test "a value may not name a later value directly" {
  let source =
    #|module Test
    #|pub let y : I64 = x
    #|pub let x : I64 = 1
  assert_diagnostic_headline(
    single_check_diagnostic(source),
    "E2001",
    "cannot find value `x`",
  )
}
