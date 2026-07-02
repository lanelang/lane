///|
fn int_type() -> @buslane.Type {
  Primitive(Int)
}

///|
test "runtime reports unhandled operation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [int_type()],
    int_type(),
  )
  let error = try {
    ignore(
      evaluate_buslane_expr(
        Perform({
          operation: print,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [Literal(Int(1L))],
        }),
        BuslaneRuntimeEnvironment(),
        BuslaneExternalRuntime(),
      ),
    )
    abort("expected unhandled operation")
  } catch {
    error => error
  }
  inspect(
    @prettyprinter.render(error, width=100),
    content="unhandled_operation operation#0",
  )
}
