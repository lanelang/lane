///|
test "parse extern expression as a distinct source form" {
  let result = parse_string(
    "module Test\nlet host : (String) -> Unit ! Io = extern(\"println\")",
  )
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  guard file.declarations[0]
    is @syntax.Let({ initializer: Extern(name, ..), .. }) else {
    abort("expected extern initializer")
  }
  inspect(name, content="println")
}
