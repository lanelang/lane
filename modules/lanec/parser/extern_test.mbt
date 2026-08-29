///|
test "parse extern expression as a distinct source form" {
  let result = parse_string(
    "module Test\nlet host : (I64) -> Unit ! Io = extern(\"lane.test\", \"println\")",
  )
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  guard file.declarations[0]
    is Let({ initializer: Extern(module_name~, field_name~, ..), .. }) else {
    abort("expected extern initializer")
  }
  assert_eq((module_name, field_name), ("lane.test", "println"))
}
